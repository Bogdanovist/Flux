#!/usr/bin/env bash
# Pure-bash test harness for scripts/lib/staging-schema.sh.
# Verifies the validate_staging_entry and check_blocklist contracts
# that the staging-drain hook and the /learn slash command both depend on.
#
# Each test writes a temp entry file, sources the library, calls the
# function under test, and asserts exit code + (where checked) stderr
# substring. No bats dependency — portable across macOS and Linux.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$SCRIPT_DIR/lib/staging-schema.sh"

PASS=0
FAIL=0
FAILED_NAMES=()

color_pass() { printf '\033[32m%s\033[0m' "$1"; }
color_fail() { printf '\033[31m%s\033[0m' "$1"; }

# Each test_* function writes a fixture file, runs the function under
# test in a subshell (so a sourcing failure in one test doesn't poison
# the next), captures stdout+stderr and exit code into LAST_OUTPUT /
# LAST_RC, then the verify_* check returns 0/1.
run_test() {
  local name="$1"
  local tmpdir
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/flux-test.XXXXXX")" || exit 1
  pushd "$tmpdir" >/dev/null
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
  popd >/dev/null
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

# Write a fully-valid entry to $1. Caller may then mutate it with sed
# or rewrite individual fields to construct failure cases. Includes the
# advisory fields (target/scope/rationale) an automated emission site
# would supply — these are accepted but no longer required.
write_valid_entry() {
  local path="$1"
  cat >"$path" <<'EOF'
---
uuid: 550e8400-e29b-41d4-a716-446655440000
timestamp: 2026-05-18T09:00:00Z
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
# Used to exercise the blocklist.
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

# ---------------------------------------------------------------
# Scenarios — schema validation (required fields)
# ---------------------------------------------------------------

scenario_valid_entry() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_valid_entry "$TEST_TMP/entry.md"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_valid_entry() { [ "$LAST_RC" = "0" ]; }

# The quick-and-easy path: only uuid + timestamp + proposed-text. No
# target, no scope, no rationale. Must validate clean — this is what a
# freeform `/learn <prose>` writes.
scenario_minimal_freeform_entry() {
  # shellcheck disable=SC1090
  source "$LIB"
  cat >"$TEST_TMP/entry.md" <<'EOF'
---
uuid: 550e8400-e29b-41d4-a716-446655440000
timestamp: 2026-05-18T09:00:00Z
proposed-text: |
  When a background worker emits idle pings it is at rest, not dead.
---
EOF
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_minimal_freeform_entry() { [ "$LAST_RC" = "0" ]; }

# target is an optional advisory hint — omitting it must validate clean.
scenario_optional_target_omitted() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_valid_entry "$TEST_TMP/entry.md"
  sed -i.bak '/^target:/d' "$TEST_TMP/entry.md"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_optional_target_omitted() { [ "$LAST_RC" = "0" ]; }

# scope is an optional advisory hint — omitting it must validate clean.
scenario_optional_scope_omitted() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_valid_entry "$TEST_TMP/entry.md"
  sed -i.bak '/^scope:/d' "$TEST_TMP/entry.md"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_optional_scope_omitted() { [ "$LAST_RC" = "0" ]; }

# rationale is an optional advisory hint — omitting it must validate clean.
scenario_optional_rationale_omitted() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_valid_entry "$TEST_TMP/entry.md"
  sed -i.bak '/^rationale:/d' "$TEST_TMP/entry.md"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_optional_rationale_omitted() { [ "$LAST_RC" = "0" ]; }

# proposed-text (the lesson body) is still required.
scenario_missing_proposed_text() {
  # shellcheck disable=SC1090
  source "$LIB"
  cat >"$TEST_TMP/entry.md" <<'EOF'
---
uuid: 550e8400-e29b-41d4-a716-446655440000
timestamp: 2026-05-18T09:00:00Z
target: sideproject/.claude/rules/review-lessons.md
scope: add
rationale: Demonstration entry without proposed-text body.
---
EOF
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_missing_proposed_text() {
  [ "$LAST_RC" = "1" ] && echo "$LAST_OUTPUT" | grep -q "proposed-text"
}

# scope is advisory now — a value outside the old enum must NOT block.
scenario_advisory_scope_not_enforced() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_valid_entry "$TEST_TMP/entry.md"
  sed -i.bak 's/^scope: add/scope: delete/' "$TEST_TMP/entry.md"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_advisory_scope_not_enforced() { [ "$LAST_RC" = "0" ]; }

# target is advisory now — an off-shape value must NOT block filing.
# (The curator's edit guard still enforces target_shape_valid against
# the destination it actually picks; see the shape_* tests below.)
scenario_advisory_target_not_shape_checked() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_valid_entry "$TEST_TMP/entry.md"
  sed -i.bak 's|^target:.*|target: not-a-valid-target|' "$TEST_TMP/entry.md"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_advisory_target_not_shape_checked() { [ "$LAST_RC" = "0" ]; }

# A repo with no checkout in an advisory target must NOT block
# filing either (it's a hint, not a routing decision).
scenario_advisory_target_repo_not_checked() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_valid_entry "$TEST_TMP/entry.md"
  sed -i.bak 's|^target:.*|target: no-checkout/.claude/rules/review-lessons.md|' "$TEST_TMP/entry.md"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_advisory_target_repo_not_checked() { [ "$LAST_RC" = "0" ]; }

scenario_empty_entry() {
  # shellcheck disable=SC1090
  source "$LIB"
  : >"$TEST_TMP/entry.md"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_empty_entry() { [ "$LAST_RC" = "1" ]; }

scenario_missing_uuid() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_valid_entry "$TEST_TMP/entry.md"
  sed -i.bak '/^uuid:/d' "$TEST_TMP/entry.md"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_missing_uuid() {
  [ "$LAST_RC" = "1" ] && echo "$LAST_OUTPUT" | grep -qi "uuid"
}

scenario_malformed_uuid() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_valid_entry "$TEST_TMP/entry.md"
  # Replace v4 UUID with something that isn't v4-shaped.
  sed -i.bak 's/^uuid:.*/uuid: not-a-uuid/' "$TEST_TMP/entry.md"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_malformed_uuid() {
  [ "$LAST_RC" = "1" ] && echo "$LAST_OUTPUT" | grep -qi "uuid"
}

# ---------------------------------------------------------------
# Scenarios — blocklist (exit 2, distinct from schema fail)
# ---------------------------------------------------------------

scenario_blocklist_no_verify() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_entry_with_phrase "$TEST_TMP/entry.md" "--no-verify"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_blocklist_no_verify() { [ "$LAST_RC" = "2" ]; }

scenario_blocklist_force_push() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_entry_with_phrase "$TEST_TMP/entry.md" "force push"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_blocklist_force_push() { [ "$LAST_RC" = "2" ]; }

scenario_blocklist_skip_tests() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_entry_with_phrase "$TEST_TMP/entry.md" "skip tests"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_blocklist_skip_tests() { [ "$LAST_RC" = "2" ]; }

scenario_blocklist_ignore_word() {
  # shellcheck disable=SC1090
  source "$LIB"
  # Phrase-level: only the full "ignore failing tests" phrase fires,
  # so bare uses of "ignore" in discipline-strengthening prose
  # (e.g. "Never ignore type errors") stay clean.
  write_entry_with_phrase "$TEST_TMP/entry.md" "ignore failing tests"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_blocklist_ignore_word() { [ "$LAST_RC" = "2" ]; }

scenario_blocklist_always_override() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_entry_with_phrase "$TEST_TMP/entry.md" "always override"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_blocklist_always_override() { [ "$LAST_RC" = "2" ]; }

scenario_blocklist_disable_word() {
  # shellcheck disable=SC1090
  source "$LIB"
  # Phrase-level: bare "disable" passes (e.g. "Disable assertions
  # only with reviewer sign-off"); the test-gating phrase trips.
  write_entry_with_phrase "$TEST_TMP/entry.md" "disable tests"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_blocklist_disable_word() { [ "$LAST_RC" = "2" ]; }

# Sanity: word-boundary means "disabled" inside another word does NOT
# fire (otherwise legitimate rationale text would be blocked).
scenario_blocklist_word_boundary_no_false_positive() {
  # shellcheck disable=SC1090
  source "$LIB"
  cat >"$TEST_TMP/entry.md" <<'EOF'
---
uuid: 550e8400-e29b-41d4-a716-446655440000
timestamp: 2026-05-18T09:00:00Z
target: sideproject/.claude/rules/review-lessons.md
scope: add
rationale: Word-boundary sanity check.
proposed-text: |
  The reviewer should ensure the documentation describes how features
  are enabled and undisabled-by-default in production paths.
---
EOF
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_blocklist_word_boundary_no_false_positive() {
  [ "$LAST_RC" = "0" ]
}

# ---------------------------------------------------------------
# Scenarios — target_shape_valid (the curator edit-guard's contract)
#
# Filing no longer shape-checks `target:`, but the curator's edit-path
# guard (assert-curator-edit-allowed.sh) still calls target_shape_valid
# against the destination the curator picks at promote time. These tests
# pin that contract directly, repo + rest-of-path, exit 0 PASS / 1 FAIL.
# ---------------------------------------------------------------

# A project repo is curatable when it has a checkout under the src root,
# so these scenarios point the library at a throwaway one.
use_fixture_src_root() {
  export FLUX_SRC_ROOT="$TEST_TMP/src"
  mkdir -p "$FLUX_SRC_ROOT/sideproject"
}

scenario_shape_project_root_claude() {
  use_fixture_src_root
  # shellcheck disable=SC1090
  source "$LIB"
  target_shape_valid sideproject "CLAUDE.md"
}
verify_shape_project_root_claude() { [ "$LAST_RC" = "0" ]; }

scenario_shape_project_root_agents() {
  use_fixture_src_root
  # shellcheck disable=SC1090
  source "$LIB"
  target_shape_valid sideproject "AGENTS.md"
}
verify_shape_project_root_agents() { [ "$LAST_RC" = "0" ]; }

scenario_shape_claude_rules() {
  use_fixture_src_root
  # shellcheck disable=SC1090
  source "$LIB"
  target_shape_valid sideproject ".claude/rules/review-lessons.md"
}
verify_shape_claude_rules() { [ "$LAST_RC" = "0" ]; }

scenario_shape_flux_root_claude() {
  # shellcheck disable=SC1090
  source "$LIB"
  target_shape_valid flux "CLAUDE.md"
}
verify_shape_flux_root_claude() { [ "$LAST_RC" = "0" ]; }

scenario_shape_flux_root_agents() {
  # shellcheck disable=SC1090
  source "$LIB"
  target_shape_valid flux "AGENTS.md"
}
verify_shape_flux_root_agents() { [ "$LAST_RC" = "0" ]; }

scenario_shape_flux_model_profiles() {
  # shellcheck disable=SC1090
  source "$LIB"
  target_shape_valid flux "model-profiles.toml"
}
verify_shape_flux_model_profiles() { [ "$LAST_RC" = "0" ]; }

scenario_shape_flux_agents() {
  # shellcheck disable=SC1090
  source "$LIB"
  target_shape_valid flux "agents/curator.md"
}
verify_shape_flux_agents() { [ "$LAST_RC" = "0" ]; }

scenario_shape_flux_skill() {
  # shellcheck disable=SC1090
  source "$LIB"
  target_shape_valid flux "skills/curate/SKILL.md"
}
verify_shape_flux_skill() { [ "$LAST_RC" = "0" ]; }

# Skills live one directory deep, each with its own SKILL.md. A target nested
# under a bundle directory names a tree this repo does not have, so the shape
# check must reject it rather than let the curator write outside skills/.
scenario_shape_flux_skill_bundle_rejected() {
  # shellcheck disable=SC1090
  source "$LIB"
  target_shape_valid flux "skill-bundles/core/learn/SKILL.md"
}
verify_shape_flux_skill_bundle_rejected() { [ "$LAST_RC" = "1" ]; }

scenario_shape_flux_claude_rules() {
  # shellcheck disable=SC1090
  source "$LIB"
  target_shape_valid flux ".claude/rules/foo.md"
}
verify_shape_flux_claude_rules() { [ "$LAST_RC" = "0" ]; }

# Hooks are code, not curatable prose — must FAIL the shape check.
scenario_shape_flux_hooks_rejected() {
  # shellcheck disable=SC1090
  source "$LIB"
  target_shape_valid flux "hooks/foo.sh"
}
verify_shape_flux_hooks_rejected() { [ "$LAST_RC" = "1" ]; }

scenario_shape_flux_random_rejected() {
  # shellcheck disable=SC1090
  source "$LIB"
  target_shape_valid flux "random/foo.md"
}
verify_shape_flux_random_rejected() { [ "$LAST_RC" = "1" ]; }

# A CLAUDE.md in the wrong place (nested, no .claude/) must FAIL.
scenario_shape_nested_claude_rejected() {
  use_fixture_src_root
  # shellcheck disable=SC1090
  source "$LIB"
  target_shape_valid sideproject "docs/CLAUDE.md"
}
verify_shape_nested_claude_rejected() { [ "$LAST_RC" = "1" ]; }

# A repo with no checkout must FAIL naming the src root it looked in:
# the curator cannot read text that is not on this machine.
scenario_shape_repo_without_checkout_rejected() {
  use_fixture_src_root
  # shellcheck disable=SC1090
  source "$LIB"
  target_shape_valid no-checkout ".claude/rules/foo.md"
}
verify_shape_repo_without_checkout_rejected() {
  [ "$LAST_RC" = "1" ] && echo "$LAST_OUTPUT" | grep -qi "no checkout"
}

# ---------------------------------------------------------------
# Scenarios — prompt-injection blocklist
# ---------------------------------------------------------------

scenario_blocklist_ignore_instructions() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_entry_with_phrase "$TEST_TMP/entry.md" "ignore all instructions"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_blocklist_ignore_instructions() { [ "$LAST_RC" = "2" ]; }

scenario_blocklist_disregard_previous() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_entry_with_phrase "$TEST_TMP/entry.md" "disregard previous instructions"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_blocklist_disregard_previous() { [ "$LAST_RC" = "2" ]; }

scenario_blocklist_forget_prior() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_entry_with_phrase "$TEST_TMP/entry.md" "forget prior instructions"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_blocklist_forget_prior() { [ "$LAST_RC" = "2" ]; }

scenario_blocklist_system_tag() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_entry_with_phrase "$TEST_TMP/entry.md" "</system>"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_blocklist_system_tag() { [ "$LAST_RC" = "2" ]; }

scenario_blocklist_instructions_tag() {
  # shellcheck disable=SC1090
  source "$LIB"
  write_entry_with_phrase "$TEST_TMP/entry.md" "<instructions>"
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_blocklist_instructions_tag() { [ "$LAST_RC" = "2" ]; }

# Sanity: legitimate uses of these verbs in evergreen rules-file prose
# must NOT trip the blocklist. "Ignore comments" is generic; "the
# system" appears in plenty of architectural lessons.
scenario_blocklist_injection_false_positive() {
  # shellcheck disable=SC1090
  source "$LIB"
  cat >"$TEST_TMP/entry.md" <<'EOF'
---
uuid: 550e8400-e29b-41d4-a716-446655440000
timestamp: 2026-05-18T09:00:00Z
target: sideproject/.claude/rules/review-lessons.md
scope: add
rationale: Injection-false-positive sanity check.
proposed-text: |
  Reviewers should not ignore comments left by previous reviewers.
  The system under test is what matters, not the system stub. When
  refactoring, disregard the local diff size and look at the whole
  call site.
---
EOF
  validate_staging_entry "$TEST_TMP/entry.md"
}
verify_blocklist_injection_false_positive() { [ "$LAST_RC" = "0" ]; }

# ---------------------------------------------------------------
# Run all scenarios.
# ---------------------------------------------------------------

echo "Running staging-schema.sh tests..."

run_test valid_entry
run_test minimal_freeform_entry
run_test optional_target_omitted
run_test optional_scope_omitted
run_test optional_rationale_omitted
run_test missing_proposed_text
run_test advisory_scope_not_enforced
run_test advisory_target_not_shape_checked
run_test advisory_target_repo_not_checked
run_test empty_entry
run_test missing_uuid
run_test malformed_uuid
run_test blocklist_no_verify
run_test blocklist_force_push
run_test blocklist_skip_tests
run_test blocklist_ignore_word
run_test blocklist_always_override
run_test blocklist_disable_word
run_test blocklist_word_boundary_no_false_positive
run_test shape_project_root_claude
run_test shape_project_root_agents
run_test shape_claude_rules
run_test shape_flux_root_claude
run_test shape_flux_root_agents
run_test shape_flux_model_profiles
run_test shape_flux_agents
run_test shape_flux_skill
run_test shape_flux_skill_bundle_rejected
run_test shape_flux_claude_rules
run_test shape_flux_hooks_rejected
run_test shape_flux_random_rejected
run_test shape_nested_claude_rejected
run_test shape_repo_without_checkout_rejected
run_test blocklist_ignore_instructions
run_test blocklist_disregard_previous
run_test blocklist_forget_prior
run_test blocklist_system_tag
run_test blocklist_instructions_tag
run_test blocklist_injection_false_positive

echo
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  printf '  Failed: %s\n' "${FAILED_NAMES[*]}"
  exit 1
fi
