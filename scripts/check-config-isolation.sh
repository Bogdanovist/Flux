#!/usr/bin/env bash
# check-config-isolation.sh — prove Flux and another config repo each own a
# separate Claude Code config dir, and that neither reaches into the other.
#
# The Flux dir passes when every link in it, and in its skills/, resolves into
# the Flux checkout, its settings file names FLUX_DIR, and nothing in it names
# the other repo. The other dir passes when its CLAUDE.md resolves into the
# other repo, no link in it resolves into Flux, and its settings file carries
# no Flux merge: no flux-merged.json, no FLUX_* env key, no path into Flux.
#
# Reads only. Prints one PASS or FAIL line per check.
#
# Usage: check-config-isolation.sh <flux-config-dir> <other-config-dir> <other-repo>
# Environment: FLUX_DIR  root of the Flux checkout (default: this script's repo)
#
# Exit codes: 0 every check passed, 1 a check failed, 2 bad usage.

set -uo pipefail

[ $# -eq 3 ] || { echo "usage: check-config-isolation.sh <flux-config-dir> <other-config-dir> <other-repo>" >&2; exit 2; }
FLUX="${FLUX_DIR:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FLUX_CFG="$1" OTHER_CFG="$2" OTHER_REPO="$3"

FAILED=0
check() { # check <name> <ok-if-empty-or-true> ...
  if [ "$2" = ok ]; then printf 'PASS %s\n' "$1"
  else FAILED=1; printf 'FAIL %s\n%s\n' "$1" "$(printf '%s\n' "$2" | sed 's/^/     /')"; fi
}
or_ok() { [ -n "$1" ] && printf '%s' "$1" || printf ok; }

# Every link at the top of a config dir and in its skills/, as "<link> -> <target>".
links() {
  find "$1" "$1/skills" -maxdepth 1 -type l 2>/dev/null | while read -r l; do
    printf '%s -> %s\n' "$l" "$(readlink "$l")"
  done
}

for d in "$FLUX_CFG" "$OTHER_CFG"; do
  [ -d "$d" ] || { check "$d exists" "missing"; }
done

printf '%s\n' "Flux config dir: $FLUX_CFG"
check "CLAUDE.md resolves into Flux" \
  "$( [ "$(readlink "$FLUX_CFG/CLAUDE.md" 2>/dev/null)" = "$FLUX/CLAUDE.md" ] && echo ok || echo "$(readlink "$FLUX_CFG/CLAUDE.md" 2>/dev/null || echo 'no link')")"
check "every link resolves into Flux" \
  "$(or_ok "$(links "$FLUX_CFG" | grep -v -- "-> $FLUX/")")"
check "every Flux skill is linked" \
  "$(or_ok "$(for s in "$FLUX"/skills/*/; do n="$(basename "$s")"; [ "$(readlink "$FLUX_CFG/skills/$n" 2>/dev/null)" = "$FLUX/skills/$n" ] || echo "$n"; done)")"
check "settings name this FLUX_DIR" \
  "$( [ "$(jq -r '.env.FLUX_DIR // empty' "$FLUX_CFG/settings.json" 2>/dev/null)" = "$FLUX" ] && echo ok || echo "env.FLUX_DIR is '$(jq -r '.env.FLUX_DIR // empty' "$FLUX_CFG/settings.json" 2>/dev/null)'")"
check "settings never name the other repo" \
  "$(or_ok "$(grep -n -- "$OTHER_REPO" "$FLUX_CFG/settings.json" 2>/dev/null)")"

printf '%s\n' "Other config dir: $OTHER_CFG"
other_claude_md="$(readlink "$OTHER_CFG/CLAUDE.md" 2>/dev/null || echo 'no link')"
check "CLAUDE.md resolves into the other repo" \
  "$( [ "${other_claude_md#"$OTHER_REPO"/}" != "$other_claude_md" ] && echo ok || echo "$other_claude_md")"
check "no link resolves into Flux" \
  "$(or_ok "$(links "$OTHER_CFG" | grep -- "-> $FLUX/")")"
check "no Flux merge record" \
  "$( [ -e "$OTHER_CFG/flux-merged.json" ] && echo "$OTHER_CFG/flux-merged.json exists" || echo ok)"
check "settings carry no FLUX_* env key" \
  "$(or_ok "$(jq -r '.env // {} | keys[] | select(startswith("FLUX_"))' "$OTHER_CFG/settings.json" 2>/dev/null)")"
check "settings never name Flux" \
  "$(or_ok "$(grep -n -e "$FLUX" -e 'gcloud-flux' "$OTHER_CFG/settings.json" 2>/dev/null)")"

exit "$FAILED"
