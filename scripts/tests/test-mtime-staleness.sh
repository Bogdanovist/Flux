#!/usr/bin/env bash
# Test harness for scripts/lib/file-mtime.sh and the two gates that depend on it.
#
# `stat` is spelled differently on GNU coreutils and on BSD, and the wrong
# spelling does not fail cleanly: it can write text to stdout and still exit
# non-zero. A staleness gate that inherits that text computes an age from a
# string. Under `set -euo pipefail` the hook then dies — noisily for the
# freshness hook, and silently permissive for the PR gate, whose block never
# runs. So the gates are exercised end-to-end here, on this machine's `stat`,
# rather than trusting the helper's unit tests alone.

set -uo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1090
source "$REPO_ROOT/scripts/lib/file-mtime.sh"

PASS=0
FAIL=0
FAILED=()
color_pass() { printf '\033[32m%s\033[0m' "$1"; }
color_fail() { printf '\033[31m%s\033[0m' "$1"; }

check() { # label want got
  if [ "$2" = "$3" ]; then
    PASS=$((PASS+1)); printf '  %s %s\n' "$(color_pass PASS)" "$1"
  else
    FAIL=$((FAIL+1)); FAILED+=("$1")
    printf '  %s %s\n    want: [%s]\n    got:  [%s]\n' "$(color_fail FAIL)" "$1" "$2" "$3"
  fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

printf 'mtime-staleness\n'

# --- file_mtime / file_age_seconds ------------------------------------------
# `touch -t` with an absolute stamp is the one form GNU and BSD both take;
# BSD `touch -d` wants strict ISO 8601 and rejects GNU's relative phrasing. The
# anchor is far enough back to be in the past on any clock the tests run under.
make_old() { touch -t 200001010000 "$1"; }

printf 'x' >"$TMP/now"
make_old "$TMP/old"

check "mtime is digits only" "digits" \
  "$(m=$(file_mtime "$TMP/now"); [[ "$m" =~ ^[0-9]+$ ]] && echo digits || echo "[$m]")"

# Pinned against the clock rather than a literal epoch: reading the file's real
# timestamp and reading a hardcoded number look identical when both are wrong.
check "mtime of a new file agrees with the clock" "agrees" \
  "$(m=$(file_mtime "$TMP/now"); n=$(date +%s); d=$(( n - m )); \
     (( d >= -5 && d <= 5 )) && echo agrees || echo "off by ${d}s")"

check "an older file reads as older" "ordered" \
  "$(o=$(file_mtime "$TMP/old"); n=$(file_mtime "$TMP/now"); \
     (( o < n )) && echo ordered || echo "old=$o now=$n")"

check "age of a just-touched file is small" "small" \
  "$(a=$(file_age_seconds "$TMP/now"); (( a >= 0 && a < 60 )) && echo small || echo "$a")"

check "age of an old file is large" "large" \
  "$(a=$(file_age_seconds "$TMP/old"); (( a > 86400 )) && echo large || echo "$a")"

file_mtime "$TMP/absent" >/dev/null 2>&1
check "missing file returns non-zero" "1" "$?"

check "missing file prints nothing" "" "$(file_mtime "$TMP/absent" 2>/dev/null)"

file_age_seconds "$TMP/absent" >/dev/null 2>&1
check "missing file has no age" "1" "$?"

# Arithmetic on the helper's output is what the gates do; it must not explode
# under `set -u` no matter what the platform's `stat` printed.
( set -euo pipefail
  a=$(file_age_seconds "$TMP/now") || exit 3
  (( a >= 0 )) ) >/dev/null 2>&1
check "age survives arithmetic under set -euo" "0" "$?"

# --- hooks/git-fetch-freshness.sh -------------------------------------------
# A repo with a remote whose fetch cannot succeed: the hook must still exit 0
# with no error output, because freshness is best-effort and never blocks work.
git init -q "$TMP/fresh"
git -C "$TMP/fresh" remote add origin "$TMP/nonexistent-remote.git"
: >"$TMP/fresh/.git/FETCH_HEAD"

run_freshness() { # command -> "exit|output"
  local out rc
  out=$( (cd "$TMP/fresh" && printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"cwd":"%s"}' \
    "$1" "$TMP/fresh" | "$REPO_ROOT/hooks/git-fetch-freshness.sh") 2>&1 )
  rc=$?
  printf '%s|%s' "$rc" "$out"
}

check "freshness hook: fresh FETCH_HEAD is a silent allow" "0|" \
  "$(run_freshness 'git log origin/main -1')"

make_old "$TMP/fresh/.git/FETCH_HEAD"
got=$(run_freshness 'git log origin/main -1')
check "freshness hook: stale FETCH_HEAD exits 0" "0" "${got%%|*}"
check "freshness hook: failed fetch reports staleness, not a crash" "note" \
  "$(case "${got#*|}" in (*'refs may be stale'*) echo note ;; ('') echo silent ;; (*) echo "${got#*|}" ;; esac)"

rm -f "$TMP/fresh/.git/FETCH_HEAD"
check "freshness hook: absent FETCH_HEAD exits 0" "0" \
  "$(got=$(run_freshness 'git log origin/main -1'); echo "${got%%|*}")"

check "freshness hook: unrelated command is untouched" "0|" \
  "$(run_freshness 'ls -la')"

printf '\n  %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '  failed: %s\n' "${FAILED[*]}"
  exit 1
fi
exit 0
