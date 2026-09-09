#!/usr/bin/env bash
# checkouts-sync.sh — SessionStart hook. Fast-forward the code checkouts
# before the session reads anything out of them.
#
# hooks/flux-sync.sh does this for the context repo, where being behind
# means stale rules. This hook covers the repos the work is actually done
# in, where being behind means something worse: an agent reads the working
# tree, finds a doc that matches the code in front of it, and reports
# "current". Nothing in the session contradicts it, because every file it
# opened was internally consistent — just weeks old.
#
# hooks/git-fetch-freshness.sh does not close this. It refreshes
# remote-tracking refs, which moves `origin/main` but not the tree; and it
# triggers only on commands that name a remote ref, so a session that
# greps and cats its way through a checkout never fires it at all.
#
# The fast-forward is attempted whatever sits in the working tree, on the
# same reasoning as flux-sync: git refuses a fast-forward that would
# overwrite a modified file, names it, and leaves HEAD alone. Gating on a
# clean tree instead would skip the sync on any checkout with work in
# flight — which is most of them, most of the day.
#
# Whatever cannot be synced is reported rather than passed over. A silent
# skip is how the stale checkout gets read as current, so a repo left
# behind is named, with the reason and the compensating move.
#
# It is a nudge, not a gate: never blocks session start, always exits 0.
#
# Environment (overridable for testing):
#   FLUX_SRC_ROOT         directory holding the checkouts (default $HOME/src)
#   FLUX_SYNC_TIMEOUT     seconds to bound each fetch (default 10)
#   FLUX_SYNC_SKIP        space-separated basenames to leave alone

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)

# Compaction continues a session rather than starting one; these checkouts
# were synced when it began.
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null || true)
[ "$SOURCE" = "compact" ] && exit 0

SRC_ROOT="${FLUX_SRC_ROOT:-$HOME/src}"
FETCH_TIMEOUT="${FLUX_SYNC_TIMEOUT:-10}"
# Flux itself is flux-sync.sh's job — it speaks about rules rather than
# code. Two hooks fast-forwarding one checkout would race for the same
# index lock.
SKIP="${FLUX_SYNC_SKIP:-Flux}"

# Resolve the repo physically: hooks are invoked through ~/.claude/hooks,
# a symlink into this repo, so a logical `..` lands in ~/.claude instead.
REPO_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
SYNC_LIB="$REPO_ROOT/scripts/lib/git-sync.sh"

emit() {
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

# Without the library there is no way to bound a fetch or read a checkout's
# standing. Say so rather than let the session assume the trees are current.
if [ ! -f "$SYNC_LIB" ]; then
  emit "[checkouts-sync] Could not load ${SYNC_LIB}, so no code checkout was synced. Any claim about what is or is not in a repo may be reading a stale tree; verify against origin before asserting one."
fi
# shellcheck disable=SC1090
source "$SYNC_LIB"

[ -d "$SRC_ROOT" ] || exit 0

# --- Discover the main checkouts. ---
# A linked worktree's .git is a file, not a directory: skipping those keeps
# the hook off ~/src/<repo>-worktrees/* and off any worktree parked
# elsewhere, so it only ever moves a branch someone deliberately checked
# out as the repo's primary tree.
REPOS=()
for dir in "$SRC_ROOT"/*/; do
  dir="${dir%/}"
  name="$(basename "$dir")"
  [ -d "$dir/.git" ] || continue
  case " $SKIP " in *" $name "*) continue ;; esac
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
  REPOS+=("$dir")
done
[ "${#REPOS[@]}" -gt 0 ] || exit 0

# --- Fetch every repo at once. ---
# Sequential fetches would charge the session boundary the sum of the
# timeouts; in parallel it is bounded by the slowest single repo.
STATUS_DIR="$(mktemp -d 2>/dev/null)" || exit 0
trap 'rm -rf "$STATUS_DIR"' EXIT

for dir in "${REPOS[@]}"; do
  (
    if bounded_fetch "$dir" origin "$FETCH_TIMEOUT"; then
      printf 'ok\n' >"$STATUS_DIR/$(basename "$dir").fetch"
    else
      printf 'failed\n' >"$STATUS_DIR/$(basename "$dir").fetch"
    fi
  ) &
done
wait

# --- Fast-forward what can be, and account for everything that cannot. ---
SYNCED=""      # moved, no longer stale
STALE=""       # still behind: the lines that matter
DIVERGED=""    # local commits present, left untouched

for dir in "${REPOS[@]}"; do
  name="$(basename "$dir")"
  branch=$(git -C "$dir" branch --show-current 2>/dev/null)

  # Detached HEAD has no upstream to measure against, and moving it is
  # never what someone in that state wants.
  if [ -z "$branch" ]; then
    STALE="${STALE}
  - ${name}: detached HEAD — not synced, and its tree may be old."
    continue
  fi

  if [ "$(cat "$STATUS_DIR/$name.fetch" 2>/dev/null)" != "ok" ]; then
    STALE="${STALE}
  - ${name}: could not reach origin (fetch failed or timed out after ${FETCH_TIMEOUT}s) — standing unknown."
    continue
  fi

  COUNTS=$(ahead_behind "$dir") || {
    STALE="${STALE}
  - ${name}: ${branch} has no upstream — nothing to compare against."
    continue
  }
  AHEAD=$(printf '%s' "$COUNTS" | awk '{print $1}')
  BEHIND=$(printf '%s' "$COUNTS" | awk '{print $2}')

  [ "${BEHIND:-0}" -eq 0 ] && continue

  if [ "${AHEAD:-0}" -gt 0 ]; then
    DIVERGED="${DIVERGED}
  - ${name}: ${branch} has ${AHEAD} local commit(s) and is ${BEHIND} behind — left alone."
    continue
  fi

  if git -C "$dir" merge --ff-only "@{u}" >/dev/null 2>&1; then
    SYNCED="${SYNCED} ${name}(+${BEHIND})"
  else
    STALE="${STALE}
  - ${name}: ${BEHIND} commit(s) behind origin/${branch} and the fast-forward failed — usually an incoming commit touching a file modified here (\`git -C ${dir} status --porcelain -uall\`)."
  fi
done

# Nothing to say when every checkout was already current: the common case
# should cost the session no context at all.
[ -z "$SYNCED" ] && [ -z "$STALE" ] && [ -z "$DIVERGED" ] && exit 0

MSG="[checkouts-sync]"
[ -n "$SYNCED" ] && MSG="${MSG} Fast-forwarded:${SYNCED}."

if [ -n "$STALE" ] || [ -n "$DIVERGED" ]; then
  MSG="${MSG}
These checkouts were NOT brought up to date:${STALE}${DIVERGED}
Their working trees may be behind origin. Before asserting what a repo does or does not contain — a file, a symbol, a flag, a dependency — read it through \`git grep <pattern> origin/<branch>\` or \`git show origin/<branch>:<path>\`, or sweep a detached worktree at origin. A doc that matches the tree in front of you proves nothing when the tree itself is old."
else
  MSG="${MSG} No need to mention this."
fi

emit "$MSG"
