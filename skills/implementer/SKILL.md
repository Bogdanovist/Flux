---
name: implementer
description: Conduct one tracer — or a tightly-coupled bundle — by spawning a disposable worker per slug, raising the PR, then offering shared review on it. Required argument: <project-name>; optional slug(s), defaulting to the next unstarted tracer.
argument-hint: "<project-name> [slug[,slug2,...]]"
---

# Implementer

Act as a conductor, not as a worker. Hold slugs, pointers, compact reports and
verdicts. Never hold file contents, the diff, or test logs. Every heavy read
happens inside a disposable worker, which returns you a bounded summary.
Output: commits, one PR with its review threads, and a completion note plus
what the tracer taught appended to each spec.

For genuinely trivial work — a typo, a one-line rename — skip the skill.

## Process

0. **Resolve the slug(s)** from `tracers.md` (default: first row with no
   completion whose prerequisites are met), then check the re-cut gate:
   any shipped tracer with `Re-cut: pending` names a finding the project
   has not absorbed. Read its taught-section beside the spec about to run
   and answer one question: does this slice rest on the part of the plan that
   moved? Proceed only if the answer is a one-clause "no", and say it aloud.
   If you have any doubt, stop and hand the re-cut back.
1. **Worktree.** Fetch, then create the branch worktree at
   `~/src/<repo>-worktrees/<branch-slug>` off the base ref (`main`, or the
   predecessor branch when stacking). Run one editing agent per worktree,
   ever. Check `git stash list` for interrupted prior work first.
2. **Implement.** One `tracer-implementer` worker per slug, serial, on the
   best tier, handed pointers — project, slug, worktree, branch. The
   worker reads the spec and the spine's cited assertions itself, runs the
   TDD loop (strict red-green-refactor where acceptance criteria cite
   assertion IDs; TDD-bias otherwise), commits, and returns a compact
   report. Stop on `blocked` or any needs-human item.
3. **Raise the PR.** Compose `writing-pr-descriptions`. In the body, state
   which assertion IDs the diff implements, which is the checkable half of
   the coverage manifest. Add an `## Incidentals` section for in-diff
   sweep-ups. For UI slices, run `visual-preflight` first and paste its
   report into the PR body.
4. **Review, in public.** Offer `reviewing-diff` against the open PR, with
   `spec:` naming the tracer spec or specs. It runs once the human approves,
   and its findings land as PR comments on the lines they judge. Send a
   BLOCK to one remediation worker, composing `receiving-code-review` so the
   worker evaluates each finding before applying it. Push the remediation
   commits, then choose the re-review by what the remediation changed:
   - Substantial change: run all dimensions again.
   - Narrow change: run the matching subset.
   - A few lines, written in full view of the findings: run none, and record
     that judgement.

   The human approver reads the final thread in every case, and the human
   merges, on every downstream repo.
5. **Record.** Append the completion note (shipped date, PR) and
   `## What this tracer taught` to each executed spec — the fact the
   design lacked with its evidence, the records affected, the remaining
   tracers affected, and the `Re-cut:` line. `Re-cut:` reads `pending` until
   the project absorbs the finding. A probe always writes `pending`, because
   finding that answer was its whole purpose. Flip the index row to
   `shipped <PR>`, and say the project is due a re-cut. The user drives that.

## Sweep-ups

While you read for the tracer, you will find things beside it. `followup` owns
where each one goes: inline, a project note, or the inbox. Fix something inline only when you have verified it is broken, the fix
is unambiguous, and it is one localised change in a file you are already
editing.

Announce every fix you fold in. Put a `sweep:` bullet in the commit and a line
in the PR's `## Incidentals`. If you fix something silently, the reviewer
cannot challenge it. If a find bears on the project's remaining work, put it in
the taught-section for the re-cut, and not in the inbox.

## Evergreen code

Code outlives tracers. In anything that ships, never mention the plan, the
phase, the slug, the project doc, or "for now". State the reason in terms that
stand on their own.

Write no comment that can become false while its own file stays unchanged. Put
a system-level claim in a record or an escalation, never in a comment. Give
every TODO a concrete trigger.

## Bundling

Bundle tightly-coupled tracers into one PR when every prerequisite is met and
a reviewer can still read the combined diff in one sitting. Execute each slice
in turn, and give each one its own PR sub-heading and completion note.

Never do the reverse. If you split one tracer by layer across several PRs,
neither half produces the signal you were after.
