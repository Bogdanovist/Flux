#!/usr/bin/env bash
# Tests for scripts/merge-settings.sh: the rules by which Flux's tracked
# settings.json and a machine's settings.local.json merge into the user
# settings file, and the promise to leave the file alone when nothing changes.
#
# Each test builds a fake Flux root and a fake user file in a fresh tmpdir.

set -uo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MERGE="$SCRIPT_DIR/../merge-settings.sh"

PASS=0
FAIL=0
FAILED=()

check() { # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then
    PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"
  else
    FAIL=$((FAIL+1)); FAILED+=("$1")
    printf '  \033[31mFAIL\033[0m %s\n    expected: %s\n    actual:   %s\n' "$1" "$2" "$3"
  fi
}

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
FLUX="$T/flux"; USER_FILE="$T/claude/settings.json"
mkdir -p "$FLUX" "$T/claude"
merge() { FLUX_DIR="$FLUX" bash "$MERGE" "$USER_FILE"; }
q() { jq -c "$1" "$USER_FILE"; }
backups() { find "$T/claude" -name 'settings.json.bak.*' | wc -l | tr -d ' '; }

FLUX_HOOK='bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/a.sh"'
cat >"$FLUX/settings.json" <<JSON
{"model":"opus","env":{"A":"flux"},
 "permissions":{"allow":["Bash(git push:*)"],"defaultMode":"auto"},
 "hooks":{"Stop":[{"hooks":[{"type":"command","command":$(jq -n --arg c "$FLUX_HOOK" '$c')}]}]}}
JSON
cat >"$FLUX/settings.local.json" <<'JSON'
{"env":{"B":"machine"},"permissions":{"deny":["Bash(gcloud:*)"]},
 "hooks":{"Stop":[{"hooks":[{"type":"command","command":"/machine/status"}]}]}}
JSON
cat >"$USER_FILE" <<'JSON'
{"model":"sonnet","env":{"A":"old"},"permissions":{"allow":["Read"]},
 "hooks":{"Stop":[{"hooks":[{"type":"command","command":"mine.sh"}]}]}}
JSON

printf 'merge-settings\n'
check "first merge reports merged"      "merged" "$(merge)"
check "user preference is kept"         '"sonnet"' "$(q .model)"
check "source env wins, both sources"   '{"A":"flux","B":"machine"}' "$(q .env)"
check "permission entries are added"    '["Read","Bash(git push:*)"]' "$(q .permissions.allow)"
check "machine deny is added"           '["Bash(gcloud:*)"]' "$(q .permissions.deny)"
check "missing scalar permission is set" '"auto"' "$(q .permissions.defaultMode)"
check "user hook first, then sources"   "[\"mine.sh\",$(jq -n --arg c "$FLUX_HOOK" '$c'),\"/machine/status\"]" "$(q '[.hooks.Stop[].hooks[].command]')"
check "first merge makes one backup"    "1" "$(backups)"

check "second merge is silent"          "" "$(merge)"
check "second merge makes no backup"    "1" "$(backups)"
check "second merge adds no hook"       "3" "$(q '[.hooks.Stop[].hooks[]] | length')"

jq '.hooks = {}' "$FLUX/settings.local.json" >"$T/x" && mv "$T/x" "$FLUX/settings.local.json"
merge >/dev/null
check "hook dropped from source leaves" "[\"mine.sh\",$(jq -n --arg c "$FLUX_HOOK" '$c')]" "$(q '[.hooks.Stop[].hooks[].command]')"

# A file merged before the record existed already holds the Flux hook.
rm "$T/claude/flux-merged.json"
merge >/dev/null
check "merge with no record adds no hook"    "1" "$(q '[.hooks.Stop[].hooks[] | select(.command != "mine.sh")] | length')"
check "merge with no record keeps user hook" "1" "$(q '[.hooks.Stop[].hooks[] | select(.command == "mine.sh")] | length')"

rm "$USER_FILE"; ln -s "$FLUX/settings.json" "$USER_FILE"
merge >/dev/null 2>&1; check "a linked user file is refused" "1" "$?"
rm "$USER_FILE"

mv "$FLUX/settings.json" "$FLUX/settings.json.off"
check "no tracked settings, no file"    "no" "$(merge; [ -e "$USER_FILE" ] && echo yes || echo no)"

printf '\n  %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then printf '  failed: %s\n' "${FAILED[*]}"; exit 1; fi
exit 0
