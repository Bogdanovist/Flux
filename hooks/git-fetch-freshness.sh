#!/bin/bash
# git-fetch-freshness.sh — PreToolUse hook on Bash
#
# Makes "reasoning over remote-tracking refs" deterministic. Before a git command
# that READS remote refs (origin/…, @{u}, `branch -r/-a`, `cherry`, refs/remotes)
# runs against a repo whose refs haven't been fetched recently, this auto-fetches
# so the command sees current data — taking ref-freshness out of probabilistic
# "remember to fetch" and into the harness.
#
# The failure it prevents (observed, expensive): an agent — or a spawned research
# sub-agent — asserting "X is/ isn't on main", "this commit is unpushed", or "that
# migration does not exist" off remote-tracking refs that were days stale, then
# writing those wrong facts into a plan. A single fetch up front prevents all of it,
# and a hook guarantees it for every agent and sub-agent rather than trusting each
# to remember.
#
# Behaviour:
#   - Triggers only on git commands that consult remote-tracking refs.
#   - Fresh  (FETCH_HEAD younger than GIT_FRESH_MAX_AGE, default 120s) → allow, silent.
#   - Stale/absent → `git fetch <remote> --prune`; on success allow silently, on
#     failure allow but inject a "refs may be stale — fetch failed" note so the
#     staleness is surfaced to the model, never silent.
#   - NEVER blocks: freshness is best-effort; a down network must not break work.
#   - Escape hatch: GIT_FRESH_SKIP=1 (process env or inline prefix) → allow, no fetch.
#   - Worktree-aware: FETCH_HEAD lives in the shared git-common-dir, so one fetch
#     refreshes every worktree of a repo.
#
# Tunables (env): GIT_FRESH_MAX_AGE (seconds), GIT_FRESH_REMOTE (force remote name),
# GIT_FRESH_SKIP=1 (bypass).
#
# Output contract mirrors the repo's other PreToolUse hooks: jq-built JSON, exit 0.

set -euo pipefail

MAX_AGE="${GIT_FRESH_MAX_AGE:-120}"
LOG_DIR="${FLUX_LOG_DIR:-${HOME}/.claude/logs}"
LOG_FILE="${LOG_DIR}/git-fetch-freshness.log"

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
[[ "$TOOL_NAME" == "Bash" ]] || exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[[ -n "$COMMAND" ]] || exit 0

# Cheap gate: no `git` token anywhere → nothing to do. Keeps the awk/regex work off
# the hot path for the overwhelming majority of Bash calls.
[[ "$COMMAND" == *git* ]] || exit 0

# Heredoc stripping and repo resolution are shared with shared-checkout-guard.sh:
# both gates must read a Bash command the same way, or one will act on an
# invocation the other treats as prose. Resolve the repo physically — this hook
# is invoked through ~/.claude/hooks, a symlink into the repo.
HOOK_REPO_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
CMD_LIB="$HOOK_REPO_ROOT/scripts/lib/bash-command.sh"
MTIME_LIB="$HOOK_REPO_ROOT/scripts/lib/file-mtime.sh"
# Freshness is best-effort and must never block work, so a missing library means
# allow-and-stay-quiet rather than guess.
[[ -f "$CMD_LIB" && -f "$MTIME_LIB" ]] || exit 0
# shellcheck disable=SC1090
source "$CMD_LIB"
# shellcheck disable=SC1090
source "$MTIME_LIB"

STRIPPED=$(strip_heredocs "$COMMAND")

# Quote-stripped form for robust token matching.
NORM="${STRIPPED//\"/}"
NORM="${NORM//\'/}"

# Escape hatch: process env or inline `GIT_FRESH_SKIP=1 …` / `export GIT_FRESH_SKIP=1`.
INLINE_SKIP_RE='(^|[[:space:]\;\&\|\`\(])(export[[:space:]]+)?GIT_FRESH_SKIP=1([[:space:]]|$|\;|\&|\||\`|\))'
if [[ "${GIT_FRESH_SKIP:-}" == "1" ]] || [[ "$NORM" =~ $INLINE_SKIP_RE ]]; then
  exit 0
fi

# --- Trigger detection: does this command's answer depend on remote-tracking refs? --
# Over-approximate (a false positive costs only a needless, safe fetch). A remote ref
# may be preceded by start/space/`.`/`/`/`:`/`=` (ranges like main..origin/main), so
# the boundary excludes only a preceding word char (avoids "myorigin/").
trigger=0
if [[ "$NORM" =~ (^|[^[:alnum:]_])(origin|upstream)/ ]]; then trigger=1; fi   # origin/… upstream/…
if [[ "$NORM" == *'@{u'* ]]; then trigger=1; fi                              # @{u} / @{upstream}
if [[ "$NORM" == *'refs/remotes'* ]]; then trigger=1; fi                     # explicit remotes namespace
if [[ "$NORM" == *' cherry'* || "$NORM" == 'cherry'* ]]; then trigger=1; fi  # git cherry vs upstream
# `git branch` that enumerates / filters across remote refs.
if [[ "$NORM" == *branch* ]] && [[ "$NORM" =~ (^|[[:space:]])(-[[:alpha:]]*[ra]|--remotes|--all|--contains|--no-contains|--merged|--no-merged)([[:space:]]|$) ]]; then
  trigger=1
fi
(( trigger == 1 )) || exit 0

