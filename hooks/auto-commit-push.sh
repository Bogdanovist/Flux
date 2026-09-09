#!/bin/bash
# Backstop for work left behind when an agent session finishes responding.
# Outputs anything the user must act on via stderr so Claude relays it.
#
# Two repo shapes get two treatments. A downstream project repo is a worktree
# per branch with one editing agent in it, so sweeping the tree there claims
# that agent's own work — and its default branch is push-protected, so work is
# moved onto a fresh branch before committing. The Flux context repo is one
# checkout that all of a person's sessions share, so a sweep there is the one
# place a session can commit another session's half-written files under a
# message describing neither: uncommitted files are reported, never swept.
# What Flux does get is a push path — commits a session made on the current
# branch are pushed at session end, rebasing over whatever other machines
# pushed meanwhile, so captures reach origin instead of stranding on a
# laptop.
#
# Environment (overridable for testing):
#   FLUX_DIR             root of the Flux context repo (default $HOME/src/Flux)
#   FLUX_FETCH_TIMEOUT   seconds to bound the divergence-check fetch (default 10)

FETCH_TIMEOUT="${FLUX_FETCH_TIMEOUT:-10}"

# Resolve the repo physically. Hooks are invoked through ~/.claude/hooks, which is
# a symlink into this repo, so a logical `..` walks lexically out of the link and
# lands in ~/.claude instead of the checkout.
REPO_ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
SYNC_LIB="$REPO_ROOT/scripts/lib/git-sync.sh"
SYNC_LIB_LOADED=0
if [ -f "$SYNC_LIB" ]; then
  # shellcheck disable=SC1090
  source "$SYNC_LIB" && SYNC_LIB_LOADED=1
fi

auto_commit_push() {
  local dir="$1"
  local label="$2"

  cd "$dir" 2>/dev/null || return 0

  # Must be in a git repo
  git rev-parse --is-inside-work-tree &>/dev/null || return 0

  # Check for any uncommitted changes (staged, unstaged, or untracked)
  if git diff --quiet HEAD 2>/dev/null && git diff --cached --quiet 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    return 0
  fi

  # A non-empty index means an agent staged a specific set of files and owns the
  # commit — it is describing that change in a message this hook cannot write,
  # and it may have staged a subset deliberately. Sweeping the index into
  # "auto: <files>" destroys both. Report and leave the repo alone; the backstop
  # exists for unstaged and untracked leftovers, not for work in flight.
  if ! git diff --cached --quiet 2>/dev/null; then
    STAGED_COUNT=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    echo "${label}: ${STAGED_COUNT} file(s) staged and uncommitted — left for the agent to commit." >&2
    return 0
  fi

  BRANCH=$(git branch --show-current 2>/dev/null)
  [ -z "$BRANCH" ] && return 0

  # Project repos protect their default branch — a commit straight to main can
  # never be pushed, so it strands locally and silently piles up. Move the work
  # onto a fresh branch first, then commit/push there.
  if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
    WIP_BRANCH="auto/wip-$(date +%Y%m%d-%H%M%S)"
    if git checkout -b "$WIP_BRANCH" &>/dev/null; then
      echo "${label}: '${BRANCH}' is push-protected — moved changes onto ${WIP_BRANCH}." >&2
      BRANCH="$WIP_BRANCH"
    else
      echo "${label}: on protected '${BRANCH}' and could not create a work branch — changes left uncommitted." >&2
      return 0
    fi
  fi

  # Stage all changes
  git add -A 2>/dev/null

  # Build commit message from changed files
  CHANGED=$(git diff --cached --name-only 2>/dev/null | head -10 | tr '\n' ', ' | sed 's/,$//')
  [ -z "$CHANGED" ] && return 0

  git commit -m "auto: ${CHANGED}" --no-verify &>/dev/null || return 0

  # Push to remote
  if git remote get-url origin &>/dev/null; then
    if git push origin "$BRANCH" &>/dev/null; then
      echo "${label}: committed and pushed to ${BRANCH}. Run: git pull origin ${BRANCH}" >&2
    else
      echo "${label}: committed locally but push failed. Run: git push origin ${BRANCH}" >&2
    fi
  else
    echo "${label}: committed locally (no remote configured)." >&2
  fi
}

