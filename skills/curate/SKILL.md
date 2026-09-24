---
name: curate
description: Run the lessons curation pass — drain pending captures into staging, have a read-only curator analyst cluster them into themes and draft ranked proposals judged against the promotion bar, walk the proposals one at a time, and land one PR per approval behind the deterministic guards. Use when the session-start nudge says staging is past the threshold, or when you want the pile cleared.
user-invocable: true
---

# Curate

Run curation as a conversation. Bring forward only the few changes that carry
their weight, and argue each one well enough that you can approve it on sight.
Record everything else, and lose nothing.

`curation/promotion-bar.md` is the judgement standard. Cite it on every pass.

## The pass

1. **Drain.** Pull main. Validate and append every file in
   `learnings/pending/` into `learnings/staging.md` (the validator is
   `scripts/lib/staging-schema.sh`; a file that fails stays in pending with
   its error reported). `hooks/drain-to-staging.sh` does this at session end,
   so staging is usually already current — run the drain here anyway, because
   a capture filed in this session has not passed through it yet.
2. **Analyse.** Spawn the read-only `curator` analyst on the staging
   entries plus `learnings/evidence.md`. The analyst clusters by theme, and
   never by target file. It folds every lesson into the ledger, including a
   one-off at count 1, which seeds the cluster a future pass crosses the bar
   with. It dedups against ledger UUIDs and applies the promotion bar's
   gates. It returns three things: the ranked proposal queue, where each
   entry is a three-part case; the proposed ledger updates; and a
   per-lesson disposition map. It edits nothing.
3. **Review one proposal per turn, in prose.** Each case gives you three
   things: the evidence and its count; the exact edit at the exact
   destination, quoted before and after; and the mechanism that will consume
   it. Then take one of four actions:
   - Approve it, and land it.
   - Ask for a revision. Reframe it, re-present it, and carry the feedback
     into every later proposal.
   - Reject it. Write `rejected: <reason>` in the ledger and keep the count.
   - Defer it. Mark it `pending`, and it resurfaces as its count climbs.
4. **Land approvals, one change per approval, behind the guards.** The guards
   are the shell safety net for an agent editing guidance it also reads, and
   they fail closed:

   - Check the destination repo is readable before anything else:
     `bash <cwd>/scripts/lib/assert-repo-allowed.sh <repo>`. A repo with no
     checkout cannot be read, and a proposal quoting text nobody read is the
     failure this pass exists to prevent.
   - For a change to a project repo, take a worktree and branch
     `lessons/<slug>` from the destination file's slug:

     ```bash
     git -C $FLUX_SRC_ROOT/<repo> fetch origin
     git -C $FLUX_SRC_ROOT/<repo> worktree add \
       $FLUX_SRC_ROOT/<repo>-worktrees/lessons-<slug> -b lessons/<slug> origin/main
     ```

     Run the branch guard twice, after the add and again before the push:
     `bash <cwd>/scripts/lib/assert-branch-lessons.sh -C <worktree>`.
   - For a change to Flux itself, commit on `main` in `$FLUX_DIR`. Flux is
     your own context repo, so a branch here buys a review nobody is waiting
     to give.
   - Before every Edit or Write, whichever the destination:
     `bash <cwd>/scripts/lib/assert-curator-edit-allowed.sh <repo> <root> <abs-path>`
   - Apply the exact edit you approved — the before and after from part 2.
     Stage only that file by path, never `-A`. Commit:

     ```text
     lessons: <one-line improvement to the file>

     <what the theme contributed; cite the recurrence if a pattern>

     uuids: <comma-separated UUIDs of the lessons behind this proposal>
     ```

   - Push. In a project repo, open the PR titled `[LESSONS] <summary>` and
     leave it for the user to merge. Say in the PR body which lessons drove
     it: a change to guidance every future session loads deserves the same
     look as code.
5. **Bookkeep.** Apply the ledger updates to `learnings/evidence.md`
   (counts, fingerprints capped ~5 per cluster, statuses overlaid with
   actual outcomes); append each staged lesson verbatim to
   `learnings/archive.md` tagged with its disposition; clear staging;
   commit the ledger and archive to Flux main.
6. **Report.** List what you approved, with the commits or PR URLs, then what
   was revised, rejected and deferred. Flag loudly any lesson that recurred
   after a fix shipped. If a shipped rule keeps recurring, nothing is
   consuming it. Change the intervention, and do not make the rule louder.

## What this pass never does

- Never land a change the user has not approved in this session.
- Never accept a laundry list. If a proposal reads like a per-file dump, push
  back on it.
- Never edit a guidance file outside the guards.
- Never discard a lesson. Every lesson lands in the ledger and the archive,
  whatever you decided about it.

Ratify sweep proposals from `context-sweep` in the same sitting, and keep them
in their own ledger. The two machines share a pass. They do not share a file.
