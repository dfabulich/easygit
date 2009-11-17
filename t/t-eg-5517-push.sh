#!/bin/sh

test_description="tests of eg's pushing behavior"

. ./test-lib.sh

D=`pwd`

invert () {
	if "$@"; then
		return 1
	else
		return 0
	fi
}

mk_repo_pair () {
	rm -rf pushfrom pushto &&
	mkdir pushto &&
	(
		cd pushto &&
		git init --bare
	) &&
	mkdir pushfrom &&
	(
		cd pushfrom &&
		git init &&
		git remote add $1 origin ../pushto
	)
}


# BRANCH tests
test_expect_success 'setup' '

	mk_repo_pair &&
	cd pushfrom &&
	echo one >foo && git add foo && git commit -m one
'

cat > expect << EOF
Aborting: You have unresolved conflicts from your merge (run 'eg status' to get
the list of files with conflicts).  You should first resolve any conflicts
before trying to push your work elsewhere.
EOF

cat > unmerge-info <<EOF
0 0000000000000000000000000000000000000000	foo
100644 8a1218a1024a212bb3db30becd860315f9f3ac52 1	foo
100755 8a1218a1024a212bb3db30becd860315f9f3ac52 2	foo
EOF

test_expect_success 'unmerged files present prevents push' '
	cat unmerge-info | git update-index --index-info &&
	test_must_fail git push origin master > actual 2>&1 &&
	test_cmp expect actual
'

test_expect_success 'unmerged check bypassed by -b' '
	git push -b origin master
'

cat > expect << EOF
Aborting: You have new unknown files and changed files present.  You should
first commit any such changes (and/or use the -b flag to bypass this check)
before trying to push your work elsewhere.
New unknown files:
  newfile
EOF

test_expect_success 'new unknown and changed files prevents push' '
	git reset -q --hard HEAD &&
	git --git-dir=../pushto update-ref -d refs/heads/master
	echo content >> foo &&
	touch newfile &&
	test_must_fail git push origin master > actual 2>&1 &&
	test_cmp expect actual
'

cat > expect << EOF
Aborting: You have new unknown files present.  You should either commit these
new files before trying to push your work elsewhere, or use the
-b flag to bypass this check.
New unknown files:
  newfile
EOF

test_expect_success 'new unknown files prevents push' '
	git revert foo &&
	test_must_fail git push origin master > actual 2>&1 &&
	test_cmp expect actual &&
	rm newfile
'

cat > expect << EOF
Aborting: You have modified your files since the last commit.  You should
first commit any such changes before trying to push your work
elsewhere, or use the -b flag to bypass this check.
EOF

test_expect_success 'modified files prevents push' '
	echo content >> foo &&
	test_must_fail git push origin master > actual 2>&1 &&
	test_cmp expect actual
'

test_expect_success 'unmerged/modified/newfile checks bypassed by -b' '
	cat unmerge-info | git update-index --index-info &&
	touch newfile &&
	git push -b origin master &&
	git reset --hard HEAD &&
	rm newfile
'

cd ..
cat > expect <<EOF
Aborting: You are trying to push to a repository with an associated working
copy, which will leave its working copy out of sync with its repository.
Rather than pushing changes to that repository, you should go to where that
repository is located and pull changes into it (using eg pull).  If you
know what you are doing and know how to deal with the consequences, you can
override this check by explicitly specifying source and destination
references, e.g.
  eg push REMOTE BRANCH:REMOTE_BRANCH
Please refer to
  eg help topic refspecs
to learn what this syntax means and what the consequences of overriding this
check are.
EOF

test_expect_success 'push into non-bare repo fails without full refspec' '
	mk_repo_pair &&
	(
		mkdir non-bare-repo &&
		cd non-bare-repo &&
		git init &&
		cd ../pushfrom &&
		echo one >foo && git add foo && git commit -m one &&
		git push origin master &&
		echo hello > world && git add world && git commit -mnewcommit
	) &&
	cd pushfrom &&
	test_must_fail git push ../non-bare-repo master > ../actual 2>&1 &&
	test_cmp ../expect ../actual
'

test_expect_success 'push into non-bare repo succeeds with full refspec' '
	git push ../non-bare-repo master:fooish &&
	mymaster=$(git show-ref -s --verify refs/heads/master) &&
	other=$(git --git-dir=../non-bare-repo/.git show-ref -s --verify refs/heads/fooish) &&
	test "$mymaster" = "$other" &&
	cd ..
