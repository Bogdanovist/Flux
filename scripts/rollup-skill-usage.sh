#!/usr/bin/env bash
# rollup-skill-usage.sh — derive this box's skill-usage rollup for the sweep.
#
# hooks/skill-usage-log.sh appends one JSON line per skill load to a log that
# never leaves the machine (~/.claude/skill-usage.jsonl). This script reduces
# that log to the summary the sweep reads: per-skill load counts and
# last-used timestamps, written to
# curation/telemetry/skill-usage/<user>@<host>.json. The filename is the box's
# derived identity — `id -un` @ `hostname -s` — so two boxes write disjoint
# files and no registry has to exist.
#
# hooks/flux-sync.sh runs this weekly at session start and commits the
# refreshed file; skills/context-sweep/SKILL.md §The ledger protocol reads
# every file in the directory as evidence on bloat calls.
#
# A missing or unreadable log still writes a rollup: `"records": 0` from a box
# says the box reports and has recorded nothing, which an absent file cannot
# say. A log line that does not parse as JSON is skipped — the emitter never
# blocks, so a torn line is expected occasionally.
#
# Prints the path written. Exits 0 on success, 1 when nothing could be written.
#
# Environment (overridable for testing):
#   SKILL_USAGE_LOG   log to aggregate (default $HOME/.claude/skill-usage.jsonl)
#   FLUX_DIR        repo root receiving the rollup (default: this script's repo)

set -uo pipefail

LOG="${SKILL_USAGE_LOG:-$HOME/.claude/skill-usage.jsonl}"

# Resolve the repo physically: the script can be reached through the
# ~/.claude/hooks symlink chain, where a lexical `..` leaves the repo.
REPO_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
FLUX="${FLUX_DIR:-$REPO_ROOT}"

USER_NAME="$(id -un 2>/dev/null)" || exit 1
HOST_NAME="$(hostname -s 2>/dev/null || hostname 2>/dev/null)" || exit 1
IDENTITY="${USER_NAME}@${HOST_NAME}"

OUT_DIR="$FLUX/curation/telemetry/skill-usage"
OUT="$OUT_DIR/$IDENTITY.json"
mkdir -p "$OUT_DIR" 2>/dev/null || exit 1

SRC="/dev/null"
[ -r "$LOG" ] && SRC="$LOG"

# generated_at_epoch exists for the freshness check in hooks/flux-sync.sh:
# comparing integers needs no GNU `date -d`, so the check runs the same on
# macOS and Linux.
TMP="$OUT.tmp.$$"
if ! jq -R -s \
    --arg identity "$IDENTITY" \
    --arg now_iso "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson now_epoch "$(date +%s)" \
    '
    # A multi-line Bash command that reads several SKILL.md files is logged
    # as one record whose skill field joins the names with newlines. Each
    # name is one load, so split before counting; `records` stays the count
    # of log records aggregated.
    [ split("\n")[]
      | select(length > 0)
      | (fromjson? // empty)
      | select((.skill // "") != "") ] as $recs
    | { identity: $identity,
        generated_at: $now_iso,
        generated_at_epoch: $now_epoch,
        records: ($recs | length),
        skills: ( [ $recs[]
                    | { ts: (.ts // "") } + { name: (.skill | split("\n")[]) }
                    | select(.name != "") ]
                  | group_by(.name)
                  | map({ key: .[0].name,
                          value: { count: length,
                                   last_used: (map(.ts) | max) } })
                  | from_entries ) }
    ' <"$SRC" >"$TMP" 2>/dev/null; then
  rm -f "$TMP" 2>/dev/null
  exit 1
fi

if ! mv "$TMP" "$OUT" 2>/dev/null; then
  rm -f "$TMP" 2>/dev/null
  exit 1
fi
printf '%s\n' "$OUT"
exit 0
