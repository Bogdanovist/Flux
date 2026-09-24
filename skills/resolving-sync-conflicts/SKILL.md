---
name: resolving-sync-conflicts
description: What to do when git in the shared Flux checkout is in a state you did not create — a rebase that conflicted, a stash holding another session's edits, an index.lock, a half-finished rebase, unpushed commits, files in the tree that are not yours. Use the moment any of those appears, before running a second git command. Applies to `$FLUX_DIR`, which every session on a machine shares.
user-invocable: true
---

# Resolving sync conflicts

Every session on a machine works in one `$FLUX_DIR` checkout, and your other
machines push to `main` from theirs. So the tree you are looking at holds
another session's half-written files, and `origin/main` moves under you while
you work. That sharing is what makes a capture reach every machine you work
from, rather than stranding on the one that wrote it.

You pay for that with the occasional stop, where git asks you a question. This
file gives one answer to each question, so that two agents meeting the same
state do the same thing. If you improvise here, you leave a tree that the next
agent cannot read.

## The three rules everything below follows

**Rebase, never merge.** `hooks/auto-commit-push.sh` rebases at session end. If
you merge by hand, you put merge commits into a history the hook expects to be
linear, and the next rebase conflicts on them.

**Treat a conflict as a stop.** Git is telling you that two sessions edited the
same lines, and you can see only one of the two intentions. Stop and report.
Your commits stay local, and waiting costs you nothing.

**Re-apply, do not resolve.** When your own change collides, take the incoming
version whole and redo your edit on top of it. If you edit hunk by hunk inside
someone else's paragraph, you turn two half-correct edits into one wrong one.

## Never, in this checkout

Each of the following looks like progress and destroys someone's work. Never
run any of them here:

- `git push --force` / `--force-with-lease` — the commits you would overwrite
  are on someone's machine, not just origin.
- `git rebase -X ours` / `-X theirs`, `git checkout --ours/--theirs` — these
  discard one side of a conflict without reading it.
- `git add -A`, `git add .`, `git commit -a` — the tree holds other sessions'
  files. Stage your own paths by name.
- `git stash` to get past a dirty tree — those uncommitted files are someone
  else's work.
- `git reset --hard`, `git checkout .`, `git restore .`, `git clean` — these
  delete uncommitted work belonging to sessions you cannot see.
- `rm .git/index.lock` without the check in **E** below.
- `git commit --no-verify` to get past a suite failure that is not yours.

## The states, and what to do in each

### A. The rebase hit a real conflict

The hook reports the conflicting files and who pushed the incoming commits, and
has already run `git rebase --abort`. Your commits are still local; origin is
untouched.

1. `git -C $FLUX_DIR fetch origin && git -C $FLUX_DIR log --oneline HEAD..@{u}`
   — read what landed.
2. If the incoming change makes yours unnecessary, drop yours with
   `git reset --keep @{u}`. Not `--hard`, which deletes every uncommitted
   change in the tree and most of them are not yours. `--keep` moves HEAD,
   leaves local modifications alone where the two commits agree on the file,
   and aborts with `Entry '<file>' not uptodate. Cannot merge.` exactly when
   it would have to overwrite one. If it aborts, the guard is working. Find
   whose edit it is before you go further.
3. Otherwise re-apply: `git rebase @{u}`, and at the stop open the file, take
   the incoming version whole, and redo your edit on top.
4. If you cannot read the other author's intention from the diff, stop and say
   so, naming them. Reporting that is a finished piece of work.

### B. The rebase succeeded but re-applying uncommitted edits conflicted

The hook says the edits are preserved in `git stash`. They are not in the tree,
and **they are probably not yours** — the autostash sweeps whatever the shared
tree held.

1. `git -C $FLUX_DIR stash show -p` — read it before touching it.
2. Every file in it that you did not edit belongs to another session. Do not pop.
3. If it is all yours: `git stash pop`.
4. If any of it is not: leave the stash, and report which files and which stash
   entry, so that the owner pops it themselves. A stash entry is durable. The
   risk is that you pop it into a tree where its owner has stopped looking.