'

test_expect_success 'push defaults to tracking branch when push.default unset' '
	mk_repo_pair &&
	cd pushfrom &&
	(
		echo one >foo && git add foo && git commit -m one &&
		git push origin master &&
		git push origin master:trackme &&
		echo hello > world && git add world && git commit -mnewcommit &&
		git config branch.master.merge refs/heads/trackme
	) &&
	git push &&
	(
		mymaster=$(git show-ref -s --verify refs/heads/master) &&
		origin_master=$(git --git-dir=../pushto show-ref -s --verify refs/heads/master) &&
		origin_trackme=$(git --git-dir=../pushto show-ref -s --verify refs/heads/trackme) &&
		test "$mymaster" != "$origin_master" &&
		test "$mymaster" =  "$origin_trackme"
	) &&
	cd ..
'

push_setup () {
	mk_repo_pair &&
	cd pushfrom &&
	(
		echo one >foo && git add foo && git commit -m one &&
		git push origin master &&
		git push origin master:trackme &&
		git fetch origin trackme:trackme &&
		git checkout trackme &&
		echo hi > abc && git add abc && git commit -m greeting &&
		git checkout master &&
		echo hello > world && git add world && git commit -mnewcommit &&
		git track origin/trackme &&
		git branch foobranch
	) &&
	cd ..
}

test_expect_success 'push obeys push.default=matching' '
	push_setup &&
	cd pushfrom &&
	git config push.default matching &&
	git push &&
	(
		mymaster=$(git show-ref -s --verify refs/heads/master) &&
		mytrackme=$(git show-ref -s --verify refs/heads/trackme) &&
		myfoobranch=$(git show-ref -s --verify refs/heads/foobranch) &&
		origin_master=$(git --git-dir=../pushto show-ref -s --verify refs/heads/master) &&
		origin_trackme=$(git --git-dir=../pushto show-ref -s --verify refs/heads/trackme) &&
		test_must_fail git --git-dir=../pushto show-ref --quiet --verify refs/heads/foobranch &&
		test "$mymaster"  = "$origin_master" &&
		test "$mytrackme" = "$origin_trackme"
	) &&
	cd ..
'

cat > expect <<EOF
fatal: You didn't specify any refspecs to push, and push.default is "nothing".
EOF

test_expect_success 'push obeys push.default=nothing' '
	push_setup &&
	cd pushfrom &&
	git config push.default nothing &&
	test_must_fail git push > ../actual 2>&1 &&
	test_cmp ../expect ../actual &&
	cd ..
'

test_expect_success 'push obeys push.default=tracking' '
	push_setup &&
	cd pushfrom &&
	git config push.default tracking &&
	git push &&
	(
		myoldmaster=$(git rev-parse refs/heads/master~1) &&
		mymaster=$(git show-ref -s --verify refs/heads/master) &&
		mytrackme=$(git show-ref -s --verify refs/heads/trackme) &&
		myfoobranch=$(git show-ref -s --verify refs/heads/foobranch) &&
		origin_master=$(git --git-dir=../pushto show-ref -s --verify refs/heads/master) &&
		origin_trackme=$(git --git-dir=../pushto show-ref -s --verify refs/heads/trackme) &&
		test_must_fail git --git-dir=../pushto show-ref --quiet --verify refs/heads/foobranch &&
		test "$mymaster"    = "$origin_trackme" &&
		test "$myoldmaster" = "$origin_master"
	) &&
	cd ..
'

test_expect_success 'push obeys push.default=current' '
	push_setup &&
	cd pushfrom &&
	git config push.default current &&
	git push &&
	(
		myoldmaster=$(git rev-parse refs/heads/master~1) &&
		mymaster=$(git show-ref -s --verify refs/heads/master) &&
		mytrackme=$(git show-ref -s --verify refs/heads/trackme) &&
		myfoobranch=$(git show-ref -s --verify refs/heads/foobranch) &&
		origin_master=$(git --git-dir=../pushto show-ref -s --verify refs/heads/master) &&
		origin_trackme=$(git --git-dir=../pushto show-ref -s --verify refs/heads/trackme) &&
		test_must_fail git --git-dir=../pushto show-ref --quiet --verify refs/heads/foobranch &&
		test "$mymaster"    = "$origin_master" &&
		test "$myoldmaster" = "$origin_trackme"
	) &&
	cd ..
