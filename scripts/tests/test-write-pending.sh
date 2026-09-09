#!/usr/bin/env bash
# Pure-bash test harness for the pending-file emission contract.
#
# Every emission-site skill writes a file under learnings/pending/
# whose front-matter must clear `validate_staging_entry` from
# scripts/lib/staging-schema.sh. The contract — what fields to fill,
# what filename to use, where the UUID comes from — lives as
# documented prose in learnings/ENTRY-TEMPLATE.md so the SKILL.md
# files can reference it by path instead of inlining the schema.
#
# This harness exercises that single-source-of-truth: it hand-authors
# a file matching the template's documented emission pattern and
# asserts the validator accepts it. It also asserts that the template
# itself names UUID + timestamp generation (the two fields the
# emission site has to synthesise at write time — everything else is
# user-supplied content) so the SKILL.md authors have unambiguous
# instructions to follow.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$SCRIPT_DIR/lib/staging-schema.sh"
TEMPLATE="$REPO_ROOT/learnings/ENTRY-TEMPLATE.md"
DRAIN_HOOK="$REPO_ROOT/hooks/drain-to-staging.sh"

PASS=0
FAIL=0
FAILED_NAMES=()

color_pass() { printf '\033[32m%s\033[0m' "$1"; }
color_fail() { printf '\033[31m%s\033[0m' "$1"; }

# Each scenario writes a fixture file, runs the assertion in a subshell
# (so a sourcing failure in one test doesn't poison the next), captures
# stdout+stderr and exit code into LAST_OUTPUT / LAST_RC, then the
# verify_* check returns 0/1.
run_test() {
  local name="$1"
  local tmpdir
  tmpdir="$(mktemp -d)"
  export TEST_TMP="$tmpdir"
  local out=""
  local rc=0
  if out="$( ( eval "scenario_$name" ) 2>&1 )"; then
    rc=0
  else
    rc=$?
  fi
  export LAST_OUTPUT="$out"
  export LAST_RC="$rc"
  if eval "verify_$name"; then
    PASS=$((PASS+1))
    printf '  %s %s\n' "$(color_pass PASS)" "$name"
    rm -rf "$tmpdir"
  else
    FAIL=$((FAIL+1))
    FAILED_NAMES+=("$name")
    printf '  %s %s\n    tmpdir: %s\n    rc=%s\n    out: %s\n' \
      "$(color_fail FAIL)" "$name" "$tmpdir" "$rc" "$out"
  fi
}

# ---------------------------------------------------------------
# Fixture: emit a pending file the way an emission-site skill would.
# Mirrors the documented pattern in ENTRY-TEMPLATE.md exactly so the
# test fails closed if the template drifts away from a schema-valid
# shape.
# ---------------------------------------------------------------

# Write a fixture using freshly-generated UUID + timestamp (matching
# what an emission-site skill would synthesise at write time) and the
# four user-supplied fields hard-coded for the test.
emit_pending_like_skill() {
  local dst="$1"
  local uuid
  if command -v uuidgen >/dev/null 2>&1; then
    uuid="$(uuidgen | tr 'A-Z' 'a-z')"
  else
    # Synth a deterministic v4-shaped UUID if uuidgen is unavailable
    # (some minimal CI containers). Keeps the test portable.
    uuid="550e8400-e29b-41d4-a716-446655440000"
  fi
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat >"$dst" <<EOF
---
uuid: $uuid
timestamp: $timestamp
target: analytics/.claude/rules/review-lessons.md
scope: add
rationale: Reviewers repeatedly miss the no-nested-subqueries SQL convention.
proposed-text: |
  Prefer CTEs over nested subqueries in SQL. Qualify all column names
  with table aliases.
---
EOF
}

# ---------------------------------------------------------------
# Scenarios
# ---------------------------------------------------------------

# An emitted pending file built per the documented contract must pass
# the schema validator end-to-end (no schema fail, no blocklist hit).
scenario_emitted_file_validates() {
  # shellcheck disable=SC1090
  source "$LIB"
  emit_pending_like_skill "$TEST_TMP/sess-abcd-$(date +%s).md"
  validate_staging_entry "$TEST_TMP"/sess-*.md
}
verify_emitted_file_validates() { [ "$LAST_RC" = "0" ]; }

# The template doc must instruct emission-site authors how to obtain
# the two fields the skill has to synthesise at write time. Without
# these the SKILL.md authors have no choice but to inline guesses,
# which is what the single-source-of-truth pattern is meant to prevent.
scenario_template_documents_uuid_generation() {
  grep -q 'uuidgen' "$TEMPLATE"
}
verify_template_documents_uuid_generation() { [ "$LAST_RC" = "0" ]; }

scenario_template_documents_timestamp_generation() {
  # date -u with an ISO-8601 format is the canonical recipe; the
  # template must show it explicitly so emission sites don't roll
  # their own divergent format.
  grep -Eq 'date.*-u.*%Y-%m-%dT%H:%M:%SZ' "$TEMPLATE"
}
verify_template_documents_timestamp_generation() { [ "$LAST_RC" = "0" ]; }

# The template must describe the Write-tool invocation pattern — the
# atomic .tmp → final-name rename — so every emission site converges
# on the same shape. Without this, two skills could pick different
# write strategies and one could leak half-written files into the
# drain hook's glob.
scenario_template_documents_atomic_write() {
  grep -Eq '\.tmp.*→.*\.md|atomic rename|mv .*\.tmp' "$TEMPLATE"
}
verify_template_documents_atomic_write() { [ "$LAST_RC" = "0" ]; }

# End-to-end: an emitted file fed through the real drain hook must
# land in staging.md and have its source removed. Re-asserts the
# integration covered by the drain-hook tests, this time from the
# emission contract's perspective.
scenario_emitted_file_drains_cleanly() {
  local learnings="$TEST_TMP/learnings"
  mkdir -p "$learnings/pending/.rejected"
  : >"$learnings/staging.md"
  emit_pending_like_skill "$learnings/pending/sess-abcd-001.md"
  LEARNINGS_DIR="$learnings" bash "$DRAIN_HOOK"
}
verify_emitted_file_drains_cleanly() {
  [ "$LAST_RC" = "0" ] || return 1
  local learnings="$TEST_TMP/learnings"
  # Source consumed.
  [ ! -f "$learnings/pending/sess-abcd-001.md" ] || return 1
  # Staging grew.
  [ -s "$learnings/staging.md" ] || return 1
  # And the entry it gained matches the shape we wrote.
  grep -q '^target: analytics/.claude/rules/review-lessons.md$' \
    "$learnings/staging.md" || return 1
  return 0
}

# ---------------------------------------------------------------
# Run all scenarios.
# ---------------------------------------------------------------

echo "Running write-pending emission contract tests..."

run_test emitted_file_validates
run_test template_documents_uuid_generation
run_test template_documents_timestamp_generation
run_test template_documents_atomic_write
run_test emitted_file_drains_cleanly

echo
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  printf '  Failed: %s\n' "${FAILED_NAMES[*]}"
  exit 1
fi
