---
name: codebase-review
description: Review standing code — correctness, security, efficiency and accreted complexity — over a named repo, path or feature, with no diff in front of it. Escalates live defects immediately and hands the weekly pass a ranked batch carrying one proposal per finding. Reads only; approved fixes land as PRs.
user-invocable: true
argument-hint: "<repo | path | feature> under review"
---

# Codebase Review

A diff review looks at what changed, once, and either passes it or blocks it.
Standing code holds everything no diff review looked for: code that predates
the practice, a defect a reviewer read past, an invariant that two separately
correct changes broke between them, and the wrapper, the flag and the fourth
abstraction that each arrived reviewably and accreted into something nobody
would write on purpose.

This pass reads the code itself. Run one over a subject you are about to work
in. Escalate live defects in the same session, and send everything else to the
next weekly pass, beside `context-sweep`'s batch.

## The subject

Name the subject at invocation: a repo, a directory or subsystem path, or a
feature. `features/<feature>/index.md` lists the repos a feature's code spans.
If nobody named a subject, ask the invoker. Keep the subject small: a pass over
five repos returns more findings than one sitting can disposition, and it
returns the same ones again the week after.

Bring every checkout in the subject up to date before you read anything.
`context-sweep` carries the fetch-and-fast-forward procedure, and the rule that
a refused fast-forward is itself a finding. Record the verified-at SHA for each
repo in the batch header. If a batch cannot say which commit it read, nobody
can re-adjudicate it.

## The dimensions

Use `reviewing-diff`'s dimensions, and read them against standing code instead
of a diff. Run one read-only agent per dimension, in parallel. Use
`codebase-researcher` where the dimension needs comprehension, and a search
agent where it needs coverage. Ground every claim about live behaviour in
`gathering-runtime-evidence-*`; reading the code alone is not enough.

- **Correctness** — logic wrong on a path nothing exercises, an invariant
  broken by the interaction of two changes that each held, a caller never
  updated when its callee's meaning changed, an error path that swallows,
  boundary data nobody validates. If non-trivial logic has no runnable check
  behind it, record that as a correctness finding on its own. The missing
  check is what would have caught everything else.
- **Security** — a credential in the tree, an unauthenticated surface, data
  exposed in logs or responses, a sidestep of the repo's established
  pattern. Rate a live credential CRITICAL at minimum, and open its proposal
  with rotation. Git history is distributed, so deleting the file does not
  unpublish the secret.
- **Efficiency** — redundant work, N+1 patterns across a whole flow,
  unbounded structures, hot-path bloat. A diff cannot show you whole-flow
  scale.
- **Complexity** — the ladder below. Reuse findings live there as `reuse:`.

## The complexity ladder

Ask down the ladder. The first rung that holds is the tag.

- **`delete:`** does it need to exist at all — dead code, a flag nothing
  sets, flexibility nothing uses, a feature nobody asked for. Replacement:
  nothing.
- **`reuse:`** does this codebase already have it — a helper, a type, a
  pattern a few files over. Name the one that exists.
- **`stdlib:`** does the standard library ship it. Name the function.
- **`native:`** does the platform already do it — a built-in test over a
  bespoke check, an engine function over a hand-written one, a database
  constraint over application code, a hosting feature over a hand-rolled
  one. Name the feature.
- **`yagni:`** one implementation behind the interface, one product from the
  factory, one caller through the layer, a config value no environment sets.
  Inline it until the second arrives.
- **`shrink:`** same behaviour, materially fewer lines. Show the shorter
  form.

You find these in the same places every time: dependencies the stdlib or the
platform already ships, dependencies with a single call site, wrappers that
only delegate, a PostHog flag whose rollout finished and whose gate stayed in,
and one piece of logic standing in two repos.

## What every finding carries

- **Location** — the repo and `path:Lstart-Lend`.
- **The evidence** — what was actually run and what it returned: the failing
  test, the query, the log line, the grep. Code that surprises you is often
  correct for reasons you do not have. If you cannot verify a finding, flag it
  for a human on `followup`'s evidence bar, and never assert that it is
  broken.
- **The proposal** — one line: what changes, and what stands in its place.
- **The size, for a complexity finding** — lines, files and dependencies
  removed. Complexity findings rank by it.
- **The caller search, for a cut** — when you cut something, you make a claim
  about every caller, and that claim holds only inside the repo you searched.
  Both analytics and datascience import hestia, so a grep inside one of them
  tells you nothing about the other.

## Severity decides the latency

Every finding carries `CRITICAL`, `SIGNIFICANT`, `MODERATE` or `MINOR`, on
`reviewing-diff`'s scale.

- **CRITICAL and SIGNIFICANT leave the session they were found in.** Name
  each one to the user with its evidence, now, and route it through
  `followup`. The batch names each one in a line and says where it went. A
  weekly sitting is too slow for a live defect.
- **MODERATE, MINOR and every complexity finding go to the batch**, for the
  weekly pass to disposition.

Two floors. Rate a live credential CRITICAL. Rate SIGNIFICANT any consumer
that re-implements logic a shared library already ships: that duplication is
silent, and the two copies diverge without either side failing.

## What is never a cut

- Validation at a trust boundary, error handling that prevents data loss, and
  auth and secret handling. Record a finding when these are missing. Never
  record one when they are present.
- Tests. Record a missing check as a correctness finding. Never cut a check
  that exists.
- Duplication that holds train/serve parity. hestia is the single-source home
  for it, so the finding in that shape is the reverse one named above.
- A constant that exists to be tuned — a threshold, a lookback window, a
  rate. Check whether it has ever been changed before calling it dead
  config.

## Cluster before proposing

Treat twelve rows of one shape as one finding. Name the pattern, and propose
the single change that ends it: the shared helper, the missing enforcer, or
the deletion of whatever the copies came from. If the pattern says something
about how we work, and not about this code, capture it with `/learn` and let
`curate` route it.

## Output

`curation/code-review-<subject>-<date>.md`, in the shape of a sweep batch:
the subject and its verified-at SHAs, what was read, the escalations and
where they went, then the findings — defects first by severity, then
complexity findings by size of cut — each carrying one proposal. The header
closes with the total cut available: `-<N> lines, -<M> dependencies`. If a
pass finds nothing, report that too, along with what you read to reach it.

Ledger entries land in `curation/code-review-ledger.md` on `context-sweep`'s
ledger protocol. Diff the pass against the ledger, send only new and changed
findings to the weekly pass, and give every finding one of `deferred`,
`wont-fix` or `actioned` on the way out. This is a second ledger because a
code finding stays true until the code changes, while a rot finding dies with
its subject. The two machines share the pass.

Raise each ratified fix as a PR to the repo it touches, under that repo's own
rules. Give datascience and hestia datascience-level care, reviewed on the
diff. This pass reads and proposes. It applies nothing.

## Boundary

`reviewing-diff` reviews one change on its PR, against the intent that change
was built to serve. `review-solution-design` reviews a design before it is
code. `context-sweep` reads prose and rules for rot, so send a stale comment
or a rule the code contradicts to that ledger, and do not open a second row
here. This pass reads the code standing in front of you, whether or not a diff
review ever saw it.
