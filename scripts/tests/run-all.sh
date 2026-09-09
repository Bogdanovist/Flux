#!/usr/bin/env bash
# Run every scripts/tests/test-*.sh and report one verdict.
#
# These suites cover hooks and libraries that run on every session, on two
# platforms whose shell utilities differ. A suite that only runs when someone
# remembers it reports a break long after the break, so this is the single entry
# point: hooks/pre-commit.sh calls it whenever a commit touches hooks/ or
# scripts/, and it is what to run by hand after editing either.
#
# Each suite prints its own PASS/FAIL lines and exits non-zero on failure. This
# runner adds the roll-up and the exit status, and prints a failing suite's
# output in full so the failure is readable without a second run.
#
# Usage: scripts/tests/run-all.sh [name-fragment …]
#        With fragments, run only suites whose filename contains one of them.

# Counters rather than arrays for the tallies: under `set -u`, bash 3.2 — the
# /bin/bash macOS ships — treats an empty array's expansion as an unbound
# variable, so an all-green run is exactly when the summary would die.

set -uo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

color() { printf '\033[%sm%s\033[0m' "$1" "$2"; }

SUITES=()
N_SUITES=0
for f in "$SCRIPT_DIR"/test-*.sh; do
  [[ -f "$f" ]] || continue
  if (( $# > 0 )); then
    for frag in "$@"; do
      [[ "$(basename "$f")" == *"$frag"* ]] || continue
      SUITES+=("$f"); N_SUITES=$((N_SUITES+1)); break
    done
  else
    SUITES+=("$f"); N_SUITES=$((N_SUITES+1))
  fi
done

if (( N_SUITES == 0 )); then
  printf 'No suites matched.\n'
  exit 1
fi

N_PASSED=0
N_FAILED=0
FAILED_NAMES=""

for suite in "${SUITES[@]}"; do
  name=$(basename "$suite" .sh)
  start=$(date +%s)
  output=$(bash "$suite" 2>&1)
  rc=$?
  elapsed=$(( $(date +%s) - start ))
  if (( rc == 0 )); then
    N_PASSED=$((N_PASSED+1))
    printf '%s %-28s %ss\n' "$(color 32 'PASS')" "$name" "$elapsed"
  else
    N_FAILED=$((N_FAILED+1))
    FAILED_NAMES="${FAILED_NAMES:+$FAILED_NAMES }$name"
    printf '%s %-28s %ss  (exit %d)\n' "$(color 31 'FAIL')" "$name" "$elapsed" "$rc"
    printf '%s\n' "$output" | sed 's/^/    /'
  fi
done

printf '\n%d suites: %d passed, %d failed\n' "$N_SUITES" "$N_PASSED" "$N_FAILED"
if (( N_FAILED > 0 )); then
  printf 'failed: %s\n' "$FAILED_NAMES"
  exit 1
fi
exit 0
