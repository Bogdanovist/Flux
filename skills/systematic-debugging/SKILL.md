---
name: systematic-debugging
description: >
  Root cause investigation methodology for bugs and failures. Use when
  encountering test failures, unexpected behavior, or errors during research
  or implement phases. Find the cause before attempting fixes.
---

# Systematic Debugging

**Always find the root cause before you attempt a fix.**

Debugging without a method wastes time and creates new bugs. A random fix
addresses the symptom and leaves the cause in place. A quick patch hides the
underlying problem. If you are trying fixes without understanding why any of
them might work, you are guessing. Stop, and investigate.

## Look at the Data First

For data-shaped bugs — wrong numbers, missing rows, duplicates, failing data tests, broken aggregates —
**inspect the actual data before reasoning about code.** The data is ground truth. The code in the repo today
may not be what produced the data: old versions, env quirks, manual overrides, partial backfills, retries, and
race conditions all leave fingerprints in rows that you cannot recover from reading source.

The shape of inspection depends on the bug. Open with whatever fits: sample rows, value distributions, key
cardinality, NULL density, timestamp ranges, schema-vs-expectation. Don't form hypotheses or open the SQL file
until you've actually looked.

## The Four Phases

Complete each phase in order. Do not skip to implementation.

### Phase 1: Root Cause Investigation

**Understand what's happening before theorizing why.**

1. **Read the error carefully**
   - Full error message, not just the first line
   - Stack trace - where did it originate?
   - Error codes or types

2. **Reproduce consistently**
   - Can you trigger the failure reliably?
   - What are the exact steps?
   - Does it fail the same way every time?

3. **Review recent changes**
   - What changed since it last worked?
   - Check git log for recent commits
   - Any new dependencies or configuration?

4. **Gather diagnostic evidence**
   - Add logging at key points
   - Check system state (memory, disk, network)
   - Inspect input data

5. **Trace backwards**
   - Start from the error
   - Work backwards through the call stack
   - Find where correct behavior diverges

### Phase 2: Pattern Analysis

**Compare against working code.**

1. **Find similar working code**
   - How does a working version do this?
   - What's different about this case?

2. **Compare against references**
   - Documentation examples
   - Library/framework conventions
   - Previous implementations

3. **Identify the difference**
   - What's unique about the failing case?
   - What assumption is being violated?

4. **Understand dependencies**
   - What does this code depend on?
   - Could a dependency have changed?
   - Are versions correct?

### Phase 3: Hypothesis and Testing

**Scientific method for debugging.**

