#!/usr/bin/env bash
# file-mtime.sh — a file's modification time, the same answer on macOS and Linux.
#
# This file is sourced (not executed) by the hooks that gate on staleness:
#   - hooks/git-fetch-freshness.sh   (is FETCH_HEAD recent enough to trust?)
#
# `stat` takes different flags on GNU coreutils and on BSD, and the flag one
# platform rejects the other accepts with an unrelated meaning: on Linux
# `stat -f` reports the *filesystem*, printing a block of text to stdout before
# exiting non-zero. A probe's exit status is therefore not evidence that its
# output is a timestamp. Every result is checked to be digits before it is
# returned, so a caller receives either an integer or a non-zero return — never
# a string to do arithmetic on.
#
# Two functions are exported:
#
#   file_mtime <path>
#       Echo the file's modification time in epoch seconds. Return 1 if the
#       file is unreadable or no probe yields a number.
#
#   file_age_seconds <path>
#       Echo how many seconds ago the file was modified. Return 1 on the same
#       terms as file_mtime. Staleness gates want the age, so the subtraction
#       lives here once rather than at each call site.

file_mtime() {
  local f="$1" m
  m=$(stat -c %Y "$f" 2>/dev/null || true)      # GNU coreutils
  if [[ ! "$m" =~ ^[0-9]+$ ]]; then
    m=$(stat -f %m "$f" 2>/dev/null || true)    # BSD / macOS
  fi
  [[ "$m" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$m"
}

file_age_seconds() {
  local m now
  m=$(file_mtime "$1") || return 1
  now=$(date +%s)
  printf '%s\n' "$(( now - m ))"
}
