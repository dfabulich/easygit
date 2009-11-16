#!/bin/sh
#
# Copyright (c) 2007 Steven Grimm
#

test_description='eg commit

Tests for selected commit options.'

. ./test-lib.sh

commit_msg_is () {
	test "`git log --pretty=format:%s%b -1`" = "$1"
}

# A sanity check to see if commit is working at all.
test_expect_success 'a basic commit in an empty tree should succeed' '
	echo content > foo &&
	git add foo &&
	git commit -q -m "initial commit"
'

cat > expect << EOF
Aborting: Nothing to commit (run 'eg status' for details).
EOF

test_expect_success 'working copy clean' '
	test_must_fail git commit > actual 2>&1 &&
	test_cmp expect actual
'

cat > expect << EOF
Aborting: You have unresolved conflicts from your merge (run 'eg status' to get
the list of files with conflicts).  You must first resolve any conflicts and
then mark the relevant files as being ready for commit (see 'eg help stage' to
learn how to do so) before proceeding.
EOF

cat > unmerge-info <<EOF
0 0000000000000000000000000000000000000000	foo
100644 8a1218a1024a212bb3db30becd860315f9f3ac52 1	foo
100755 8a1218a1024a212bb3db30becd860315f9f3ac52 2	foo
EOF

test_expect_success 'unmerged files present prevents commit' '
	cat unmerge-info | git update-index --index-info &&
	test_must_fail git commit > actual 2>&1 &&
	test_cmp expect actual
'

test_expect_success 'unmerged files present prevents commit even with -a' '
	cat unmerge-info | git update-index --index-info &&
	test_must_fail git commit -a > actual 2>&1 &&
	test_cmp expect actual
'

cat > expect << EOF
Aborting: You have new unknown files present and it is not clear whether
they should be committed.  Run 'eg help commit' for details (in
particular the -b option).
New unknown files:
  actual
  expect
  unmerge-info
EOF

test_expect_success 'new unknown files' '
	git reset -q --hard HEAD &&
	echo content >> foo &&
	test_must_fail git commit > actual 2>&1 &&
	test_cmp expect actual
'

cat > expect << EOF
Aborting: It is not clear which changes should be committed; you have both
staged (explictly marked as ready for commit) changes and unstaged changes
present.  Run 'eg help commit' for details (in particular, the -a and
--staged options).
EOF

test_expect_success 'both staged and unstaged changes present' '
	git ls-files -o --exclude-standard > .git/info/ignored-unknown &&
	git add foo &&
	echo content >> foo &&
	test_must_fail git commit > actual 2>&1 &&
	test_cmp expect actual
'

cat > expect << EOF
Aborting: It is not clear which changes should be committed; you have new
unknown files, staged (explictly marked as ready for commit) changes, and
unstaged changes all present.  Run 'eg help commit' for details (in
particular, the -b option and either the -a or --staged options).
New unknown files:
  newfile.C
EOF

test_expect_success 'new unknowns and both staged and unstaged changes present' '
	touch newfile.C &&
	test_must_fail git commit > actual 2>&1 &&
	test_cmp expect actual
'

cat > expect << EOF
Aborting: It is not clear whether you want to simply amend the commit
message or whether you want to include your local changes in the amended
commit.  Please pass --staged to just amend the previous commit message, or
pass -a to include your current local changes with the previous amended
commit.
EOF

test_expect_success 'amend with unstaged changes' '
	git reset -q foo &&
	test_must_fail git commit -b --amend > actual 2>&1 &&
	test_cmp expect actual
'

test_expect_success 'amend with only staged changes' '
	git add foo &&
	git commit -q -b -mLameCommitMsg
'

test_expect_success 'amend in clean copy allowed' '
	git commit -q --amend -mCommitMsgThatsNoBetter
'

test_expect_success 'Alias --all-known for -a works' '
	echo content >> foo &&
	echo hello > world &&
	git add world &&
	git commit -q --all-known -mallknownworks
'

test_expect_success '--staged flag works' '
	echo content >> foo &&
	echo hello >> world &&
	git add world &&
	git commit -q --staged -mstagedworks &&
	test_must_fail git diff --quiet foo
'

test_expect_success '-d (--dirty) flag also works' '
	echo hello >> world &&
	git add foo &&
	git commit -q -d -mdirtyworks &&
	test_must_fail git diff --quiet world
'

test_expect_success '-F flag works' '
	echo "This is my commit message" > tempfile &&
	git ls-files -o --exclude-standard > .git/info/ignored-unknown &&
	git commit -q -F tempfile
'

test_done
