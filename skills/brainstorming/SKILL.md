---
name: brainstorming
description: >
  Collaborative design methodology for creative work. Use before research or
  planning when requirements are unclear, multiple approaches exist, or the
  idea needs exploration. Refines ideas through progressive questioning.
argument-hint: topic or idea to explore
---

# Brainstorming

Explore ideas with the user before you commit to an approach. If you jump from a
vague idea to an implementation, you waste the effort. Use this skill to refine
the concept, surface the constraints, and weigh the approaches, before anyone
commits to research or planning. Doing it well stops you building the wrong
thing.

## When to Use

Use brainstorming when:

- Requirements are vague or incomplete
- Multiple valid approaches exist
- The problem space is unfamiliar
- Trade-offs need explicit discussion
- Creative design decisions are required

Skip brainstorming when:

- Requirements are clear and specific
- The approach is obvious
- This is a bug fix with known cause
- This is routine maintenance

## The Three Phases

### Phase 1: Understanding the Idea

**Goal**: Clarify what the user wants to accomplish.

Apply the `grilling` discipline for how to ask and when to stop. Topics to cover:

1. **What problem are you solving?**
   - The underlying need, not the proposed solution
   - Why does this matter?

2. **Who is this for?**
   - End users, developers, operators?
   - What do they need?

3. **What does success look like?**
   - How will you know it works?
   - What would make this valuable?

4. **What constraints exist?**
   - Technical limitations
   - Time constraints
   - Compatibility requirements

5. **What have you considered?**
   - Initial ideas or preferences
   - Approaches to avoid
   - Prior art to reference

6. **Is post-merge verification required?** (two-part)
   - First, yes/no: is any verification beyond automated CI needed? A perfectly valid answer
     is "no — CI covers it"; the purpose of the yes/no framing is to make the answer
     explicit rather than implicit.
   - If yes, follow up: "describe the trigger, commands, and owner." Examples of cases that
     usually need post-merge verification: cross-repo coordination, Terraform applies
     against live infra, post-deploy smoke checks, manual functional checks that require
     data/access unavailable locally.

### Phase 2: Exploring Approaches

**Goal**: Present options with trade-offs.

After understanding the idea, present 2-3 approaches:

```text
## Approach A: [Name]
[2-3 sentences describing the approach]

**Pros**: [Key advantages]
**Cons**: [Key disadvantages]
**Best when**: [Situations where this shines]

## Approach B: [Name]
[2-3 sentences describing the approach]

**Pros**: [Key advantages]
**Cons**: [Key disadvantages]
**Best when**: [Situations where this shines]

## Approach C: [Name] (if applicable)
...

## Recommendation
[Which approach and why, based on stated constraints]
```

Get the user's preference between:

- "Approach A (recommended)" - with brief rationale
- "Approach B" - with brief rationale
- "Explore further" - discuss more options
- "None of these" - gather more requirements

### Phase 3: Design Documentation

**Goal**: Document the agreed design.

After selecting an approach, document it:

1. **Present design in sections** (200-300 words each)
2. **Validate each section** before continuing
3. **Adjust based on feedback**
4. **Save final design** into the project's working doc,
   `<repo>/context/projects/<slug>/plan.md` — `open-project` owns the
   header contract and the checkout it is written in

Design document structure:

```markdown
# Design: <Topic> (YYYY-MM-DD)

## Problem Statement
[What problem this solves]

## Chosen Approach
[Selected approach and rationale]

## Design Details
[Specific design decisions]

## Trade-offs Accepted
[What we're giving up and why it's acceptable]

## Verification Plan

**Post-merge verification required**: yes | no
**If yes — what needs to run, where, and when**:
- [step with access requirement / repo / trigger point]

## Open Questions
[Anything still unresolved]

## Next Steps
- [ ] Research phase (if needed)
- [ ] Planning phase
- [ ] Implementation
```

## YAGNI Principle

**You Aren't Gonna Need It.**

Ruthlessly apply this during brainstorming:

- Reject features "for later"
- Question every "nice to have"
- Focus on the minimum viable solution
- Complexity can be added later; removing it is hard

```text
User: "We should also add support for X in case we need it"
Response: "Let's focus on the core need first. We can add X
later if it becomes necessary. What's the minimum we need now?"
```

## Transition to Next Phase

After brainstorming, guide to appropriate next step:

**If design is complete and validated:**

```text
"Design documented at <repo>/context/projects/<slug>/plan.md

Next step per the core loop (AGENTS.md): commit the doc to the repo's main and
put it to the user, per open-project §Where the doc is written. If the risk
justifies it, grow the doc into the solution-design spine first, which
review-solution-design then gates. If more context is needed, continue
brainstorming or run explore-problem."
```

## Anti-Patterns

### Skipping to Solutions

**Wrong**: "Let's build X using Y framework"
**Right**: "What problem are we solving? Who is it for?"

### Analysis Paralysis

**Wrong**: Endless exploration without converging
**Right**: Time-box exploration, make decisions

### Gold Plating

**Wrong**: Designing every possible feature
**Right**: YAGNI - minimum viable solution first

### Ignoring Constraints

**Wrong**: Designing without considering limitations
**Right**: Surface constraints early, design within them

### Monologue Design

**Wrong**: Presenting complete design without validation
**Right**: Incremental presentation with checkpoints

## Checklist Before Proceeding

- [ ] Problem statement clear
- [ ] Success criteria defined
- [ ] Constraints identified
- [ ] Multiple approaches considered
- [ ] Trade-offs discussed
- [ ] YAGNI applied ruthlessly
- [ ] Verification plan captured (`Post-merge verification required: no`, or `yes` with steps identified)
- [ ] Design documented (if proceeding to plan)
- [ ] Next phase identified
