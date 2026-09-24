#!/usr/bin/env bash
# skills-relink.sh — SessionStart hook. Rebuild the provider skill dir from
# skills/ so the session's skill list matches what is on disk.
#
# skills/ is the source of truth — flat, no bundles: every skill Flux ships
# is installed all the time. The provider skill dir is a
# directory of per-skill symlinks, and without a rebuild every edit drifts
# silently: adding a skill leaves it unlinked, renaming one leaves a dangling
# link, deleting one leaves a link to nothing. The symptom is a skill that
# simply is not in the session's list, which reads as the model failing to
# find it rather than as a missing symlink — the drift is invisible from
# inside the session that suffers it.
#
# It runs AFTER flux-sync.sh, so it links the skills that sync just
# fast-forwarded in rather than the ones it is about to replace.
#
# It only owns the links that point into the Flux repo: it creates one per
# skills/<name>/ directory, repairs those that point into the repo at the
# wrong place, and removes those that point into the repo but no longer
# resolve. An entry owned by anything else — a real directory, or a link into
# another tree — is never touched, since silently overwriting it would
# destroy another config repo's install; it is reported as a collision alongside
# the next change instead.
#
# Silent when the link set is unchanged, which is almost every session. It
# never blocks session start and always exits 0.
#
# Environment (overridable for testing):
#   FLUX_DIR         root of the Flux context repo (default: resolved from this file)
#   FLUX_SKILLS_DIR  provider skill dir to link into (default ~/.claude/skills)

set -uo pipefail

INPUT=$(cat 2>/dev/null || true)

# Compaction continues an existing session rather than starting one; the skill
# list it carries was built when that session began and a rebuild cannot reach it.
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null || true)
if [ "$SOURCE" = "compact" ]; then
  exit 0
fi

# Resolve the repo physically. Hooks are invoked through ~/.claude/hooks, which
# is a symlink into this repo, so a logical `..` walks lexically out of the link
# and lands in ~/.claude instead of the checkout.
REPO_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
FLUX="${FLUX_DIR:-$REPO_ROOT}"
SKILLS_SRC="$FLUX/skills"
TARGET_DIR="${FLUX_SKILLS_DIR:-$HOME/.claude/skills}"

emit() {
  jq -n --arg msg "$1" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $msg
    }
  }'
  exit 0
}

[ -d "$SKILLS_SRC" ] || emit "[skills-relink] ${SKILLS_SRC} is missing, so no skill symlinks were rebuilt. Any skill added or renamed since the last rebuild is absent from this session's skill list; \`ls -l ${TARGET_DIR}\` shows what is actually linked."

mkdir -p "$TARGET_DIR" 2>/dev/null || emit "[skills-relink] Could not create ${TARGET_DIR}, so no skill symlinks were rebuilt."

FLUX_REAL="$(cd -P "$FLUX" && pwd)"

# Does this link target sit inside the Flux repo? Matched on the raw target
# string against the two spellings a link here can carry — the physical path
# and the configured path.
in_flux() {
  case "$1" in
    "$FLUX_REAL"/*|"$FLUX"/*) return 0 ;;
    *) return 1 ;;
  esac
}

ADDED=""
REMOVED=""
COLLIDED=""
append() { # append <var-name> <item> — comma-separated accumulator
  local cur
  eval "cur=\$$1"
  if [ -n "$cur" ]; then
    eval "$1=\"\${cur}, $2\""
  else
    eval "$1=\"$2\""
  fi
}

# Link every skill directory. A link already pointing into the repo is
# repaired to the canonical target; anything else standing on the name is a
# collision and stays.
for src in "$SKILLS_SRC"/*/; do
  [ -d "$src" ] || continue
  name="$(basename "$src")"
  link="$TARGET_DIR/$name"
  want="$SKILLS_SRC/$name"

  if [ -L "$link" ]; then
    target="$(readlink "$link")"
    if [ "$target" = "$want" ]; then
      continue
    elif in_flux "$target"; then
      ln -sfn "$want" "$link" 2>/dev/null && append ADDED "$name"
    else
      append COLLIDED "$name"
    fi
  elif [ -e "$link" ]; then
    append COLLIDED "$name"
  else
    ln -s "$want" "$link" 2>/dev/null && append ADDED "$name"
  fi
done

# Prune links that point into the repo but no longer resolve — the residue of
# a deleted or renamed skill. Links into anything else belong to another
# config repo.
for link in "$TARGET_DIR"/*; do
  [ -L "$link" ] || continue
  target="$(readlink "$link")"
  in_flux "$target" || continue
  [ -e "$link" ] && continue
  rm -f "$link" 2>/dev/null && append REMOVED "$(basename "$link")"
done

# A standing collision alone stays quiet — the link set did not change, and a
# nag repeated every session start would drown the messages that matter.
[ -z "$ADDED" ] && [ -z "$REMOVED" ] && exit 0

CHANGES=""
[ -n "$ADDED" ] && CHANGES="now available: ${ADDED}"
[ -n "$REMOVED" ] && CHANGES="${CHANGES:+${CHANGES}; }no longer present: ${REMOVED}"
[ -n "$COLLIDED" ] && CHANGES="${CHANGES:+${CHANGES}; }not linked — the name is already taken by something outside this repo (left untouched): ${COLLIDED}"

emit "[skills-relink] Rebuilt the skill symlinks from ${SKILLS_SRC} — ${CHANGES}. Mention this once, briefly."
