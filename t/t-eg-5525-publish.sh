#!/bin/sh

test_description="tests of eg's publishing behavior"

. ./test-lib.sh

D=`pwd`
TEMPDIR=$(mktemp -d)

test_expect_success 'setup' '

	git init &&
	echo one >foo && git add foo && git commit -m one
'

cat > expect <<EOF
Aborting: Need a URL to push to!
EOF

test_expect_success 'publish fails when not given a URL' '
	test_must_fail git publish > actual 2>&1 &&
	test_cmp expect actual
'

cat > expect <<EOF
Aborting: Too many args to eg publish: master origin $TEMPDIR
EOF

test_expect_success 'publish fails when given too many args' '
	test_must_fail git publish master origin $TEMPDIR > actual 2>&1 &&
	test_cmp expect actual
'

cat > expect <<EOF
Aborting: Could not parse remote repository URL 'origin'.
EOF

test_expect_success 'publish fails when only given a remote name' '
	git ls-files -o --exclude-standard > .git/info/ignored-unknown &&
	test_must_fail git publish origin > actual 2>&1 &&
	test_cmp expect actual
'

cat > expect << EOF
Aborting: You have unresolved conflicts from your merge (run 'eg status' to get
the list of files with conflicts).  You should first resolve any conflicts
before trying to publish your work elsewhere.
EOF

cat > unmerge-info <<EOF
0 0000000000000000000000000000000000000000	foo
100644 8a1218a1024a212bb3db30becd860315f9f3ac52 1	foo
100755 8a1218a1024a212bb3db30becd860315f9f3ac52 2	foo
EOF

test_expect_success 'unmerged files present prevents publish' '
	cat unmerge-info | git update-index --index-info &&
	test_must_fail git publish $TEMPDIR > actual 2>&1 &&
	rm -rf $TEMPDIR &&
	test_cmp expect actual
'

test_expect_success 'unmerged check bypassed by -b' '
	git publish -b $TEMPDIR &&
	git remote rm origin &&
	rm -rf $TEMPDIR
'

cat > expect << EOF
Aborting: You have new unknown files and changed files present.  You should
first commit any such changes (and/or use the -b flag to bypass this check)
before trying to publish your work elsewhere.
New unknown files:
  newfile
EOF

test_expect_success 'new unknown and changed files prevents publish' '
	git reset -q --hard HEAD &&
	echo content >> foo &&
	touch newfile &&
	test_must_fail git publish $TEMPDIR > actual 2>&1 &&
	rm -rf $TEMPDIR &&
	test_cmp expect actual
'

cat > expect << EOF
Aborting: You have new unknown files present.  You should either commit these
new files before trying to publish your work elsewhere, or use the
-b flag to bypass this check.
New unknown files:
  newfile
EOF

test_expect_success 'new unknown files prevents push' '
	git revert foo &&
	test_must_fail git publish $TEMPDIR > actual 2>&1 &&
	rm -rf $TEMPDIR &&
	test_cmp expect actual &&
	rm newfile
'

cat > expect << EOF
Aborting: You have modified your files since the last commit.  You should
first commit any such changes before trying to publish your work
elsewhere, or use the -b flag to bypass this check.
EOF

test_expect_success 'modified files prevents push' '
	echo content >> foo &&
	test_must_fail git publish $TEMPDIR > actual 2>&1 &&
	rm -rf $TEMPDIR &&
	test_cmp expect actual
'

test_expect_success 'unmerged/modified/newfile checks bypassed by -b' '
	cat unmerge-info | git update-index --index-info &&
	touch newfile &&
	git publish -b $TEMPDIR &&
	git remote rm origin &&
	rm -rf $TEMPDIR &&
	git reset --hard HEAD &&
	rm newfile
'

cat > expect <<EOF
Setting up not-so-remote repository...
$TEMPDIR already exists!
Remote repository setup failed!
EOF

test_expect_success 'publish over an existing path fails' '
	mkdir $TEMPDIR &&
	echo hello > $TEMPDIR/world &&
	test_must_fail git publish $TEMPDIR > actual 2>&1 &&
	rm -rf $TEMPDIR &&
	test_cmp expect actual
'

cat > expect <<EOF
Aborting: remote 'origin' already exists, please specify a REMOTE_ALIAS!
EOF

test_expect_success 'publish fails without remote name when origin exists' '
	git remote add origin fake.address.org:/path/to/repo &&
	test_must_fail git publish $TEMPDIR > actual 2>&1 &&
	test_cmp expect actual
'

cat > expect <<EOF
Aborting: remote 'public' already exists!
EOF

test_expect_success 'publish fails when given an existing remote name' '
	git remote add public superfake.org:/path/to/repo.git &&
	test_must_fail git publish public $TEMPDIR > actual 2>&1 &&
	test_cmp expect actual
'

test_expect_success 'publish succeeds when given a new unique remote name' '
	git publish foobar $TEMPDIR &&
	git show-ref --heads > expect &&
	git --git-dir=$TEMPDIR show-ref --heads > actual &&
	test_cmp expect actual &&
	rm -rf $TEMPDIR &&
	git remote rm foobar
'

cat > ssh <<EOF
#!/bin/sh

false
EOF
chmod u+x ssh

test_expect_success 'publish fails when ssh does' '
	export PATH=.:$PATH &&
	git ls-files -o --exclude-standard > .git/info/ignored-unknown &&
	test_must_fail git publish foobar localhost:$TEMPDIR
'

cat > ssh <<EOF
#!/bin/sh

# This fake ssh runs the given command locally; it assumes that only simple
# arguments (ones that match -*), plus hostname and command will be passed
# to it.
while test \$# -ne 0
do
  case "\$1" in
  -*)
    shift
    ;;
  *)
    shift  # Remove hostname
    break
  esac
done
eval \$@
EOF

test_expect_success 'publish works over ssh' '
	export PATH=.:$PATH &&
	git publish foobar localhost:$TEMPDIR &&
	git show-ref --heads > expect &&
	git --git-dir=$TEMPDIR show-ref --heads > actual &&
	test_cmp expect actual &&
	rm -rf $TEMPDIR &&
	git remote rm foobar
'

# Pick a non-active group, if one exists
GROUP=$(groups | tr ' ' '\n' | tail -n 1)
test_expect_success 'publish sets the appropriate groups' '
	git publish -g $GROUP foobar $TEMPDIR &&
	git show-ref --heads > expect &&
	git --git-dir=$TEMPDIR show-ref --heads > actual &&
	test_cmp expect actual &&
	test $(find $TEMPDIR ! -group $GROUP | wc -l) = 0 &&
	rm -rf $TEMPDIR &&
	git remote rm foobar
'

test_expect_success 'publish fails when given a bad group' '
	test_must_fail git publish -g nowaythisgroupexists999 foobar $TEMPDIR
'

test_done