### C. Commits are unpushed because files are staged

The hook will not rebase over a non-empty index, because autostash would
re-apply the staged set unstaged and destroy it.

Commit the staged files under their own message, or `git restore --staged` the
paths you did not mean to stage. Then the next session end pushes. Do not push
by hand around the index.

### D. Origin was unreachable

Do nothing. Your commits are local, and the next session that can reach origin
pushes them. Do not retry in a loop, and do not work around it. A fetch that did
not complete leaves the checkout not knowing where it stands, and a push from
there publishes a divergence.

### E. `Unable to create '.git/index.lock': File exists`

Another session is running a git command in the same checkout. This is normal
and usually clears in seconds.

1. Wait five seconds and retry. Twice.
2. Still there — check whether it is stale rather than live:
   `ps -eo pid,etimes,args | grep -E '[g]it (commit|rebase|merge|add)'`
3. If a git process is live, wait, however long it takes. Interrupting a commit
   mid-write leaves a corrupt index.
4. Only with no live git process, and a lock file older than the oldest git
   process on the box, remove it: `rm $FLUX_DIR/.git/index.lock`. Say in your
   response that you did.

### F. A rebase is already in flight

`.git/rebase-merge` or `.git/rebase-apply` exists and git refuses to do anything
else. A session died mid-rebase, and **it was not necessarily yours.**

1. Check for a live rebase first, as in **E**. If one is running, wait.
2. With none running, `git -C $FLUX_DIR rebase --abort` returns the tree to
   the commit it started from. Nothing committed is lost.
3. If `--abort` fails because no rebase is in progress, the directory is a
   leftover. Report it, and do not delete it by hand.

### G. The tree is full of files you did not write

Expect this. `hooks/auto-commit-push.sh` reports them at session end and never
commits them, because a sweep here would commit another session's half-written
files under a message describing neither.

Stage your own paths by name and commit those. Leave the rest exactly as it is,
including untracked files that look like debris — a scratch file you delete may
be the only copy of something another session is mid-way through.

### H. A capture file conflicted

It cannot conflict, by design. `/learn` writes `learnings/pending/<uuid>.md`
and `/followup` writes `followups/inbox/<session>-<uuid>.md`, so two sessions
never touch one file. A conflict there means the naming broke.

Do not resolve it. Report it as a defect in whichever skill wrote the file.

### I. The pre-commit suites fail on a change that is not yours

`hooks/pre-commit.sh` runs the shell suites when a commit stages anything under
`hooks/` or `scripts/`. In a shared checkout the suites read the whole working
tree, so someone else's half-finished edit can fail them.

Do not commit with `--no-verify` to get past it. Fix the break if you can: it is
in front of you, and it blocks everyone. If it is not yours to fix, report which
suite fails and whose edit causes it, and leave your commit uncommitted.

### J. `shared-checkout-guard` blocked the command

`hooks/shared-checkout-guard.sh` refuses sweeping adds and discarding commands
when it resolves the command's directory to `$FLUX_DIR`. It resolves that
directory from a leading `cd` in the command, falling back to the session's own
directory when the `cd` target is a shell variable it cannot expand. So a
genuinely unrelated command in a temp repo is blocked whenever its path is
behind a variable. The guard fails closed on purpose. A false block costs you a
retry. A miss costs another session its uncommitted work.

Reach for the literal path before the override:

- `cd /tmp/scratch/repo && git reset --hard` resolves, and is allowed.
- `cd "$TMP" && git reset --hard` does not resolve, and is blocked.

`FLUX_GUARD_SKIP=1` exists and is logged. Use it only when you have already
confirmed the target is not `$FLUX_DIR`, and say in your response why. Never
use it to get past a block inside the shared checkout. There, the guard is right
and your command is wrong.

## When none of these fit

Stop and report the state: the exact git output, the files involved, and what
you were doing. Other people are writing to this checkout, so when you meet a
state you do not recognise, guessing costs more than waiting.
