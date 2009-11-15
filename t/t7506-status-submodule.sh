#!/bin/sh

test_description='git status for submodule'

. ./test-lib.sh

test_expect_success 'setup' '
	test_create_repo sub
	cd sub &&
	: >bar &&
	git add bar &&
	git commit -m " Add bar" &&
	cd .. &&
	git add sub &&
	git commit -m "Add submodule sub"
'

test_expect_success 'status clean' '
	test "1" == $(git status | wc -l)
'
test_expect_success 'status -a clean' '
	test "1" == $(git status -a | wc -l)
'
test_expect_success 'rm submodule contents' '
	rm -rf sub/* sub/.git
'
test_expect_success 'status clean (empty submodule dir)' '
	test "1" == $(git status | wc -l)
'
test_expect_success 'status -a clean (empty submodule dir)' '
	test "1" == $(git status -a | wc -l)
'

test_done
