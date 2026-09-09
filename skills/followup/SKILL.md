---
name: followup
description: Route an incidental find — a bug beside the work, a stale TODO, a failing test, a judgement call — to exactly one destination; fix it, note it to the project it belongs to, or file it to the inbox the weekly pass drains. Compose from any skill where code-reading surfaces broken windows; invoke directly to capture one deliberately.
user-invocable: true
---

# Followup

While you read or edit code for one purpose, you will find problems beside it.
Send each one to exactly one destination. Work down the three below, and stop
at the first that fits. Announce every deferral in the turn you make it, so
that the user can see it and veto it.

## The three destinations

### 1. It is the work in hand — finish it

Take this destination when the find is part of what the user asked for, when
you need it to make the work function, when it is an unmet acceptance
criterion, or when it is a broken window beside the work that you can fix
cheaply in this change. The charter requires that last one. Finish it, or say
plainly that you did not and why. If you route deliverable work into any sink,
you have relabelled it as optional.

### 2. It falls inside your own live project's intent — note it there

Take this destination by default for anything you find during project work,
and set a high bar for choosing anything else. Ask one question about intent:
is this the kind of thing the project exists to sort out? Do not ask which
files the find touches, and do not ask whether a planned step covers it.
Working in slices produces nuances, surprises, and assumptions that turned out
wrong. All of them belong to the project that produced them.

Write a note in the project's working doc. State the problem and the evidence.
Say nothing about how to slice it: the user makes the re-cut, with the plan
open in front of them.

### 3. Everything else — the inbox, for the weekly pass

No live project it belongs to, no clear shape, or a judgement call worth
sitting down with: one file per item in `followups/inbox/`,
`<session>-<uuid>.md` (unique names keep concurrent captures conflict-free),
carrying repo, kind, urgency (`blocks-now` / `before-this-project-ends` /
`whenever`), a one-line summary that clusters well, the evidence, and — when
an agent filed it — the one-line reason it is not the current work's
business. `triage` drains the inbox. A `blocks-now` item is named to the user
in the turn you file it: the inbox is a weekly store, and urgent work must not
wait for it.

## The evidence bar

Put what you actually saw in every capture: the failing output, the
`file:line`, the command you ran. "Looks wrong to me" is not evidence. Code
that surprises you is often correct for reasons you do not have, so flag an
unverifiable find for the user and never assert that it is broken. The
conservative tag costs you nothing. A "fix" to a load-bearing quirk costs a
lot and is hard to spot.

## Labelling from read-only contexts

A read-only subagent never routes a find. It labels each incidental in its
report, and the invoking session routes it. Use three tags, and give every tag
its evidence:

- `[FIX-INLINE]` — belongs in the current change.
- `[FIX-FOLLOWUP]` — route it to destinations 2 to 4.
- `[FLAG-HUMAN]` — you cannot verify it, or touching it without more context
  is risky. Use this tag whenever you are in doubt.

## Boundaries

- Send observations and lessons to `/learn`. Never make them tickets, and
  never put them in the inbox.
- If a find invalidates a later planned step, send it to its project,
  destination 2. Do not send it to the inbox, however good the evidence. A
  correct finding in the wrong sink arrives too late to help.
- Never park a deferral only in a PR body, a code comment, or chat. Those
  merge and evaporate. Destinations 2 to 4 are the durable sinks.
