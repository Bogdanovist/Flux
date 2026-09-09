#!/usr/bin/env bash
# Pre-commit hook for the Flux repo — the checks a commit here must pass.
#
#   1. Secrets scan (hooks/pre-commit-secrets-check.sh) — every commit.
#   2. Shell suites (scripts/tests/run-all.sh) — only when the commit stages a
#      change under hooks/ or scripts/.
#
# The session hooks run against every tool call of every session, on two
# platforms whose shell utilities differ, and they fail non-blocking: a defect
# there bills every session that follows until someone stops to read a stack
# trace. The commit that introduces it is the last cheap place to catch it.
# Scoping to the directories under test keeps a docs-only commit at zero cost.
#
# The suites read the working tree, not the staged snapshot, so a commit staged
# from a half-finished edit is judged on the whole edit. They run with git's
# repo-location variables cleared and re-entry blocked, because a suite that
# commits in a fixture repo would otherwise commit here and re-enter this hook.
#
# The tree they are read from is the one being committed, which is not always
# the one holding this file: worktrees share .git, so this single installed hook
# fires for a commit in any of them. Resolving the suites from the hook's own
# directory would test the main checkout every time — passing a worktree commit
# that breaks a suite, because the copy it ran lacks the change, and failing one
# that fixes a suite, because the copy it ran is still broken.
#
# Escape hatch: `git commit --no-verify`.

set -uo pipefail

# git invokes this as .git/hooks/pre-commit, a symlink to the file itself, so the
# repo is found by resolving the link chain — `cd -P` on the containing directory
# would resolve .git/hooks and land back inside .git. Plain `readlink` in a loop
# rather than `readlink -f`, which BSD does not have.
resolve_self() {
  local src="${BASH_SOURCE[0]}" dir
  while [[ -L "$src" ]]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" == /* ]] || src="$dir/$src"
  done
  (cd -P "$(dirname "$src")" && pwd)
}

HOOK_DIR="$(resolve_self)"

# git runs a hook from the top of the working tree it is committing in, so this
# is the tree whose suites the commit is answerable for. The secrets check on
# the other hand stays at HOOK_DIR deliberately: it is the gate, and a commit
# must not be able to weaken the scan that admits it by editing its own copy.
WORKTREE_DIR="$(git rev-parse --show-toplevel)"

# A commit made from inside this hook reaches this hook again. The suites below
# build fixture repos and commit in them, so a nested commit is ordinary and
# must be allowed through — but re-running the suites from inside themselves
# recurses without a floor, and every level holds a process and writes a commit.
# Allowing the commit and skipping the suites is the only bounded reading.
#
# Exported, so it reaches a nested commit at any process depth. Clearing the
# git environment below deliberately leaves it set.
if [ -n "${FLUX_PRE_COMMIT_ACTIVE:-}" ]; then
  exit 0
fi
export FLUX_PRE_COMMIT_ACTIVE=1

"$HOOK_DIR/pre-commit-secrets-check.sh" || exit 1

STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)
printf '%s\n' "$STAGED" | grep -qE '^(hooks|scripts)/' || exit 0

printf 'Flux: staged changes touch hooks/ or scripts/ — running shell suites\n'

# A tree staging hooks/ or scripts/ changes without a runner is a broken tree,
# not a tree exempt from its suites. Falling back to another checkout's runner
# here is the defect this hook had.
if [ ! -x "$WORKTREE_DIR/scripts/tests/run-all.sh" ]; then
  printf 'Commit blocked: no runnable scripts/tests/run-all.sh in %s\n' "$WORKTREE_DIR"
  exit 1
fi
# git hands a hook its own repo and its own identity through the environment,
# and both outrank what a suite sets for a fixture repo it builds:
#
#   - the repo-location variables (GIT_DIR, GIT_INDEX_FILE, …) outrank
#     `git -C <dir>`, so a fixture commit lands in *this* repo instead;
#   - GIT_AUTHOR_NAME/EMAIL/DATE outrank the fixture's own `user.name`, so
#     every fixture commit carries the real committer and a suite asserting on
#     authorship reads its own machines as one person.
#
# `git rev-parse --local-env-vars` names the first set, so it follows the git
# in use rather than a list written down here and outgrown. The rest are not in
# it and are named directly: the identity pair above, GIT_NAMESPACE, which would
# file a fixture's refs under a namespace, and GIT_REFLOG_ACTION, which would
# describe a fixture's reflog entries as whatever this commit is doing.
#
# Cleared in a subshell rather than here, because the secrets check and the
# staged-path gate above need the real index to read.
if ! (
      unset $(git rev-parse --local-env-vars) \
            GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE \
            GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE \
            GIT_NAMESPACE GIT_REFLOG_ACTION
      "$WORKTREE_DIR/scripts/tests/run-all.sh"
    ); then
  printf '\nCommit blocked: a shell suite failed. Fix it, or commit with --no-verify.\n'
  exit 1
fi
exit 0
