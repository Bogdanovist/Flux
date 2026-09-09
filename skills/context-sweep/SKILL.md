---
name: context-sweep
description: Sweep the repos you name for context rot — stale claims, misplaced content, uncited bloat — diff the findings against the sweep ledger, and hand the weekly pass a batch of new-or-changed items with a proposal each.
user-invocable: true
---

# Context Sweep

Verify-at-cite checks the context somebody cites. This sweep hunts the context
nobody cites, which is exactly the context that rots.

Run it weekly over Flux and the project repos the caller names. With no
repos named, take the `repos:` line of every live doc under `projects/`, plus
Flux itself, and say which list you swept — a sweep whose scope nobody can
name cannot be re-run against the same ground. The sweep only reads, and it
only proposes. Land approved changes as commits or PRs afterwards, and never
as silent edits.

## Before anything reads

A sweep tests context against the current code, so a stale checkout compares
against the wrong side, and looks current while it does. `git status` reports a
clean tree against remote refs that may be weeks old.

The conductor runs this preflight before it spawns any repo agent. The agents
themselves stay strictly read-only.

1. Fetch every in-scope checkout. Resolve each repo's actual directory and
   default branch, and do not assume either. A checkout's name can differ in
   case from the repo's name, and not every repo defaults to `main`.
2. Fast-forward each checkout to its remote default branch. This is the one
   change the sweep makes, and it only moves a checkout to commits that are
   already on origin. If git refuses the fast-forward, because of local edits
   or divergence, record that as a checkout-hygiene finding for the batch.
   Leave the working tree alone, and sweep that repo from origin's HEAD
   instead, in a detached worktree you remove when the sweep ends.
3. Record the verified-at commit for each repo in the batch header. If a batch
   cannot say which SHA it checked, nobody can re-adjudicate it.

## What it reads, per repo

Read the repo's AGENTS.md and CLAUDE.md and its rules files, its skills, and
its code comments wherever they make a checkable claim. In Flux, also read
the feature indexes, the decision records, and every working doc under
`projects/`. Run one read-only agent per repo, in parallel. Each one returns
findings in the four classes below, with evidence.

## The four finding classes

- **stale** — context contradicting the current code: a comment naming a
  function that moved, a rules line about a table that changed shape, a
  record whose re-verify command fails, a `Currently:` pointer that no
  longer resolves. Evidence: the claim, the command run, what it returned.
- **misplaced** — content sitting at the wrong level of the hierarchy:
  AGENTS.md prose that belongs in a skill, a Flux record that could now be
  a code comment, a record that has gained an enforcer and should absorb into
  it, or a working doc missing its header contract.
- **bloat / uncited** — near-duplicate rules, a section nobody has needed, and
  records nothing has cited in a long time. These are your kill candidates,
  and killing them is the cheapest fix in the whole system.
- **dormant** — a working doc in `projects/` that reads as live work when no
  work is in flight. `open-project` names the harm: the next agent reads a
  plan on `main` as settled and in flight, and builds on it. Evidence: the
  last commit under `projects/<slug>/` with its date and subject, what the
  doc says happens next, and what the repos show against that.

## Judging a dormant project

Two weeks with no commit under `projects/<slug>/` is the trigger to look. It
settles nothing on its own. Every edit to a project doc pushes straight to
`main`, so an idle directory means idle work, and not work held on a branch. A
fresh commit proves no more, because a rename or a sweep fix touches a dead
doc without advancing it.

Reach the verdict from the whole picture:

- **The doc.** It states what happens next. Did that happen?
- **The work.** Check the repos in the doc's `repos:` line for the branches,
  PRs and code it promised. Shipped work under an open doc is a project that
  needs closing.
- **A successor.** A newer doc, record or feature index covering the same
  ground supersedes this one.

Idle and live is a real state: the work waits on an upstream release, on a
deploy you have to run by hand, or on a decision you have not made. Name what
it waits on, and give the ledger entry that as its revisit trigger.

Propose one of three. **close** — the work finished, so run `close-project`
and work the promotion gate. **abandon** — the work stopped, or something else
covers it, so run `close-project`'s abandon path with the reason and the
successor. **live** — something moves it, and the evidence says what.

The user decides. Put the proposal to them with its evidence, and never close
or abandon a project on your own reading.

## The ledger protocol

`curation/sweep-ledger.md` is the memory that keeps weekly sweeps from
re-raising the same bodies:

1. Diff this week's findings against the ledger. Only **new** findings and
   **changed** ones (evidence moved, a revisit trigger fired, the subject
   vanished) reach the pass.
2. Every finding present at a pass leaves it with a disposition:
   `deferred` (with a revisit trigger — a date or a condition), `wont-fix`
   (with the one-line reason), or `actioned` (with the PR). Suppression
   without a disposition is how bodies vanish undecided.
3. Each pass re-checks existing entries against the repo it is already
   reading and drops entries whose subject is gone.

Skill-usage rollups are standing evidence for the bloat class.
`curation/telemetry/skill-usage/` holds one JSON file per machine: per-skill
load counts and last-used timestamps, refreshed weekly from that machine's
local log by `scripts/rollup-skill-usage.sh`. Read every file present before
you class a skill as bloat, and cite each file's `generated_at` in the
finding's evidence. Coverage is per-machine and partial — a machine that never
synced leaves no file — so zero recorded uses across every rollup supports a
kill proposal and does not decide one.

## Output

A digestible batch for the weekly pass: per finding — repo, location, class,
evidence, and a one-line proposal (the fix, the move down the hierarchy, or
the kill). Approved fixes become PRs to the affected repos, reviewed by their
normal rules; Flux-side kills and absorptions land with the pass's own commit.
Week one will be noisy; that is the picture of where everything is buried, and
the ledger makes week two quiet.
