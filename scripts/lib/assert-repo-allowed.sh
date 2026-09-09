#!/usr/bin/env bash
# assert-repo-allowed.sh — exit 0 if lessons may be routed into the
# named repo, exit 1 otherwise.
#
# Invoked by the curator subagent once per lesson, BEFORE it creates a
# cross-repo worktree or pushes any branch. A repo qualifies when it has
# a checkout under the src root, which is also the only state in which
# the curator can read the text it proposes to change; `flux` qualifies
# wherever this repo itself is checked out.
#
# Usage:
#   assert-repo-allowed.sh <repo-name>
#
# Environment:
#   FLUX_SRC_ROOT  directory holding the checkouts (default $HOME/src)
#
# Exit codes:
#   0  lessons may be routed into the repo
#   1  the repo has no checkout to read or write
#   2  usage error

set -uo pipefail

_err() { printf 'assert-repo-allowed: %s\n' "$*" >&2; }

if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
  _err "usage: assert-repo-allowed.sh <repo-name>"
  exit 2
fi

repo="$1"
SRC_ROOT="${FLUX_SRC_ROOT:-$HOME/src}"

if [ "$repo" = "flux" ]; then
  exit 0
fi

if [ -d "$SRC_ROOT/$repo" ]; then
  exit 0
fi

_err "repo '$repo' has no checkout under ${SRC_ROOT}"
exit 1
