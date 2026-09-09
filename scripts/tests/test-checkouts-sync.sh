#!/usr/bin/env bash
# Pure-bash test harness for hooks/checkouts-sync.sh.
#
# Verifies the contract the code checkouts depend on: a checkout behind its
# remote is fast-forwarded before the session reads it; one carrying local
# commits is left alone; one that cannot be brought up to date is REPORTED
# rather than passed over silently, since a quiet skip is precisely how a
# stale tree gets read as current; the context repo is left to
# flux-sync.sh; linked worktrees are never moved; and a session that
# starts against wholly current checkouts pays no context for the check.
#
# Each test builds a fresh set of bare origins and clones in an isolated
# tmpdir with hermetic git config, so no real repo and no user config is
# ever touched. No bats dependency — portable across macOS and Linux.

set -uo pipefail

# Git exports GIT_DIR, GIT_INDEX_FILE, GIT_WORK_TREE and friends to every
# hook it runs, and `git -C <path>` does NOT override them — the env wins.
# hooks/pre-commit.sh runs this suite from inside `git commit`, so without
# this every fixture command below would operate on the real repository
# instead of its tmpdir: `git init --bare` marks it bare, `git add` stages
# into its index, and fixture commits land on its branch. Observed, not
# theoretical.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
      GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX GIT_COMMON_DIR \
      GIT_NAMESPACE GIT_CONFIG_PARAMETERS GIT_REFLOG_ACTION \
      GIT_AUTHOR_DATE GIT_COMMITTER_DATE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO_ROOT/hooks/checkouts-sync.sh"

PASS=0
FAIL=0
FAILED_NAMES=""

color_pass() { printf '\033[32m%s\033[0m' "$1"; }
color_fail() { printf '\033[31m%s\033[0m' "$1"; }

