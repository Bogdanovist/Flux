---
name: triage
description: Drain the followups inbox — verify each item is still live, cluster by theme, build one root-cause case per cluster, and force one disposition each, biasing hard toward subtraction and the kill. Use when the session-start nudge says the inbox is due, or when you want the pile cleared.
user-invocable: true
---

# Triage

Run one pass that clears the whole accumulated inbox. Work globally, and not
item by item: read everything, cluster by theme, then decide per cluster.
Three items that are not worth fixing alone can point at one systematic fix
that is.

Treat every follow-up as a symptom. This sitting exists so that you find the
cause behind a cluster and act on that instead. Bias hard toward subtraction.
The best resolution deletes the cause. The next best simplifies what exists.
Adding a mechanism is your last resort. **Kill with a reason by default.**
Most follow-ups should die on the record.

## The pass

1. **Read the whole inbox** (`$FLUX_DIR/followups/inbox/`) before you
   decide anything, and pull main first, because captures land there from
   every session on every machine. If the inbox is empty, report that and
   stop.
2. **Verify that each item is still live.** Items age, and the code moves
   between filing and triage. Check each claim against the current repo, and
   mark it **live** if it reproduces, **fixed** if it no longer does (archive
   it as `killed: already fixed in <ref>`), or **moved** if the code changed
   shape (restate it against what is there now, then cluster it). Never
   disposition an item on its filed evidence alone.
3. **Audit for misroutes.** If a session punted deliverable work here, hand
   it back to the user as "go finish that", and do not disposition it. If a
   find sits inside a live project's intent, redirect it to that project's
   doc and do not cluster it: the project owns the re-cut, and a note in the
   plan reaches the work while the inbox waits for a sitting.
4. **Surface urgency.** Name anything marked `blocks-now` immediately, and
   call out the `before-this-project-ends` items in the report.
5. **Cluster by theme**: the same subsystem, the same class of smell, or the
   same root cause. Never cluster by repo or kind alone.
6. **Take one cluster per turn.** Give the problem and its evidence, then the
   root cause, then the best option that subtracts, then the best option that
   adds, stated fairly, then your recommendation. An honest "no shared cause"
   here is usually a kill. If you recommend adding something, justify both
   its net benefit and why simplification cannot do the job.

## Dispositions

| Disposition | When | On ratify |
| --- | --- | --- |
| **fix-now** | Small and clear | Do it (worktree + PR in the repo); archive `fixed: <ref>` |
| **project-note** | Inside a live project's intent | Note in that project's doc; archive `project-note: <path>` |
| **project** | Worth its own piece of work | Open it with `open-project` (or `solution-design`); archive `project: <slug>` |
| **record** | A durable decision, or a measured fact, that no enforcer holds | Mint via `records` at its scope and kind; archive `record: <path>` |
| **rule** | Recurring "we keep getting X wrong" | Climb the form ladder first — an enforcer beats a record beats prose. Only working-style guidance becomes a pending lesson for `curate`; archive `rule: <uuid>` |
| **standing** | A durable domain fact worth holding, not a discrete fix | Propose the edit to the feature index it belongs to; archive `standing: <path>` |
| **kill** | Not worth it | Archive `killed: <one-line reason>` — the default |

Every disposition is yours to make in the sitting. Nothing stays in the inbox
after the pass — deferral is itself a decision, archived as
`killed: deferred — re-raise if it recurs`.

## The archive and the records cull

Dispositions land in `followups/archive.md` — written only during this
pass, the serialised-append-file rule. Then the cheap records cull: grep
for citations of each `held` record whose `verified:` stamp has aged;
a record nothing cites is surfaced with its overturn condition and, on
ratify, retired. Git history is the archive.
