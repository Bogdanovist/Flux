#!/usr/bin/env bash
# drain-to-staging.sh — consume learnings/pending/*.md files, validate
# each against the schema + content blocklist, and atomically append
# passing entries to learnings/staging.md under an exclusive lock
# (flock(1) on Linux, mkdir-based mutex fallback on macOS).
#
# This hook runs on every Stop event BEFORE auto-commit-push.sh so the
# staging.md delta lands in the same auto-commit that the user expects
# to capture all session-end changes.
#
# Failure semantics are deliberate and load-bearing:
#
#   - The hook ALWAYS exits 0 except on catastrophic IO failure
#     (LEARNINGS_DIR unreachable or unwritable). A single malformed
#     pending file MUST NOT break the session-end auto-commit cycle —
#     otherwise every drain failure becomes a missed push.
#
#   - Per-file failures are visible via the pending/.rejected/ tree.
#     Rejected files keep their original name, prepended with a
#     `# REJECTED: <reason>` header so a human reading the file
#     immediately sees why it was bounced. The original temp file is
#     never silently dropped.
#
# Environment:
#   LEARNINGS_DIR         — root of the learnings tree (default:
#                           $FLUX_PROJECT_DIR/learnings,
#                           $CLAUDE_PROJECT_DIR/learnings, or
#                           $PWD/learnings if neither is set).
#   LEARNINGS_PENDING_DIR — pending tree to drain (default:
#                           $LEARNINGS_DIR/pending). Tests override
#                           this to exercise the flock contract with
#                           disjoint pending dirs but a shared staging
#                           file.

set -uo pipefail

LEARNINGS_DIR="${LEARNINGS_DIR:-${FLUX_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}}/learnings}"
PENDING_DIR="${LEARNINGS_PENDING_DIR:-$LEARNINGS_DIR/pending}"
REJECTED_DIR="$PENDING_DIR/.rejected"
STAGING_FILE="$LEARNINGS_DIR/staging.md"
LOCK_FILE="$LEARNINGS_DIR/staging.lock"

# Resolve the repo physically. This hook is invoked through ~/.claude/hooks, which
# is a symlink into this repo, so a logical `..` walks lexically out of the link and
# lands in ~/.claude — where the schema library only happens to be reachable on a
# machine that also has a hand-made ~/.claude/scripts symlink. Without -P the drain
# silently validates nothing on every machine set up by setup.sh, and every emitted
# lesson sits in pending/ forever.
REPO_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
SCHEMA_LIB="$REPO_ROOT/scripts/lib/staging-schema.sh"
TRIGGER_HOOK="$REPO_ROOT/hooks/curation-trigger.sh"

# If the staging tree doesn't exist there's nothing to do — and
# nothing to risk. Exit clean so a fresh checkout that never invoked
# /learn doesn't see a hook failure on first session-end.
if [ ! -d "$LEARNINGS_DIR" ]; then
  exit 0
fi

# Ensure rejected tree exists. mkdir -p is idempotent and safe.
mkdir -p "$REJECTED_DIR" 2>/dev/null || true

# Source the validator. If the library is missing, the hook is
# misconfigured at the repo level — log to stderr but still exit 0
# so the auto-commit cycle keeps running.
if [ ! -f "$SCHEMA_LIB" ]; then
  echo "drain-to-staging: schema library missing at $SCHEMA_LIB" >&2
  exit 0
fi
# shellcheck disable=SC1090
source "$SCHEMA_LIB"

# Move a rejected pending file into pending/.rejected/ with a reason
# header prepended. Reason is one of: schema, blocklist.
#
# Removes the source only after the .rejected/ copy is confirmed on
# disk. If the write or rename fails (unwritable .rejected/, full FS,
# unreadable src), the source stays in pending/ and the failure is
# surfaced to stderr — the entry must never disappear from pending/,
# .rejected/, and staging simultaneously.
reject_entry() {
  local src="$1" reason="$2"
  local base
  base="$(basename "$src")"
  local dst="$REJECTED_DIR/$base"
  if {
       printf '# REJECTED: %s\n' "$reason"
       cat "$src"
     } > "$dst.tmp" 2>/dev/null && mv -f "$dst.tmp" "$dst" 2>/dev/null; then
    rm -f "$src" 2>/dev/null || true
  else
    rm -f "$dst.tmp" 2>/dev/null || true
    echo "drain-to-staging: failed to write rejection for $src (reason=$reason); leaving in pending/ for retry" >&2
  fi
}

