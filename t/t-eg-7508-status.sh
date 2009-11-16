#!/bin/sh
#
# Copyright (c) 2007 Johannes E. Schindelin
# Modified 2009 Elijah Newren
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
	git add dir2/added
'

cat > expect << \EOF
(On branch master)
Changes ready to be committed ("staged"):
	new file:   dir2/added
Changed but not updated ("unstaged"):
	modified:   dir1/modified
Newly created unknown files:
	dir1/untracked
	dir2/modified
	dir2/untracked
	expect
	untracked
Unknown files:
	output
EOF

test_expect_success 'status (2)' '

	git status > output 2>&1 &&
	test_cmp expect output

'

cat >expect <<EOF
(On branch master)
Changes ready to be committed ("staged"):
	new file:   dir2/added
Changed but not updated ("unstaged"):
	modified:   dir1/modified
EOF
test_expect_success 'status -uno' '
	mkdir dir3 &&
	: > dir3/untracked1 &&
	: > dir3/untracked2 &&
	git status -uno >output 2>&1 &&
	test_cmp expect output
'

test_expect_success 'status (status.showUntrackedFiles no)' '
	git config status.showuntrackedfiles no
	git status >output 2>&1 &&
	test_cmp expect output
'

cat >expect <<EOF
(On branch master)
Changes ready to be committed ("staged"):
	new file:   dir2/added
Changed but not updated ("unstaged"):
	modified:   dir1/modified
Newly created unknown files:
	dir1/untracked
	dir2/modified
	dir2/untracked
	dir3/
	expect
	untracked
Unknown files:
	output
EOF
test_expect_success 'status -unormal' '
	git status -unormal >output 2>&1 &&
	test_cmp expect output
'

test_expect_success 'status (status.showUntrackedFiles normal)' '
	git config status.showuntrackedfiles normal
	git status >output 2>&1 &&
	test_cmp expect output
'

cat >expect <<EOF
(On branch master)
Changes ready to be committed ("staged"):
	new file:   dir2/added
Changed but not updated ("unstaged"):
	modified:   dir1/modified
Newly created unknown files:
	dir1/untracked
	dir2/modified
	dir2/untracked
	dir3/untracked1
	dir3/untracked2
	expect
	untracked
Unknown files:
	output
EOF
test_expect_success 'status -uall' '
	git status -uall >output 2>&1 &&
	test_cmp expect output
'
test_expect_success 'status (status.showUntrackedFiles all)' '
	git config status.showuntrackedfiles all
	git status >output 2>&1 &&
	rm -rf dir3 &&
	git config --unset status.showuntrackedfiles &&
	test_cmp expect output
'

cat > expect << \EOF
(On branch master)
Changes ready to be committed ("staged"):
	new file:   ../dir2/added
Changed but not updated ("unstaged"):
	modified:   modified
Newly created unknown files:
	untracked
	../dir2/modified
	../dir2/untracked
	../expect
	../untracked
Unknown files:
	../output
EOF

test_expect_success 'status with relative paths' '

	(cd dir1 && git status) > output 2>&1 &&
	test_cmp expect output

'

cat > expect << \EOF
(On branch master)
Changes ready to be committed ("staged"):
	new file:   dir2/added
Changed but not updated ("unstaged"):
	modified:   dir1/modified
Newly created unknown files:
	dir1/untracked
	dir2/modified
	dir2/untracked
	expect
	output
	untracked
EOF

test_expect_success 'status without relative paths' '

	git config status.relativePaths false
	(cd dir1 && git status) > output 2>&1 &&
	test_cmp expect output

'

cat <<EOF >expect
(On branch master)
Changes ready to be committed ("staged"):
	modified:   dir1/modified
Newly created unknown files:
	dir1/untracked
	dir2/
	expect
	untracked
Unknown files:
	output
EOF
test_expect_success 'status of partial commit excluding new file in index' '
	git status dir1/modified >output 2>&1 &&
	test_cmp expect output
'

test_expect_success 'setup status submodule summary' '
	test_create_repo sm && (
		cd sm &&
		>foo &&
		git add foo &&
		git commit -m "Add foo"
	) &&
	git add sm
'

cat >expect <<EOF
(On branch master)
Changes ready to be committed ("staged"):
	new file:   dir2/added
	new file:   sm
Changed but not updated ("unstaged"):
	modified:   dir1/modified
Newly created unknown files:
	dir1/untracked
	dir2/modified
	dir2/untracked
	expect
	untracked
Unknown files:
	output
EOF
test_expect_success 'status submodule summary is disabled by default' '
	git status >output 2>&1 &&
	test_cmp expect output
'

# we expect the same as the previous test
test_expect_success 'status --untracked-files=all does not show submodule' '
	git status --untracked-files=all >output 2>&1 &&
	test_cmp expect output
'

head=$(cd sm && git rev-parse --short=7 --verify HEAD)

cat >expect <<EOF
(On branch master)
Changes ready to be committed ("staged"):
	new file:   dir2/added
	new file:   sm
Changed but not updated ("unstaged"):
	modified:   dir1/modified
Modified submodules:
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
Changed but not updated ("unstaged"):
	modified:   dir1/modified
Newly created unknown files:
	dir1/untracked
	dir2/modified
	dir2/untracked
	expect
	untracked
Unknown files:
	output
EOF
test_expect_success 'status submodule summary (clean submodule)' '
	git commit --staged -m "commit submodule" &&
	git config status.submodulesummary 10 &&
	test_must_fail git status >output 2>&1 &&
	test_cmp expect output
'

cat >expect <<EOF
(On branch master)
Changes ready to be committed ("staged"):
	new file:   dir2/added
	new file:   sm
Changed but not updated ("unstaged"):
	modified:   dir1/modified
Modified submodules:
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
test_expect_success 'status submodule summary (--amend)' '
	git config status.submodulesummary 10 &&
	git status --amend >output 2>&1 &&
	test_cmp expect output
'

cat >expect <<EOF
(On branch master)
Changes ready to be committed ("staged"):
	[32mmodified:   dir2/added[m
Unmerged paths (files with conflicts):
	[31mboth modified:      file[m
	[31mdeleted by us:      file2[m
Changed but not updated ("unstaged"):
	[31mmodified:   dir1/modified[m
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
