#!/usr/bin/env bash
# bash-command.sh — reading a Bash tool call well enough to gate on it.
#
# This file is sourced (not executed) by:
#   - hooks/git-fetch-freshness.sh    (does this command read remote refs?)
#   - hooks/shared-checkout-guard.sh  (does this command sweep a shared tree?)
#
# Both must answer "which repo does this command actually act on", and both must
# not be fooled by a command that merely *quotes* git in a heredoc — a hook that
# blocks a document for describing the thing it documents is worse than no hook.
# One definition, so the two gates cannot disagree about what a command does.
#
# Two functions are exported:
#
#   strip_heredocs <command>
#       Echo the command with heredoc bodies removed, so quoted text is treated
#       as data rather than as an invocation. If a closing delimiter is never
#       found the parse is unreliable and the raw text is returned unchanged —
#       failing towards "inspect it" rather than towards "ignore it".
#
#   command_segments <command>
#       Echo one line per command-position segment, with the contents of quoted
#       spans blanked. A gate matching anywhere in the raw string fires on a
#       command that merely *mentions* the pattern — `echo "run git add -A"`,
#       `grep -r 'git add -A' .` — and a gate that blocks prose is a gate that
#       gets removed. Only a segment whose own first word is the command counts.
#
#       Leading `VAR=value` assignments are stripped so `FOO=1 git add -A` still
#       reads as a git invocation. Known limits, both erring towards allowing:
#       `sudo git …` and `bash -c "git …"` are not treated as command position.
#
#   resolve_command_dir <stripped-command> <fallback-cwd>
#       Echo the directory the command acts on. An explicit `git -C <dir>` wins
#       because git -C overrides the shell's cwd; otherwise the last `cd <dir>`
#       in the chain; otherwise the fallback the harness reported.

# Remove heredoc bodies from a command string.
strip_heredocs() {
  awk '
    BEGIN { ih = 0; oc = 0 }
    {
      raw[NR] = $0
      if (ih) {
        line = $0
        if (dash) sub(/^\t+/, "", line)
        if (line == delim) ih = 0
        next
      }
      if (match($0, /<<-?[[:space:]]*[^[:alnum:]_[:space:]]?[[:alnum:]_]+/)) {
        tok = substr($0, RSTART, RLENGTH)
        dash = (tok ~ /^<<-/) ? 1 : 0
        if (match(tok, /[[:alnum:]_]+$/)) delim = substr(tok, RSTART, RLENGTH)
        ih = 1
      }
      out[++oc] = $0
    }
    END {
      if (ih) { for (i = 1; i <= NR; i++) print raw[i] }
      else    { for (i = 1; i <= oc; i++) print out[i] }
    }
  ' <<<"$1"
}

# Echo one command-position segment per line, quoted contents blanked.
command_segments() {
  # Blank what is inside quotes before splitting, so a separator sitting inside
  # a string cannot manufacture a segment that never existed.
  printf '%s\n' "$1" \
    | sed "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g" \
    | sed 's/&&/\n/g; s/||/\n/g; s/[;|(){}`]/\n/g' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | sed -E 's/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)+//' \
    | grep -v '^$'
}

# Determine which directory a command operates on.
resolve_command_dir() {
  local stripped="$1"
  local fallback="${2:-}"
  local dir=""

  if [[ "$stripped" =~ (^|[[:space:]\;\&\|\(])git[[:space:]]+-C[[:space:]]+\"([^\"]+)\" ]]; then
    dir="${BASH_REMATCH[2]}"
  elif [[ "$stripped" =~ (^|[[:space:]\;\&\|\(])git[[:space:]]+-C[[:space:]]+\'([^\']+)\' ]]; then
    dir="${BASH_REMATCH[2]}"
  elif [[ "$stripped" =~ (^|[[:space:]\;\&\|\(])git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
    dir="${BASH_REMATCH[2]}"
  elif [[ "$stripped" =~ (^|.*[[:space:]\;\&\|\(])cd[[:space:]]+\"([^\"]+)\" ]]; then
    dir="${BASH_REMATCH[2]}"
  elif [[ "$stripped" =~ (^|.*[[:space:]\;\&\|\(])cd[[:space:]]+\'([^\']+)\' ]]; then
    dir="${BASH_REMATCH[2]}"
  elif [[ "$stripped" =~ (^|.*[[:space:]\;\&\|\(])cd[[:space:]]+([^[:space:]]+) ]]; then
    dir="${BASH_REMATCH[2]}"
    dir="${dir%%[;&|]*}"
  fi

  if [[ "$dir" == "~" || "$dir" == "~/"* ]]; then
    dir="${HOME}${dir:1}"
  fi
  # Skills name the checkouts through these variables, so a guard that left
  # them literal would never match the Flux checkout.
  local var
  for var in FLUX_DIR FLUX_SRC_ROOT HOME; do
    [[ -n "${!var:-}" ]] || continue
    dir="${dir//\$\{$var\}/${!var}}"
    dir="${dir//\$$var/${!var}}"
  done
  [[ -n "$dir" ]] || dir="$fallback"

  printf '%s\n' "$dir"
}
