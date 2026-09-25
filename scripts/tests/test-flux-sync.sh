#!/usr/bin/env bash
# Pure-bash test harness for the two halves of the multi-checkout guard:
# hooks/flux-sync.sh (SessionStart: fast-forward before the session reads
# anything) and the divergence guard in hooks/auto-commit-push.sh (Stop:
# refuse to commit while behind).
#
# They are tested together because they share a fixture — a bare origin plus
# two clones, one standing in for the other machine — and because the pair's
# value is the invariant they hold jointly: a checkout never commits onto a
# history it has not caught up with, so the append-only stores
# (learnings/staging.md, the two archives) never need a conflict resolution.
#
# Each test runs against fresh tmpdirs so no real checkout is touched. No bats
# dependency — portable across macOS and Linux.

set -uo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SYNC_HOOK="$REPO_ROOT/hooks/flux-sync.sh"
COMMIT_HOOK="$REPO_ROOT/hooks/auto-commit-push.sh"

PASS=0
FAIL=0
FAILED_NAMES=()

color_pass() { printf '\033[32m%s\033[0m' "$1"; }
color_fail() { printf '\033[31m%s\033[0m' "$1"; }

# ---------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------
# Builds:  ORIGIN (bare)  <-- OTHER (the other machine)
#                         <-- FLUX (the checkout under test)
# FLUX starts level with ORIGIN; a test advances ORIGIN via OTHER to
# put FLUX behind.
build_fixture() {
  ORIGIN="$TEST_TMP/origin.git"
  OTHER="$TEST_TMP/other"
  FLUX="$TEST_TMP/flux"

  # Branch names are pinned rather than inherited: init.defaultBranch varies by
  # machine, and a fixture that lands on `master` pushes nothing to `main`, so
  # origin never moves and every "behind" assertion passes vacuously.
  git init --quiet --bare "$ORIGIN"
  git -C "$ORIGIN" symbolic-ref HEAD refs/heads/main

  git clone --quiet "$ORIGIN" "$OTHER" 2>/dev/null
  git -C "$OTHER" symbolic-ref HEAD refs/heads/main
  git -C "$OTHER" config user.email test@example.com
  git -C "$OTHER" config user.name "Test"
  mkdir -p "$OTHER/learnings"
  printf 'base\n' >"$OTHER/learnings/staging.md"
  printf 'rules\n' >"$OTHER/AGENTS.md"
  git -C "$OTHER" add -A
  git -C "$OTHER" commit --quiet -m "base"
  git -C "$OTHER" push --quiet -u origin main

  git clone --quiet --branch main "$ORIGIN" "$FLUX" 2>/dev/null
  git -C "$FLUX" config user.email test@example.com
  git -C "$FLUX" config user.name "Test"
}

# Advance origin by one commit, made on the other machine.
#
# Hard-fails if origin's main did not actually move. A fixture that silently
# no-ops turns every behind/diverged assertion green for the wrong reason,
# which is exactly how this suite passed on one platform and not the other.
advance_origin() {
  local before after
  before=$(git -C "$ORIGIN" rev-parse main)
  git -C "$OTHER" pull --quiet --ff-only origin main
  printf 'moved on %s\n' "$1" >>"$OTHER/AGENTS.md"
  git -C "$OTHER" add -A
  git -C "$OTHER" commit --quiet -m "other machine: $1"
  git -C "$OTHER" push --quiet origin main
  after=$(git -C "$ORIGIN" rev-parse main)
  if [ "$before" = "$after" ]; then
    echo "FIXTURE BROKEN: origin/main did not advance" >&2
    return 1
  fi
}

run_sync_hook() {
  local source_field="${1:-startup}"
  printf '{"source":"%s"}' "$source_field" \
    | FLUX_DIR="$FLUX" FLUX_SYNC_TIMEOUT=10 CLAUDE_CONFIG_DIR="$TEST_TMP/claude" \
      bash "$SYNC_HOOK" 2>&1
}

run_commit_hook() {
  FLUX_DIR="$FLUX" FLUX_PROJECT_DIR="$FLUX" FLUX_FETCH_TIMEOUT=10 \
    bash "$COMMIT_HOOK" 2>&1
}

head_of() { git -C "$1" rev-parse HEAD; }

