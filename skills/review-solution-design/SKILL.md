---
name: review-solution-design
description: Cold-context adversarial review of a project's spine doc — a fresh-eyes reviewer independently re-verifies the design's claims and checks the known defect classes, as the standing gate between design and decomposition. Required argument: <project-name>.
argument-hint: "<project-name>"
---

# Review Solution Design

Catching a design error here costs one conversation. Catching it later costs a
rebuild. This is the last gate before the design turns into work.

**Run the review in a cold context.** Use a spawned reviewer or a fresh
session that had no hand in writing the design. Read exactly what an
implementer would read, in the order the doc states. A reviewer who watched
the design being written inherits its blind spots.

## Restatement first

Before you check any assertion, restate the design's story from its narrative
alone: what is being built, why, and how the system operates before and after.
If you cannot restate the narrative, the design fails here, whatever its
registers say.

Then restate each register entry the same way: its scope, its rule, and what a
failing input looks like, in your own words. If you cannot restate an entry, an
implementer cannot execute it cold, whatever it says.

This step also guards against reconstruction errors. Never flag designed
behaviour as a defect because no section told you the operating model. If the
model was missing, the missing model is the finding.

## Verify independently

Never treat the doc's word as evidence for the doc's own claims.

- Run every re-verify command the doc carries, and count how many checkable
  facts carry none. Record three things as findings: a command that fails, a
  "command" that is only a pointer, and a load-bearing fact with no command.
- Check claims about code and data at the layer where the answer is visible. A
  table downstream of a filter cannot answer a question about that filter.
- Check every cited record: has its overturn condition fired, do its facts
  still verify?

## The defect classes

Itemise what to check for this specific project first — its own discipline
section may adapt the flow, and the review honours the adaptation while
checking that dropped disciplines were named, not silently lost. Then the
standing classes, each of which has produced real damage:

1. **Restatement drift** — one fact stated in two places that disagree,
   including an assertion naming what the target-shape block lacks.
2. **Coverage** — every pinned contract has an assertion; every danger
   links to a canonical statement that exists and says what the danger
   claims; nothing catastrophic lives only as inline bolding.
3. **Checks that cannot fail** — for each verification: what would it
   return if the claim were false? A comparison against its own source
   proves the copy ran.
4. **Decided voice on undecided things** — statements resting on an open
   question without a provisional marker at the point of use.
5. **Migration obligations** — one rollback label per state, numbered
   ordering, what goes dark, abort conditions.
6. **The end-to-end gap** — the design must cover the whole change:
   migrations, data steps, operational steps, monitoring. Name what has no
   home.
7. **Contradictions** between decisions stated and design specified.
8. **Structural integrity** — reading order stated, references resolve,
   every counted claim has its enumeration, every quantified set written
   out, and every pointer aims at an artefact with equal or longer life
   than its own — a durable entry citing an ephemeral doc dies with it.
9. **A better solution** — understand the why, then ask whether a
   materially simpler shape delivers it. One good challenge outweighs ten
   nits.
10. **Length** — name the specific cuts; verbose docs bloat every
    downstream context.

## Output — shared

Findings go to `projects/<name>/solution-design-review-<date>.md`, beside the
design they judge. When the design rides a PR in a project repo instead, they
land as PR comments anchored to the lines they concern, with the summary
comment carrying the verdict. Either way: per
finding, the class, the evidence, and a severity — blocks-decomposition /
should-fix / note — plus what was checked and found clean, so a missed area
reads as missed rather than silently passed. Findings that indicate a
methodology gap — a defect class the skills should have prevented — get one
line saying so.

The main session works the findings through with the user. This gate never
applies fixes.
