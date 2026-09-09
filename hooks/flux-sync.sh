#!/usr/bin/env bash
# flux-sync.sh — SessionStart hook. Fast-forward the Flux checkout
# before the session reads anything out of it.
#
# Flux is checked out on every machine you work from against one remote,
# and nothing else in the tree pulls: git-fetch-freshness.sh refreshes
# remote-tracking refs but never merges, and `git status` on a checkout
# whose refs are days old still reports a clean `## main...origin/main`
# with no hint that main has moved. A machine can therefore sit weeks
# behind while looking current — running stale charter rules, and reading
# a follow-up inbox and skills whose entries were disposed of on another
# machine.
#
# The fast-forward is attempted whatever else sits in the working tree,
# because git already refuses one that would overwrite a modified file: it
# names the file, aborts, and leaves HEAD where it was. That check is per
# file, so an incoming commit touching nothing a concurrent session is
# mid-edit still lands, and one that would trample an edit still cannot.
# Gating the whole sync on a dirty tree instead would disable it on any
# machine with a session in flight — in a checkout several sessions share,
# most of the working day, and exactly when there is something to pull.
#
# It also keeps this box's skill-usage rollup fresh: when
# curation/telemetry/skill-usage/<user>@<host>.json is absent or more than
# seven days old, it runs scripts/rollup-skill-usage.sh and commits the one
# refreshed file. hooks/auto-commit-push.sh pushes that commit at session end
# with the checkout's other local commits.
#
# It is a nudge, not a gate: it never blocks session start, always exits 0,
# and says nothing when the checkout is current.
#
# Environment (overridable for testing):
#   FLUX_DIR           root of the Flux context repo (default $HOME/src/Flux)
#   FLUX_SYNC_TIMEOUT  seconds to bound the fetch (default 10)
#   SKILL_USAGE_LOG      log the rollup aggregates (see scripts/rollup-skill-usage.sh)

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)

# Compaction continues an existing session rather than starting one; the
# checkout was already synced when that session began.
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null || true)
if [ "$SOURCE" = "compact" ]; then
  exit 0
fi

FLUX="${FLUX_DIR:-$HOME/src/Flux}"
FETCH_TIMEOUT="${FLUX_SYNC_TIMEOUT:-10}"

# Resolve the repo physically. Hooks are invoked through ~/.claude/hooks,
# which is a symlink into this repo, so a logical `..` walks lexically out
# of the link and lands in ~/.claude instead of the checkout.
REPO_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
SYNC_LIB="$REPO_ROOT/scripts/lib/git-sync.sh"

# The weekly skill-usage rollup (cheap, never blocking). Each box's log stays
# local; curation/telemetry/skill-usage/ holds the derived summary the sweep
# reads. Session start is the one point every box passes through weekly, so:
# when this box's rollup is absent or older than seven days, regenerate it and
# commit that one file by name — never a sweep, per the shared-checkout rules.
# The pathspec commit stages and commits only the rollup, so another session's
# staged files stay staged and untouched, and pre-commit's suite gate does not
# fire (the rollup is under curation/, and the gate keys on hooks/ and
# scripts/). Every step tolerates failure — a box that cannot roll up still
# starts its session, and retries at the next one. hooks/auto-commit-push.sh
# pushes the commit at session end.
ROLLUP_MAX_AGE_SECONDS=$((7 * 24 * 3600))
weekly_rollup() {
  local script="$REPO_ROOT/scripts/rollup-skill-usage.sh"
  [ -f "$script" ] || return 0
  git -C "$FLUX" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local user host file epoch now
  user="$(id -un 2>/dev/null)" || return 0
  host="$(hostname -s 2>/dev/null || hostname 2>/dev/null)" || return 0
  file="$FLUX/curation/telemetry/skill-usage/${user}@${host}.json"
  if [ -f "$file" ]; then
    epoch="$(jq -r '.generated_at_epoch // 0' "$file" 2>/dev/null)" || epoch=0
    case "$epoch" in ''|*[!0-9]*) epoch=0 ;; esac
    now="$(date +%s)"
    [ $((now - epoch)) -lt "$ROLLUP_MAX_AGE_SECONDS" ] && return 0
  fi
  FLUX_DIR="$FLUX" bash "$script" >/dev/null 2>&1 || return 0
  [ -n "$(git -C "$FLUX" status --porcelain -- "$file" 2>/dev/null)" ] || return 0
  git -C "$FLUX" add -- "$file" >/dev/null 2>&1 || return 0
  git -C "$FLUX" commit \
    -m "telemetry: skill-usage rollup for ${user}@${host}" \
    -- "$file" >/dev/null 2>&1 || true
  return 0
}

# Emit the sync outcome and exit. Every terminal path funnels through here,
# so the weekly rollup guard runs exactly once per session start, after
# whatever syncing was possible.
emit() {
  weekly_rollup
  local msg="${1:-}"
  [ -z "$msg" ] && exit 0
  jq -n --arg msg "$msg" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $msg
    }
  }'
  exit 0
}

# Without the library there is no way to tell where this checkout stands.
# Say so rather than starting the session on an unverified tree.
if [ ! -f "$SYNC_LIB" ]; then
  emit "[flux-sync] Could not load ${SYNC_LIB}, so the context checkout was not synced and may be behind origin. Mention this once; treat any rule, follow-up, or skill read from it as possibly stale."
fi
# shellcheck disable=SC1090
source "$SYNC_LIB"

git -C "$FLUX" rev-parse --is-inside-work-tree >/dev/null 2>&1 || emit ""

BRANCH=$(git -C "$FLUX" branch --show-current 2>/dev/null)
[ -n "$BRANCH" ] || emit ""

if ! bounded_fetch "$FLUX" origin "$FETCH_TIMEOUT"; then
  emit "[flux-sync] Could not reach origin to sync the context checkout (fetch failed or timed out after ${FETCH_TIMEOUT}s). It may be behind: charter rules, skills and the follow-up inbox could all be stale. Mention this once, briefly."
fi

# No upstream to compare against — nothing to sync, nothing to warn about.
COUNTS=$(ahead_behind "$FLUX") || emit ""
AHEAD=$(printf '%s' "$COUNTS" | awk '{print $1}')
BEHIND=$(printf '%s' "$COUNTS" | awk '{print $2}')

[ "${BEHIND:-0}" -eq 0 ] && emit ""

if [ "${AHEAD:-0}" -gt 0 ]; then
  emit "[flux-sync] The context checkout has diverged from origin/${BRANCH} — ${AHEAD} local commit(s) it has not pushed, ${BEHIND} it has not pulled. Nothing was synced. The session-end hook will rebase and push the local commits if they replay cleanly; a conflict there needs a human to reconcile. Surface this to the user before doing other work."
fi

if git -C "$FLUX" merge --ff-only "@{u}" >/dev/null 2>&1; then
  emit "[flux-sync] Synced the context checkout: fast-forwarded ${BEHIND} commit(s) from origin/${BRANCH}. Charter rules, skills and the follow-up inbox are current. No need to mention this."
fi

emit "[flux-sync] The context checkout is ${BEHIND} commit(s) behind origin/${BRANCH} and the fast-forward failed, so charter rules and the shared stores may be stale. The usual cause is an incoming commit touching a file that is modified here; \`git -C ${FLUX} status --porcelain -uall\` names what is live, and the sync lands once that file is committed. Mention this once."
