#!/usr/bin/env bash
# curation-trigger.sh — write or clear the .curation-needed sentinel
# based on the size and age of learnings/staging.md.
#
# Sentinel contract:
#   - Path: ${LEARNINGS_DIR}/.curation-needed
#   - Present  → the SessionStart debt-review nudge tells the user to
#                invoke /curate.
#   - Absent   → staging is below both thresholds; no prompt fires.
#
# Trigger thresholds (both checked; either fires the sentinel):
#   - Volume: staging has ≥ CURATION_TRIGGER_COUNT entries (default 15).
#   - Age:    the earliest entry's timestamp is ≥ CURATION_TRIGGER_DAYS
#             days old (default 7).
#
# An entry is delimited by a `---` opening fence; counting opening
# fences is equivalent to counting entries. The earliest timestamp is
# the first `^timestamp:` line in the file (entries are appended in
# arrival order).
#
# This script is idempotent: it may be called from the drain hook on
# every Stop event AND from a cron/launchd job. Repeated invocations
# with unchanged input produce unchanged sentinel state.
#
# Exit codes: always 0 unless catastrophic IO failure (read-only FS,
# unwritable LEARNINGS_DIR). The sentinel is a hint, not a gate — a
# trigger failure must not break the auto-commit critical path.

set -uo pipefail

# Physical resolve: this hook is reached through the ~/.claude/hooks symlink.
REPO_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
LEARNINGS_DIR="${LEARNINGS_DIR:-${FLUX_DIR:-$REPO_ROOT}/learnings}"
STAGING_FILE="$LEARNINGS_DIR/staging.md"
SENTINEL="$LEARNINGS_DIR/.curation-needed"

CURATION_TRIGGER_COUNT="${CURATION_TRIGGER_COUNT:-15}"
CURATION_TRIGGER_DAYS="${CURATION_TRIGGER_DAYS:-7}"

# Missing learnings dir or staging file → no entries, sentinel absent.
if [ ! -d "$LEARNINGS_DIR" ] || [ ! -s "$STAGING_FILE" ]; then
  rm -f "$SENTINEL" 2>/dev/null || true
  exit 0
fi

# Count entries: each entry has exactly two `---` fences (open + close),
# so total fence count divided by 2 is the entry count.
fence_count="$(grep -c '^---$' "$STAGING_FILE" 2>/dev/null || echo 0)"
entry_count=$((fence_count / 2))

if [ "$entry_count" -ge "$CURATION_TRIGGER_COUNT" ]; then
  : >"$SENTINEL" 2>/dev/null || true
  exit 0
fi

# Age check: find the earliest `timestamp:` value (first occurrence,
# since entries append in arrival order) and convert to epoch seconds.
earliest_ts="$(awk '/^timestamp:[[:space:]]/ {
  sub(/^timestamp:[[:space:]]*/, "");
  sub(/[[:space:]]+$/, "");
  print;
  exit;
}' "$STAGING_FILE")"

if [ -n "$earliest_ts" ]; then
  # date(1) is split-flavoured on macOS (-j -f) vs Linux (-d). Try
  # GNU first, fall back to BSD. Either way, output is epoch seconds.
  earliest_epoch=""
  if earliest_epoch="$(date -u -d "$earliest_ts" +%s 2>/dev/null)"; then
    :
  elif earliest_epoch="$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$earliest_ts" +%s 2>/dev/null)"; then
    :
  else
    earliest_epoch=""
  fi
  if [ -n "$earliest_epoch" ]; then
    now_epoch="$(date -u +%s)"
    age_seconds=$((now_epoch - earliest_epoch))
    threshold_seconds=$((CURATION_TRIGGER_DAYS * 86400))
    if [ "$age_seconds" -ge "$threshold_seconds" ]; then
      : >"$SENTINEL" 2>/dev/null || true
      exit 0
    fi
  fi
fi

# Neither threshold tripped — sentinel should not exist.
rm -f "$SENTINEL" 2>/dev/null || true
exit 0
