---
name: git-worktrees
description: The recipe for the one worktree path the charter allows — where a worktree goes, how to create it, how to work in it, and how it gets reaped. Use when starting any branch of work, in any repo, including Flux's own charter, skills and project docs.
user-invocable: true
---

# Git worktrees

`AGENTS.md` §Worktrees and agent safety tells you to make every edit in a
worktree for its branch, and never in the main checkout. This skill is the
recipe for doing that. The charter holds the rule; do not restate the rule
here.

## Where a worktree goes

One place, for every repo:

```
~/src/{REPO}-worktrees/{branch-slug}
```

Turn the branch name into the slug by replacing each `/` with `-`, so the
branch `matt/study-calculator` gets the directory
`~/src/Flux-worktrees/matt-study-calculator`.

Use this path and no other. `scripts/cleanup-merged-worktrees.sh` walks
`~/src/*-worktrees/*/` and reaps nothing outside it, so a worktree you put
anywhere else survives its merged PR and nobody finds it again.

## Create one

```
git -C ~/src/{REPO} fetch origin
git -C ~/src/{REPO} worktree add ~/src/{REPO}-worktrees/{branch-slug} \
  -b {branch} origin/main
```

Branch from `origin/main`, not from whatever the main checkout happens to
have. When you stack a branch on an unmerged predecessor, branch from that
predecessor instead and say so in the PR.

Not every repo's default branch is `main`. Check before you assume.

## Work in it

- Run every git, build and test command from inside the worktree. Pass
  `git -C <worktree>`, or start the command there.
- Install dependencies in the worktree before your first test run. A fresh
  worktree has no `node_modules`, no `.venv`, and no build cache.
- Run one editing agent per worktree, ever. Read-only agents in parallel are
  fine. Two editing agents collide on stashes and lose each other's work.
- Before you touch anything in a worktree you did not just create, run
  `git status` and `git stash list`. Someone may have left work in it.

## Flux is the exception

Flux is your own context repo, and every change to it — the charter, the
skills, the rules, a project doc, a capture — commits in the shared
`~/src/Flux` checkout and pushes to `main`.

Take a worktree here only for a reason you can state, and say the reason when
you take one: a change you want to be able to abandon cleanly, or one whose
several commits only make sense together. Everything else goes to `main`.

Commit only the files your own change owns, by explicit path. Other sessions
work in that same checkout, so a sweep with `git add -A` takes their
half-written work with it, and `hooks/shared-checkout-guard.sh` blocks it.

If git stops in that shared checkout, follow `resolving-sync-conflicts`
before you run a second git command.

## Reap it

```
~/src/Flux/scripts/cleanup-merged-worktrees.sh          # dry run
~/src/Flux/scripts/cleanup-merged-worktrees.sh --apply
```

The script asks `gh` whether each worktree's PR merged or closed, and removes
the worktree when it did. It refuses to remove a worktree holding uncommitted
changes or unpushed commits, and those need a human.

Never use `rm -rf` on a worktree. That leaves the parent repo's worktree
metadata pointing at a directory that no longer exists, and the next
`git worktree add` on that path fails.

To remove one by hand, from the main checkout:

```
git -C ~/src/{REPO} worktree remove ~/src/{REPO}-worktrees/{branch-slug}
git -C ~/src/{REPO} worktree prune
```
