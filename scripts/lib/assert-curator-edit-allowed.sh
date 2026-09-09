#!/usr/bin/env bash
# assert-curator-edit-allowed.sh — per-repo edit-path guard for the
# curator. Exits 0 if the supplied absolute path falls inside the
# curator's writable surface for the named target repo; exits 1
# otherwise.
#
# Centralises the curator's writable surface. The meta-repo (flux)
# is wider than `.claude/` alone — its sources of truth live in
# `agents/`, `skills/`, the model tier map, and the repo-root
# instruction files. The per-repo shape contract is shared with the
# schema validator via the `target_shape_valid` function in
# `staging-schema.sh`, so a path the curator is permitted to edit is the
# same path the schema would accept in a `target:` field. The two cannot
# drift.
#
# Usage:
#   assert-curator-edit-allowed.sh <repo> <worktree-root> <edit-path>
#
# Arguments:
#   <repo>           Lowercase repo identifier — `flux`, or a project
#                    repo with a checkout under the src root.
#   <worktree-root>  Absolute path to the worktree root the curator is
#                    operating inside.
#   <edit-path>      Absolute path of the file the curator wants to
#                    Edit or Write to.
#
# Exit codes:
#   0  edit-path lives inside worktree-root AND its relative position
#      matches one of the per-repo shapes allowed by
#      `target_shape_valid`
#   1  edit-path is outside the worktree-root, or its relative
#      position does not match a permitted shape
#   2  usage error or missing schema library

set -uo pipefail

_err() { printf 'assert-curator-edit-allowed: %s\n' "$*" >&2; }

if [ "$#" -ne 3 ]; then
  _err "usage: assert-curator-edit-allowed.sh <repo> <worktree-root> <edit-path>"
  exit 2
fi

repo="$1"
worktree_root="$2"
edit_path="$3"

if [ -z "$repo" ] || [ -z "$worktree_root" ] || [ -z "$edit_path" ]; then
  _err "all three arguments must be non-empty"
  exit 2
fi

# Locate the schema library relative to this helper so the curator
# does not have to know its absolute path.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
schema_lib="${script_dir}/staging-schema.sh"
if [ ! -f "$schema_lib" ]; then
  _err "schema library not found at ${schema_lib}"
  exit 2
fi
# shellcheck disable=SC1090
source "$schema_lib"

# Strip a trailing slash from the worktree root so the prefix check
# behaves predictably for callers passing either form.
worktree_root_trimmed="${worktree_root%/}"

# Require the edit-path to live inside the worktree root. The check is
# lexical (no symlink resolution) so a worktree under a symlinked
# parent works, but a sibling path that happens to share a prefix
# substring is rejected because the next character after the prefix
# must be `/`.
case "$edit_path" in
  "$worktree_root_trimmed"/*)
    rest="${edit_path#"$worktree_root_trimmed"/}"
    ;;
  *)
    _err "edit-path '$edit_path' is not inside worktree-root '$worktree_root_trimmed'"
    exit 1
    ;;
esac

# Reuse the schema validator's per-repo shape contract.
if ! target_shape_valid "$repo" "$rest"; then
  # `target_shape_valid` already wrote a diagnostic line; surface a
  # second line that names the offending absolute path so a curator
  # log shows both the contract violation and the disk path.
  _err "edit-path '$edit_path' is outside the curator's writable surface for repo '$repo'"
  exit 1
fi

exit 0
