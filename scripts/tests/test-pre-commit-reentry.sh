#!/usr/bin/env bash
# Tests hooks/pre-commit.sh in the environment git actually gives it.
#
# git exports GIT_DIR, GIT_INDEX_FILE and its other repo-location variables
# into every hook, and they outrank `git -C <dir>`. The suites the hook runs
# build fixture repos and commit in them, so without those variables cleared
# every such commit lands in the repo being committed to — which re-enters the
# hook, which runs the suites again, without a floor.
#
# Both halves are covered: the suites see a cleared environment, and a nested
# commit is let through without re-running them. The second is what bounds the
# recursion if the first ever regresses, so it is tested on its own rather than
# inferred from the first passing.
#
# The fixture is a repo carrying copies of the hook, the secrets check and the
# runner, so `resolve_self` lands inside the fixture and the real suites never
# run. The probe suite refuses to act past REENTRY_CEILING, so a regression in
# either half fails this test instead of filling the machine.

set -uo pipefail

# This suite is itself run by the hook it tests, which exports the re-entry
# guard. Inherited, every fixture commit below would skip the hook body and
# every assertion would pass without testing anything.
unset FLUX_PRE_COMMIT_ACTIVE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

REENTRY_CEILING=2

PASS=0
FAIL=0
FAILED_NAMES=""

color_pass() { printf '\033[32m%s\033[0m' "$1"; }
color_fail() { printf '\033[31m%s\033[0m' "$1"; }

TEST_TMP=""
cleanup() { [ -n "$TEST_TMP" ] && rm -rf "$TEST_TMP"; }
trap cleanup EXIT

# A repo that runs the real hook against a probe suite of our own.
#
# $1 is the body of the probe. It runs as scripts/tests/test-probe.sh, with
# PROBE_LOG naming a file outside the fixture (inside, a commit would sweep it)
# and DEPTH_FILE counting entries so a runaway cannot outlive this test.
build_fixture() {
  local probe_body="$1"

  FIXTURE="$TEST_TMP/fixture"
  PROBE_LOG="$TEST_TMP/probe.log"
  DEPTH_FILE="$TEST_TMP/depth"

  mkdir -p "$FIXTURE/hooks" "$FIXTURE/scripts/tests"
  : >"$PROBE_LOG"
  printf '0\n' >"$DEPTH_FILE"

  cp "$REPO_ROOT/hooks/pre-commit.sh" "$FIXTURE/hooks/pre-commit.sh"
  cp "$REPO_ROOT/hooks/pre-commit-secrets-check.sh" "$FIXTURE/hooks/"
  cp "$REPO_ROOT/scripts/tests/run-all.sh" "$FIXTURE/scripts/tests/run-all.sh"
  chmod +x "$FIXTURE/hooks/"*.sh "$FIXTURE/scripts/tests/run-all.sh"

  {
    printf '#!/usr/bin/env bash\n'
    printf 'PROBE_LOG=%q\n' "$PROBE_LOG"
    printf 'DEPTH_FILE=%q\n' "$DEPTH_FILE"
    printf 'FIXTURE=%q\n' "$FIXTURE"
    printf 'TEST_TMP=%q\n' "$TEST_TMP"
    printf 'CEILING=%q\n' "$REENTRY_CEILING"
    # The ceiling is read and written before the probe does anything, so a
    # probe that re-enters is stopped on the way in rather than on the way out.
    printf 'depth=$(cat "$DEPTH_FILE")\n'
    printf 'depth=$((depth + 1))\n'
    printf 'printf "%%s\\n" "$depth" >"$DEPTH_FILE"\n'
    printf 'if [ "$depth" -gt "$CEILING" ]; then\n'
    printf '  printf "CEILING\\n" >>"$PROBE_LOG"\n'
    printf '  exit 0\n'
    printf 'fi\n'
    printf '%s\n' "$probe_body"
  } >"$FIXTURE/scripts/tests/test-probe.sh"
  chmod +x "$FIXTURE/scripts/tests/test-probe.sh"

  git init -q "$FIXTURE"
  git -C "$FIXTURE" config user.email test@example.invalid
  git -C "$FIXTURE" config user.name "Test"
  git -C "$FIXTURE" config commit.gpgsign false
  ln -sf "$FIXTURE/hooks/pre-commit.sh" "$FIXTURE/.git/hooks/pre-commit"

  # A first commit with the hook bypassed, so the fixture has a HEAD to count
  # from and the suites are not run by the setup itself.
  git -C "$FIXTURE" add -A
  git -C "$FIXTURE" commit -q --no-verify -m "fixture base"
}

run_test() {
  local name="$1"
  TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/flux-test.XXXXXX")" || exit 1
  "scenario_$name"
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    PASS=$((PASS + 1))
    printf '  %s %s\n' "$(color_pass PASS)" "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES="${FAILED_NAMES} $name"
    printf '  %s %s\n' "$(color_fail FAIL)" "$name"
  fi
  cleanup
  TEST_TMP=""
  return 0
}

