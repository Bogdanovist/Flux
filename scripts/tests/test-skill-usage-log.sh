#!/usr/bin/env bash
# Pure-bash test harness for hooks/skill-usage-log.sh.
#
# The hook's job is to record a skill load whichever of the three paths it
# arrives by — Skill tool, typed slash command, or a direct read of a SKILL.md
# — because a session that reaches for `cat` has loaded and applied the same
# discipline as one that calls the tool, and counting only the tool scores it
# as unused. These tests pin both halves of that: what counts as a load, and
# what is only inspection.
#
# Each test pipes a synthetic hook payload into the hook under a throwaway
# HOME, then asserts on the JSONL line it appends. No bats dependency —
# portable across macOS and Linux.

set -uo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/skill-usage-log.sh"

PASS=0
FAIL=0
FAILED_NAMES=()

color_pass() { printf '\033[32m%s\033[0m' "$1"; }
color_fail() { printf '\033[31m%s\033[0m' "$1"; }

# Runs the hook against a throwaway HOME and echoes whatever it logged.
run_hook() {
  printf '%s' "$1" | HOME="$TEST_TMP" bash "$HOOK" >/dev/null 2>&1
  cat "$TEST_TMP/.claude/skill-usage.jsonl" 2>/dev/null
}

post_tool() {
  jq -c -n --arg tool "$1" --argjson input "$2" \
    '{hook_event_name:"PostToolUse", tool_name:$tool, tool_input:$input,
      session_id:"s1", cwd:"/Users/test/src/datascience"}'
}

run_test() {
  local name="$1"
  local tmpdir
  tmpdir="$(mktemp -d)"
  export TEST_TMP="$tmpdir"
  mkdir -p "$tmpdir/.claude"
  local out
  out="$(eval "scenario_$name" 2>&1)"
  export LAST_OUTPUT="$out"
  if eval "verify_$name"; then
    PASS=$((PASS+1))
    printf '  %s %s\n' "$(color_pass PASS)" "$name"
    rm -rf "$tmpdir"
  else
    FAIL=$((FAIL+1))
    FAILED_NAMES+=("$name")
    printf '  %s %s\n    tmpdir: %s\n    out: %s\n' \
      "$(color_fail FAIL)" "$name" "$tmpdir" "$out"
  fi
}

logged_as() {
  printf '%s' "$LAST_OUTPUT" | jq -e --arg s "$1" --arg src "$2" \
    'select(.skill == $s and .source == $src)' >/dev/null 2>&1
}

# ---------------------------------------------------------------
# The three load paths
# ---------------------------------------------------------------

scenario_skill_tool_logs_source_tool() {
  run_hook "$(post_tool Skill '{"skill":"shape-tracers","args":"two candidate slices"}')"
}
verify_skill_tool_logs_source_tool() { logged_as shape-tracers tool; }

scenario_leading_slash_logs_source_slash() {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"/to-tracers daedalus-mvp","session_id":"s1"}'
}
verify_leading_slash_logs_source_slash() { logged_as to-tracers slash; }

# The case the tool-only count misses: a skill told to compose another reaches
# for `cat` and loads the identical discipline text.
scenario_cat_of_skill_md_logs_source_read() {
  run_hook "$(post_tool Bash '{"command":"cat /Users/test/.claude/skills/shape-tracers/SKILL.md 2>&1"}')"
}
verify_cat_of_skill_md_logs_source_read() { logged_as shape-tracers read; }

scenario_read_tool_of_skill_md_logs_source_read() {
  run_hook "$(post_tool Read '{"file_path":"/Users/test/src/Flux/skill-bundles/core/grilling/SKILL.md"}')"
}
verify_read_tool_of_skill_md_logs_source_read() { logged_as grilling read; }

# ---------------------------------------------------------------
# Name resolution across layouts and command shapes
# ---------------------------------------------------------------

scenario_bundle_layout_resolves_skill_not_bundle() {
  run_hook "$(post_tool Bash '{"command":"cat skill-bundles/tracer-flow/to-tracers/SKILL.md"}')"
}
verify_bundle_layout_resolves_skill_not_bundle() { logged_as to-tracers read; }

scenario_cat_after_a_chained_command_still_counts() {
  run_hook "$(post_tool Bash '{"command":"cd ~/src/Flux && cat skill-bundles/core/handoff/SKILL.md"}')"
}
verify_cat_after_a_chained_command_still_counts() { logged_as handoff read; }

# ---------------------------------------------------------------
# Inspection, not a load
# ---------------------------------------------------------------

scenario_grep_over_skill_md_is_not_a_load() {
  run_hook "$(post_tool Bash '{"command":"grep -rn \"Primary key\" skill-bundles/core/grilling/SKILL.md"}')"
}
verify_grep_over_skill_md_is_not_a_load() { [ -z "$LAST_OUTPUT" ]; }

scenario_windowed_read_is_not_a_load() {
  run_hook "$(post_tool Read '{"file_path":"/Users/test/.claude/skills/grilling/SKILL.md","limit":20}')"
}
verify_windowed_read_is_not_a_load() { [ -z "$LAST_OUTPUT" ]; }

scenario_ordinary_bash_is_not_a_load() {
  run_hook "$(post_tool Bash '{"command":"cat README.md"}')"
}
verify_ordinary_bash_is_not_a_load() { [ -z "$LAST_OUTPUT" ]; }

scenario_slash_mid_prompt_is_prose() {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"see /curate for context","session_id":"s1"}'
}
verify_slash_mid_prompt_is_prose() { [ -z "$LAST_OUTPUT" ]; }

# ---------------------------------------------------------------
# The hook is on the critical path of every tool call
# ---------------------------------------------------------------

scenario_malformed_payload_exits_zero() {
  printf 'not json at all' | HOME="$TEST_TMP" bash "$HOOK" >/dev/null 2>&1
  printf 'rc=%s\n' "$?"
}
verify_malformed_payload_exits_zero() { [ "$LAST_OUTPUT" = "rc=0" ]; }

scenario_record_carries_session_and_cwd() {
  run_hook "$(post_tool Skill '{"skill":"verification-before-completion"}')"
}
verify_record_carries_session_and_cwd() {
  printf '%s' "$LAST_OUTPUT" | jq -e \
    'select(.session == "s1" and .cwd == "/Users/test/src/datascience" and (.ts | length) > 0)' \
    >/dev/null 2>&1
}

# ---------------------------------------------------------------

TESTS=(
  skill_tool_logs_source_tool
  leading_slash_logs_source_slash
  cat_of_skill_md_logs_source_read
  read_tool_of_skill_md_logs_source_read
  bundle_layout_resolves_skill_not_bundle
  cat_after_a_chained_command_still_counts
  grep_over_skill_md_is_not_a_load
  windowed_read_is_not_a_load
  ordinary_bash_is_not_a_load
  slash_mid_prompt_is_prose
  malformed_payload_exits_zero
  record_carries_session_and_cwd
)

printf 'skill-usage-log\n'
for t in "${TESTS[@]}"; do
  run_test "$t"
done

printf '\n  %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '  failed: %s\n' "${FAILED_NAMES[*]}"
  exit 1
fi
exit 0
