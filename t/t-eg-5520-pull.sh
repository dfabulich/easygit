#!/bin/sh

test_description="tests of eg's pulling behavior"

. ./test-lib.sh

D=`pwd`
fgit="--git-dir=pullfrom/.git"
tgit="--git-dir=pullto/.git"

# Notes:
#   git pull URL    : pulls from HEAD (not master or whatever, but HEAD)
#   git pull REMOTE : whine if branch.*.remote!=REMOTE || branch.*.merge unset
#   git pull        : needs branch.*.(merge|remote)
#
#   Weird:
#     'git pull' or 'git pull origin' with origin set and branch.*.merge
#      set correctly pulls from the origin repository (though listing url)
#      and then whines:
#         From file:///home/newren/otherhome/eg/t/trash directory....
#            07c68b0..3ad2682  bugfix     -> origin/bugfix
#         Your configuration specifies to merge the ref 'bugfix' from the
#         remote, but no such ref was fetched.
#      not knowing what to merge, asking the user to set
#      branch.master.merge, which is already set.
#   

# Cases:
#   Plain pull (origin defined, unless otherwise specified):
#     Into void
#     Into non-void, origin not specified
#     only branch.*.remote setup
#     only branch.*.merge setup
#     only branch.*.merge setup & origin not defined
#     remote side has one branch
#     remote side has two branches
#   Pull w/ repo arg: (repeat for repo = remote & repo = url??)
#     Into void
#     only branch.*.remote setup
#     only branch.*.merge setup
#     fully setup, but mismatch of branch.*.remote
#     remote side has one branch
#     remote side has two branches
#   Pull w/ --branch arg:
#     Into void
#     only branch.*.remote setup
#     only branch.*.merge setup
#     only branch.*.merge setup & origin not defined
#     remote side has one branch
#     remote side has two branches

mk_repo_pair () {
	rm -rf pullfrom pullto &&
	mkdir pullto &&
	(
		cd pullto &&
		git init -q &&
		git remote add origin ../pullfrom
	) &&
	mkdir pullfrom &&
	(
		cd pullfrom &&
		git init -q &&
		git symbolic-ref HEAD refs/heads/newbranch &&
		echo one >foo && git add foo && git commit -q -m one &&
		git symbolic-ref HEAD refs/heads/bugfix &&
		rm .git/index &&
		rm foo &&
		echo content >bar && git add bar && git commit -q -m stuff
	)
}

verify_pulled () {
	remote_b=$1 &&
	num_branches=$2 &&
	t_master=$(git $tgit rev-parse refs/heads/master) &&
	test_must_fail git $tgit show-ref -q -s --verify refs/heads/newbranch &&
	test_must_fail git $tgit show-ref -q -s --verify refs/heads/bugfix &&
	echo git $fgit show-ref -s --verify refs/heads/$remote_b &&
	f_remote=$(git $fgit show-ref -s --verify refs/heads/$remote_b) &&
	test "$t_master" = "$f_remote" &&
	test $(git $tgit show-ref --head | wc -l) = "$num_branches"
}

test_expect_success 'pulling with direct URL' '
	mk_repo_pair &&
	(
		cd pullto &&
		git pull ../pullfrom   # will merge from HEAD=bugfix
	) &&
	verify_pulled bugfix 2
'

cat > expect << EOF
Aborting: No repository specified, and "origin" is not set up as a remote
repository.  Please specify a repository or setup "origin" by running
  eg remote add origin URL
EOF

test_expect_success 'pull w/o origin setup and no branch.$branch.remote' '
	mk_repo_pair &&
	(
		cd pullto &&
		echo hi > world && git add world && git commit -m commitone &&
		git remote rm origin &&
		test_must_fail git pull > actual 2>&1
	) &&
	test_cmp expect pullto/actual
'

cat > expect << EOF
Aborting: It is not clear which remote branch to pull changes from.  Please
retry, specifying which branch(es) you want to be merged into your current
branch.  Existing remote branches of
  origin
are
  bugfix newbranch
EOF

test_expect_success 'pull w/o active branch & >1 remote branch' '
	mk_repo_pair &&
	(
		cd pullto &&
		echo hi > world && git add world && git commit -m commitone &&
		git checkout HEAD^{commit} &&
		test_must_fail git pull > actual 2>&1
	) &&
	test_cmp expect pullto/actual
'

test_expect_success 'pull when branch.$branch.remote unset & >1 remote branch' '
	mk_repo_pair &&
	(
		cd pullto &&
		test_must_fail git pull > actual 2>&1
	) &&
	test_cmp expect pullto/actual
