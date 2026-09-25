#!/usr/bin/env bash
# Tests for the curator's deterministic constraint helpers:
# assert-branch-lessons.sh, assert-repo-allowed.sh, and
# assert-curator-edit-allowed.sh.
#
# These helpers are the shell-level safety net for the curator
# subagent. Even if the LLM prompt drifts or a future model decides to
# "be helpful" by pushing to main, opening a PR against the wrong repo,
# or editing a file outside the approved guidance surface, the helpers
# fail closed and the curator's bash invocation hard-aborts.
#
# Tests are exit-code-only — no output matching beyond "is the helper
# emitting on stderr where the contract says it should". No bats
# dependency; pattern mirrors scripts/tests/test-drain-to-staging.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/lib"

BRANCH_GUARD="$LIB_DIR/assert-branch-lessons.sh"
REPO_GUARD="$LIB_DIR/assert-repo-allowed.sh"
EDIT_GUARD="$LIB_DIR/assert-curator-edit-allowed.sh"

PASS=0
FAIL=0
FAILED_NAMES=()

color_pass() { printf '\033[32m%s\033[0m' "$1"; }
color_fail() { printf '\033[31m%s\033[0m' "$1"; }

run_test() {
  local name="$1"
  local tmpdir
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/flux-test.XXXXXX")" || exit 1
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

# Initialise a throwaway git repo in TEST_TMP with one commit on the
# named branch. Returns the repo path on stdout.
init_repo_on_branch() {
  local branch="$1"
  local repo="$TEST_TMP/repo"
  mkdir -p "$repo"
  (
    cd "$repo"
    git init -q -b "$branch" .
    git -c user.email=t@t -c user.name=t commit --allow-empty -q -m "init"
  )
  printf '%s' "$repo"
}

# Point the guards at a throwaway src root holding one project checkout,
# so a scenario can exercise a repo that has a checkout (`sideproject`)
# and one that does not (`no-checkout`) without reading the real ~/src.
use_fixture_src_root() {
  export FLUX_SRC_ROOT="$TEST_TMP/src"
  mkdir -p "$FLUX_SRC_ROOT/sideproject"
}

# ---------------------------------------------------------------
# assert-branch-lessons.sh
# ---------------------------------------------------------------

scenario_branch_guard_accepts_lessons_branch() {
  local repo
  repo="$(init_repo_on_branch lessons/foo)"
  bash "$BRANCH_GUARD" -C "$repo"
}
verify_branch_guard_accepts_lessons_branch() {
  [ "$LAST_RC" = "0" ] || return 1
  return 0
}

scenario_branch_guard_rejects_main_branch() {
  local repo
  repo="$(init_repo_on_branch main)"
  bash "$BRANCH_GUARD" -C "$repo"
}
verify_branch_guard_rejects_main_branch() {
  [ "$LAST_RC" = "1" ] || return 1
  echo "$LAST_OUTPUT" | grep -q 'main' || return 1
  return 0
}

scenario_branch_guard_rejects_master_branch() {
  local repo
  repo="$(init_repo_on_branch master)"
  bash "$BRANCH_GUARD" -C "$repo"
}
verify_branch_guard_rejects_master_branch() {
  [ "$LAST_RC" = "1" ] || return 1
  return 0
}

# Detached HEAD: `git branch --show-current` prints empty. We assert
# the guard treats that as rejection.
scenario_branch_guard_rejects_detached_head() {
  local repo
  repo="$(init_repo_on_branch lessons/foo)"
  (
    cd "$repo"
    git checkout -q --detach HEAD
  )
  bash "$BRANCH_GUARD" -C "$repo"
}
verify_branch_guard_rejects_detached_head() {
  [ "$LAST_RC" = "1" ] || return 1
  echo "$LAST_OUTPUT" | grep -qi 'detached\|empty' || return 1
  return 0
}

# A branch that contains "lessons" as a substring but does NOT start
# with `lessons/` must be rejected — the guard is anchored to the
# branch-name prefix, not a substring match.
scenario_branch_guard_rejects_lookalike_branch() {
  local repo
  repo="$(init_repo_on_branch feat/lessons-curation)"
  bash "$BRANCH_GUARD" -C "$repo"
}
verify_branch_guard_rejects_lookalike_branch() {
  [ "$LAST_RC" = "1" ] || return 1
  return 0
}

scenario_branch_guard_rejects_non_repo() {
  bash "$BRANCH_GUARD" -C "$TEST_TMP"
}
verify_branch_guard_rejects_non_repo() {
  [ "$LAST_RC" = "2" ] || return 1
  return 0
}

# ---------------------------------------------------------------
# assert-repo-allowed.sh
# ---------------------------------------------------------------

scenario_repo_guard_accepts_project_with_checkout() {
  use_fixture_src_root
  bash "$REPO_GUARD" sideproject
}
verify_repo_guard_accepts_project_with_checkout() {
  [ "$LAST_RC" = "0" ] || return 1
  return 0
}

scenario_repo_guard_rejects_project_without_checkout() {
  use_fixture_src_root
  bash "$REPO_GUARD" no-checkout
}
verify_repo_guard_rejects_project_without_checkout() {
  [ "$LAST_RC" = "1" ] || return 1
  echo "$LAST_OUTPUT" | grep -q 'no-checkout' || return 1
  return 0
}

scenario_repo_guard_rejects_empty_arg() {
  bash "$REPO_GUARD" ""
}
verify_repo_guard_rejects_empty_arg() {
  [ "$LAST_RC" = "2" ] || return 1
  return 0
}

scenario_repo_guard_rejects_missing_arg() {
  bash "$REPO_GUARD"
}
verify_repo_guard_rejects_missing_arg() {
  [ "$LAST_RC" = "2" ] || return 1
  return 0
}

# Flux itself is curatable wherever it is checked out, so the guard
# accepts it without a fixture.
scenario_repo_guard_accepts_flux() {
  bash "$REPO_GUARD" flux
}
verify_repo_guard_accepts_flux() {
  [ "$LAST_RC" = "0" ] || return 1
  return 0
}

# ---------------------------------------------------------------
# assert-curator-edit-allowed.sh — per-repo edit-path guard
# ---------------------------------------------------------------

# Project repos: accept .claude/ paths under the worktree.
scenario_edit_guard_accepts_project_rules() {
  use_fixture_src_root
  bash "$EDIT_GUARD" sideproject /repos/sideproject-worktrees/lessons-abc /repos/sideproject-worktrees/lessons-abc/.claude/rules/foo.md
}
verify_edit_guard_accepts_project_rules() { [ "$LAST_RC" = "0" ]; }

scenario_edit_guard_accepts_project_root_claude_md() {
  use_fixture_src_root
  bash "$EDIT_GUARD" sideproject /repos/sideproject-worktrees/lessons-abc /repos/sideproject-worktrees/lessons-abc/CLAUDE.md
}
verify_edit_guard_accepts_project_root_claude_md() { [ "$LAST_RC" = "0" ]; }

scenario_edit_guard_accepts_project_root_agents_md() {
  use_fixture_src_root
  bash "$EDIT_GUARD" sideproject /repos/sideproject-worktrees/lessons-abc /repos/sideproject-worktrees/lessons-abc/AGENTS.md
}
verify_edit_guard_accepts_project_root_agents_md() { [ "$LAST_RC" = "0" ]; }

# Project repos: reject everything else.
scenario_edit_guard_rejects_project_src_path() {
  use_fixture_src_root
  bash "$EDIT_GUARD" sideproject /repos/sideproject-worktrees/lessons-abc /repos/sideproject-worktrees/lessons-abc/src/foo.py
}
verify_edit_guard_rejects_project_src_path() { [ "$LAST_RC" = "1" ]; }

scenario_edit_guard_rejects_project_agents_dir_path() {
  use_fixture_src_root
  bash "$EDIT_GUARD" sideproject /repos/sideproject-worktrees/lessons-abc /repos/sideproject-worktrees/lessons-abc/agents/foo.md
}
verify_edit_guard_rejects_project_agents_dir_path() { [ "$LAST_RC" = "1" ]; }

# Flux: wider writable surface.
scenario_edit_guard_accepts_flux_root_claude_md() {
  bash "$EDIT_GUARD" flux /repos/Flux-worktrees/lessons-abc /repos/Flux-worktrees/lessons-abc/CLAUDE.md
}
verify_edit_guard_accepts_flux_root_claude_md() { [ "$LAST_RC" = "0" ]; }

scenario_edit_guard_accepts_flux_root_agents_md() {
  bash "$EDIT_GUARD" flux /repos/Flux-worktrees/lessons-abc /repos/Flux-worktrees/lessons-abc/AGENTS.md
}
verify_edit_guard_accepts_flux_root_agents_md() { [ "$LAST_RC" = "0" ]; }

scenario_edit_guard_accepts_flux_model_profiles() {
  bash "$EDIT_GUARD" flux /repos/Flux-worktrees/lessons-abc /repos/Flux-worktrees/lessons-abc/model-profiles.toml
}
verify_edit_guard_accepts_flux_model_profiles() { [ "$LAST_RC" = "0" ]; }

scenario_edit_guard_accepts_flux_agents() {
  bash "$EDIT_GUARD" flux /repos/Flux-worktrees/lessons-abc /repos/Flux-worktrees/lessons-abc/agents/curator.md
}
verify_edit_guard_accepts_flux_agents() { [ "$LAST_RC" = "0" ]; }

scenario_edit_guard_accepts_flux_skill() {
  bash "$EDIT_GUARD" flux /repos/Flux-worktrees/lessons-abc /repos/Flux-worktrees/lessons-abc/skills/learn/SKILL.md
}
verify_edit_guard_accepts_flux_skill() { [ "$LAST_RC" = "0" ]; }

# Skills live one directory deep. A path nested under a bundle directory
# points at a tree Flux does not have.
scenario_edit_guard_rejects_flux_skill_bundle() {
  bash "$EDIT_GUARD" flux /repos/Flux-worktrees/lessons-abc /repos/Flux-worktrees/lessons-abc/skill-bundles/core/learn/SKILL.md
}
verify_edit_guard_rejects_flux_skill_bundle() { [ "$LAST_RC" = "1" ]; }

scenario_edit_guard_accepts_flux_claude_rules() {
  bash "$EDIT_GUARD" flux /repos/Flux-worktrees/lessons-abc /repos/Flux-worktrees/lessons-abc/.claude/rules/foo.md
}
verify_edit_guard_accepts_flux_claude_rules() { [ "$LAST_RC" = "0" ]; }

# Flux: hooks and random paths still rejected.
scenario_edit_guard_rejects_flux_hooks() {
  bash "$EDIT_GUARD" flux /repos/Flux-worktrees/lessons-abc /repos/Flux-worktrees/lessons-abc/hooks/foo.sh
}
verify_edit_guard_rejects_flux_hooks() { [ "$LAST_RC" = "1" ]; }

scenario_edit_guard_rejects_flux_random_path() {
  bash "$EDIT_GUARD" flux /repos/Flux-worktrees/lessons-abc /repos/Flux-worktrees/lessons-abc/random/foo.md
}
verify_edit_guard_rejects_flux_random_path() { [ "$LAST_RC" = "1" ]; }

# Edit-path must live INSIDE the worktree — sibling paths fail.
scenario_edit_guard_rejects_path_outside_worktree() {
  bash "$EDIT_GUARD" flux /repos/Flux-worktrees/lessons-abc /repos/somewhere-else/CLAUDE.md
}
verify_edit_guard_rejects_path_outside_worktree() { [ "$LAST_RC" = "1" ]; }

# Prefix-substring lookalike: worktree-root is `/repos/foo` but path
# is `/repos/foobar/CLAUDE.md`. Must reject (not match by substring).
scenario_edit_guard_rejects_prefix_substring_lookalike() {
  bash "$EDIT_GUARD" flux /repos/foo /repos/foobar/CLAUDE.md
}
verify_edit_guard_rejects_prefix_substring_lookalike() { [ "$LAST_RC" = "1" ]; }

# A repo with no checkout always fails: the curator cannot read the text
# it proposes to change.
scenario_edit_guard_rejects_repo_without_checkout() {
  use_fixture_src_root
  bash "$EDIT_GUARD" no-checkout /repos/no-checkout-worktrees/lessons-abc /repos/no-checkout-worktrees/lessons-abc/.claude/rules/foo.md
}
verify_edit_guard_rejects_repo_without_checkout() { [ "$LAST_RC" = "1" ]; }

scenario_edit_guard_rejects_missing_args() {
  bash "$EDIT_GUARD" flux /repos/Flux-worktrees/lessons-abc
}
verify_edit_guard_rejects_missing_args() { [ "$LAST_RC" = "2" ]; }

# ---------------------------------------------------------------
# Run all scenarios.
# ---------------------------------------------------------------

echo "Running curator-constraints tests..."

run_test branch_guard_accepts_lessons_branch
run_test branch_guard_rejects_main_branch
run_test branch_guard_rejects_master_branch
run_test branch_guard_rejects_detached_head
run_test branch_guard_rejects_lookalike_branch
run_test branch_guard_rejects_non_repo

run_test repo_guard_accepts_project_with_checkout
run_test repo_guard_rejects_project_without_checkout
run_test repo_guard_rejects_empty_arg
run_test repo_guard_rejects_missing_arg
run_test repo_guard_accepts_flux

run_test edit_guard_accepts_project_rules
run_test edit_guard_accepts_project_root_claude_md
run_test edit_guard_accepts_project_root_agents_md
run_test edit_guard_rejects_project_src_path
run_test edit_guard_rejects_project_agents_dir_path
run_test edit_guard_accepts_flux_root_claude_md
run_test edit_guard_accepts_flux_root_agents_md
run_test edit_guard_accepts_flux_model_profiles
run_test edit_guard_accepts_flux_agents
run_test edit_guard_accepts_flux_skill
run_test edit_guard_rejects_flux_skill_bundle
run_test edit_guard_accepts_flux_claude_rules
run_test edit_guard_rejects_flux_hooks
run_test edit_guard_rejects_flux_random_path
run_test edit_guard_rejects_path_outside_worktree
run_test edit_guard_rejects_prefix_substring_lookalike
run_test edit_guard_rejects_repo_without_checkout
run_test edit_guard_rejects_missing_args

echo
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  printf '  Failed: %s\n' "${FAILED_NAMES[*]}"
  exit 1
fi
