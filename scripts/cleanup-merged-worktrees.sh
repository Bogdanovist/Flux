#!/usr/bin/env bash
# cleanup-merged-worktrees.sh — reap cross-repo worktrees whose PRs are merged.
#
# Walks every $FLUX_SRC_ROOT/*-worktrees/*/ directory, identifies the branch checked out
# there, asks `gh` whether its PR is merged or closed, and removes the worktree
# if so. Refuses to remove anything with uncommitted changes or unpushed
# commits — those need human eyes.
#
# Dry-run by default. Pass --apply to actually run `git worktree remove`.
#
# Convention this assumes is documented in Flux's AGENTS.md under
# "Worktrees and agent safety", with the recipe in the git-worktrees skill.

set -euo pipefail

APPLY=0
case "${1:-}" in
  --apply) APPLY=1 ;;
  ""|--dry-run) APPLY=0 ;;
  *) echo "usage: $0 [--apply|--dry-run]" >&2; exit 2 ;;
esac

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh is required" >&2
  exit 2
fi

shopt -s nullglob

removed=0
kept=0
skipped=0

SRC_ROOT="${FLUX_SRC_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

for wt in "$SRC_ROOT"/*-worktrees/*/; do
  wt="${wt%/}"

  # Only proceed if this looks like a git worktree (has .git as file pointing
  # to the main repo's worktrees/ admin dir).
  if [[ ! -e "$wt/.git" ]]; then
    echo "skip   $wt  (no .git entry)"
    skipped=$((skipped+1))
    continue
  fi

  branch=$(git -C "$wt" branch --show-current 2>/dev/null || true)
  if [[ -z "$branch" ]]; then
    echo "skip   $wt  (detached HEAD)"
    skipped=$((skipped+1))
    continue
  fi

  # Derive owner/repo from origin remote so this works across orgs.
  # Handles both git@host:owner/repo(.git) and https://host/owner/repo(.git).
  origin_url=$(git -C "$wt" config --get remote.origin.url 2>/dev/null || true)
  repo_slug=""
  if [[ -n "$origin_url" ]]; then
    stripped="${origin_url%.git}"
    stripped="${stripped//://}"
    repo_slug=$(printf '%s' "$stripped" | awk -F/ 'NF>=2{print $(NF-1)"/"$NF}')
  fi
  if [[ -z "$repo_slug" ]]; then
    echo "skip   $wt  (could not parse origin: $origin_url)"
    skipped=$((skipped+1))
    continue
  fi

  pr_state=$(gh -R "$repo_slug" pr list \
    --head "$branch" --state all --limit 1 \
    --json state --jq '.[0].state // ""' 2>/dev/null || true)

  case "$pr_state" in
    MERGED|CLOSED)
      # Refuse to nuke a worktree with dirty state. `-uall` is load-bearing: without an explicit
      # `-u` flag, `git status` honours `status.showUntrackedFiles`, and with that set to `no` this
      # guard reads a worktree full of unsaved work as clean. `git worktree remove` offers no
      # backstop there — it consults the same setting, so it too deletes untracked files without
      # being asked to `--force`.
      if [[ -n "$(git -C "$wt" status --porcelain -uall)" ]]; then
        echo "keep   $wt  ($branch -> $pr_state)  [DIRTY — clean up manually]"
        kept=$((kept+1))
        continue
      fi
      # Refuse to nuke a worktree with commits not pushed to origin/<branch>.
      # If origin/<branch> is gone (typical post-merge), nothing to compare to,
      # so allow removal.
      if git -C "$wt" rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        ahead=$(git -C "$wt" rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo 0)
        if [[ "$ahead" -gt 0 ]]; then
          echo "keep   $wt  ($branch -> $pr_state)  [$ahead unpushed commit(s)]"
          kept=$((kept+1))
          continue
        fi
      fi

      if (( APPLY )); then
        # `git worktree remove` must run from the main repo, not the worktree.
        main_repo=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir)
        main_repo=$(dirname "$main_repo")
        git -C "$main_repo" worktree remove "$wt"
        echo "REMOVE $wt  ($branch -> $pr_state)"
      else
        echo "REMOVE $wt  ($branch -> $pr_state)  [dry-run]"
      fi
      removed=$((removed+1))
      ;;
    OPEN|DRAFT|"")
      echo "keep   $wt  ($branch -> ${pr_state:-no-PR})"
      kept=$((kept+1))
      ;;
    *)
      echo "keep   $wt  ($branch -> $pr_state)"
      kept=$((kept+1))
      ;;
  esac
done

echo
if (( APPLY )); then
  echo "Done. Removed $removed, kept $kept, skipped $skipped."
else
  echo "Dry run. Would remove $removed, keep $kept, skip $skipped."
  echo "Re-run with --apply to actually remove."
fi