# Which remote to refresh. Default origin; switch to upstream only when the command
# references upstream and not origin. Force with GIT_FRESH_REMOTE.
REMOTE="${GIT_FRESH_REMOTE:-origin}"
if [[ -z "${GIT_FRESH_REMOTE:-}" ]]; then
  if [[ "$NORM" =~ (^|[^[:alnum:]_])upstream/ ]] && ! [[ "$NORM" =~ (^|[^[:alnum:]_])origin/ ]]; then
    REMOTE="upstream"
  fi
fi

# --- Resolve the repo the command actually runs against. ---
# The first git segment's directory is the repo whose remote refs it reads. A
# command with no git segment reads refs from wherever its last segment runs.
CMD_DIR=$(command_segment_dirs "$STRIPPED" "$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)" \
  | awk -F'\t' '{ last = $1 } !found && $2 ~ /^git([[:space:]]|$)/ { found = $1 } END { print (found != "" ? found : last) }')
[[ -n "$CMD_DIR" && -d "$CMD_DIR" ]] || CMD_DIR="$(pwd)"

# Inside a git repo? If not, nothing to refresh.
REPO_ROOT=$(git -C "$CMD_DIR" rev-parse --show-toplevel 2>/dev/null || true)
[[ -n "$REPO_ROOT" ]] || exit 0

# Remote must exist (a repo may have no 'origin').
git -C "$REPO_ROOT" remote get-url "$REMOTE" >/dev/null 2>&1 || exit 0

# FETCH_HEAD lives in the git-common-dir, shared across all worktrees of the repo —
# one fetch refreshes every worktree's remote-tracking refs.
COMMON_DIR=$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
if [[ -z "$COMMON_DIR" ]]; then
  COMMON_DIR=$(git -C "$REPO_ROOT" rev-parse --git-common-dir 2>/dev/null || echo "${REPO_ROOT}/.git")
  [[ "$COMMON_DIR" = /* ]] || COMMON_DIR="${REPO_ROOT}/${COMMON_DIR}"
fi
FETCH_HEAD="${COMMON_DIR}/FETCH_HEAD"

# An unreadable mtime is treated as infinitely old: fetching costs a few seconds,
# reasoning on stale refs costs a plan.
AGE=$(file_age_seconds "$FETCH_HEAD" 2>/dev/null || echo "never")
# Fresh enough — the command will read current refs. Silent allow.
if [[ "$AGE" != "never" ]] && (( AGE <= MAX_AGE )); then
  exit 0
fi

# --- Stale: fetch synchronously so the command reads fresh refs. ---
run_with_timeout() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$secs" "$@"; return $?; fi
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@"; return $?; fi
  "$@" & local p=$!
  ( sleep "$secs"; kill -TERM "$p" 2>/dev/null ) & local w=$!
  disown "$w" 2>/dev/null || true   # stop the shell announcing "Terminated" when we reap the watchdog
  local rc=0; wait "$p" 2>/dev/null || rc=$?
  kill "$w" 2>/dev/null || true
  return $rc
}

log() {
  mkdir -p "$LOG_DIR" 2>/dev/null || return 0
  printf '%s\t%s\trepo=%s\tremote=%s\tage=%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$REPO_ROOT" "$REMOTE" "$AGE" "$2" >>"$LOG_FILE" 2>/dev/null || true
}

fetch_rc=0
run_with_timeout 15 git -C "$REPO_ROOT" fetch "$REMOTE" --prune --quiet >/dev/null 2>&1 || fetch_rc=$?

if (( fetch_rc == 0 )); then
  log "fetched" "ok"
  # The fetch moved the remote-tracking refs; it did not move the working
  # tree. A session that then reads files — greps, cats, opens a doc — is
  # reading whatever the checkout held, and a tree weeks behind looks
  # internally consistent right up to the moment a claim about it is wrong.
  # SessionStart fast-forwards what it can; this covers main moving
  # underneath a session already in progress, and costs one local rev-list
  # on a fetch that already happened. Counted inline rather than through
  # git-sync.sh's ahead_behind: one command, and sourcing a library into a
  # per-command hook to save it is not a trade worth making.
  BEHIND=$(git -C "$REPO_ROOT" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)
  if [[ "${BEHIND:-0}" =~ ^[0-9]+$ ]] && (( BEHIND > 0 )); then
    BRANCH=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo HEAD)
    log "behind" "n=${BEHIND}"
    MSG="git-fetch-freshness: ${REPO_ROOT} is ${BEHIND} commit(s) behind origin/${BRANCH}. Remote-tracking refs are now current but the working tree is not, so files read from this checkout may be out of date. Read through 'git grep <pattern> origin/${BRANCH}' or 'git show origin/${BRANCH}:<path>' before asserting what the repo contains."
    jq -cn --arg m "$MSG" \
      '{systemMessage:$m, hookSpecificOutput:{hookEventName:"PreToolUse", additionalContext:$m}}'
  fi
  exit 0
fi

# Fetch failed (offline / creds / timeout). Don't block — but make the staleness
# explicit to the model so it doesn't reason on possibly-stale refs unknowingly.
log "fetch-failed" "rc=${fetch_rc}"
MSG="git-fetch-freshness: could not refresh ${REMOTE} for ${REPO_ROOT} (fetch exit ${fetch_rc}); remote-tracking refs may be stale. Treat any 'on main / merged / pushed / exists upstream' conclusion from this command as unverified until a successful 'git fetch ${REMOTE}'."
jq -cn --arg m "$MSG" \
  '{systemMessage:$m, hookSpecificOutput:{hookEventName:"PreToolUse", additionalContext:$m}}'
exit 0
