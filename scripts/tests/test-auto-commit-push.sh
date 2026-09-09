#!/usr/bin/env bash
# Pure-bash test harness for the Flux push path in hooks/auto-commit-push.sh.
#
# Verifies the sync contract the shared checkout depends on: commits made on
# two machines to disjoint files both reach origin (the behind machine rebases
# its own commits onto origin and pushes); a genuine textual conflict aborts
# the rebase, leaves the commits local, and names who to reconcile with rather
# than resolving anything; and the autostash carries another session's
# uncommitted edit across the rebase without committing or losing it.
#
# Each test builds a fresh bare origin plus two clones ("machine A" and
# "machine B") in an isolated tmpdir, with a hermetic git config, so no real
# repo and no user config is ever touched. No bats dependency — portable
# across macOS and Linux.

set -uo pipefail

# Git exports GIT_DIR, GIT_INDEX_FILE, GIT_WORK_TREE and friends to every
# hook it runs, and `git -C <path>` does NOT override them — the env wins.
# hooks/pre-commit.sh runs this suite from inside `git commit`, so without
# this every fixture command below would operate on the real repository
# instead of its tmpdir: `git init --bare` marks it bare, `git add` stages
# into its index, and fixture commits land on its branch. Observed, not
# theoretical.
# The identity pair matters as much as the location: GIT_AUTHOR_NAME outranks
# a fixture clone's own `user.name`, so the two machines this suite builds both
# commit as whoever ran the outer commit, and every assertion about who to
# reconcile with reads one person where there were two.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX GIT_COMMON_DIR \
      GIT_NAMESPACE GIT_CONFIG_PARAMETERS GIT_REFLOG_ACTION \
      GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE \
      GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO_ROOT/hooks/auto-commit-push.sh"

PASS=0
FAIL=0
FAILED_NAMES=""

color_pass() { printf '\033[32m%s\033[0m' "$1"; }
color_fail() { printf '\033[31m%s\033[0m' "$1"; }

# Each test gets a fresh origin/cloneA/cloneB fixture under TEST_TMP. The
# scenario runs in a subshell so a failure in one cannot poison the next;
# stdout+stderr and exit code land in LAST_OUTPUT / LAST_RC for the verify.
run_test() {
  local name="$1"
  local tmpdir
  tmpdir="$(mktemp -d)"
  export TEST_TMP="$tmpdir"

  # Hermetic git: identity comes from the per-clone config below, nothing
  # from the machine running the tests.
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_CONFIG_GLOBAL="$tmpdir/gitconfig"
  cat >"$GIT_CONFIG_GLOBAL" <<'EOF'
[init]
	defaultBranch = main
[user]
	name = Test Harness
	email = harness@example.invalid
EOF

  export ORIGIN="$tmpdir/origin.git"
  export CLONE_A="$tmpdir/machine-a"
  export CLONE_B="$tmpdir/machine-b"

  git init --bare -q "$ORIGIN"
  local seed="$tmpdir/seed"
  git init -q "$seed"
  printf 'seed\n' >"$seed/README.md"
  printf 'one\n' >"$seed/shared.txt"
  git -C "$seed" add README.md shared.txt
  git -C "$seed" commit -qm "seed"
  git -C "$seed" push -q "$ORIGIN" main

  git clone -q "$ORIGIN" "$CLONE_A"
  git clone -q "$ORIGIN" "$CLONE_B"
  git -C "$CLONE_A" config user.name "Machine A"
  git -C "$CLONE_A" config user.email "machine-a@example.invalid"
  git -C "$CLONE_B" config user.name "Machine B"
  git -C "$CLONE_B" config user.email "machine-b@example.invalid"

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
    FAILED_NAMES="${FAILED_NAMES} ${name}"
    printf '  %s %s\n    tmpdir: %s\n    rc=%s\n    out: %s\n' \
      "$(color_fail FAIL)" "$name" "$tmpdir" "$rc" "$out"
  fi
}

# Run the Flux pass of the hook against one clone. CLAUDE_PROJECT_DIR is
# pointed at the same clone so the Project pass recognises it as the Flux
# repo and skips — exactly the dispatch a real session hits.
run_hook_on() {
  local clone="$1"
  FLUX_DIR="$clone" CLAUDE_PROJECT_DIR="$clone" FLUX_FETCH_TIMEOUT=10 \
    bash "$HOOK"
}

origin_files() {
  git -C "$ORIGIN" ls-tree --name-only main
}

# ---------------------------------------------------------------
# 1. Two machines commit disjoint files; both land after the rebase replay.
# ---------------------------------------------------------------

