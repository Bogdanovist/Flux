---
name: reviewing-diff
description: Review a PR's diff after the PR exists — focused review dimensions, verified findings with severity tags, everything written as PR comments anchored to the lines they concern. Use on your own PR before you merge it.
argument-hint: "pr:<number> tier:<mid|best> spec:<path,...> agents:<subset>"
---

# Reviewing a Diff

Run this pass against an open PR. Post each finding as a PR comment anchored
to its diff line, so the finding sits beside the code it judges and a commit
answers it. Close the pass with one summary comment carrying the verdict.

A review nobody can read next month did not happen. Write no local verdict
files, and give no chat-only reports.

## Approval before the run

This pass dispatches one agent per dimension across the PR's full diff, so the
cost grows with the diff and the tier. The human decides whether that is worth
paying on this PR, because they hold what settles it: how large the diff is,
how much of it they have already read, and whether the risk sits where these
dimensions look.

Ask before you dispatch. Name the PR, the dimensions you would run, the tier,
and the size of the diff. Then wait. Get approval for each run separately. An
approval on one PR does not carry to the next, and a standing instruction does
not replace it.

## Arguments

- **`pr`** — the PR number. It defaults to the current branch's PR
  (`gh pr view`). Review the PR's full diff against its base. A remediation
  round reviews that same full diff again, and never a shrunken one.
- **`tier`** — `mid` (default) or `best`. Every dispatched agent inherits it.
- **`spec`** — the path or paths to what the change was built against: the
  plan doc, the tracer spec, the design. Pass each one in full to every
  review agent, so that the reviewer holds the context the implementer held.
  If there is no spec, take the intent from the PR description and the commit
  messages.
- **`agents`** — a subset of `correctness,reuse,quality,efficiency,security`,
  for a re-review matched to a remediation. A first review runs all five.

## The dimensions

Dispatch the selected agents in parallel, each with the diff, the PR
metadata, and the spec text:

1. **Correctness** — logic errors, unhandled edge cases, error-handling
   gaps, race conditions, intent-vs-implementation divergence, unvalidated
   boundary data.
2. **Reuse** — newly written code that duplicates an existing helper;
   inline logic an existing utility already covers.
3. **Quality** — redundant state, parameter sprawl, copy-paste variants,
   leaky abstractions, stringly-typed code, unnamed complexity — and
   plan-narrative residue (`# Phase 1`, `# for now`, `# rest comes later`),
   which misleads future readers and floors at significant severity.
4. **Efficiency** — redundant work, N+1 patterns, missed concurrency,
   hot-path bloat, unbounded structures.
5. **Security** — hardcoded credentials, missing auth on new surfaces, data
   exposure in logs and responses, sidesteps of the repo's established
   security patterns.

**Verify before you flag.** Put a finding in the output only after Grep or
Read has confirmed it exists in the actual diff. If you cannot confirm an
issue, either state it as an assumption or drop it.

A search proves absence only inside the repository you ran it in. An invariant
enforced in a sibling repo reads as unenforced from here. So before you claim
that nothing enforces something, name the repo you searched.

## Output — onto the PR

- One comment per finding, anchored to the diff line, tagged
  `CRITICAL` (blocks merge) / `SIGNIFICANT` (fix before merge) /
  `MODERATE` (follow-up acceptable) / `MINOR` (nit).
- One summary comment: verdict (`PASS` — no actionable concerns; `WARN` —
  moderate/minor only; `BLOCK` — any critical or significant), a one-line
  read of the diff, test-quality classification (behavioural /
  implementation / insufficient / none, and whether tests exercise real
  data paths), and what was checked and found clean.
- Comment only. Never approve, and never request changes. A human approves and
  a human merges, and downstream branch protection enforces that.

## Lessons

If you find a pattern worth carrying beyond this diff, file it with `/learn`,
and file at most three. The weekly curation routes them. Finding no lesson is
normal, and files nothing.
