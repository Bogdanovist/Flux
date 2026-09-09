#!/usr/bin/env bash
# assert-branch-lessons.sh — exit 0 if the current git branch name
# matches `lessons/*`, exit 1 otherwise.
#
# Invoked by the curator subagent immediately before any `git push`
# inside a cross-repo lessons worktree. Hard-aborts a push to `main`,
# `master`, an empty branch (detached HEAD), or any non-`lessons/`
# branch the curator might end up on if a worktree-setup step went
# wrong.
#
# Usage:
#   assert-branch-lessons.sh                 # checks current dir's branch
#   assert-branch-lessons.sh -C <worktree>   # checks <worktree>'s branch
#
# Exit codes:
#   0  current branch matches ^lessons/.+
#   1  current branch is main / master / empty / does not match
#   2  git invocation failed (not a worktree, git absent, etc.)
#
# Diagnostics on stderr, never on stdout — keeps the exit code usable
# inside `if` constructs the curator prompt embeds.

set -uo pipefail

_err() { printf 'assert-branch-lessons: %s\n' "$*" >&2; }

git_cmd=(git)
if [ "${1:-}" = "-C" ]; then
  if [ -z "${2:-}" ]; then
    _err "missing argument to -C"
    exit 2
  fi
  git_cmd=(git -C "$2")
  shift 2
fi

if ! branch="$("${git_cmd[@]}" branch --show-current 2>/dev/null)"; then
  _err "git branch --show-current failed; not a git working tree?"
  exit 2
fi

if [ -z "$branch" ]; then
  _err "current branch is empty (detached HEAD)"
  exit 1
fi

case "$branch" in
  main|master)
    _err "refusing to operate on branch '$branch'; curator must run on a lessons/* branch"
    exit 1
    ;;
esac

if printf '%s' "$branch" | grep -Eq '^lessons/.+'; then
  exit 0
fi

_err "branch '$branch' does not match lessons/*; curator must run on a lessons/* branch"
exit 1