'

test_expect_success 'pull when repo!=branch.$branch.remote & >1 remote branch' '
	mk_repo_pair &&
	(
		cd pullto &&
		git remote add foo ../pullfrom &&
		git config branch.master.remote foo &&
		git config branch.master.merge refs/heads/bugfix &&
		test_must_fail git pull origin > actual 2>&1
	) &&
	test_cmp expect pullto/actual
'

cat > expect << EOF
fatal: 'foobarbaz' does not appear to be a git repository
fatal: The remote end hung up unexpectedly
Aborting: Could not determine remote branches from repository 'foo'
EOF

test_expect_success 'pull when repo is bad remote' '
	mk_repo_pair &&
	(
		cd pullto &&
		git remote add foo foobarbaz &&
		test_must_fail git pull foo > actual 2>&1
	) &&
	test_cmp expect pullto/actual
'

cat > expect << EOF
Aborting: It is not clear which remote branch to pull changes from.  Please
retry, specifying which branch(es) you want to be merged into your current
branch.  Existing remote branches of
  foo
are
  bugfix newbranch
EOF

test_expect_success 'pull when repo!=branch.$branch.remote & >1 remote branch' '
	mk_repo_pair &&
	(
		cd pullto &&
		git remote add foo ../pullfrom &&
		git config branch.master.remote origin &&
		git config branch.master.merge refs/heads/bugfix &&
		test_must_fail git pull foo > actual 2>&1
	) &&
	test_cmp expect pullto/actual
'

test_expect_success 'pull when branch.$branch.merge unset & >1 remote branch' '
	mk_repo_pair &&
	(
		cd pullto &&
		git remote add foo ../pullfrom &&
		git config branch.master.remote origin &&
		test_must_fail git pull foo > actual 2>&1
	) &&
	test_cmp expect pullto/actual
'

test_expect_success 'pull when everything setup' '
	mk_repo_pair &&
	(
		cd pullto &&
		git remote add foo ../pullfrom &&
		git config branch.master.remote foo &&
		git config branch.master.merge refs/heads/bugfix &&
		git pull
	) &&
	verify_pulled bugfix 4
'

nuke_branch () {
	killit=$1 &&
	git $fgit branch -D $killit
}

test_expect_success 'pull w/o active branch & 1 remote branch' '
	mk_repo_pair &&
	nuke_branch newbranch
	(
		cd pullto &&
		echo hi > world && git add world && git commit -m commitone &&
		git checkout HEAD^{commit} &&
		git pull
	) &&
	test $(git $tgit rev-list --grep=Merge HEAD | wc -l) = "1"
'

test_expect_success 'pull when branch.$branch.remote unset & 1 remote branch' '
	mk_repo_pair &&
	nuke_branch newbranch
	(
		cd pullto &&
		git pull
	) &&
	verify_pulled bugfix 2
'

test_expect_success 'pull when repo!=branch.$branch.remote & 1 remote branch' '
	mk_repo_pair &&
	nuke_branch newbranch
	(
		cd pullto &&
		git remote add foo ../pullfrom &&
		git config branch.master.remote foo &&
		git config branch.master.merge refs/heads/bugfix &&
		git pull origin
	) &&
	verify_pulled bugfix 2
'

test_expect_success 'pull when repo!=branch.$branch.remote & 1 remote branch' '
	mk_repo_pair &&
	nuke_branch newbranch
	(
		cd pullto &&
		git remote add foo ../pullfrom &&
		git config branch.master.remote origin &&
		git config branch.master.merge refs/heads/bugfix &&
		git pull foo
	) &&
	verify_pulled bugfix 2
'

test_expect_success 'pull when branch.$branch.merge unset & 1 remote branch' '
	mk_repo_pair &&
	nuke_branch newbranch
	(
		cd pullto &&
		git remote add foo ../pullfrom &&
		git config branch.master.remote origin &&
		git pull foo
	) &&
	verify_pulled bugfix 2
'

cat > expect << EOF
Aborting: No repository specified, and "origin" is not set up as a remote
repository.  Please specify a repository or setup "origin" by running
  eg remote add origin URL
EOF

test_expect_success 'pull with --branch, no repo specified' '
	mk_repo_pair &&
	(
		cd pullto &&
		git remote rm origin &&
		test_must_fail git pull --branch newbranch > actual 2>&1
	) &&
	test_cmp expect pullto/actual
'

test_expect_success 'pull with --branch, using default of origin' '
	mk_repo_pair &&
	(
		cd pullto &&
		git pull --branch newbranch
	) &&
	verify_pulled newbranch 2
'

test_done
