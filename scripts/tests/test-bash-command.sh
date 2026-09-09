#!/usr/bin/env bash
# Pure-bash test harness for scripts/lib/bash-command.sh.
#
# Two PreToolUse gates read Bash commands through this library, and they must
# read them the same way: if one treats an invocation as prose while the other
# acts on it, the pair is incoherent. The cases here are the ones where a naive
# reading goes wrong — a command quoted inside a heredoc, and a target directory
# set by `git -C` or by the last `cd` in a chain rather than by the tool's cwd.

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

# --- resolve_command_dir ----------------------------------------------------
check "no directive falls back"      "/FB"   "$(resolve_command_dir 'git status' /FB)"
check "git -C wins"                  "/a/b"  "$(resolve_command_dir 'git -C /a/b log' /FB)"
check "git -C double-quoted"         "/a b"  "$(resolve_command_dir 'git -C "/a b" log' /FB)"
check "git -C single-quoted"         "/a b"  "$(resolve_command_dir "git -C '/a b' log" /FB)"
check "cd sets the target"           "/x/y"  "$(resolve_command_dir 'cd /x/y && git add -A' /FB)"
check "last cd wins"                 "/two"  "$(resolve_command_dir 'cd /one && cd /two && git status' /FB)"
check "git -C beats a later cd"      "/exp"  "$(resolve_command_dir 'git -C /exp log && cd /other' /FB)"
check "separator trimmed off cd"     "/x/y"  "$(resolve_command_dir 'cd /x/y; git log' /FB)"
check "tilde expanded"               "$HOME/src/Flux" "$(resolve_command_dir 'cd ~/src/Flux && git add -A' /FB)"
check "non-git command falls back"   "/FB"   "$(resolve_command_dir 'echo hello' /FB)"

printf '\n  %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '  failed: %s\n' "${FAILED[*]}"
  exit 1
fi
exit 0