ok()   { PASS=$((PASS+1)); printf '  %s %s\n' "$(color_pass PASS)" "$1"; }
bad()  { FAIL=$((FAIL+1)); FAILED_NAMES="${FAILED_NAMES:+$FAILED_NAMES }$1"
         printf '  %s %s\n' "$(color_fail FAIL)" "$1"
         [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /'; }

# Build "<name>" as a bare origin plus a clone under $SRC, seeded with two
# files so a later commit can touch one while the tree modifies the other.
make_repo() {
  local name="$1"
  local origin="$TEST_TMP/$name-origin.git"
  git init --bare -q "$origin"
  local seed="$TEST_TMP/$name-seed"
  git init -q "$seed"
  printf 'a\n' >"$seed/a.txt"
  printf 'b\n' >"$seed/b.txt"
  git -C "$seed" add . && git -C "$seed" commit -qm seed
  git -C "$seed" push -q "$origin" HEAD:refs/heads/main
  git clone -q "$origin" "$SRC/$name"
  git -C "$SRC/$name" checkout -q -B main --track origin/main 2>/dev/null || true
}

# Add a commit to <name>'s origin, so the clone falls behind by one.
advance_origin() {
  local name="$1" file="${2:-a.txt}" body="${3:-remote}"
  local work="$TEST_TMP/$name-adv"
  rm -rf "$work"
  git clone -q "$TEST_TMP/$name-origin.git" "$work"
  printf '%s\n' "$body" >>"$work/$file"
  git -C "$work" add . && git -C "$work" commit -qm "advance $file"
  git -C "$work" push -q origin HEAD:main
}

# Is <name>'s checkout at its origin's tip?
#
# Deliberately not `rev-list HEAD..@{u}`: that reads the remote-tracking
# ref, which in a fresh clone is stale until something fetches — so it
# reports "not behind" for a checkout that is, which is the very failure
# this hook exists to catch. Comparing HEAD against the origin repository's
# own branch tip needs no remote-tracking ref and cannot go stale.
at_origin_tip() {
  local name="$1"
  [ "$(git -C "$SRC/$name" rev-parse HEAD 2>/dev/null)"     = "$(git -C "$TEST_TMP/$name-origin.git" rev-parse main 2>/dev/null)" ]
}

run_hook() {
  ( cd "$TEST_TMP" && printf '{"source":"startup"}' \
      | FLUX_SRC_ROOT="$SRC" FLUX_SYNC_TIMEOUT=10 bash "$HOOK" 2>&1 )
}

setup() {
  TEST_TMP="$(mktemp -d)"
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_CONFIG_GLOBAL="$TEST_TMP/gitconfig"
  cat >"$GIT_CONFIG_GLOBAL" <<'EOF'
[init]
	defaultBranch = main
[user]
	name = Test Harness
	email = harness@example.invalid
[advice]
	detachedHead = false
EOF
  SRC="$TEST_TMP/src"
  mkdir -p "$SRC"
}
teardown() { rm -rf "$TEST_TMP"; }

printf '\ncheckouts-sync\n'

# --- 1. A behind checkout is fast-forwarded. -------------------------------
setup
make_repo sideproject
advance_origin sideproject
at_origin_tip sideproject && before=at-tip || before=behind
out=$(run_hook)
at_origin_tip sideproject && after=at-tip || after=behind
if [ "$before" = "behind" ] && [ "$after" = "at-tip" ]; then
  ok "fast-forwards a checkout that is behind"
else
  bad "fast-forwards a checkout that is behind" "before=$before after=$after out=$out"
fi
if printf '%s' "$out" | grep -q 'sideproject(+1)'; then
  ok "names the synced repo and how far it moved"
else
  bad "names the synced repo and how far it moved" "$out"
fi
teardown

# --- 2. Local commits are never trampled. ----------------------------------
setup
make_repo webapp
advance_origin webapp a.txt
printf 'local\n' >>"$SRC/webapp/b.txt"
git -C "$SRC/webapp" add . && git -C "$SRC/webapp" commit -qm "local work"
head_before=$(git -C "$SRC/webapp" rev-parse HEAD)
out=$(run_hook)
head_after=$(git -C "$SRC/webapp" rev-parse HEAD)
if [ "$head_before" = "$head_after" ]; then
  ok "leaves a diverged checkout untouched"
else
  bad "leaves a diverged checkout untouched" "HEAD moved: $head_before -> $head_after"
fi
if printf '%s' "$out" | grep -q 'NOT brought up to date' \
   && printf '%s' "$out" | grep -q 'webapp.*local commit'; then
  ok "reports the diverged checkout instead of passing over it"
else
  bad "reports the diverged checkout instead of passing over it" "$out"
fi
teardown

# --- 3. A dirty tree still syncs when nothing collides. --------------------
# flux-sync's precedent: git refuses per file, so an incoming commit that
# touches nothing being edited must still land.
setup
make_repo toolbelt
advance_origin toolbelt a.txt
printf 'uncommitted\n' >>"$SRC/toolbelt/b.txt"
out=$(run_hook)
if at_origin_tip toolbelt; then
  ok "syncs past an uncommitted edit to an unrelated file"
else
  bad "syncs past an uncommitted edit to an unrelated file" "$out"
fi
if grep -q uncommitted "$SRC/toolbelt/b.txt"; then
  ok "preserves the uncommitted edit"
else
  bad "preserves the uncommitted edit" "b.txt lost its local change"
fi
teardown

# --- 4. A collision is surfaced, not swallowed. ----------------------------
setup
make_repo atlas
advance_origin atlas a.txt
printf 'conflicting\n' >>"$SRC/atlas/a.txt"
out=$(run_hook)
if ! at_origin_tip atlas; then
  ok "declines the fast-forward that would trample a modified file"
else
  bad "declines the fast-forward that would trample a modified file" "$out"
fi
if printf '%s' "$out" | grep -q 'NOT brought up to date' \
   && printf '%s' "$out" | grep -q 'atlas'; then
  ok "reports the checkout it could not sync"
else
  bad "reports the checkout it could not sync" "$out"
fi
if printf '%s' "$out" | grep -q 'git grep'; then
  ok "names the compensating move for a stale tree"
else
  bad "names the compensating move for a stale tree" "$out"
fi
teardown

# --- 5. The context repo belongs to flux-sync. ---------------------------
setup
make_repo Flux
advance_origin Flux
out=$(run_hook)
if ! at_origin_tip Flux; then
  ok "leaves the Flux checkout to flux-sync.sh"
else
  bad "leaves the Flux checkout to flux-sync.sh" "$out"
fi
teardown

# --- 6. Linked worktrees are not primary checkouts. ------------------------
setup
make_repo sideproject
advance_origin sideproject
git -C "$SRC/sideproject" worktree add -q --detach "$SRC/sideproject-wt" HEAD 2>/dev/null
out=$(run_hook)
if [ -f "$SRC/sideproject-wt/.git" ]; then
  ok "fixture built a linked worktree (.git is a file)"
else
  bad "fixture built a linked worktree (.git is a file)" "no worktree created"
fi
if ! printf '%s' "$out" | grep -q 'sideproject-wt'; then
  ok "never touches a linked worktree"
else
  bad "never touches a linked worktree" "$out"
fi
teardown

# --- 7. Current checkouts cost the session nothing. ------------------------
setup
make_repo quiet_one
make_repo quiet_two
out=$(run_hook)
if [ -z "$out" ]; then
  ok "stays silent when every checkout is already current"
else
  bad "stays silent when every checkout is already current" "$out"
fi
teardown

# --- 8. Compaction is not a session start. --------------------------------
setup
make_repo compacting
advance_origin compacting
out=$( cd "$TEST_TMP" && printf '{"source":"compact"}' \
        | FLUX_SRC_ROOT="$SRC" bash "$HOOK" 2>&1 )
if [ -z "$out" ] && ! at_origin_tip compacting; then
  ok "does nothing on compaction"
else
  bad "does nothing on compaction" "out=$out at_tip=$(at_origin_tip compacting && echo yes || echo no)"
fi
teardown

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'failed: %s\n' "$FAILED_NAMES"
  exit 1
fi
exit 0