1. **Generate 3–5 ranked falsifiable hypotheses**
   - Each must make a *prediction*: "If X is the cause, then changing Y will make the bug
     disappear / change the result from N to M / shift the failing rows from set A to set B"
   - Rank by likelihood given the evidence
   - **Show the ranked list to the user before instrumenting.** They often have context that
     re-ranks instantly ("we just promoted a new champion model", "marketing backfilled that
     source yesterday", "there's a known TZ issue with `tapped_at`"). Cheap checkpoint, big
     time saver
   - Single-hypothesis generation anchors on the first plausible idea — usually wrong on hard bugs

2. **Design a test**
   - How would you prove/disprove this hypothesis?
   - What would you expect to see if correct?
   - What would you expect to see if wrong?

3. **Make minimal changes**
   - Change ONE thing to test the hypothesis
   - Don't bundle multiple changes
   - Keep changes reversible

4. **Observe results**
   - Did the change affect the behavior?
   - Does it match your prediction?
   - Record what happened

5. **Iterate or proceed**
   - Hypothesis confirmed: proceed to Phase 4
   - Hypothesis rejected: form new hypothesis, repeat Phase 3

#### Data-pipeline usual suspects

For data-shaped bugs, bias hypothesis ranking toward these — they dominate by frequency:

1. **Join cardinality** — silent M:M where 1:1 was assumed. Probe: group by left-PK, count.
2. **NULL semantics** — `NULL ≠ ''`, `NULL ≠ 0`, `WHERE x != 'foo'` excludes NULLs, `COUNT(col)` skips NULLs but `COUNT(*)` doesn't, `SUM` over all-NULL returns NULL not 0.
3. **Timezone / date-vs-timestamp** — UTC boundary slip, naive vs aware, `DATE(timestamp)` in the wrong TZ.
4. **Filter / aggregation ordering** — `WHERE` before vs after `JOIN` / `GROUP BY`; `HAVING` vs `WHERE`; window function evaluated before the `WHERE` you thought filtered its input.
5. **Control-group / counterfactual contamination** — control members delivered to, or test members ending up in control measurement.
6. **Referential integrity** — child rows whose parent doesn't exist or no longer exists.
7. **Extraction / checkpoint state** — partial extracts, late-arriving events with backdated timestamps that landed *before* the checkpoint moved past them.
8. **Non-determinism in code that must replay** — reading wall-clock time, RNG, external state, or iterating an unordered map where the same input must produce the same output twice.
9. **Stale or wrongly-pointed inputs** — a transform run without its upstreams, a stale incremental build, an env var aimed at the wrong dataset or database.
10. **Engine semantic drift** — `DISTINCT`, `ORDER BY NULLS FIRST/LAST`, integer division, division by zero, string equality with whitespace, and timestamp precision all differ between engines, and between any engine and a local probe.
11. **Schema drift upstream** — source columns added, removed or renamed, a fixture reordered. Check `git log` on the staging layer and the fixtures.
12. **Sample bias** — works on the test dataset because the test dataset lacks the edge case. Confirm the offending row exists in the slice you are inspecting.

### Phase 4: Implementation

**Fix only after understanding.**

1. **Write a failing test at the right seam**
   - Capture the bug in a test
   - Test should fail before fix, pass after fix
   - **For data bugs, the canonical seam is a query that returns failing rows** —
     zero rows means pass. Put it wherever the repo runs its data tests, and mirror
     the shape of the ones already there. For a column-level invariant, use whatever
     schema-level constraint the stack offers.
   - **For code paths**, use the repo's test runner at the appropriate seam.
   - **If no correct seam exists** — the transform is one untestable block, or the bug
     only reproduces inside an orchestration the test suite cannot isolate — that
     itself is the finding. Note it; flag for refactor. Do not write a fake test at the
     wrong seam; it gives false confidence.

2. **Implement single fix**
   - Address the root cause
   - Not symptoms or side effects
   - Minimal change required

3. **Verify the fix**
   - Original test passes
   - All other tests pass
   - Manual verification if applicable

4. **Check for related issues — verify each, then fix or escalate**
   - Could this bug exist elsewhere?
   - Search for similar patterns
   - For each candidate instance: **verify it's actually broken in the
     same way** (reproduce or trace the failure path; check that
     callers and tests don't depend on the surprising behavior). A
     pattern that *looks* like the same bug may be intentional or
     test-pinned in its own context.
   - Fix the instances where you can establish all of: (a) verified
     broken by the same root cause, (b) correct behavior is
     unambiguous, (c) fix is localized. Otherwise **escalate to the
     user** with the list of suspected sites and what you
     could and couldn't verify.
   - Report fixed instances prominently in your output (commit message
     bullet, summary section) — do not bury sweep-ups inside step
     verification text. Both "found and left as pre-existing" AND
     "swept up without verification" are failure modes.

5. **Ask: would a check at the boundary have caught this?**
   - Most data bugs are recurrences of a bug that wasn't constraint-checked at ingest or
     staging. If a constraint at the source, staging, or contract layer would have caught it,
     **add the check now** as part of this fix:
     - A failing-rows test for a cross-table invariant
     - A schema-level constraint for a column invariant
     - A freshness check if it was a staleness bug
     - An input assertion at the entry point if it was a bad-input bug
   - Make this recommendation **after** the fix lands. By then you know more
     now than when you started.

6. **Emit a reusable lesson if the bug points to a missing rule.**
   - If the boundary-check question above answered "yes — a check
     would have caught this", that's evidence the repo's `.claude/`
     rules don't yet name the pattern that bites. Write **one**
     pending lesson capturing the rule in evergreen prose, following
     the emission recipe in
     `$FLUX_DIR/learnings/ENTRY-TEMPLATE.md`
     ("How to emit a lesson from a skill").
   - The `proposed-text` is the rule as you'd want a future reviewer
     to see it — not a description of this specific bug. The
     `rationale` is one sentence naming the bug class.
   - Skip emission if the bug is too specific to generalise (e.g. a
     one-off typo, a vendor-side incident). Bias toward writing
     when in doubt; the curator and PR review will filter noise.

## Red Flags: You're Skipping Investigation

| Thought | Reality |
|---------|---------|
| "Let me try this quick fix" | You don't understand the cause |
| "I'll just restart the service" | Masking the symptom |
| "Maybe if I add a null check here" | Guessing, not debugging |
| "Let me try a few things" | Random changes waste time |
| "This usually fixes it" | Past fixes don't explain current bugs |
| "I don't have time to investigate" | You don't have time NOT to |

## Integration with planned work

### During Research Phase

When investigating an issue:

1. Use this skill to understand the problem
2. Document root cause in research findings
3. Root cause informs the implementation plan

### During Implement Phase

When a step fails verification:

1. Stop the step (do not proceed)
2. Apply this debugging methodology
3. Find root cause before attempting fixes
4. Update plan if fix requires changes
5. Resume implementation after fix verified

## Escalation: When to Question Architecture

If you've attempted three or more fixes and the problem persists:

**Stop fixing. Question the architecture.**

- Is the design fundamentally flawed?
- Are we fighting the framework?
- Should this be reimplemented differently?

Raise these architectural concerns with the user before continuing.

## Evidence Gathering Techniques

### Logging

```text
Add temporary logging:
- Entry/exit of functions
- Variable values at key points
- Timestamps for timing issues
- Request/response payloads
```

### Bisection

```text
When did it break?
- git bisect to find breaking commit
- Binary search through code changes
- Narrow down to specific change
```

### Isolation

```text
Simplify to reproduce:
- Remove unrelated code
- Use minimal test case
- Eliminate variables
```

### Comparison

```text
What's different?
- Working vs broken environment
- Working vs broken input
- Working vs broken configuration
```

## Anti-Patterns

### Shotgun Debugging

**Wrong**: Try random changes hoping one works
**Right**: Form hypothesis, test it, iterate

### Fix and Pray

**Wrong**: Apply fix, hope it works, move on
**Right**: Verify fix addresses root cause

### Debugging by Deletion

**Wrong**: Remove code until error goes away
**Right**: Understand why code causes error

### Copy-Paste Fixes

**Wrong**: Find similar fix online, apply blindly
**Right**: Understand why the fix works for your case

### Skipping to Phase 4

**Wrong**: "I think I know the fix, let me just try it"
**Right**: Complete investigation phases first

## Checklist Before Fixing

- [ ] Error message read completely
- [ ] Failure reproduced consistently
- [ ] Recent changes reviewed
- [ ] Diagnostic evidence gathered
- [ ] Root cause identified (not just symptoms)
- [ ] Hypothesis formed and tested
- [ ] Fix addresses root cause
- [ ] Failing test written before fix
