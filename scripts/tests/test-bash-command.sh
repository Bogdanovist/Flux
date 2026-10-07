#!/usr/bin/env bash
# Pure-bash test harness for scripts/lib/bash-command.sh.
#
# Two PreToolUse gates read Bash commands through this library, and they must
# read them the same way: if one treats an invocation as prose while the other
# acts on it, the pair is incoherent. The cases here are the ones where a naive
# reading goes wrong — a command quoted inside a heredoc, and a target directory
# set by `git -C` or by a `cd` earlier in the chain rather than by the tool's cwd.

set -uo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1090
source "$REPO_ROOT/scripts/lib/bash-command.sh"

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

printf 'bash-command\n'

# --- strip_heredocs ---------------------------------------------------------
# A document that quotes a command must not read as running it.
got=$(strip_heredocs "cat > d.md <<'EOF'
git add -A
EOF" | grep -c 'git add -A')
check "heredoc body removed" "0" "$got"

# The command around the heredoc is still visible.
got=$(strip_heredocs "cat > d.md <<'EOF'
git add -A
EOF" | grep -c 'cat > d.md')
check "surrounding command kept" "1" "$got"

# An unterminated heredoc cannot be parsed reliably; returning the raw text
# fails towards inspecting the command rather than ignoring it.
got=$(strip_heredocs "cat > d.md <<'EOF'
git add -A" | grep -c 'git add -A')
check "unterminated heredoc returns raw" "1" "$got"

# The <<- form strips leading tabs from the delimiter line.
got=$(strip_heredocs "$(printf 'cat <<-END\n\tgit add -A\n\tEND\n')" | grep -c 'git add -A')
check "tab-indented <<- delimiter honoured" "0" "$got"

# No heredoc at all: unchanged.
got=$(strip_heredocs 'git add -A && echo done')
check "plain command unchanged" 'git add -A && echo done' "$got"

# --- command_segment_dirs --------------------------------------------------
# dirs <command> [fallback]: the directory column, one segment per line.
dirs() { command_segment_dirs "$1" "${2:-/FB}" | cut -f1 | paste -sd' ' -; }
check "no directive falls back"      "/FB"        "$(dirs 'git status')"
check "git -C applies to its segment" "/a/b"      "$(dirs 'git -C /a/b log')"
check "git -C double-quoted"         "/a b"       "$(dirs 'git -C "/a b" log')"
check "git -C single-quoted"         "/a b"       "$(dirs "git -C '/a b' log")"
check "git -C is per segment"        "/a /FB"     "$(dirs 'git -C /a status && git add -A')"
check "cd sets later segments"       "/x/y /x/y"  "$(dirs 'cd /x/y && git add -A')"
check "cd after git does not reach back" "/FB /tmp" "$(dirs 'git add -A && cd /tmp')"
check "each cd applies in order"     "/one /two /two" "$(dirs 'cd /one && cd /two && git status')"
check "relative cd resolves against the chain" "/w /w/sub /w/sub" "$(dirs 'cd /w && cd sub && git status')"
check "cd .. resolves against the chain" "/w/a /w/a/.. /w/a/.." "$(dirs 'cd /w/a && cd .. && git status')"
check "cd - returns to the previous dir" "/w /FB /FB" "$(dirs 'cd /w && cd - && git status')"
check "subshell cd ends with the subshell" "/s /s /FB" "$(dirs '(cd /s && git log) && git add -A')"
check "separator trimmed off cd"     "/x/y /x/y"  "$(dirs 'cd /x/y; git log')"
check "tilde expanded"               "$HOME/src/Flux $HOME/src/Flux" "$(dirs 'cd ~/src/Flux && git add -A')"
check "\$FLUX_DIR expanded"          "/flux"      "$(FLUX_DIR=/flux dirs 'git -C $FLUX_DIR add -A')"
check "\${FLUX_DIR} expanded"        "/flux"      "$(FLUX_DIR=/flux dirs 'git -C "${FLUX_DIR}" add -A')"
check "\$FLUX_SRC_ROOT expanded"     "/src/x /src/x" "$(FLUX_SRC_ROOT=/src dirs 'cd $FLUX_SRC_ROOT/x && git add -A')"
check "quoted separator is not a split" "1"      "$(command_segments 'git commit -m "a && b"' | wc -l | tr -d ' ')"
check "quoted contents blanked"      'git commit -m ""' "$(command_segments 'git commit -m "use -a"')"
check "assignment prefix stripped"   'git add -A' "$(command_segments 'FOO=1 git add -A')"

printf '\n  %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '  failed: %s\n' "${FAILED[*]}"
  exit 1
fi
exit 0