# ---------------------------------------------------------------
# The suites run without git's repo-location variables, so a fixture repo the
# suite builds receives the suite's commits.
scenario_suite_sees_no_repo_env() {
  build_fixture '
    for v in GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_PREFIX GIT_COMMON_DIR \
             GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE \
             GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE \
             GIT_NAMESPACE GIT_REFLOG_ACTION; do
      if [ -n "${!v:-}" ]; then printf "LEAKED %s\n" "$v" >>"$PROBE_LOG"; fi
    done
    # The idiom every suite uses: build a repo in a tmpdir, commit in it.
    seed="$TEST_TMP/seed"
    git init -q "$seed"
    git -C "$seed" config user.email t@t.invalid
    git -C "$seed" config user.name T
    printf "seed\n" >"$seed/README.md"
    git -C "$seed" add README.md
    git -C "$seed" commit -qm "seed"
    printf "SEED_COMMITS %s\n" "$(git -C "$seed" rev-list --count HEAD 2>/dev/null || echo 0)" >>"$PROBE_LOG"
    printf "SEED_AUTHOR %s\n" "$(git -C "$seed" log -1 --format=%an 2>/dev/null)" >>"$PROBE_LOG"
  '

  printf 'change\n' >"$FIXTURE/scripts/marker.txt"
  git -C "$FIXTURE" add scripts/marker.txt
  git -C "$FIXTURE" commit -q -m "trigger the suites" >/dev/null 2>&1

  grep -q '^LEAKED' "$PROBE_LOG" && return 1
  grep -q '^SEED_COMMITS 1$' "$PROBE_LOG" || return 1
  # Authored by the fixture repo's own config, not by whoever ran the commit.
  grep -q '^SEED_AUTHOR T$' "$PROBE_LOG" || return 1
  # The seed commit went to the seed repo, so the fixture gained only its own.
  [ "$(git -C "$FIXTURE" rev-list --count HEAD)" = "2" ] || return 1
  return 0
}

# ---------------------------------------------------------------
# A commit made into the repo under commit re-enters the hook. The nested
# commit is allowed, the suites are not run again, and nothing recurses. This
# is what holds if the environment clearing above ever regresses, so the probe
# commits into the fixture directly rather than relying on a leak to do it.
scenario_nested_commit_does_not_rerun_suites() {
  build_fixture '
    printf "nested\n" >"$FIXTURE/scripts/nested.txt"
    git -C "$FIXTURE" add scripts/nested.txt
    git -C "$FIXTURE" commit -qm "nested commit from inside the suite" \
      >>"$PROBE_LOG" 2>&1
    printf "NESTED_RC %s\n" "$?" >>"$PROBE_LOG"
  '

  printf 'change\n' >"$FIXTURE/scripts/marker.txt"
  git -C "$FIXTURE" add scripts/marker.txt
  git -C "$FIXTURE" commit -q -m "trigger the suites" >/dev/null 2>&1

  # The probe ran once. A second entry means the nested commit re-ran the
  # suites, which is the unbounded case.
  [ "$(cat "$DEPTH_FILE")" = "1" ] || return 1
  grep -q '^CEILING$' "$PROBE_LOG" && return 1
  # The nested commit was allowed rather than blocked.
  grep -q '^NESTED_RC 0$' "$PROBE_LOG" || return 1
  return 0
}

# ---------------------------------------------------------------
# Worktrees share .git, so the one installed hook fires for a commit in any of
# them while `resolve_self` still lands in the main checkout. The suites must
# come from the tree being committed: the fixture's own probe logs MAIN and the
# worktree's logs WORKTREE, so reading the wrong tree is visible rather than
# merely unproven.
scenario_suites_come_from_the_committed_tree() {
  build_fixture '
    printf "MAIN\n" >>"$PROBE_LOG"
  '

  local wt="$TEST_TMP/worktree"
  git -C "$FIXTURE" worktree add -q "$wt" -b wt-branch >/dev/null 2>&1 || return 1

  # Same path, different content: only the tree the hook reads decides which runs.
  {
    printf '#!/usr/bin/env bash\n'
    printf 'printf "WORKTREE\\n" >>%q\n' "$PROBE_LOG"
  } >"$wt/scripts/tests/test-probe.sh"
  chmod +x "$wt/scripts/tests/test-probe.sh"

  git -C "$wt" add scripts/tests/test-probe.sh
  git -C "$wt" commit -q -m "trigger the suites from the worktree" >/dev/null 2>&1

  grep -q '^WORKTREE$' "$PROBE_LOG" || return 1
  grep -q '^MAIN$' "$PROBE_LOG" && return 1
  return 0
}

# ---------------------------------------------------------------
# A tree staging hooks/ or scripts/ changes but carrying no runner is broken,
# and must be blocked. The main checkout's runner is present throughout, so a
# hook that reached for it would run the fixture's probe and let the commit
# through — which is what "no runner here" must not silently become.
scenario_missing_runner_blocks_the_commit() {
  build_fixture '
    printf "MAIN\n" >>"$PROBE_LOG"
  '

  local wt="$TEST_TMP/worktree"
  git -C "$FIXTURE" worktree add -q "$wt" -b wt-branch >/dev/null 2>&1 || return 1
  rm -f "$wt/scripts/tests/run-all.sh"

  printf 'change\n' >"$wt/scripts/marker.txt"
  git -C "$wt" add scripts/marker.txt
  git -C "$wt" commit -q -m "stage a scripts change with no runner" >/dev/null 2>&1

  # Blocked, and the main checkout's runner never stood in for the missing one.
  [ -z "$(git -C "$wt" log --oneline --grep 'no runner' 2>/dev/null)" ] || return 1
  grep -q '^MAIN$' "$PROBE_LOG" && return 1
  return 0
}

# ---------------------------------------------------------------

printf 'test-pre-commit-reentry: hook environment and re-entry\n'
run_test suite_sees_no_repo_env
run_test nested_commit_does_not_rerun_suites
run_test suites_come_from_the_committed_tree
run_test missing_runner_blocks_the_commit

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'failed:%s\n' "$FAILED_NAMES"
  exit 1
fi
exit 0
