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
# Three functions are exported:
#
#   strip_heredocs <command>
#       Echo the command with heredoc bodies removed, so quoted text is treated
#       as data rather than as an invocation. If a closing delimiter is never
#       found the parse is unreliable and the raw text is returned unchanged —
#       failing towards "inspect it" rather than towards "ignore it".
#
#   command_segment_dirs <stripped-command> <fallback-cwd>
#       Echo `<dir><TAB><segment>` for each command-position segment, with the
#       contents of quoted spans blanked. A gate matching anywhere in the raw
#       string fires on a command that merely *mentions* the pattern —
#       `echo "run git add -A"`, `grep -r 'git add -A' .` — and a gate that
#       blocks prose is a gate that gets removed. Only a segment whose own
#       first word is the command counts.
#
#       <dir> is where that segment runs. The walk starts at the fallback the
#       harness reported and applies each `cd` in order, so a `cd` after a git
#       segment cannot change the repo that segment acts on. A `cd` inside
#       `( … )` ends with the subshell. A git segment's own `-C` applies to that
#       segment alone. A relative path resolves against the running directory.
#
#       Leading `VAR=value` assignments are stripped so `FOO=1 git add -A` still
#       reads as a git invocation. Known limits, both erring towards allowing:
#       `sudo git …` and `bash -c "git …"` are not treated as command position.
#
#   command_segments <command>
#       The segment column of command_segment_dirs alone.

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

# Split a command into raw segments, honouring quotes. Each output line is
# `S<TAB><segment>` for a segment, or `(` / `)` where a subshell opens or
# closes, so a `cd` inside `( … )` or `$( … )` does not leak past it.
_split_segments() {
  printf '%s' "$1" | awk '
    BEGIN { RS = "\001" }
    function flush() { gsub(/\n/, " ", seg); print "S\t" seg; seg = "" }
    {
      n = length($0); sq = 0; dq = 0; seg = ""
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (sq) { seg = seg c; if (c == "\047") sq = 0; continue }
        if (dq) { seg = seg c; if (c == "\"") dq = 0; continue }
        if (c == "\047") { sq = 1; seg = seg c; continue }
        if (c == "\"")   { dq = 1; seg = seg c; continue }
        two = substr($0, i, 2)
        if (two == "&&" || two == "||") { flush(); i++; continue }
        if (c == "(") { flush(); print "("; continue }
        if (c == ")") { flush(); print ")"; continue }
        if (c == ";" || c == "|" || c == "{" || c == "}" || c == "`" || c == "\n") { flush(); continue }
        seg = seg c
      }
      flush()
    }'
}

# Expand the forms skills use to name a checkout, and resolve a relative path
# against the directory the segment runs in.
_expand_dir() { # <dir> <current-dir>
  local dir="$1" cur="$2" var
  if [[ "$dir" == "~" || "$dir" == "~/"* ]]; then
    dir="${HOME}${dir:1}"
  fi
  # Skills name the checkouts through these variables, so a guard that left
  # them literal would never match the Flux checkout.
  for var in FLUX_DIR FLUX_SRC_ROOT HOME; do
    [[ -n "${!var:-}" ]] || continue
    dir="${dir//\$\{$var\}/${!var}}"
    dir="${dir//\$$var/${!var}}"
  done
  [[ "$dir" == /* ]] || dir="${cur%/}/$dir"
  printf '%s\n' "$dir"
}

# Strip one level of surrounding quotes from a word.
_unquote() {
  local w="$1"
  if [[ "$w" =~ ^\"(.*)\"$ || "$w" =~ ^\'(.*)\'$ ]]; then w="${BASH_REMATCH[1]}"; fi
  printf '%s\n' "$w"
}

# Leading word of a segment: a quoted span or a run of non-space characters.
_WORD_RE='("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+)'

# Echo `<dir><TAB><segment>` for each command-position segment, in order.
command_segment_dirs() { # <stripped-command> <fallback-cwd>
  local cur="${2:-}" old="${2:-}" kind raw seg dir rest
  local -a stack=()
  while IFS=$'\t' read -r kind raw; do
    case "$kind" in
      "(") stack+=("$cur"); continue ;;
      ")") if (( ${#stack[@]} )); then
             cur="${stack[${#stack[@]}-1]}"; unset 'stack[${#stack[@]}-1]'
           fi
           continue ;;
    esac
    seg=$(printf '%s\n' "$raw" \
      | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
      | sed -E 's/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)+//')
    [[ -n "$seg" ]] || continue

    if [[ "$seg" =~ ^cd([[:space:]]+(-[LP][[:space:]]+)*${_WORD_RE})?[[:space:]]*$ ]]; then
      dir=$(_unquote "${BASH_REMATCH[3]}")
      case "$dir" in
        "")  dir="$HOME" ;;
        -)   dir="$old" ;;
        *)   dir=$(_expand_dir "$dir" "$cur") ;;
      esac
      old="$cur"; cur="$dir"
    fi

    dir="$cur"
    if [[ "$seg" =~ ^git[[:space:]] ]]; then
      rest="${seg#git}"
      while [[ "$rest" =~ ^[[:space:]]+(-C|-c)[[:space:]]+${_WORD_RE}(.*)$ ]]; do
        rest="${BASH_REMATCH[3]}"
        if [[ "${BASH_REMATCH[1]}" == "-C" ]]; then
          dir=$(_expand_dir "$(_unquote "${BASH_REMATCH[2]}")" "$dir")
        fi
      done
    fi

    # Quoted contents are blanked so a gate cannot match a pattern that a
    # segment only mentions, such as `git commit -m "use -a"`.
    seg=$(printf '%s\n' "$seg" | sed "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g")
    printf '%s\t%s\n' "$dir" "$seg"
  done < <(_split_segments "$1")
}

# Echo one command-position segment per line, quoted contents blanked.
command_segments() {
  command_segment_dirs "$1" "" | cut -f2-
}
