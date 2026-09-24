#!/usr/bin/env bash
# Install the Flux config onto a machine.
#
# Usage:
#   ./setup.sh                                  # install into ~/.claude
#   FLUX_CLAUDE_DIR=~/.claude-flux ./setup.sh   # install into its own config dir
#
# One config repo owns one config dir. A machine that also carries another
# config repo — a work one, say — needs Flux somewhere else, because both
# would otherwise claim the same CLAUDE.md and the same skill links. Install
# Flux into its own dir there, and start personal sessions with
# `CLAUDE_CONFIG_DIR=~/.claude-flux claude`, which relocates the whole config
# dir the CLI reads.
#
# The script backs up whatever it replaces and converges on re-runs. A link
# that already points into another config repo is reported and left alone,
# because removing it would break that install.

set -euo pipefail

REPO_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${FLUX_CLAUDE_DIR:-$HOME/.claude}"

echo "Installing Flux from $REPO_DIR into $CLAUDE_DIR"

mkdir -p "$CLAUDE_DIR" "$CLAUDE_DIR/logs"

# Shell dotfiles are absent from this script deliberately and must never be
# added: a machine's ~/.zshrc is its own, it is untracked, and it may hold
# secrets that linking a tracked file over it would destroy.
link_item() {
  local name="$1"
  local target="$CLAUDE_DIR/$name"
  local source="$REPO_DIR/$name"

  if [ -L "$target" ]; then
    case "$(readlink "$target")" in
      "$REPO_DIR"/*) ;;
      *)
        echo "  SKIP $name — $target points into another config repo. Remove it by hand, or install Flux with FLUX_CLAUDE_DIR set."
        return 0
        ;;
    esac
    rm "$target"
  elif [ -e "$target" ]; then
    local backup="${target}.bak"
    # An earlier backup may be the only copy of what it holds.
    [ -e "$backup" ] && backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$target" "$backup"
    echo "  Backed up $target -> $backup"
  fi

  ln -s "$source" "$target"
  echo "  Linked $target -> $source"
}

for item in AGENTS.md CLAUDE.md agents hooks; do
  link_item "$item"
done

# settings.local.json holds this machine's settings: permissions, env and
# hooks that belong to this machine alone. It is gitignored: created from the
# template on a first install, never overwritten.
if [ ! -e "$REPO_DIR/settings.local.json" ]; then
  cp "$REPO_DIR/settings.local.example.json" "$REPO_DIR/settings.local.json"
  echo "  Created settings.local.json from the template"
else
  echo "  settings.local.json already exists (kept as-is)"
fi

# The checkout's location is this machine's choice, and the repos Flux works on
# sit beside it. Hooks, scripts and skill commands read both paths from these
# variables, which Claude Code passes to every hook and Bash command.
FLUX_SRC_ROOT="$(dirname "$REPO_DIR")"
tmp="$(mktemp)"
jq --arg flux "$REPO_DIR" --arg src "$FLUX_SRC_ROOT" \
  '.env = ((.env // {}) + {FLUX_DIR: $flux, FLUX_SRC_ROOT: $src})' \
  "$REPO_DIR/settings.local.json" >"$tmp" && mv "$tmp" "$REPO_DIR/settings.local.json"
echo "  Set FLUX_DIR=$REPO_DIR and FLUX_SRC_ROOT=$FLUX_SRC_ROOT in settings.local.json"

# The user settings file is the person's own, and Flux merges into it;
# scripts/merge-settings.sh says how. hooks/flux-sync.sh repeats the merge at
# every session start, so a change to either source applies from the next
# session.
for name in settings.json settings.local.json; do
  if [ -L "$CLAUDE_DIR/$name" ] && [ "$(readlink "$CLAUDE_DIR/$name")" = "$REPO_DIR/$name" ]; then
    rm "$CLAUDE_DIR/$name"
    echo "  Removed the link $CLAUDE_DIR/$name"
  fi
done
merge_result="$(bash "$REPO_DIR/scripts/merge-settings.sh" "$CLAUDE_DIR/settings.json")"
if [ "$merge_result" = merged ]; then
  echo "  Merged settings.json and settings.local.json into $CLAUDE_DIR/settings.json"
else
  echo "  $CLAUDE_DIR/settings.json already holds the merged settings"
fi

# Some filesystems drop the execute bit on clone, and every hook runs as a
# script.
chmod +x "$REPO_DIR"/hooks/*.sh "$REPO_DIR"/scripts/*.sh "$REPO_DIR"/scripts/lib/*.sh \
         "$REPO_DIR"/scripts/tests/*.sh

# Repo-local git hook: the secrets scan runs on every commit here, and the
# shell suites run when a commit touches hooks/ or scripts/.
mkdir -p "$REPO_DIR/.git/hooks"
ln -sf "$REPO_DIR/hooks/pre-commit.sh" "$REPO_DIR/.git/hooks/pre-commit"
echo "  Installed the pre-commit hook (secrets scan + shell suites)"

# Skills: one link per skills/<name>/ into the config dir's skills/. The
# relink hook owns that directory's Flux-owned links and reports collisions
# with anything else. stdin is closed because the hook reads its JSON input
# from stdin when a session fires it, and an open terminal would block it.
relink_report=$(FLUX_SKILLS_DIR="$CLAUDE_DIR/skills" \
  bash "$REPO_DIR/hooks/skills-relink.sh" </dev/null 2>/dev/null || true)
echo "  Linked skills into $CLAUDE_DIR/skills"
if [ -n "$relink_report" ] && command -v jq >/dev/null 2>&1; then
  printf '  %s\n' "$(printf '%s' "$relink_report" \
    | jq -r '.hookSpecificOutput.additionalContext // empty')"
fi

echo
echo "Done. Re-run any time; the install converges."
echo
if [ "$CLAUDE_DIR" != "$HOME/.claude" ]; then
  echo "Start personal sessions with: CLAUDE_CONFIG_DIR=$CLAUDE_DIR claude"
  echo
fi
echo "Next: edit $REPO_DIR/settings.local.json to set this machine's settings. The next session merges them."
