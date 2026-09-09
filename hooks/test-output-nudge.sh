#!/bin/bash
# test-output-nudge.sh — PostToolUse hook on Bash
#
# When the model runs a test / lint / typecheck / heavy-build command via Bash
# and the output is large, inject a gentle nudge reminding it to delegate such
# calls to the `test-runner` subagent. The cheap-tier worker reads the noise;
# the main agent gets a summary + log path. Keeps expensive model contexts clean.
#
# Fires at most once per session (marker file keyed by session_id) so we don't
# nag on every invocation.

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Match well-known test/lint/typecheck/build commands. Deliberately conservative
# — we only want to nudge on commands whose output is reliably mostly noise.
NOISY_CMD_RE='(^|[[:space:]]|/|&&|\|\|)(pytest|jest|vitest|mocha|rspec|mypy|ruff|flake8|eslint|tsc|rubocop|phpunit)([[:space:]]|$)'
NOISY_COMPOUND_RE='(cargo[[:space:]]+test|go[[:space:]]+test|\./gradlew[[:space:]]+test|mvn[[:space:]]+test|(npm|yarn|pnpm)[[:space:]]+(run[[:space:]]+)?test)'

if ! echo "$COMMAND" | grep -Eq "$NOISY_CMD_RE" && \
   ! echo "$COMMAND" | grep -Eq "$NOISY_COMPOUND_RE"; then
  exit 0
fi

# Size threshold: roughly ~2-3K tokens of noise. Below this the savings aren't
# worth the nudge; above this it adds up fast across a session.
STDOUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // ""' 2>/dev/null)
STDERR=$(echo "$INPUT" | jq -r '.tool_response.stderr // ""' 2>/dev/null)
TOTAL_BYTES=$(printf '%s%s' "$STDOUT" "$STDERR" | wc -c | tr -d ' ')

if (( TOTAL_BYTES < 8000 )); then
  exit 0
fi

# Once-per-session dedup.
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
MARKER="${TMPDIR:-/tmp}/flux-test-nudge-${SESSION_ID}"
if [[ -f "$MARKER" ]]; then
  exit 0
fi
touch "$MARKER"

# Emit additionalContext back to the model.
BYTES_DISPLAY=$(awk -v b="$TOTAL_BYTES" 'BEGIN { printf "%.1f", b/1024 }')
MSG="[nudge] That Bash call produced ~${BYTES_DISPLAY}KB of output on a command whose result you mostly want as pass/fail + errors. Next time, delegate commands like this (pytest/jest/vitest/mypy/ruff/eslint/tsc/cargo test/go test/etc.) to the \`test-runner\` subagent — it returns a summary plus a log path you can read if you need full detail. This keeps your context clean and shifts the log-parsing work to the cheap tier. (This tip fires once per session.)"

jq -n --arg msg "$MSG" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $msg
  }
}'
