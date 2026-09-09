#!/usr/bin/env bash
# Pure-bash test harness for hooks/shared-checkout-guard.sh.
#
# Verifies the contract the shared checkout depends on: the two unsafe command
# shapes — sweeps (`git add -A|.|--all`, `git commit -a`) and discards
# (`git checkout -- <path>`, `git restore <path>`, `git reset --hard`) — are
# blocked when they act on the Flux checkout, whether the session sits in it,
# `cd`s into it, or names it with `git -C`; the same commands pass untouched in
# a worktree, because the guard keys on the checkout's physical path, not on
# the command alone; safe forms (named pathspecs, branch switches,
# `git restore --staged`, soft resets) pass everywhere; a command that merely
# quotes a dangerous pattern in prose or a heredoc is never blocked; the
# inline escape hatch works and is logged; and every block is delivered as a
# `{"decision":"block"}` JSON with the safe alternative named in the reason,
# with exit status 0.
#
# The guard runs no git commands — it classifies the command string and
# compares physical paths — so the fixtures are plain directories in an
# isolated tmpdir. No bats dependency — portable across macOS and Linux.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO_ROOT/hooks/shared-checkout-guard.sh"

# A real value in the session's environment would silently disarm every
# blocking assertion below.
unset FLUX_GUARD_SKIP

PASS=0
FAIL=0
FAILED_NAMES=""

color_pass() { printf '\033[32m%s\033[0m' "$1"; }
color_fail() { printf '\033[31m%s\033[0m' "$1"; }

