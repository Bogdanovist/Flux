#!/usr/bin/env bash
# shared-checkout-guard.sh — PreToolUse hook on Bash.
#
# Blocks the two git commands that cannot be used safely in a checkout shared by
# concurrent sessions, and names the safe form in the block reason.
#
# Flux is one checkout on main that every session works in at once. Two
# command shapes are unsafe there, and both fail silently — the damage is only
# visible later, in someone else's history or in work that is simply gone:
#
#   Sweeps    `git add -A|.|--all`, `git commit -a|-am` stage whatever any other
#             session has half-written, so their work lands in a commit whose
#             message describes none of it. The owning session then finds its
#             files already committed by a message it did not write.
#
#   Discards  `git checkout -- <path>`, `git restore <path>`, `git reset --hard`
#             destroy uncommitted changes belonging to whoever made them. There
#             is no reflog for unstaged work: it is gone, not recoverable.
#
# Project repos are exempt by construction — a worktree per branch with one
# editing agent in it, where a sweep claims that agent's own work and a discard
# throws away only its own. The guard therefore fires only when the command acts
# on the Flux checkout.
#
# This is a gate, not a nudge: it blocks, because both failures are silent and
# both have a correct alternative that costs only keystrokes. Every block names
# that alternative — a gate that only says no teaches nothing.
#
# Escape hatch: prefix the command with `FLUX_GUARD_SKIP=1 ` inline (parsed
# out of the command string, so it works from the Bash tool); logged.
#
# Tunables (env): FLUX_DIR (default: the checkout holding this hook),
# FLUX_GUARD_SKIP=1 (bypass), FLUX_LOG_DIR.

set -uo pipefail

FLUX="${FLUX_DIR:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# Commands name the checkout as `$FLUX_DIR`; the parser expands it from here.
export FLUX_DIR="$FLUX"
LOG_DIR="${FLUX_LOG_DIR:-${HOME}/.claude/logs}"
LOG_FILE="${LOG_DIR}/shared-checkout-guard.log"

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
[[ "$TOOL_NAME" == "Bash" ]] || exit 0

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[[ -n "$COMMAND" ]] || exit 0

# Cheap gate: no `git` token anywhere means nothing to consider.
[[ "$COMMAND" == *git* ]] || exit 0

REPO_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
CMD_LIB="$REPO_ROOT/scripts/lib/bash-command.sh"
# Without the parser this hook cannot tell a real invocation from a documented
# one. Blocking on a guess would be worse than not guarding; allow and stay quiet.
[[ -f "$CMD_LIB" ]] || exit 0
# shellcheck disable=SC1090
source "$CMD_LIB"

STRIPPED=$(strip_heredocs "$COMMAND")

# Quote-stripped form, used only to spot the inline escape hatch.
NORM="${STRIPPED//\"/}"
NORM="${NORM//\'/}"

INLINE_SKIP_RE='(^|[[:space:]\;\&\|\`\(])(export[[:space:]]+)?FLUX_GUARD_SKIP=1([[:space:]]|$|\;|\&|\||\`|\))'
if [[ "${FLUX_GUARD_SKIP:-}" == "1" ]] || [[ "$NORM" =~ $INLINE_SKIP_RE ]]; then
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  printf '%s\tskipped\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${COMMAND:0:200}" >>"$LOG_FILE" 2>/dev/null || true
  exit 0
fi

# --- Does this command act on the shared checkout? ---------------------------
FALLBACK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
CMD_DIR=$(resolve_command_dir "$STRIPPED" "$FALLBACK_CWD")
[[ -n "$CMD_DIR" && -d "$CMD_DIR" ]] || CMD_DIR="$(pwd)"

TARGET_REAL=$(cd "$CMD_DIR" 2>/dev/null && pwd -P) || exit 0
FLUX_REAL=$(cd "$FLUX" 2>/dev/null && pwd -P) || exit 0
[[ "$TARGET_REAL" == "$FLUX_REAL" ]] || exit 0

block() {
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  printf '%s\tblocked\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "${COMMAND:0:200}" >>"$LOG_FILE" 2>/dev/null || true
  printf '{"decision":"block","reason":%s}\n' "$(printf '%s' "$2" | jq -Rs .)"
  exit 0
}

# --- Classify each command-position segment --------------------------------
# Matching anywhere in the command string would fire on one that merely quotes
# the pattern, so only a segment whose own first word is `git` is considered.
SWEEP_KIND=""
DISCARD_KIND=""

