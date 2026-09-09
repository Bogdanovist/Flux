---
name: plan-review
description: Adversarial review of a plan before anything is built — the problem, the approach, the contracts it touches, the risks it names, and whether its depth matches the work. Use on a plan doc in Flux, or on a plan PR in a project repo.
---

# Plan Review

Run this before the build starts, while changing course is still cheap.

Where the findings go follows where the plan lives. A plan on a PR takes
anchored PR comments, one per finding, so each sits beside the lines it
judges. A plan doc in Flux takes the findings in this session, and every
finding you accept becomes an edit to the doc in the same sitting — an
accepted finding that never reaches the doc is one the next agent reads the
plan without.

## What a reviewer checks

Check these against the plan as the author wrote it. Do not read it as
charitably as you can.

1. **The problem is real, and the plan evidences it.** The plan says who feels
   it, what the status quo costs, and how the author knows. Every claim about
   existing behaviour names how the author verified it. If one does not,
   comment asking for the command.
2. **The approach answers the problem.** A reader who accepts the Why finds
   the Approach sufficient for it. Look for leaps, and for a step that
   smuggles in a contract nobody has decided.
3. **The plan names every contract it touches.** It lists the schemas,
   interfaces, message formats and migration behaviour the work will change,
   and it lists the consumers of each. A contract the plan does not name is
   the highest-severity finding you can raise, because that is where work
   gets built wrong.
4. **The plan names its risks and unknowns, and does not smooth them over.**
   It marks what reasoning cannot settle as open, and says what would resolve
   each one.
5. **The depth matches the work.** If a plan carries spine-level risk, such as
   many consumers or facts about live systems, comment recommending the
   author escalate to the optional `solution-design` spine. If a trivial
   change carries a full plan, comment recommending ship-it.
6. **The plan bounds its scope.** It states what is out of scope. If a plan
   sets no boundary, the build will find one for it.

## Mechanics

- On a PR, comment with `gh pr review --comment` or `gh api`, anchored to the
  plan's lines. Give every finding a severity, wherever it lands: `blocking`,
  meaning do not build on this as written, `should-fix`, or `note`.
- Close the pass with one summary comment carrying the verdict, the finding
  count, and what you checked and found clean. If you stay silent about an
  area, a reader takes it as unexamined, and not as passed.
- A `blocking` finding stops the build until the plan answers it. Say so
  plainly rather than starting work beside it.
- Re-run this pass when the plan changes course. An approach settled against
  the old Why has not been reviewed against the new one.