# Whether the checkout has reached origin's tip. HEAD equality is not the same
# question: the sync hook also refreshes this machine's skill-usage rollup and
# commits that one file, so HEAD moves on a session start that synced nothing.
at_origin_tip() { [ "$(git -C "$FLUX" rev-parse HEAD)" = "$(git -C "$ORIGIN" rev-parse main)" ]; }

run_test() {
  local name="$1"
  local tmpdir
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/flux-test.XXXXXX")" || exit 1
  export TEST_TMP="$tmpdir"
  local out=""
  local rc=0
  if out="$( ( build_fixture >/dev/null 2>&1; eval "scenario_$name" ) 2>&1 )"; then
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
# flux-sync.sh
# ---------------------------------------------------------------

# Behind with a clean tree is the case the hook exists for.
scenario_behind_clean_fast_forwards() {
  advance_origin "one"
  local before; before=$(head_of "$FLUX")
  local out; out=$(run_sync_hook)
  printf 'BEFORE=%s AFTER=%s OUT=%s\n' "$before" "$(head_of "$FLUX")" "$out"
}
verify_behind_clean_fast_forwards() {
  local before after
  before=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*BEFORE=\([0-9a-f]*\).*/\1/p')
  after=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*AFTER=\([0-9a-f]*\).*/\1/p')
  [ "$before" != "$after" ] || return 1
  printf '%s' "$LAST_OUTPUT" | grep -q "Synced the context checkout" || return 1
  printf '%s' "$LAST_OUTPUT" | grep -q "fast-forwarded 1 commit" || return 1
}

# A concurrent session editing a file the incoming commits do not touch must
# not cost this checkout its sync — that tree is dirty most of the working
# day, so gating on it would disable the hook whenever it had work to do.
# advance_origin moves AGENTS.md, so staging.md stands in for the bystander.
scenario_behind_dirty_elsewhere_still_syncs() {
  advance_origin "one"
  printf 'another session mid-edit\n' >>"$FLUX/learnings/staging.md"
  local before; before=$(head_of "$FLUX")
  local out; out=$(run_sync_hook)
  printf 'BEFORE=%s AFTER=%s KEPT=%s OUT=%s\n' \
    "$before" "$(head_of "$FLUX")" \
    "$(grep -c 'another session mid-edit' "$FLUX/learnings/staging.md")" "$out"
}
verify_behind_dirty_elsewhere_still_syncs() {
  local before after
  before=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*BEFORE=\([0-9a-f]*\).*/\1/p')
  after=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*AFTER=\([0-9a-f]*\).*/\1/p')
  [ "$before" != "$after" ] || return 1
  # The bystander's uncommitted work must survive the fast-forward untouched.
  printf '%s' "$LAST_OUTPUT" | grep -q "KEPT=1" || return 1
  printf '%s' "$LAST_OUTPUT" | grep -q "Synced the context checkout" || return 1
}

# When the incoming commits DO touch a modified file, git aborts the merge and
# the hook reports rather than retrying — the edit is someone's uncommitted
# work, and there is no reflog to recover it from.
scenario_behind_dirty_on_incoming_path_refuses() {
  advance_origin "one"
  printf 'another session mid-edit\n' >>"$FLUX/AGENTS.md"
  local out; out=$(run_sync_hook)
  at_origin_tip && printf 'SYNCED=yes\n' || printf 'SYNCED=no\n'
  printf 'KEPT=%s OUT=%s\n' \
    "$(grep -c 'another session mid-edit' "$FLUX/AGENTS.md")" "$out"
}
verify_behind_dirty_on_incoming_path_refuses() {
  printf '%s' "$LAST_OUTPUT" | grep -q 'SYNCED=no' || return 1
  printf '%s' "$LAST_OUTPUT" | grep -q "KEPT=1" || return 1
  printf '%s' "$LAST_OUTPUT" | grep -q "fast-forward failed" || return 1
}

# Untracked files cannot be harmed by a fast-forward, and counting them would
# wedge the sync shut on a machine accumulating undrained pending entries.
scenario_behind_untracked_only_still_syncs() {
  advance_origin "one"
  mkdir -p "$FLUX/learnings/pending"
  printf 'undrained lesson\n' >"$FLUX/learnings/pending/abc.md"
  local before; before=$(head_of "$FLUX")
  local out; out=$(run_sync_hook)
  printf 'BEFORE=%s AFTER=%s KEPT=%s OUT=%s\n' \
    "$before" "$(head_of "$FLUX")" \
    "$([ -f "$FLUX/learnings/pending/abc.md" ] && echo yes || echo no)" "$out"
}
verify_behind_untracked_only_still_syncs() {
  local before after
  before=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*BEFORE=\([0-9a-f]*\).*/\1/p')
  after=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*AFTER=\([0-9a-f]*\).*/\1/p')
  [ "$before" != "$after" ] || return 1
  printf '%s' "$LAST_OUTPUT" | grep -q "KEPT=yes" || return 1
  printf '%s' "$LAST_OUTPUT" | grep -q "Synced the context checkout" || return 1
}

# Diverged needs a human: the append-only stores conflict on the merge.
scenario_diverged_reports_and_refuses() {
  advance_origin "one"
  printf 'local work\n' >>"$FLUX/learnings/staging.md"
  git -C "$FLUX" add -A
  git -C "$FLUX" commit --quiet -m "local commit"
  local out; out=$(run_sync_hook)
  at_origin_tip && printf 'SYNCED=yes\n' || printf 'SYNCED=no\n'
  printf 'OUT=%s\n' "$out"
}
verify_diverged_reports_and_refuses() {
  printf '%s' "$LAST_OUTPUT" | grep -q 'SYNCED=no' || return 1
  printf '%s' "$LAST_OUTPUT" | grep -q "diverged from origin" || return 1
}

# Current checkout: no banner at all, so the hook stays invisible in normal use.
scenario_up_to_date_is_silent() {
  local out; out=$(run_sync_hook)
  printf 'OUT=[%s]\n' "$out"
}
verify_up_to_date_is_silent() {
  printf '%s' "$LAST_OUTPUT" | grep -q 'OUT=\[\]' || return 1
}

# Compaction continues a session that already synced at its start.
scenario_compact_source_is_skipped() {
  advance_origin "one"
  local before; before=$(head_of "$FLUX")
  local out; out=$(run_sync_hook compact)
  printf 'BEFORE=%s AFTER=%s OUT=[%s]\n' "$before" "$(head_of "$FLUX")" "$out"
}
verify_compact_source_is_skipped() {
  local before after
  before=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*BEFORE=\([0-9a-f]*\).*/\1/p')
  after=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*AFTER=\([0-9a-f]*\).*/\1/p')
  [ "$before" = "$after" ] || return 1
  printf '%s' "$LAST_OUTPUT" | grep -q 'OUT=\[\]' || return 1
}

# Never blocks session start, whatever it found.
scenario_always_exits_zero() {
  advance_origin "one"
  printf 'local edit\n' >>"$FLUX/AGENTS.md"
  run_sync_hook >/dev/null
  printf 'RC=%s\n' "$?"
}
verify_always_exits_zero() {
  printf '%s' "$LAST_OUTPUT" | grep -q 'RC=0' || return 1
}

# ---------------------------------------------------------------
# auto-commit-push.sh divergence guard
# ---------------------------------------------------------------

# The shared checkout is never swept: work left in the tree belongs to whoever
# wrote it, and the hook reports it rather than committing it. A hook that
# guessed would commit one session's half-written file under another's name.
scenario_stop_hook_leaves_uncommitted_work_alone() {
  printf 'drained lesson\n' >>"$FLUX/learnings/staging.md"
  local out; out=$(run_commit_hook)
  printf 'STAGED=%s DIRTY=%s OUT=%s\n' \
    "$(git -C "$FLUX" diff --cached --name-only | wc -l | tr -d ' ')" \
    "$(git -C "$FLUX" status --porcelain=v1 -- learnings/staging.md | wc -l | tr -d ' ')" \
    "$out"
}
verify_stop_hook_leaves_uncommitted_work_alone() {
  # Nothing staged, or the next session reads the index as a commit in flight.
  printf '%s' "$LAST_OUTPUT" | grep -q 'STAGED=0' || return 1
  # The lesson survives in the working tree for the next session to commit.
  printf '%s' "$LAST_OUTPUT" | grep -q 'DIRTY=1' || return 1
  printf '%s' "$LAST_OUTPUT" | grep -q 'none of it is auto-committed' || return 1
}

# A local commit reaches origin at session end, which is what makes a capture
# committed by hand on one machine readable on the next.
scenario_stop_hook_pushes_local_commits() {
  printf 'local work\n' >>"$FLUX/learnings/staging.md"
  git -C "$FLUX" add -- learnings/staging.md
  git -C "$FLUX" commit --quiet -m "learn: capture one pending lesson"
  local head; head=$(head_of "$FLUX")
  local out; out=$(run_commit_hook)
  printf 'HEAD=%s ORIGIN=%s OUT=%s\n' \
    "$head" "$(git -C "$ORIGIN" rev-parse main)" "$out"
}
verify_stop_hook_pushes_local_commits() {
  local head origin
  head=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*HEAD=\([0-9a-f]*\).*/\1/p')
  origin=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*ORIGIN=\([0-9a-f]*\).*/\1/p')
  [ "$head" = "$origin" ] || return 1
}

# ---------------------------------------------------------------
# bounded_fetch
# ---------------------------------------------------------------

# The bound must cost nothing when the fetch completes. Every caller is a hook
# whose output the harness reads through a pipe, and a reader blocks until all
# writers close the descriptor — so a watchdog that keeps stdout charges the
# full timeout to a fetch that already returned. Measured through command
# substitution because that is how a hook is invoked; against a local origin
# the fetch itself is milliseconds, so anything near the timeout is the bug.
scenario_bounded_fetch_returns_when_fetch_completes() {
  local start end
  start=$(python3 -c 'import time;print(time.time())')
  local out
  out=$(
    FLUX_AGENT_SOCK_GLOB="$TEST_TMP/nonexistent.*" \
    bash -c '
      source "$1/scripts/lib/git-sync.sh"
      bounded_fetch "$2" origin 10 && printf "FETCH_OK\n"
    ' _ "$REPO_ROOT" "$FLUX"
  )
  end=$(python3 -c 'import time;print(time.time())')
  printf 'OUT=%s ELAPSED=%.2f\n' "$out" "$(python3 -c "print($end-$start)")"
}
verify_bounded_fetch_returns_when_fetch_completes() {
  printf '%s' "$LAST_OUTPUT" | grep -q "FETCH_OK" || return 1
  local elapsed
  elapsed=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*ELAPSED=\([0-9.]*\).*/\1/p')
  # Generous against a local origin, and still nowhere near the 10s bound.
  python3 -c "import sys; sys.exit(0 if $elapsed < 4 else 1)"
}

# A watchdog left running outlives the call and eventually TERMs a pid the
# kernel is free to have reassigned.
scenario_bounded_fetch_leaves_no_orphan() {
  local before after
  before=$(pgrep -f "sleep 10" 2>/dev/null | wc -l | tr -d ' ')
  bash -c '
    source "$1/scripts/lib/git-sync.sh"
    bounded_fetch "$2" origin 10 >/dev/null 2>&1
  ' _ "$REPO_ROOT" "$FLUX" >/dev/null 2>&1
  after=$(pgrep -f "sleep 10" 2>/dev/null | wc -l | tr -d ' ')
  printf 'BEFORE=%s AFTER=%s\n' "$before" "$after"
}
verify_bounded_fetch_leaves_no_orphan() {
  local before after
  before=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*BEFORE=\([0-9]*\).*/\1/p')
  after=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*AFTER=\([0-9]*\).*/\1/p')
  [ "${after:-1}" -le "${before:-0}" ] || return 1
}

# ---------------------------------------------------------------
# freeze sentinel
# ---------------------------------------------------------------
# ---------------------------------------------------------------
# Each case runs a real ssh-agent bound to a known socket path, with the probe
# glob pointed at it, so the result never depends on sockets belonging to the
# machine running the tests.

start_live_agent() {
  ssh-keygen -q -t ed25519 -N '' -f "$TEST_TMP/key" </dev/null >/dev/null 2>&1
  eval "$(ssh-agent -a "$TEST_TMP/agent.live" -s)" >/dev/null 2>&1
  SSH_AUTH_SOCK="$TEST_TMP/agent.live" ssh-add "$TEST_TMP/key" >/dev/null 2>&1
}
stop_live_agent() {
  [ -n "${SSH_AGENT_PID:-}" ] && ssh-agent -k >/dev/null 2>&1
  return 0
}

# Probe with the lib sourced directly: this is about the socket decision, not
# about whether a fetch to an unreachable host succeeds.
probe_repair() {
  local url="$1" inherited="$2"
  (
    SSH_AUTH_SOCK="$inherited"
    FLUX_AGENT_SOCK_GLOB="$TEST_TMP/agent.*"
    # shellcheck disable=SC1090
    source "$REPO_ROOT/scripts/lib/git-sync.sh"
    repair_ssh_agent "$url"
    printf 'SOCK=%s\n' "${SSH_AUTH_SOCK:-<unset>}"
  )
}

# The case this exists for: a pane outliving the connection that spawned it.
scenario_agent_repair_adopts_live_socket() {
  start_live_agent
  probe_repair "git@github.com:org/repo.git" "$TEST_TMP/agent.dead"
  stop_live_agent
}
verify_agent_repair_adopts_live_socket() {
  printf '%s' "$LAST_OUTPUT" | grep -q "SOCK=$TEST_TMP/agent.live" || return 1
}

# A healthy session must not have its auth state touched.
scenario_agent_repair_leaves_live_socket_alone() {
  start_live_agent
  probe_repair "git@github.com:org/repo.git" "$TEST_TMP/agent.live"
  stop_live_agent
}
verify_agent_repair_leaves_live_socket_alone() {
  printf '%s' "$LAST_OUTPUT" | grep -q "SOCK=$TEST_TMP/agent.live" || return 1
}

# Non-SSH transports never consult the agent, so nothing is adopted.
scenario_agent_repair_skips_non_ssh_remote() {
  start_live_agent
  probe_repair "$TEST_TMP/origin.git" "$TEST_TMP/agent.dead"
  probe_repair "https://github.com/org/repo.git" "$TEST_TMP/agent.dead"
  stop_live_agent
}
verify_agent_repair_skips_non_ssh_remote() {
  [ "$(printf '%s' "$LAST_OUTPUT" | grep -c "SOCK=$TEST_TMP/agent.dead")" -eq 2 ] || return 1
  printf '%s' "$LAST_OUTPUT" | grep -q "agent.live" && return 1
  return 0
}

# An agent that answers but holds no identities cannot authenticate, so it is
# not adopted in place of a dead one.
scenario_agent_repair_ignores_keyless_agent() {
  eval "$(ssh-agent -a "$TEST_TMP/agent.empty" -s)" >/dev/null 2>&1
  probe_repair "git@github.com:org/repo.git" "$TEST_TMP/agent.dead"
  [ -n "${SSH_AGENT_PID:-}" ] && ssh-agent -k >/dev/null 2>&1
  return 0
}
verify_agent_repair_ignores_keyless_agent() {
  printf '%s' "$LAST_OUTPUT" | grep -q "SOCK=$TEST_TMP/agent.dead" || return 1
}

# A settings change pulled from the other machine reaches the user settings
# file in the same session start, and a successful merge says nothing.
scenario_pulled_settings_are_merged() {
  mkdir -p "$TEST_TMP/claude"
  printf '{"theme":"light"}\n' >"$TEST_TMP/claude/settings.json"
  git -C "$OTHER" pull --quiet --ff-only origin main
  printf '{"env":{"PULLED":"1"}}\n' >"$OTHER/settings.json"
  git -C "$OTHER" add settings.json
  git -C "$OTHER" commit --quiet -m "settings"
  git -C "$OTHER" push --quiet origin main
  local out; out=$(run_sync_hook)
  printf 'MERGED=%s OUT=%s\n' \
    "$(jq -c '[.theme, .env.PULLED]' "$TEST_TMP/claude/settings.json")" "$out"
}
verify_pulled_settings_are_merged() {
  printf '%s' "$LAST_OUTPUT" | grep -qF 'MERGED=["light","1"]' || return 1
  printf '%s' "$LAST_OUTPUT" | grep -q "settings" && return 1
  return 0
}

# ---------------------------------------------------------------

TESTS=(
  behind_clean_fast_forwards
  behind_dirty_elsewhere_still_syncs
  behind_dirty_on_incoming_path_refuses
  behind_untracked_only_still_syncs
  diverged_reports_and_refuses
  up_to_date_is_silent
  pulled_settings_are_merged
  compact_source_is_skipped
  always_exits_zero
  stop_hook_leaves_uncommitted_work_alone
  stop_hook_pushes_local_commits
  bounded_fetch_returns_when_fetch_completes
  bounded_fetch_leaves_no_orphan
  agent_repair_adopts_live_socket
  agent_repair_leaves_live_socket_alone
  agent_repair_skips_non_ssh_remote
  agent_repair_ignores_keyless_agent
)

printf 'flux-sync + divergence guard\n'
for t in "${TESTS[@]}"; do
  run_test "$t"
done

printf '\n  %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '  failed: %s\n' "${FAILED_NAMES[*]}"
  exit 1
fi
exit 0