while IFS= read -r seg; do
  [[ "$seg" =~ ^git([[:space:]]|$) ]] || continue

  # Classification must see past the global options that can sit between
  # `git` and its subcommand. resolve_command_dir above already honours
  # `git -C <dir>` when deciding which repo a command acts on, so a segment
  # like `git -C "$FLUX_DIR" add -A` resolves to the shared checkout — and
  # would then slip through every pattern below, all anchored on the
  # subcommand following `git` directly. `-c <name>=<value>` is stripped on
  # the same grounds.
  while [[ "$seg" =~ ^git[[:space:]]+(-C|-c)[[:space:]]+[^[:space:]]+[[:space:]]+(.*)$ ]]; do
    seg="git ${BASH_REMATCH[2]}"
  done

  # `git add` with -A / --all / a bare `.` pathspec.
  if [[ -z "$SWEEP_KIND" && "$seg" =~ ^git[[:space:]]+add[[:space:]]+(.*)$ ]]; then
    ARGS="${BASH_REMATCH[1]}"
    if [[ "$ARGS" =~ (^|[[:space:]])(--all|-[[:alnum:]]*A[[:alnum:]]*|\.)([[:space:]]|$) ]]; then
      SWEEP_KIND="git-add-sweep"
    fi
  fi

  # `git commit -a` stages every tracked modification, whoever made it.
  if [[ -z "$SWEEP_KIND" && "$seg" =~ ^git[[:space:]]+commit[[:space:]]+(.*)$ ]]; then
    ARGS="${BASH_REMATCH[1]}"
    if [[ "$ARGS" =~ (^|[[:space:]])(--all|-[[:alnum:]]*a[[:alnum:]]*)([[:space:]]|$) ]]; then
      SWEEP_KIND="git-commit-all"
    fi
  fi

  # `git checkout` touches working-tree content only when given a pathspec — a
  # `--` separator or a bare `.`. Switching or creating a branch is left alone.
  if [[ -z "$DISCARD_KIND" && "$seg" =~ ^git[[:space:]]+checkout[[:space:]]+(.*)$ ]]; then
    ARGS="${BASH_REMATCH[1]}"
    if [[ "$ARGS" =~ (^|[[:space:]])--([[:space:]]|$) ]] \
       || [[ "$ARGS" =~ (^|[[:space:]])\.([[:space:]]|$) ]]; then
      DISCARD_KIND="git-checkout-discard"
    fi
  fi

  # `git restore --staged` without --worktree only unstages; working-tree
  # content, and so anyone's uncommitted work, survives.
  if [[ -z "$DISCARD_KIND" && "$seg" =~ ^git[[:space:]]+restore[[:space:]]+(.*)$ ]]; then
    ARGS="${BASH_REMATCH[1]}"
    if ! { [[ "$ARGS" =~ (^|[[:space:]])--staged([[:space:]]|$) ]] \
           && ! [[ "$ARGS" =~ (^|[[:space:]])--worktree([[:space:]]|$) ]]; }; then
      DISCARD_KIND="git-restore-discard"
    fi
  fi

  # Only --hard rewrites the working tree; --soft and --mixed leave it intact.
  if [[ -z "$DISCARD_KIND" && "$seg" =~ ^git[[:space:]]+reset[[:space:]]+(.*)$ ]]; then
    ARGS="${BASH_REMATCH[1]}"
    if [[ "$ARGS" =~ (^|[[:space:]])--hard([[:space:]]|$) ]]; then
      DISCARD_KIND="git-reset-hard"
    fi
  fi
done < <(command_segments "$STRIPPED")

if [[ "$SWEEP_KIND" == "git-add-sweep" ]]; then
  block "$SWEEP_KIND" "Blocked: \`git add\` with -A/--all/. in the shared Flux checkout at ${FLUX_REAL}.

Every session works in this one checkout at once, so a sweep stages whatever another session has half-written and commits it under a message describing none of it. The owning session then finds its work already committed by a message it did not write.

A directory narrows a sweep without ending it. \`git add -A some/dir/\` still takes every change under that directory — a file another session is editing there, and any deletion it has not finished making. What makes this safe is naming files, not narrowing the tree.

Name the files this change owns:
  git add -- path/one.md path/two.sh

\`git status --porcelain -uall\` shows what else is live; anything not yours, leave for its session. To override: prefix the command with \`FLUX_GUARD_SKIP=1 \` (logged to ${LOG_FILE})."
fi

if [[ "$SWEEP_KIND" == "git-commit-all" ]]; then
  block "$SWEEP_KIND" "Blocked: \`git commit\` with -a/--all in the shared Flux checkout at ${FLUX_REAL}.

-a stages every tracked modification in the tree, including files another concurrent session is mid-edit, under a message describing none of them.

Stage what this change owns, then commit the index:
  git add -- path/one.md
  git commit -m \"...\"

To override: prefix the command with \`FLUX_GUARD_SKIP=1 \` (logged to ${LOG_FILE})."
fi

if [[ -n "$DISCARD_KIND" ]]; then
  block "$DISCARD_KIND" "Blocked: a discarding git command in the shared Flux checkout at ${FLUX_REAL}.

\`git checkout -- <path>\`, \`git restore <path>\` and \`git reset --hard\` destroy uncommitted changes belonging to whoever made them. There is no reflog for unstaged work — it is gone, not recoverable — and in this checkout it may not be yours.

To undo your own edit, restore that one file from a commit into the working tree without touching anything else, after checking \`git status --porcelain -uall\` for what else is live:
  git show <ref>:path/to/file > path/to/file

To revert a committed change, add a commit rather than moving the branch:
  git revert <sha>

To override: prefix the command with \`FLUX_GUARD_SKIP=1 \` (logged to ${LOG_FILE})."
fi

exit 0
