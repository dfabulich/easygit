#
# bash completion support for easy GIT.
#
# Copyright (C) 2006,2007 Shawn O. Pearce <spearce@spearce.org>
# Copyright (C) 2008 Elijah Newren <newren gmail com>
# Heavily based on git-completion.sh
# Distributed under the GNU General Public License, version 2.0.
#
# The contained completion routines provide support for completing:
#
#    *) local and remote branch names
#    *) local and remote tag names
#    *) .git/remotes file names
#    *) git 'subcommands'
#    *) tree paths within 'ref:path/to/file' expressions
#    *) common --long-options
#
# To use these routines (s/git-completion.sh/bash-completion-eg.sh/ in
# instructions below):
#
#    1) Copy this file to somewhere (e.g. ~/.git-completion.sh).
#    2) Added the following line to your .bashrc:
#        source ~/.git-completion.sh
#
#    3) You may want to make sure the git executable is available
#       in your PATH before this script is sourced, as some caching
#       is performed while the script loads.  If git isn't found
#       at source time then all lookups will be done on demand,
#       which may be slightly slower.
#
#    4) Consider changing your PS1 to also show the current branch:
#        PS1='[\u@\h \W$(__git_ps1 " (%s)")]\$ '
#
#       The argument to __git_ps1 will be displayed only if you
#       are currently in a git repository.  The %s token will be
#       the name of the current branch.
#
# To submit patches:
#
#    *) Read Documentation/SubmittingPatches
#    *) Send all patches to the current maintainer:
#
#       "Shawn O. Pearce" <spearce@spearce.org>
#
#    *) Always CC the Git mailing list:
#
#       git@vger.kernel.org
#

__eg_commands ()
{
  if [ -n "$__eg_commandlist" ]; then
    echo "$__eg_commandlist"
    return
  fi
  local i IFS=" "$'\n'
  eg help --all | egrep "^  eg" | awk '{print $2}' | sort | uniq
}
__eg_commandlist=
__eg_commandlist="$(__eg_commands 2>/dev/null)"

_eg_commit ()
{
  local cur="${COMP_WORDS[COMP_CWORD]}"
  case "$cur" in
  --*)
    __gitcomp "
      --all-tracked --bypass-untracked-check --staged --dirty
      --author= --signoff --verify --no-verify
      --edit --amend --include --only
      "
    return
  esac
  COMPREPLY=()
}

_eg_diff ()
{
  local cur="${COMP_WORDS[COMP_CWORD]}"
  case "$cur" in
  --*)
    __gitcomp "--staged --unstaged
      --cached --stat --numstat --shortstat --summary
      --patch-with-stat --name-only --name-status --color
      --no-color --color-words --no-renames --check
      --full-index --binary --abbrev --diff-filter
      --find-copies-harder --pickaxe-all --pickaxe-regex
      --text --ignore-space-at-eol --ignore-space-change
      --ignore-all-space --exit-code --quiet --ext-diff
      --no-ext-diff"
    return
    ;;
  esac
  __git_complete_file
}

_eg_help ()
{
  local cur="${COMP_WORDS[COMP_CWORD]}"
  case "$cur" in
  --*)
    __gitcomp "--all"
    return
    ;;
  esac
  __gitcomp "$(__eg_commands)"
}

_eg_reset ()
{
  local cur="${COMP_WORDS[COMP_CWORD]}"
  case "$cur" in
  --*)
    __gitcomp "--working-copy --no-unstaging --mixed --hard --soft"
    return
    ;;
  esac
  __gitcomp "$(__git_refs)"
}

_eg_revert ()
{
  local cur="${COMP_WORDS[COMP_CWORD]}"
  case "$cur" in
  --*)
    __gitcomp "--commit --no-commit --staged --in --since"
    return
    ;;
  esac
  __git_complete_file
}

_eg ()
{
  local i c=1 command __git_dir

  while [ $c -lt $COMP_CWORD ]; do
    i="${COMP_WORDS[c]}"
    case "$i" in
    --git-dir=*) __git_dir="${i#--git-dir=}" ;;
    --bare)      __git_dir="." ;;
    --version|--help|-p|--paginate) ;;
    *) command="$i"; break ;;
    esac
    c=$((++c))
  done

  if [ $c -eq $COMP_CWORD -a -z "$command" ]; then
    case "${COMP_WORDS[COMP_CWORD]}" in
    --*=*) COMPREPLY=() ;;
    --*)   __gitcomp "
      --debug
      --translate
      --no-pager
      --git-dir=
      --bare
      --version
      --exec-path
      "
      ;;
    *)     __gitcomp "$(__eg_commands) $(__git_aliases)" ;;
    esac
    return
  fi

  local expansion=$(__git_aliased_command "$command")
  [ "$expansion" ] && command="$expansion"

  case "$command" in
  am)          _git_am ;;
  add)         _git_add ;;
  apply)       _git_apply ;;
  bisect)      _git_bisect ;;
  bundle)      _git_bundle ;;
  branch)      _git_branch ;;
  checkout)    _git_checkout ;;
  cherry)      _git_cherry ;;
  cherry-pick) _git_cherry_pick ;;
  commit)      _eg_commit ;;
  config)      _git_config ;;
  describe)    _git_describe ;;
  diff)        _eg_diff ;;
  fetch)       _git_fetch ;;
  format-patch) _git_format_patch ;;
  gc)          _git_gc ;;
  help)        _eg_help ;;
  log)         _git_log ;;
  ls-remote)   _git_ls_remote ;;
  ls-tree)     _git_ls_tree ;;
  merge)       _git_merge;;
  merge-base)  _git_merge_base ;;
  name-rev)    _git_name_rev ;;
  pull)        _git_pull ;;
  push)        _git_push ;;
  rebase)      _git_rebase ;;
  remote)      _git_remote ;;
  reset)       _eg_reset ;;
  revert)      _eg_revert ;;
  shortlog)    _git_shortlog ;;
  show)        _git_show ;;
  show-branch) _git_log ;;
  stash)       _git_stash ;;
  submodule)   _git_submodule ;;
  switch)      _git_checkout ;;
  tag)         _git_tag ;;
  whatchanged) _git_log ;;
  *)           COMPREPLY=() ;;
  esac
}

complete -o default -o nospace -F _eg eg