'

test_expect_success '--matching-branches overrides push.default' '
	push_setup &&
	cd pushfrom &&
	git config push.default nothing &&
	git push --matching-branches &&
	(
		mymaster=$(git show-ref -s --verify refs/heads/master) &&
		mytrackme=$(git show-ref -s --verify refs/heads/trackme) &&
		myfoobranch=$(git show-ref -s --verify refs/heads/foobranch) &&
		origin_master=$(git --git-dir=../pushto show-ref -s --verify refs/heads/master) &&
		origin_trackme=$(git --git-dir=../pushto show-ref -s --verify refs/heads/trackme) &&
		test_must_fail git --git-dir=../pushto show-ref --quiet --verify refs/heads/foobranch &&
		test "$mymaster"  = "$origin_master" &&
		test "$mytrackme" = "$origin_trackme"
	) &&
	cd ..
'

test_expect_success '--all-branches overrides push.default' '
	push_setup &&
	cd pushfrom &&
	git config push.default nothing &&
	git push --all-branches &&
	(
		mymaster=$(git show-ref -s --verify refs/heads/master) &&
		mytrackme=$(git show-ref -s --verify refs/heads/trackme) &&
		myfoobranch=$(git show-ref -s --verify refs/heads/foobranch) &&
		origin_master=$(git --git-dir=../pushto show-ref -s --verify refs/heads/master) &&
		origin_trackme=$(git --git-dir=../pushto show-ref -s --verify refs/heads/trackme) &&
		origin_foobranch=$(git --git-dir=../pushto show-ref -s --verify refs/heads/foobranch) &&
		test "$mymaster"    = "$origin_master" &&
		test "$mytrackme"   = "$origin_trackme" &&
		test "$myfoobranch" = "$origin_foobranch"
	) &&
	cd ..
'

test_expect_success '--all-tags ignores push.default' '
	push_setup &&
	cd pushfrom &&
	git config push.default nothing &&
	git tag foobar master~1 &&
	git push --all-tags &&
	(
		myoldmaster=$(git rev-parse refs/heads/master~1) &&
		mymaster=$(git show-ref -s --verify refs/heads/master) &&
		myoldtrackme=$(git rev-parse refs/heads/trackme~1) &&
		mytrackme=$(git show-ref -s --verify refs/heads/trackme) &&
		myfoobranch=$(git show-ref -s --verify refs/heads/foobranch) &&
		myfoobar=$(git show-ref -s --verify refs/tags/foobar) &&
		origin_master=$(git --git-dir=../pushto show-ref -s --verify refs/heads/master) &&
		origin_trackme=$(git --git-dir=../pushto show-ref -s --verify refs/heads/trackme) &&
		test_must_fail git --git-dir=../pushto show-ref --quiet --verify refs/heads/foobranch &&
		origin_foobar=$(git --git-dir=../pushto show-ref -s --verify refs/tags/foobar) &&
		test "$myoldmaster"  = "$origin_master" &&
		test "$myoldtrackme" = "$origin_trackme" &&
		test "$myoldmaster"  = "$origin_foobar" &&
		test "$myfoobar"     = "$origin_foobar"
	) &&
	cd ..
'

test_expect_success 'specifying branch to push via --branch works' '
	push_setup &&
	cd pushfrom &&
	git config push.default nothing &&
	git push --branch master:magic &&
	(
		myoldmaster=$(git rev-parse refs/heads/master~1) &&
		mymaster=$(git show-ref -s --verify refs/heads/master) &&
		myoldtrackme=$(git rev-parse refs/heads/trackme~1) &&
		mytrackme=$(git show-ref -s --verify refs/heads/trackme) &&
		myfoobranch=$(git show-ref -s --verify refs/heads/foobranch) &&
		origin_master=$(git --git-dir=../pushto show-ref -s --verify refs/heads/master) &&
		origin_trackme=$(git --git-dir=../pushto show-ref -s --verify refs/heads/trackme) &&
		origin_magic=$(git --git-dir=../pushto show-ref -s --verify refs/heads/magic) &&
		test_must_fail git --git-dir=../pushto show-ref --quiet --verify refs/heads/foobranch &&
		test "$mymaster"     = "$origin_magic" &&
		test "$myoldmaster"  = "$origin_master" &&
		test "$myoldtrackme" = "$origin_trackme"
	) &&
	cd ..
'

test_done