# Acquire an exclusive append lock. Uses flock(1) where available
# (typical Linux dev/CI boxes) and falls back to a mkdir-based mutex
# on macOS, which lacks flock. mkdir is atomic on every POSIX
# filesystem, so a successful mkdir is equivalent to acquiring the
# lock; the loop bounded-spins until the holder releases (rmdir).
#
# Bounded retries (LOCK_MAX_ATTEMPTS × LOCK_RETRY_SLEEP seconds) cap
# the worst case so a stale lockdir from a crashed prior run cannot
# wedge the drain forever — after the cap we proceed without the
# lock and surface a warning to stderr. The drain critical section
# is a single cat-append per entry, so contention windows are tiny.
LOCK_DIR="${STAGING_FILE}.lockdir"
LOCK_MAX_ATTEMPTS="${LOCK_MAX_ATTEMPTS:-50}"
LOCK_RETRY_SLEEP="${LOCK_RETRY_SLEEP:-0.1}"

_have_flock=0
if command -v flock >/dev/null 2>&1; then
  _have_flock=1
fi

with_staging_lock() {
  local action="$1"; shift
  if [ "$_have_flock" = "1" ]; then
    (
      flock -x 200
      "$action" "$@"
    ) 200>"$LOCK_FILE"
    return $?
  fi
  # mkdir-based mutex fallback (macOS).
  local attempts=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge "$LOCK_MAX_ATTEMPTS" ]; then
      echo "drain-to-staging: lockdir contended after ${attempts} attempts; proceeding unlocked" >&2
      "$action" "$@"
      return $?
    fi
    sleep "$LOCK_RETRY_SLEEP"
  done
  "$action" "$@"
  local rc=$?
  rmdir "$LOCK_DIR" 2>/dev/null || true
  return $rc
}

# Append a passing entry to staging.md under the lock. The lock is
# taken per-append so the critical section stays as small as possible.
_append_one() {
  cat "$1" >> "$STAGING_FILE"
}

# Append a passing entry to staging.md, then remove the source. The
# removal is conditional on the append succeeding: if the locked
# append returns non-zero (unwritable staging.md, full FS, FD-open
# failure on the lock file), the source stays in pending/ so the next
# drain retries — silently dropping a validated entry violates the
# documented "never silently dropped" contract.
append_to_staging() {
  local src="$1"
  if with_staging_lock _append_one "$src"; then
    rm -f "$src" 2>/dev/null || true
  else
    echo "drain-to-staging: append to staging.md failed for $src; leaving in pending/ for retry" >&2
  fi
}

# Iterate pending files in lexicographic order. nullglob makes the
# glob expand to nothing (rather than the literal pattern) when no
# files match; the ${array[@]+...} guard keeps `set -u` quiet when
# the resulting array is empty.
shopt -s nullglob
pending_files=("$PENDING_DIR"/*.md)
shopt -u nullglob

for entry in ${pending_files[@]+"${pending_files[@]}"}; do
  # Skip files inside .rejected/ — shouldn't appear since we glob
  # *.md directly under PENDING_DIR, but defensive belt-and-braces.
  case "$entry" in
    *"/.rejected/"*) continue ;;
  esac

  # validate_staging_entry exits 0 PASS, 1 schema fail, 2 blocklist hit.
  # Capture rc explicitly because `set -e` is not in effect (we want
  # the loop to keep going even on failure).
  rc=0
  validate_staging_entry "$entry" || rc=$?
  case "$rc" in
    0)
      append_to_staging "$entry"
      ;;
    1)
      reject_entry "$entry" "schema"
      ;;
    2)
      reject_entry "$entry" "blocklist"
      ;;
    *)
      # Unexpected exit code — treat as schema failure so the file is
      # surfaced for human inspection rather than silently dropped.
      reject_entry "$entry" "schema (unexpected rc=$rc)"
      ;;
  esac
done

# Update the curation-needed sentinel based on the new staging state.
# The trigger script is itself exit-0-safe so a missing or broken
# trigger never breaks the drain.
if [ -x "$TRIGGER_HOOK" ]; then
  LEARNINGS_DIR="$LEARNINGS_DIR" bash "$TRIGGER_HOOK" || true
fi

exit 0
