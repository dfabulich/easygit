#!/bin/sh
#
# Copyright (c) 2009,2010 Elijah Newren
#

test_description='eg status'

. ./test-lib.sh

test_expect_success 'setup' '
	: > tracked &&
	: > modified &&
	mkdir dir1 &&
	: > dir1/tracked &&
	: > dir1/modified &&
	mkdir dir2 &&
	: > dir1/tracked &&
	: > dir1/modified &&
	git add . &&

	git status >output &&

	test_tick &&
	git commit -b -m initial &&
	: > untracked &&
	: > dir1/untracked &&
	: > dir2/untracked &&
	echo 1 > dir1/modified &&
	echo 2 > dir2/modified &&
	echo 3 > dir2/added &&
	git add dir2/added &&

	test_create_repo sm && (
		cd sm &&
		>foo &&
		git add foo &&
		git commit -m "Add foo"
	) &&
	git add sm
'

head=$(cd sm && git rev-parse --short=7 --verify HEAD)
cat >expect <<EOF
(On branch master)
Changes ready to be committed ("staged"):
	new file:   dir2/added
	new file:   sm
Changed but not updated ("unstaged"):
	modified:   dir1/modified
Submodule changes to be committed:
* sm 0000000...$head (1):
  > Add foo
Newly created unknown files:
	dir1/untracked
	dir2/modified
	dir2/untracked
	expect
	untracked
Unknown files:
	output
EOF
test_expect_success 'status submodule summary' '
	git config status.submodulesummary 10 &&
	git status >output 2>&1 &&
	test_cmp expect output
'

cat >expect <<EOF
(On branch master)
Changes ready to be committed ("staged"):
	[32mnew file:   dir2/added[m
	[32mnew file:   sm[m
Unmerged paths (files with conflicts):
	[31mboth modified:      file[m
	[31mdeleted by us:      file2[m
Changed but not updated ("unstaged"):
	[31mmodified:   dir1/modified[m
Submodule changes to be committed:
* sm 0000000...$head (1):
  > Add foo
Newly created unknown files:
	[31mactual[m
	[31mdir1/untracked[m
	[31mdir2/modified[m
	[31mdir2/untracked[m
	[31mexpect[m
	[31mstageinfo[m
	[31muntracked[m
Unknown files:
	[31moutput[m
EOF

cat >stageinfo <<EOF
100644 5716ca5987cbf97d6bb54920bea6adde242d87e6 1	file
100644 76018072e09c5d31c8c6e3113b8aa0fe625195ca 2	file
100644 f3c8b75ec6e58bbba3511f8efa00057fb08a246e 3	file
100644 1fe912cdd835ae6be5feb79acafaa5fa8ea60f23 1	file2
100644 17375f7a12ef062f7cfbedfeb198042776c743e8 3	file2
EOF

test_expect_success 'eg parsing of colored git status output okay' '
	echo content > dir2/added &&
	git add dir2/added &&
	cat stageinfo | git update-index --index-info &&
	git config color.ui true &&
	TERM=$ORIGINAL_TERM GIT_PAGER_IN_USE=1 git status > actual 2>&1 &&
	test_cmp expect actual
'

test_done