ok()   { PASS=$((PASS+1)); printf '  %s %s\n' "$(color_pass PASS)" "$1"; }
bad()  { FAIL=$((FAIL+1)); FAILED_NAMES="${FAILED_NAMES:+$FAILED_NAMES }$1"
         printf '  %s %s\n' "$(color_fail FAIL)" "$1"
         [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /'; }

setup() {
  TEST_TMP="$(mktemp -d)"
  FLUX_FIX="$TEST_TMP/flux"
  WORKTREE_FIX="$TEST_TMP/flux-worktrees/feature"
  ELSEWHERE="$TEST_TMP/elsewhere"
  LOG_DIR="$TEST_TMP/logs"
  mkdir -p "$FLUX_FIX" "$WORKTREE_FIX" "$ELSEWHERE"
}
teardown() { rm -rf "$TEST_TMP"; }

# Feed the hook one Bash tool call: run_guard <command> <cwd> [tool_name].
run_guard() {
  jq -cn --arg cmd "$1" --arg cwd "$2" --arg tool "${3:-Bash}" \
      '{tool_name:$tool, tool_input:{command:$cmd}, cwd:$cwd}' \
    | FLUX_DIR="$FLUX_FIX" FLUX_LOG_DIR="$LOG_DIR" bash "$HOOK" 2>&1
}

# expect_block <name> <command> <cwd> [reason-fragment]
expect_block() {
  local name="$1" cmd="$2" cwd="$3" frag="${4:-}"
  local out
  out=$(run_guard "$cmd" "$cwd")
  if ! printf '%s' "$out" | jq -e '.decision == "block"' >/dev/null 2>&1; then
    bad "$name" "expected a block, got: ${out:-<empty>}"
    return
  fi
  if [ -n "$frag" ] && ! printf '%s' "$out" | jq -r '.reason' | grep -qF "$frag"; then
    bad "$name" "blocked, but the reason lacks '$frag': $out"
    return
  fi
  ok "$name"
}

# expect_allow <name> <command> <cwd> [tool_name]
expect_allow() {
  local name="$1" cmd="$2" cwd="$3" tool="${4:-Bash}"
  local out
  out=$(run_guard "$cmd" "$cwd" "$tool")
  if [ -z "$out" ]; then
    ok "$name"
  else
    bad "$name" "expected silence, got: $out"
  fi
}

printf '\nshared-checkout-guard\n'
setup

# --- 1. Sweeps are blocked in the shared checkout. --------------------------
expect_block "blocks git add -A"            'git add -A'                  "$FLUX_FIX" 'git add --'
expect_block "blocks git add ."             'git add .'                   "$FLUX_FIX"
expect_block "blocks git add --all"         'git add --all'               "$FLUX_FIX"
expect_block "blocks git add -vA (bundled)" 'git add -vA'                 "$FLUX_FIX"
expect_block "blocks git commit -a"         'git commit -a -m "msg"'      "$FLUX_FIX" 'git add --'
expect_block "blocks git commit -am"        'git commit -am "msg"'        "$FLUX_FIX"
expect_block "blocks a sweep after &&"      'git status && git add -A'    "$FLUX_FIX"

# --- 2. Discards are blocked in the shared checkout. ------------------------
expect_block "blocks git checkout -- <path>"       'git checkout -- notes.md'  "$FLUX_FIX" 'git show'
expect_block "blocks git checkout ."               'git checkout .'            "$FLUX_FIX"
expect_block "blocks git restore <path>"           'git restore notes.md'      "$FLUX_FIX"
expect_block "blocks git restore --staged --worktree" \
             'git restore --staged --worktree notes.md' "$FLUX_FIX"
expect_block "blocks git reset --hard"             'git reset --hard HEAD~1'   "$FLUX_FIX" 'git revert'

# --- 3. Safe forms pass in the shared checkout. -----------------------------
expect_allow "allows git add with named paths"   'git add -- a.md b.sh'       "$FLUX_FIX"
expect_allow "allows git add <file>"             'git add curation/x.md'      "$FLUX_FIX"
expect_allow "allows plain git commit"           'git commit -m "msg"'        "$FLUX_FIX"
expect_allow "allows git checkout -b"            'git checkout -b new-branch' "$FLUX_FIX"
expect_allow "allows git checkout <branch>"      'git checkout main'          "$FLUX_FIX"
expect_allow "allows git restore --staged"       'git restore --staged a.md'  "$FLUX_FIX"
expect_allow "allows git reset --soft"           'git reset --soft HEAD~1'    "$FLUX_FIX"
expect_allow "allows plain git reset"            'git reset HEAD~1'           "$FLUX_FIX"
expect_allow "allows git status"                 'git status'                 "$FLUX_FIX"

# --- 4. Mentioning a pattern is not invoking it. ----------------------------
expect_allow "allows quoted prose"        'echo "git add -A"'                "$FLUX_FIX"
expect_allow "allows grep for a pattern"  "grep -r 'git reset --hard' docs"  "$FLUX_FIX"
expect_allow "allows a heredoc body"      $'cat <<EOF\ngit add -A\nEOF'      "$FLUX_FIX"
expect_allow "allows -a inside a message" 'git commit -m "later use -a"'     "$FLUX_FIX"

# --- 5. The guard keys on the checkout, not the command. --------------------
expect_allow "allows a sweep in a worktree"    'git add -A'        "$WORKTREE_FIX"
expect_allow "allows a discard in a worktree"  'git reset --hard'  "$WORKTREE_FIX"
expect_allow "allows a sweep elsewhere"        'git add -A'        "$ELSEWHERE"
expect_block "blocks git -C <flux> from elsewhere" \
             "git -C $FLUX_FIX add -A" "$ELSEWHERE"
expect_block "blocks a discard via git -C <flux>" \
             "git -C $FLUX_FIX reset --hard" "$ELSEWHERE"
expect_block "blocks cd <flux> && sweep from elsewhere" \
             "cd $FLUX_FIX && git add -A" "$ELSEWHERE"
ln -s "$FLUX_FIX" "$TEST_TMP/flux-link"
expect_block "resolves a symlinked cwd to the checkout" \
             'git add -A' "$TEST_TMP/flux-link"

# --- 6. The escape hatch works and leaves a trace. --------------------------
expect_allow "inline FLUX_GUARD_SKIP=1 bypasses" \
             'FLUX_GUARD_SKIP=1 git add -A' "$FLUX_FIX"
if grep -q "skipped" "$LOG_DIR/shared-checkout-guard.log" 2>/dev/null; then
  ok "logs the bypass"
else
  bad "logs the bypass" "no 'skipped' line in $LOG_DIR/shared-checkout-guard.log"
fi
if grep -q "blocked	git-add-sweep" "$LOG_DIR/shared-checkout-guard.log" 2>/dev/null; then
  ok "logs each block with its kind"
else
  bad "logs each block with its kind" "no 'blocked' line in $LOG_DIR/shared-checkout-guard.log"
fi

# --- 7. A block is a JSON decision, never a non-zero exit. ------------------
out=$(run_guard 'git add -A' "$FLUX_FIX"); rc=$?
if [ "$rc" -eq 0 ]; then
  ok "exits 0 when blocking (the JSON carries the decision)"
else
  bad "exits 0 when blocking (the JSON carries the decision)" "exit $rc, out=$out"
fi

# --- 8. Everything outside a Bash git call passes silently. -----------------
expect_allow "ignores other tools"          'git add -A'   "$FLUX_FIX" "Read"
expect_allow "ignores commands without git" 'ls -la'       "$FLUX_FIX"
out=$(jq -cn --arg cwd "$FLUX_FIX" \
        '{tool_name:"Bash", tool_input:{command:"git add -A"}, cwd:$cwd}' \
      | FLUX_DIR="$TEST_TMP/does-not-exist" FLUX_LOG_DIR="$LOG_DIR" bash "$HOOK" 2>&1)
if [ -z "$out" ]; then
  ok "fails open when the configured checkout path is absent"
else
  bad "fails open when the configured checkout path is absent" "$out"
fi

teardown

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'failed: %s\n' "$FAILED_NAMES"
  exit 1
fi
exit 0
