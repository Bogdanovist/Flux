#!/bin/bash
# skill-usage-log.sh — records every skill load to the config dir's
# skill-usage.jsonl (~/.claude/skill-usage.jsonl unless FLUX_CLAUDE_DIR moved
# the install; scripts/rollup-skill-usage.sh reads the same path).
#
# Three load paths, each recorded under the `source` that distinguishes them:
#
#   tool   PostToolUse (Skill)         the model calls the Skill tool
#   slash  UserPromptSubmit            a human types /name
#   read   PostToolUse (Read | Bash)   the model reads a SKILL.md directly
#
# The paths never overlap, so counting any one of them alone undercounts. The
# `read` path is the easiest to miss and the most misleading when missed: a
# whole-file read of a single-file skill puts the same discipline text in
# context as the Skill tool does, so a skill that was loaded and applied scores
# as unused. It also carries the composition signal — a skill instructed to
# compose another and reaching for `cat` has obeyed the instruction.
#
# Only whole-file reads count. A grep, or a Read windowed by offset/limit, over
# a SKILL.md is inspection rather than a load. Sessions that work *on* skills
# read them too; `cwd` is recorded so authoring traffic stays separable from
# use.
#
# Append-only, one JSON object per line. Never blocks: any failure exits 0.

set -uo pipefail

LOG="${SKILL_USAGE_LOG:-${FLUX_CLAUDE_DIR:-$HOME/.claude}/skill-usage.jsonl}"
INPUT=$(cat)

EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null) || exit 0

# Read and Bash fire on almost every turn, so reject the ones that cannot be a
# skill load before spending a subprocess on them.
skill_md_mentioned() {
  case "$INPUT" in *SKILL.md*) return 0 ;; *) return 1 ;; esac
}

# A skill's name is the directory holding its SKILL.md, under both the
# ~/.claude/skills/<name>/ and skills/<name>/ repo layouts.
skill_from_path() {
  printf '%s' "$1" | sed -n 's|.*[ /]\([A-Za-z0-9._-][A-Za-z0-9._-]*\)/SKILL\.md.*|\1|p'
}

case "$EVENT" in
  PostToolUse)
    TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
    case "$TOOL" in
      Skill)
        SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
        SOURCE=tool
        ;;
      Read)
        skill_md_mentioned || exit 0
        echo "$INPUT" | jq -e '.tool_input | has("offset") or has("limit")' >/dev/null 2>&1 && exit 0
        SKILL=$(skill_from_path "$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)")
        SOURCE=read
        ;;
      Bash)
        skill_md_mentioned || exit 0
        CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
        printf '%s' "$CMD" | grep -qE '(^|[|;&(]| )cat +' || exit 0
        SKILL=$(skill_from_path "$CMD")
        SOURCE=read
        ;;
      *)
        exit 0
        ;;
    esac
    ;;
  UserPromptSubmit)
    PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
    # Only a leading slash-token counts; "see /curate for context" is prose.
    SKILL=$(printf '%s' "$PROMPT" | sed -n '1s|^/\([A-Za-z0-9][A-Za-z0-9:_-]*\).*|\1|p')
    SOURCE=slash
    ;;
  *)
    exit 0
    ;;
esac

[[ -n "${SKILL:-}" ]] || exit 0

jq -c -n \
  --arg ts      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg skill   "$SKILL" \
  --arg source  "$SOURCE" \
  --arg session "$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)" \
  --arg cwd     "$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)" \
  --arg agent   "$(echo "$INPUT" | jq -r '.agent_type // .subagent_type // empty' 2>/dev/null)" \
  '{ts:$ts, skill:$skill, source:$source, session:$session, cwd:$cwd, agent:$agent}' \
  >> "$LOG" 2>/dev/null || true

exit 0
