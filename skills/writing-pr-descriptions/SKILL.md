---
name: writing-pr-descriptions
description: >
  Write PR titles and descriptions that answer the three questions a reviewer
  has before opening the diff — what problem, how it works, how to verify.
  Use when raising a pull request (`gh pr create`), or when invoked by
  `implementer` (or any other PR-creating skill) before it creates the PR.
  Overrides the Claude Code default `## Summary` / `## Test plan` template.
---

# Writing PR Descriptions

A PR description exists to answer three questions a reviewer has before they open the diff:

1. **What problem does this solve, and why does it matter?**
2. **How does the solution work — what changed in the design or architecture?**
3. **How do I verify it's correct?**

## What to cover

**Why this change exists.** Give the actual reason, and do not repeat what the ticket said. What was broken, missing or brittle? What would have happened without this fix?

**How the design or architecture changed.** What is the system doing now that it wasn't before? If a new component was introduced, what is its role? If responsibility moved between parts, say where and why. If a key trade-off was made, name it.

**Security or cost implications.** If the change touches auth, permissions, or data access — say so. Same for anything that moves the hosting bill: new scans over large tables, more frequent jobs, larger payloads, new external API calls.

**How to verify.** Concrete steps a human can take — specific enough that the reviewer knows what "working" looks like. Not "run the tests".

## Body template

```
## Why

<The problem and why it matters. What was wrong or missing? What breaks without this fix?>

## How it works

<What changed structurally or architecturally. What the system does now that it didn't before.
Key trade-offs if any. Omit if the change is purely mechanical.>

## What to review

<Optional. Where the load-bearing logic lives, what edge cases matter, what to pay attention to.>

## Security / cost

<Optional. Auth, permissions, data exposure, or running-cost implications. Omit if neither applies.>

## Test plan

- <Specific verifiable step>
```

## Title

- Plain language, under 70 characters.
- Prefix: `feat:`, `fix:`, `chore:`, `refactor:`. Scope in parens if useful: `feat(health-lab):`.
- Do not put the ticket ID in the title.

## Hard rules

- Describe the change; never the process that produced it. What the system now does and why we wanted it *is* the body's job — it is the context behind this change, and it is written for a reader who was not in the room. What has no place is the sequence of steps that got there. The test: **does any sentence describe a state that never reached the base branch?** A review round, a correction to your own earlier commit, an approach tried and abandoned, a plan or phase or tracer number — all describe states no reader will ever see. Corrections to the *world* are different and belong: a measurement that disproves what a source document claimed is a fact about the system, and survives.
- Never list files changed — that is what the diff is for.
- Never write "Modified X.py to do Y" — write what the system now does differently.
- Never pad with: "updated imports", "added type hints", "registered activity".
- Describe only the work that is *in this diff*. Do not use the body as a task tracker. Write no `Follow-ups`, `Future work`, `Next steps`, `Known issues`, `TODO` or `Deferred` section. No process drains a PR body, so work you park there evaporates, however many people read it.
- Deferred or not-yet-done work — anything you noticed but decided *not* to do here — goes to `/followup` (the central `followups/inbox/`, drained by `/triage`), never into the body. The only incidental a body may mention is an adjacent fix you actually made *in this diff*, disclosed so the reviewer sees the scope (implementer collects these under `## Incidentals`).
