#!/usr/bin/env bash
# Test harness for hooks/pre-commit.sh.
#
# git invokes the hook as .git/hooks/pre-commit — a symlink to the file, from a
# working directory that is the repo root rather than the hook's own. A hook
# that locates the repo from `dirname $0` without following the link resolves to
# .git/hooks and finds nothing to run; git reports the resulting non-zero exit
# as a blocked commit, which reads as a failing check rather than a broken one.
# So the hook is exercised the way git invokes it: through the symlink.
#
# The hook resolves its runner from the repo being committed to, so the fixture
# repo carries its own one-suite tests directory. Pointing the hook at the real
# Flux tree would have it run this file, which commits, which runs it again.

set -uo pipefail

# Run from Flux's own pre-commit hook, this suite inherits the flag that stops
# the hook re-entering itself, and every fixture commit would then skip the
# hook under test. The fixture's runner holds one stub suite, so clearing the
# flag cannot recurse.
unset FLUX_PRE_COMMIT_ACTIVE

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

TMP="$(mktemp -d "${TMPDIR:-/tmp}/flux-test.XXXXXX")" || exit 1
trap 'rm -rf "$TMP"' EXIT

printf 'pre-commit-dispatch\n'

# The hook lives outside the repo it guards, as it does on a real machine:
# .git/hooks/pre-commit is a symlink into the Flux checkout.
FIX="$TMP/hooks-home"
mkdir -p "$FIX/hooks"
cp "$REPO_ROOT/hooks/pre-commit.sh" "$REPO_ROOT/hooks/pre-commit-secrets-check.sh" "$FIX/hooks/"
chmod +x "$FIX/hooks"/*.sh

# The repo being committed to, with the hook installed the way setup.sh does
# and carrying its own runner — the hook runs the suites of the tree it is
# committing to, and blocks a tree that stages hooks/ or scripts/ without one.
git init -q "$TMP/repo"
git -C "$TMP/repo" config user.email t@t
git -C "$TMP/repo" config user.name t
mkdir -p "$TMP/repo/scripts/tests"
cp "$REPO_ROOT/scripts/tests/run-all.sh" "$TMP/repo/scripts/tests/"
chmod +x "$TMP/repo/scripts/tests/run-all.sh"
ln -sf "$FIX/hooks/pre-commit.sh" "$TMP/repo/.git/hooks/pre-commit"

set_suite() { # exit-code
  printf '#!/usr/bin/env bash\necho "  stub suite"\nexit %s\n' "$1" >"$TMP/repo/scripts/tests/test-stub.sh"
  chmod +x "$TMP/repo/scripts/tests/test-stub.sh"
}

run_commit() { # -> "exit|verdict" where verdict is quiet | ran | unresolved
  local out rc verdict
  out=$( (cd "$TMP/repo" && git commit -q -m m) 2>&1 )
  rc=$?
  case "$out" in
    *'No such file'*)          verdict="unresolved" ;;
    *'running shell suites'*)  verdict="ran" ;;
    '')                        verdict="quiet" ;;
    *)                         verdict="$out" ;;
  esac
  printf '%s|%s' "$rc" "$verdict"
}

set_suite 0

# A commit touching neither hooks/ nor scripts/ pays nothing.
mkdir -p "$TMP/repo/docs"
printf 'text\n' >"$TMP/repo/docs/note.md"
git -C "$TMP/repo" add docs/note.md
check "docs-only commit succeeds, no suites" "0|quiet" "$(run_commit)"

# A commit touching scripts/ runs the suites, resolved through the symlink.
mkdir -p "$TMP/repo/scripts"
printf 'one\n' >"$TMP/repo/scripts/thing.sh"
git -C "$TMP/repo" add scripts/thing.sh
check "scripts commit runs the suites and passes" "0|ran" "$(run_commit)"

# A commit touching hooks/ does the same.
mkdir -p "$TMP/repo/hooks"
printf 'one\n' >"$TMP/repo/hooks/thing.sh"
git -C "$TMP/repo" add hooks/thing.sh
check "hooks commit runs the suites and passes" "0|ran" "$(run_commit)"

# A red suite blocks the commit rather than warning past it.
set_suite 1
printf 'two\n' >"$TMP/repo/scripts/thing.sh"
git -C "$TMP/repo" add scripts/thing.sh
got=$(run_commit)
check "red suite blocks the commit" "1" "${got%%|*}"
check "commit did not land" "3" \
  "$(git -C "$TMP/repo" log --oneline | wc -l | tr -d ' ')"

# The secrets scan still gates a commit the suites never see. A file whose name
# is on the never-commit list, rather than secret-shaped content — a test that
# carries a credential pattern is a test this very scan refuses to commit.
set_suite 0
printf 'K=v\n' >"$TMP/repo/.env"
git -C "$TMP/repo" add -f .env
check "secrets scan blocks a docs-only commit" "1" "$(got=$(run_commit); echo "${got%%|*}")"

printf '\n  %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '  failed: %s\n' "${FAILED[*]}"
  exit 1
fi
exit 0
