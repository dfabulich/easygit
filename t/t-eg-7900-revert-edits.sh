#!/bin/sh
#
# Copyright (c) 2009 Elijah Newren

test_description='git revert-edits'
. ./test-lib.sh

revert="git revert"
#revert="git revert-edits"

test_expect_success 'early setup' '
	echo hello > world &&
	git add world &&
	echo hi > there'

test_expect_success 'initial_commit-1' '
	$revert world &&
	test 0 = $(git ls-files | wc -l)
'

test_expect_code 128 'initial_commit-2' '
	$revert there
'

test_expect_code 1 'initial_commit-3' '
	$revert
'

test_expect_success 'setup' '
	git add world there &&
	test_tick &&
	git commit -m initial &&
	mkdir subdir &&
	echo -n "The launch code is 1-2-3-4." > subdir/secret &&
	git add subdir/secret &&
	test_tick &&
	git commit -m "Sssh.  Dont tell no one" &&
	echo A file that you cant trust > subdir/file.doc &&
	echo there >> world &&
	git add subdir/file.doc world &&
	test_tick &&
	echo -e "Random useless changes" | git commit -F - &&
	echo Do not use a preposition to end a setence with > advice &&
	git add advice &&
	test_tick &&
	git commit -m "hypocrisy is fun" &&
	echo Avoid cliches like the plague >> advice &&
	test_tick &&
	git commit -m "it is still fun advice" advice &&
	git rm there &&
	test_tick &&
	git commit -m "Removed there" &&
	echo "Four score and seven years ago" > subdir/file\ with\ spaces &&
	git add subdir/file\ with\ spaces &&
	test_tick &&
	git commit -m "Stupid file with spaces"
'

test_expect_success 'undo add' '
	cd subdir &&
	echo random > text &&
	git add text &&
	$revert text &&
	git diff --quiet HEAD
	cd ..
'

test_expect_success 'remove new file since given revision' '
	cd subdir &&
	$revert --since HEAD~1 "file with spaces" &&
	git diff --quiet HEAD~1  &&
	test ! -f "file with spaces" &&
	$revert "file with spaces" &&
	git diff --quiet HEAD~1
	cd ..
'

test_expect_success 'revert all' '
	test ! -f there &&
	$revert --since master~5 &&
	git diff --quiet master~5 &&
	$revert --since HEAD &&
	git diff --quiet &&
	test -f there &&
	rm there
'

test_expect_success 'check handling already deleted files' '
	git rm "subdir/file with spaces" &&
	$revert --since master~1 &&
	git diff --quiet master~1
'

test_expect_success 'subdirectory fun' '
	mkdir foo &&
	cd foo &&
	echo "A-B-C-D-E-F-G-H..." > alphabet &&
	git add alphabet &&
	echo hi >> ../subdir/secret &&
	chmod u+x ../subdir/file.doc &&
	$revert alphabet ../subdir &&
	git diff --quiet HEAD &&
	cd ..
'

# If we revert all changes to the staging area since some commit, then
#   git diff --cached <commit>
# should come up empty, the working copy file contents should exactly
# match HEAD, but some files might be considered untracked, so we have
# to add them back before running
#   git diff HEAD
test_expect_success 'staged only' '
	cd foo &&
	git add alphabet &&
	$revert --staged --since HEAD~5 &&
	git diff --cached --quiet HEAD~5 &&
	git add ../advice ../subdir/file.doc ../subdir/file\ with\ spaces
	git diff --quiet HEAD &&
	cd ..
'

test_expect_success 'clean again' '
	eg revert --since HEAD
'

# Similar to the staged only, reverting unstaged files can cause a new
# untracked file to appear.  It has the right contents, but to do the
# diff, we need to add it first.
test_expect_success 'unstaged only' '
	cd foo &&
	$revert --unstaged --since HEAD~5 &&
	git diff --cached --quiet HEAD &&
	git add ../there &&
	git diff --quiet HEAD~5 &&
	cd ..
'

test_expect_success 'clean yet again' '
	eg revert --since HEAD --unstaged &&
	eg revert --since HEAD --staged
'

test_expect_code 1 'plain revert' '
	$revert
'

test_expect_success 'setup_merge_conflict' '
	echo hi > a &&
	echo bye > c &&
	echo status > conflict &&
	git add a c conflict &&
	test_tick &&
	git commit -b -m "BASE" &&
	git rm c &&
	echo newline >> a &&
	echo foobar > b &&
	echo "Everything is fine" > conflict &&
	git add a b conflict &&
	test_tick &&
	git commit -m "Commit on master branch" &&
	git checkout -b other HEAD~1 &&
	git rm a &&
	echo newline >> c &&
	echo whatever > d &&
	echo "No it is not" > conflict &&
	git add c d conflict &&
	test_tick &&
	git commit -m "Commit on other branch" &&
	git checkout master
'

test_expect_code 1 'merge conflict' '
	git merge other
'

test_expect_code 1 'incomplete merge requires revision' '
	$revert c
'

test_expect_success 'incomplete merge handling' '
	$revert --since other c &&
	git diff --quiet other c &&
	$revert --since master c &&
	test ! -f c &&
	$revert --since other b &&
	test ! -f b &&
	$revert --since master b &&
	git diff --quiet master b &&
	$revert --since master conflict &&
	git diff --quiet master conflict &&
	$revert --since other conflict &&
	git diff --quiet other conflict
'

test_expect_code 1 'cleanup and restart merge' '
	git reset --hard HEAD &&
	git ls-files --others | xargs rm &&
	git merge other
'

test_expect_success 'undoing merge' '
	echo "random text" > e &&
	git add e &&
	$revert --since other &&
	git diff --quiet other &&
	test "e" == `git ls-files --others`
	$revert --since HEAD &&
	git diff --quiet HEAD &&
	test "cde" == `git ls-files --others | tr -d "\n"`
'

test_expect_success 'undoing changes to some files in previous revision' '
	$revert --in master~6 subdir/file.doc &&
	test ! -f subdir/file.doc &&
	cd foo &&
	$revert --in master~4 ../advice &&
	git diff --quiet master~5 ../advice &&
	cd ..
'

test_done
