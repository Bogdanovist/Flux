#!/usr/bin/env bash
# debt-review-nudge.sh — SessionStart hook.
#
# Surfaces the deferred-work debt-review nudge at the start of a session.
# The follow-ups inbox and the lessons staging file each accumulate
# between deliberate /triage sittings; without a reminder the piles rot
# unseen. This hook reads both stores and, when either has crossed a
# threshold, emits a one-line nudge via hookSpecificOutput.additionalContext
# so the agent can relay it to the user.
#
# Two stores feed the combined /triage ritual:
#   - Follow-ups: files under followups/inbox/ (excluding .gitkeep).
#     Due when the count is >= FOLLOWUP_TRIGGER_COUNT (default 8) OR the
#     oldest entry's `timestamp:` is >= FOLLOWUP_TRIGGER_DAYS (default 7)
#     days old.
#   - Lessons: the learnings/.curation-needed sentinel, maintained by
#     curation-trigger.sh on every Stop. Present => staging past threshold.
#
# A third store rides the same banner without feeding /triage:
#   - Reminders: files under reminders/, each carrying `due:` (YYYY-MM-DD) and
#     `what:` in its frontmatter. One fires every session from its due date
#     onward and keeps firing until the file is deleted, which is how the work
#     is marked done. Distinct from a follow-up: a follow-up is deferred work
#     disposed of in a /triage sitting on a count/age trigger, whereas a
#     reminder is work already scheduled for a date and nags until it happens.
#
# It is a nudge, not a gate: it never blocks session start, always exits 0,
# and emits nothing when no store is due. Skips the `compact` source —
# compaction continues a session rather than starting one, so re-firing the
# banner mid-session would just be noise.
#
# Environment (overridable for testing):
#   FLUX_DIR              root of the Flux meta-repo (default: the checkout holding this hook)
#   FOLLOWUP_TRIGGER_COUNT   count threshold (default 8)
#   FOLLOWUP_TRIGGER_DAYS    age threshold in days (default 7)
#   FLUX_TODAY            override today's date as YYYY-MM-DD (testing)

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)

# Compaction continues an existing session — don't re-fire the nudge then.
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null || true)
if [ "$SOURCE" = "compact" ]; then
  exit 0
fi

FLUX="${FLUX_DIR:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
INBOX="$FLUX/followups/inbox"
SENTINEL="$FLUX/learnings/.curation-needed"
REMINDERS="$FLUX/reminders"

FOLLOWUP_TRIGGER_COUNT="${FOLLOWUP_TRIGGER_COUNT:-8}"
FOLLOWUP_TRIGGER_DAYS="${FOLLOWUP_TRIGGER_DAYS:-7}"

# --- Follow-ups: count + oldest age -----------------------------------
followup_count=0
oldest_days=0
if [ -d "$INBOX" ]; then
  # Count *.md entries; the .gitkeep placeholder is not a *.md so it is
  # excluded automatically.
  shopt -s nullglob
  inbox_files=("$INBOX"/*.md)
  shopt -u nullglob
  followup_count=${#inbox_files[@]}

  if [ "$followup_count" -gt 0 ]; then
    # ISO-8601 UTC timestamps (YYYY-MM-DDTHH:MM:SSZ) sort lexically in
    # chronological order, so the first after sort is the earliest.
    earliest_ts=$(grep -h '^timestamp:' "${inbox_files[@]}" 2>/dev/null \
      | sed 's/^timestamp:[[:space:]]*//; s/[[:space:]]*$//' \
      | sort | head -1)
    if [ -n "$earliest_ts" ]; then
      # date(1) is split-flavoured: GNU (-d) on Linux, BSD (-j -f) on macOS.
      earliest_epoch=""
      if earliest_epoch=$(date -u -d "$earliest_ts" +%s 2>/dev/null); then
        :
      elif earliest_epoch=$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$earliest_ts" +%s 2>/dev/null); then
        :
      else
        earliest_epoch=""
      fi
      if [ -n "$earliest_epoch" ]; then
        now_epoch=$(date -u +%s)
        oldest_days=$(( (now_epoch - earliest_epoch) / 86400 ))
      fi
    fi
  fi
fi

followups_due=0
if [ "$followup_count" -ge "$FOLLOWUP_TRIGGER_COUNT" ] \
   || { [ "$followup_count" -gt 0 ] && [ "$oldest_days" -ge "$FOLLOWUP_TRIGGER_DAYS" ]; }; then
  followups_due=1
fi

# --- Lessons: the curation sentinel -----------------------------------
lessons_due=0
[ -e "$SENTINEL" ] && lessons_due=1

# --- Reminders: any whose due date has arrived ------------------------
# ISO dates compare correctly as strings, so no date arithmetic is needed
# and the split GNU/BSD date(1) flavours never come into it.
today="${FLUX_TODAY:-$(date -u +%F)}"
reminders_line=""
if [ -d "$REMINDERS" ]; then
  shopt -s nullglob
  for f in "$REMINDERS"/*.md; do
    # Read `due:`/`what:` from the frontmatter block only — the leading `---`
    # fence and nothing after it. A file without one (README.md) is not a
    # reminder, and a `due:` line quoted in a body or a code fence is prose.
    fm=$(awk 'NR==1 && $0=="---" {inside=1; next} inside && $0=="---" {exit} inside' "$f" 2>/dev/null)
    [ -n "$fm" ] || continue
    due=$(printf '%s\n' "$fm" | sed -n 's/^due:[[:space:]]*//p' | head -1 | tr -d '[:space:]')
    [ -n "$due" ] || continue
    [[ "$due" < "$today" || "$due" == "$today" ]] || continue
    what=$(printf '%s\n' "$fm" | sed -n 's/^what:[[:space:]]*//p' | head -1)
    [ -n "$what" ] || what=$(basename "$f" .md)
    reminders_line="${reminders_line} Due since ${due}: ${what}."
  done
  shopt -u nullglob
fi

# Nothing due -> stay silent.
if [ "$followups_due" -eq 0 ] && [ "$lessons_due" -eq 0 ] && [ -z "$reminders_line" ]; then
  exit 0
fi

# --- Build the banner -------------------------------------------------
banner=""
if [ "$followups_due" -eq 1 ] && [ "$lessons_due" -eq 1 ]; then
  banner="Debt review due — ${followup_count} open follow-ups (oldest ${oldest_days}d), and lessons staging is past the curation threshold. Run \`/triage\` for the follow-ups and \`/curate\` for the lessons, in one sitting."
elif [ "$followups_due" -eq 1 ]; then
  banner="Debt review due — ${followup_count} open follow-ups (oldest ${oldest_days}d). Run \`/triage\` to cluster and dispose of them."
elif [ "$lessons_due" -eq 1 ]; then
  banner="Lessons staging is past the curation threshold. Run \`/curate\` to clear it."
fi

if [ -n "$reminders_line" ]; then
  banner="${banner}${banner:+ }Scheduled work is due.${reminders_line} Delete the reminder file under reminders/ once it is done."
fi

MSG="[debt-review nudge] ${banner} This is a nudge, not a gate: mention it once, briefly, alongside your reply to the user's first message — do not run the command yourself or block on it."

jq -n --arg msg "$MSG" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $msg
  }
}'
exit 0
