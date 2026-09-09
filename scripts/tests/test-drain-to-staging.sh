#!/usr/bin/env bash
# Pure-bash test harness for hooks/drain-to-staging.sh.
# Verifies the drain semantics every emission-site skill depends on:
# valid pending entries land in staging.md under flock, schema-failing
# entries move to pending/.rejected/ with a reason header, blocklist
# hits move to .rejected/ likewise, the hook keeps exit 0 even when
# some entries fail (so it can never break the session-end auto-commit),
# and concurrent invocations do not interleave.
#
# Each test runs in an isolated LEARNINGS_DIR pointing at a fresh
# tmpdir so the real learnings/ tree is never touched. No bats
# dependency — portable across macOS and Linux.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRAIN_HOOK="$REPO_ROOT/hooks/drain-to-staging.sh"

PASS=0
FAIL=0
FAILED_NAMES=()

color_pass() { printf '\033[32m%s\033[0m' "$1"; }
color_fail() { printf '\033[31m%s\033[0m' "$1"; }

# Each test_* function sets up a fresh learnings tree under TEST_TMP,
# runs the drain hook in a subshell (so a sourcing failure in one test
# doesn't poison the next), captures stdout+stderr and exit code into
# LAST_OUTPUT / LAST_RC, then the verify_* check returns 0/1.
run_test() {
  local name="$1"
  local tmpdir
  tmpdir="$(mktemp -d)"
  export TEST_TMP="$tmpdir"
  export LEARNINGS_DIR="$tmpdir/learnings"
  mkdir -p "$LEARNINGS_DIR/pending/.rejected"
  : >"$LEARNINGS_DIR/staging.md"
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
# Fixture helpers
# ---------------------------------------------------------------

# Write a fully-valid entry to $1. Caller may override uuid/timestamp
# via $2 / $3 to construct multi-entry / age-based scenarios.
write_valid_entry() {
  local path="$1"
  local uuid="${2:-550e8400-e29b-41d4-a716-446655440000}"
  local timestamp="${3:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
  cat >"$path" <<EOF
---
uuid: $uuid
timestamp: $timestamp
target: sideproject/.claude/rules/review-lessons.md
scope: add
rationale: Reviewers repeatedly miss the no-nested-subqueries SQL convention.
proposed-text: |
  Prefer CTEs over nested subqueries in SQL. Qualify all column names
  with table aliases.
---
EOF
}

# Write an entry whose proposed-text body contains the supplied phrase.
write_entry_with_phrase() {
  local path="$1" phrase="$2"
  cat >"$path" <<EOF
---
uuid: 550e8400-e29b-41d4-a716-446655440000
timestamp: 2026-05-18T09:00:00Z
target: sideproject/.claude/rules/review-lessons.md
scope: add
rationale: Demonstration entry for blocklist coverage.
proposed-text: |
  This line mentions ${phrase} which should trip the blocklist.
---
EOF
}

# Count how many entries are in a staging file. Each entry starts with
# a `---` opening fence on its own line; we count those.
count_staging_entries() {
  local path="$1"
  [ -f "$path" ] || { echo 0; return; }
  grep -c '^---$' "$path" 2>/dev/null | awk '{print int($1/2)}'
}

# ---------------------------------------------------------------
# Scenarios
# ---------------------------------------------------------------

scenario_empty_pending() {
  bash "$DRAIN_HOOK"
}
verify_empty_pending() {
  [ "$LAST_RC" = "0" ] || return 1
  [ ! -s "$LEARNINGS_DIR/staging.md" ] || return 1
  return 0
}

scenario_one_valid_entry() {
  write_valid_entry "$LEARNINGS_DIR/pending/sess1-001.md"
  bash "$DRAIN_HOOK"
}
verify_one_valid_entry() {
  [ "$LAST_RC" = "0" ] || return 1
  [ -s "$LEARNINGS_DIR/staging.md" ] || return 1
  [ ! -f "$LEARNINGS_DIR/pending/sess1-001.md" ] || return 1
  grep -q '^uuid: 550e8400' "$LEARNINGS_DIR/staging.md" || return 1
  return 0
}

scenario_multiple_valid_entries_lex_order() {
  write_valid_entry "$LEARNINGS_DIR/pending/sess1-002.md" \
    "11111111-1111-4111-8111-111111111111"
  write_valid_entry "$LEARNINGS_DIR/pending/sess1-001.md" \
    "22222222-2222-4222-8222-222222222222"
  write_valid_entry "$LEARNINGS_DIR/pending/sess1-003.md" \
    "33333333-3333-4333-8333-333333333333"
  bash "$DRAIN_HOOK"
}
verify_multiple_valid_entries_lex_order() {
  [ "$LAST_RC" = "0" ] || return 1
  # All three pending files should be drained.
  [ -z "$(ls "$LEARNINGS_DIR/pending/"*.md 2>/dev/null)" ] || return 1
  # Three entries in staging.
  [ "$(count_staging_entries "$LEARNINGS_DIR/staging.md")" = "3" ] || return 1
  # Lex order: sess1-001 → 22222..., sess1-002 → 11111..., sess1-003 → 33333...
  # So in staging the uuid order should be 22222..., 11111..., 33333...
  local order
  order="$(grep '^uuid: ' "$LEARNINGS_DIR/staging.md" | awk '{print substr($2,1,8)}' | tr '\n' ' ')"
  [ "$order" = "22222222 11111111 33333333 " ] || return 1
  return 0
}

scenario_schema_invalid_file_rejected() {
  write_valid_entry "$LEARNINGS_DIR/pending/sess1-bad.md"
  # Strip a required field — schema fail.
  sed -i.bak '/^uuid:/d' "$LEARNINGS_DIR/pending/sess1-bad.md"
  rm -f "$LEARNINGS_DIR/pending/sess1-bad.md.bak"
  bash "$DRAIN_HOOK"
}
verify_schema_invalid_file_rejected() {
  [ "$LAST_RC" = "0" ] || return 1
  # Original removed.
  [ ! -f "$LEARNINGS_DIR/pending/sess1-bad.md" ] || return 1
  # Moved to .rejected/ with the original filename.
  [ -f "$LEARNINGS_DIR/pending/.rejected/sess1-bad.md" ] || return 1
  # Reason header prepended, naming the schema failure.
  head -n 1 "$LEARNINGS_DIR/pending/.rejected/sess1-bad.md" | \
    grep -q '^# REJECTED: schema' || return 1
  # Staging untouched.
  [ ! -s "$LEARNINGS_DIR/staging.md" ] || return 1
  return 0
}

scenario_blocklist_hit_rejected() {
  write_entry_with_phrase "$LEARNINGS_DIR/pending/sess1-block.md" "force push"
  bash "$DRAIN_HOOK"
}
verify_blocklist_hit_rejected() {
  [ "$LAST_RC" = "0" ] || return 1
  [ ! -f "$LEARNINGS_DIR/pending/sess1-block.md" ] || return 1
  [ -f "$LEARNINGS_DIR/pending/.rejected/sess1-block.md" ] || return 1
  head -n 1 "$LEARNINGS_DIR/pending/.rejected/sess1-block.md" | \
    grep -q '^# REJECTED: blocklist' || return 1
  [ ! -s "$LEARNINGS_DIR/staging.md" ] || return 1
  return 0
}

scenario_mixed_valid_and_invalid() {
  write_valid_entry "$LEARNINGS_DIR/pending/sess1-001.md" \
    "11111111-1111-4111-8111-111111111111"
  write_valid_entry "$LEARNINGS_DIR/pending/sess1-002.md"
  sed -i.bak '/^timestamp:/d' "$LEARNINGS_DIR/pending/sess1-002.md"
  rm -f "$LEARNINGS_DIR/pending/sess1-002.md.bak"
  write_entry_with_phrase "$LEARNINGS_DIR/pending/sess1-003.md" "skip tests"
  bash "$DRAIN_HOOK"
}
verify_mixed_valid_and_invalid() {
  # Drain must succeed even when some entries fail — never abort
  # session-end auto-commit because of one malformed lesson.
  [ "$LAST_RC" = "0" ] || return 1
  # Valid one made it.
  [ "$(count_staging_entries "$LEARNINGS_DIR/staging.md")" = "1" ] || return 1
  # The two failures got rejected.
  [ -f "$LEARNINGS_DIR/pending/.rejected/sess1-002.md" ] || return 1
  [ -f "$LEARNINGS_DIR/pending/.rejected/sess1-003.md" ] || return 1
  head -n 1 "$LEARNINGS_DIR/pending/.rejected/sess1-002.md" | \
    grep -q '^# REJECTED: schema' || return 1
  head -n 1 "$LEARNINGS_DIR/pending/.rejected/sess1-003.md" | \
    grep -q '^# REJECTED: blocklist' || return 1
  return 0
}

# Concurrent writer scenario: spawn two drain invocations in parallel
# against the same staging file with disjoint pending entries; flock on
# staging.lock must serialise the appends so the final line count
# matches the sum of valid entries — no half-written or interleaved
# entries.
scenario_concurrent_drains_serialise() {
  # Two pending dirs that share a staging.md but each have their own
  # pending entry. Drain hook reads its own pending tree; we override
  # PENDING_DIR per invocation to keep the inputs disjoint while the
  # output target is the shared staging.md under LEARNINGS_DIR.
  mkdir -p "$LEARNINGS_DIR/pending-a/.rejected" \
           "$LEARNINGS_DIR/pending-b/.rejected"
  write_valid_entry "$LEARNINGS_DIR/pending-a/sess-a.md" \
    "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  write_valid_entry "$LEARNINGS_DIR/pending-b/sess-b.md" \
    "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  LEARNINGS_PENDING_DIR="$LEARNINGS_DIR/pending-a" bash "$DRAIN_HOOK" &
  local pid_a=$!
  LEARNINGS_PENDING_DIR="$LEARNINGS_DIR/pending-b" bash "$DRAIN_HOOK" &
  local pid_b=$!
  wait "$pid_a" "$pid_b"
}
verify_concurrent_drains_serialise() {
  # Both entries land cleanly: 2 entries in staging, both source files
  # consumed, both uuids present, no interleaved lines.
  [ "$(count_staging_entries "$LEARNINGS_DIR/staging.md")" = "2" ] || return 1
  [ ! -f "$LEARNINGS_DIR/pending-a/sess-a.md" ] || return 1
  [ ! -f "$LEARNINGS_DIR/pending-b/sess-b.md" ] || return 1
  grep -q '^uuid: aaaaaaaa' "$LEARNINGS_DIR/staging.md" || return 1
  grep -q '^uuid: bbbbbbbb' "$LEARNINGS_DIR/staging.md" || return 1
  # Each entry contributes exactly 2 `---` fences. With 2 entries we
  # expect 4 fences total — proves nothing got truncated mid-entry.
  [ "$(grep -c '^---$' "$LEARNINGS_DIR/staging.md")" = "4" ] || return 1
  return 0
}

# Stress version of the concurrency check: 10 disjoint pending dirs
# all draining into one staging.md at the same time. Catches lock
# bugs that a 2-writer test would miss by chance.
scenario_concurrent_drains_stress() {
  local n=10 i
  for i in $(seq 1 "$n"); do
    mkdir -p "$LEARNINGS_DIR/pending-$i/.rejected"
    # 8-hex-digit uuid prefix so each writer is distinguishable.
    local uuid
    uuid="$(printf '%08d-0000-4000-8000-000000000000' "$i")"
    write_valid_entry "$LEARNINGS_DIR/pending-$i/sess-$i.md" "$uuid"
  done
  local pids=()
  for i in $(seq 1 "$n"); do
    LEARNINGS_PENDING_DIR="$LEARNINGS_DIR/pending-$i" \
      bash "$DRAIN_HOOK" &
    pids+=("$!")
  done
  wait "${pids[@]}"
}
verify_concurrent_drains_stress() {
  # 10 entries → 20 fences total, no truncation, all 10 uuids present.
  [ "$(count_staging_entries "$LEARNINGS_DIR/staging.md")" = "10" ] || return 1
  [ "$(grep -c '^---$' "$LEARNINGS_DIR/staging.md")" = "20" ] || return 1
  local i
  for i in $(seq 1 10); do
    grep -q "^uuid: $(printf '%08d' "$i")-0000-4000-8000-000000000000$" \
      "$LEARNINGS_DIR/staging.md" || return 1
  done
  return 0
}

# No-silent-drop contract: if the append to staging.md fails (e.g.
# staging.md is not writable), the validated pending file must stay in
# pending/ so the next drain can retry. Anything else "silently loses"
# the entry, which the drain hook is explicitly designed to never do.
scenario_append_failure_keeps_source() {
  write_valid_entry "$LEARNINGS_DIR/pending/sess1-keepme.md"
  chmod a-w "$LEARNINGS_DIR/staging.md"
  bash "$DRAIN_HOOK"
  chmod u+w "$LEARNINGS_DIR/staging.md"
}
verify_append_failure_keeps_source() {
  [ "$LAST_RC" = "0" ] || return 1
  [ -f "$LEARNINGS_DIR/pending/sess1-keepme.md" ] || return 1
  # staging.md was readonly so the append didn't land.
  [ ! -s "$LEARNINGS_DIR/staging.md" ] || return 1
  # Failure surfaced via stderr (captured into LAST_OUTPUT).
  echo "$LAST_OUTPUT" | grep -q 'append to staging.md failed' || return 1
  return 0
}

# No-silent-drop contract: if the rejection write fails (e.g. the
# .rejected/ directory is not writable), the source must stay in
# pending/ instead of vanishing from pending/, .rejected/, and staging
# simultaneously.
scenario_reject_write_failure_keeps_source() {
  write_valid_entry "$LEARNINGS_DIR/pending/sess1-keepme.md"
  # Strip a required field to force schema rejection.
  sed -i.bak '/^uuid:/d' "$LEARNINGS_DIR/pending/sess1-keepme.md"
  rm -f "$LEARNINGS_DIR/pending/sess1-keepme.md.bak"
  chmod a-w "$LEARNINGS_DIR/pending/.rejected"
  bash "$DRAIN_HOOK"
  chmod u+w "$LEARNINGS_DIR/pending/.rejected"
}
verify_reject_write_failure_keeps_source() {
  [ "$LAST_RC" = "0" ] || return 1
  [ -f "$LEARNINGS_DIR/pending/sess1-keepme.md" ] || return 1
  # Nothing landed in .rejected/.
  [ ! -f "$LEARNINGS_DIR/pending/.rejected/sess1-keepme.md" ] || return 1
  # No half-written tmp left behind.
  [ ! -f "$LEARNINGS_DIR/pending/.rejected/sess1-keepme.md.tmp" ] || return 1
  echo "$LAST_OUTPUT" | grep -q 'failed to write rejection' || return 1
  return 0
}

# ---------------------------------------------------------------
# Run all scenarios.
# ---------------------------------------------------------------

echo "Running drain-to-staging.sh tests..."

run_test empty_pending
run_test one_valid_entry
run_test multiple_valid_entries_lex_order
run_test schema_invalid_file_rejected
run_test blocklist_hit_rejected
run_test mixed_valid_and_invalid
run_test concurrent_drains_serialise
run_test concurrent_drains_stress
run_test append_failure_keeps_source
run_test reject_write_failure_keeps_source

echo
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  printf '  Failed: %s\n' "${FAILED_NAMES[*]}"
  exit 1
fi