# Push the current branch's local commits so they reach origin.
#
# Several machines commit to the same branch of the Flux repo concurrently;
# each write is one-file-per-item with a globally unique name, so two machines'
# commits touch disjoint files by construction and a rebase replays them
# cleanly. The sequence: bounded fetch (a stale origin ref reports "not behind"
# and the push then bounces); if behind, rebase this checkout's own commits
# onto the origin ref — with autostash, so files another session is mid-edit
# don't block the replay; push. A branch that has never been pushed is
# published with -u, so drafts reach origin and are never stranded.
#
# A genuine textual conflict means the one-author-per-file convention was
# broken. That is a human's call, not this hook's: abort the rebase, leave the
# commits local, and name who pushed the commits they collide with.
push_local_commits() {
  local dir="$1"
  local label="$2"

  cd "$dir" 2>/dev/null || return 0
  git rev-parse --is-inside-work-tree &>/dev/null || return 0

  local branch
  branch=$(git branch --show-current 2>/dev/null)
  [ -n "$branch" ] || return 0
  git remote get-url origin &>/dev/null || return 0

  # No upstream: a branch that has never been pushed. Publish it — a draft on a
  # branch only one laptop holds is exactly the stranding this hook prevents.
  if ! git rev-parse --abbrev-ref '@{u}' &>/dev/null; then
    if git push -u origin "$branch" &>/dev/null; then
      echo "${label}: published ${branch} to origin so this work is on the remote." >&2
    else
      echo "${label}: ${branch} has no upstream and the push failed. Run: git -C ${dir} push -u origin ${branch}" >&2
    fi
    return 0
  fi

  # Anything to push at all? Local commits cannot appear on origin without this
  # checkout pushing them, so a zero count off even a stale ref is definitive —
  # and it keeps the network off the path of every session with nothing to say.
  local ahead
  ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null) || return 0
  [ "${ahead:-0}" -gt 0 ] || return 0

  # A non-empty index means an agent staged a specific set of files and owns
  # the next commit. Rebase --autostash would stash that index and re-apply it
  # unstaged, destroying the staged set — so wait for the commit to land.
  if ! git diff --cached --quiet 2>/dev/null; then
    echo "${label}: ${ahead} commit(s) left unpushed while files are staged for another commit." >&2
    return 0
  fi

  if [ "$SYNC_LIB_LOADED" -ne 1 ]; then
    echo "${label}: could not load ${SYNC_LIB} to check where origin stands — ${ahead} commit(s) left unpushed." >&2
    return 0
  fi

  # The freshness of the answer is the point: a checkout weeks adrift reports
  # "not behind" off its own stale origin ref, then the push bounces. A fetch
  # that does not complete means the answer is unknown, and unknown is treated
  # as unsafe — the commits stay local and the next session that can reach
  # origin pushes them.
  if ! bounded_fetch "$dir" origin "$FETCH_TIMEOUT"; then
    echo "${label}: could not reach origin — ${ahead} commit(s) left unpushed; the next session that can reach origin will push them." >&2
    return 0
  fi

  local counts behind
  counts=$(ahead_behind "$dir") || return 0
  ahead=$(printf '%s' "$counts" | awk '{print $1}')
  behind=$(printf '%s' "$counts" | awk '{print $2}')
  [ "${ahead:-0}" -gt 0 ] || return 0

  if [ "${behind:-0}" -gt 0 ]; then
    # Who to reconcile with if the replay fails — read before the rebase, while
    # HEAD still names this checkout's own line of history.
    local incoming_authors
    incoming_authors=$(git log --format='%an <%ae>' 'HEAD..@{u}' 2>/dev/null | sort -u | paste -sd '; ' -)

    local rebase_out
    if ! rebase_out=$(git rebase --autostash '@{u}' 2>&1); then
      local conflict_files
      conflict_files=$(git diff --name-only --diff-filter=U 2>/dev/null | head -5 | paste -sd ', ' -)
      git rebase --abort &>/dev/null
      echo "${label}: rebase onto origin/${branch} hit a real conflict (${conflict_files:-unknown files}) — ${ahead} commit(s) left local, nothing pushed. Another commit already on origin edits the same file; reconcile with ${incoming_authors:-whoever pushed the incoming commits}, then rebase and push by hand." >&2
      return 0
    fi

    # The rebase itself can succeed while re-applying the autostash conflicts.
    # Git keeps the stashed edits in a stash entry rather than losing them, but
    # they are no longer visible in the working tree — say so, or another
    # session's live edits silently vanish from under it.
    if printf '%s' "$rebase_out" | grep -qi 'autostash resulted in conflicts'; then
      echo "${label}: rebase succeeded but re-applying uncommitted local edits conflicted — they are preserved in \`git stash\`; run: git -C ${dir} stash pop" >&2
    fi
  fi

  if git push origin "$branch" &>/dev/null; then
    if [ "${behind:-0}" -gt 0 ]; then
      echo "${label}: pushed ${ahead} commit(s) to ${branch} after rebasing over ${behind} from origin." >&2
    else
      echo "${label}: pushed ${ahead} commit(s) to ${branch}." >&2
    fi
  else
    echo "${label}: push to ${branch} failed after a clean rebase — commits remain local. Run: git -C ${dir} push origin ${branch}" >&2
  fi
}

# Name what is uncommitted without claiming any of it. For a checkout shared by
# concurrent sessions, where the files in the tree may belong to any of them.
report_uncommitted() {
  local dir="$1"
  local label="$2"

  cd "$dir" 2>/dev/null || return 0
  git rev-parse --is-inside-work-tree &>/dev/null || return 0

  local staged unstaged untracked
  staged=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  unstaged=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

  [ $((staged + unstaged + untracked)) -eq 0 ] && return 0

  echo "${label}: ${staged} staged, ${unstaged} modified, ${untracked} untracked and uncommitted. Sessions share this checkout, so none of it is auto-committed and most of it belongs to other sessions — commit the files your own change touched and leave the rest." >&2
}

FLUX="${FLUX_DIR:-$HOME/src/Flux}"

# 1. Auto-commit the current project — unless it *is* the Flux context repo,
#    which the Flux pass below handles with report-and-push semantics. Without
#    this guard the Project pass would branch Flux off main, breaking its
#    intended ship-straight-to-main flow.
PROJECT_DIR="${FLUX_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}"
PROJECT_REAL=$(cd "$PROJECT_DIR" 2>/dev/null && pwd -P)
FLUX_REAL=$(cd "$FLUX" 2>/dev/null && pwd -P)
if [ -n "$PROJECT_REAL" ] && [ "$PROJECT_REAL" != "$FLUX_REAL" ]; then
  auto_commit_push "$PROJECT_DIR" "Project"
fi

# 2. The Flux context repo: push what this session committed, report — never
#    sweep — what is uncommitted. Every session works in this one checkout, so
#    `git add -A` here commits whatever any other session happens to have
#    half-written, under a message describing neither. Flux ships direct to
#    main with no PR ceremony, so an agent commits its own work as it goes;
#    naming what is left is worth more than claiming it.
if [ -d "$FLUX/.git" ]; then
  push_local_commits "$FLUX" "Flux"
  report_uncommitted "$FLUX" "Flux"
fi

exit 0