scenario_disjoint_files_both_land() {
  printf 'from A\n' >"$CLONE_A/a.txt"
  git -C "$CLONE_A" add a.txt
  git -C "$CLONE_A" commit -qm "a: capture from machine A"
  run_hook_on "$CLONE_A"

  # B committed before A pushed, so B is now behind origin with its own commit.
  printf 'from B\n' >"$CLONE_B/b.txt"
  git -C "$CLONE_B" add b.txt
  git -C "$CLONE_B" commit -qm "b: capture from machine B"
  run_hook_on "$CLONE_B"
}
verify_disjoint_files_both_land() {
  [ "$LAST_RC" = "0" ] || return 1
  origin_files | grep -qx 'a.txt' || return 1
  origin_files | grep -qx 'b.txt' || return 1
  # B replayed onto A's push: both commits in B's history, nothing left ahead.
  [ "$(git -C "$CLONE_B" rev-list --count 'origin/main..HEAD')" = "0" ] || return 1
  printf '%s' "$LAST_OUTPUT" | grep -q 'after rebasing over 1 from origin' || return 1
  return 0
}

# ---------------------------------------------------------------
# 2. A genuine textual conflict: commits stay local, the hook reports who to
#    reconcile with, and resolves nothing.
# ---------------------------------------------------------------

scenario_conflict_reports_not_resolves() {
  printf 'A version\n' >"$CLONE_A/shared.txt"
  git -C "$CLONE_A" add shared.txt
  git -C "$CLONE_A" commit -qm "shared: A's edit"
  git -C "$CLONE_A" push -q origin main

  printf 'B version\n' >"$CLONE_B/shared.txt"
  git -C "$CLONE_B" add shared.txt
  git -C "$CLONE_B" commit -qm "shared: B's edit"
  run_hook_on "$CLONE_B"
}
verify_conflict_reports_not_resolves() {
  [ "$LAST_RC" = "0" ] || return 1
  # Origin still holds A's version only — nothing was force-resolved or pushed.
  [ "$(git -C "$ORIGIN" show main:shared.txt)" = "A version" ] || return 1
  # B's commit is still local, its content untouched, no rebase left in flight.
  [ "$(git -C "$CLONE_B" rev-list --count 'origin/main..HEAD')" = "1" ] || return 1
  [ "$(cat "$CLONE_B/shared.txt")" = "B version" ] || return 1
  [ ! -d "$CLONE_B/.git/rebase-merge" ] && [ ! -d "$CLONE_B/.git/rebase-apply" ] || return 1
  [ -z "$(git -C "$CLONE_B" status --porcelain -uall)" ] || return 1
  # The report names the conflicting file and who pushed the incoming commit.
  printf '%s' "$LAST_OUTPUT" | grep -q 'shared.txt' || return 1
  printf '%s' "$LAST_OUTPUT" | grep -q 'Machine A' || return 1
  printf '%s' "$LAST_OUTPUT" | grep -qi 'reconcile' || return 1
  return 0
}

# ---------------------------------------------------------------
# 3. Autostash: an unrelated dirty file survives the rebase — never blocking
#    it, never committed, never lost.
# ---------------------------------------------------------------

scenario_autostash_preserves_dirty_file() {
  printf 'from A\n' >"$CLONE_A/a.txt"
  git -C "$CLONE_A" add a.txt
  git -C "$CLONE_A" commit -qm "a: capture from machine A"
  git -C "$CLONE_A" push -q origin main

  # B: one commit of its own, plus another session's uncommitted edit to a
  # tracked file no commit touches.
  printf 'from B\n' >"$CLONE_B/b.txt"
  git -C "$CLONE_B" add b.txt
  git -C "$CLONE_B" commit -qm "b: capture from machine B"
  printf 'mid-edit by another session\n' >"$CLONE_B/README.md"
  run_hook_on "$CLONE_B"
}
verify_autostash_preserves_dirty_file() {
  [ "$LAST_RC" = "0" ] || return 1
  # The rebase went through and the commit was pushed despite the dirty file.
  origin_files | grep -qx 'b.txt' || return 1
  [ "$(git -C "$CLONE_B" rev-list --count 'origin/main..HEAD')" = "0" ] || return 1
  # The dirty edit is back in the working tree, still uncommitted.
  [ "$(cat "$CLONE_B/README.md")" = "mid-edit by another session" ] || return 1
  git -C "$CLONE_B" status --porcelain | grep -q '^ M README.md' || return 1
  # And origin never received it.
  [ "$(git -C "$ORIGIN" show main:README.md)" = "seed" ] || return 1
  # The leftover edit is reported, not claimed.
  printf '%s' "$LAST_OUTPUT" | grep -q '1 modified' || return 1
  return 0
}

# ---------------------------------------------------------------

printf 'test-auto-commit-push: Flux push path\n'
run_test disjoint_files_both_land
run_test conflict_reports_not_resolves
run_test autostash_preserves_dirty_file

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'failed:%s\n' "$FAILED_NAMES"
  exit 1
fi
exit 0
