---
name: shape-tracers
description: Shape a piece of work into end-to-end slices sized by the uncertainty each must resolve — thin probes against a design's open questions, then the largest reviewable slices once those close. Usable standalone or composed by to-tracers per candidate slice.
argument-hint: "<context — feature name, file path, or freeform description>"
---

# Shape Tracers

## What a tracer is

A tracer is a slice that satisfies all five of these:

- **It lands end-to-end in production code.** It runs the next time anyone
  exercises the feature. It is not a sketch.
- **It exercises a real path through the target architecture.** A module is
  wired, a flow fires, or a capability becomes reachable.
- **It produces an observable signal**: a behaviour change, new
  instrumentation, a data flow, or a test that did not exist before.
- **It ships on its own** and leaves the system valid. Cross-seam work ships
  as one coordinated rollout, with one PR per repo. See below.
- **It leaves the codebase better.** It closes debt and opens none.

If a candidate fails one of the five, reshape it. Split it if it was really
two. Deepen it if it touched only one layer, and push the path through.
Reclassify it if it opens no new path, and raise a plain refactor PR
instead.

## Size by uncertainty, not smallness

Aim a **probe** at one open question the design says reasoning cannot settle:
a query plan under real volume, or a seam nothing exercises. Make the probe as
thin as a working end-to-end thread allows. Everything you build past the
answer is speculation you will rework. Feed its finding back into the design.

Write **builds** after the unknowns close. Make each one the largest coherent
slice a reviewer can still read in one sitting. The overhead per slice is
fixed and substantial, and a large slice costs an implementer little extra, so
many small confident slices mostly buy you ceremony. A design with no open
questions can be a single slice.

A slice is too big when a reviewer can no longer read it in one sitting, or
when it bundles an unresolved unknown together with work that depends on the
answer. In the second case, split the unknown out as a probe. Migration states
are rollback boundaries. Do not use them as slice boundaries.

## Not a tracer

None of these is a tracer:

- A rename that opens no new path. That is a plain refactor.
- A module you added but did not wire. It does not land end-to-end.
- Frontend now, backend later. That splits one capability by layer, and
  neither half produces the signal.
- A hack to unblock, plus a cleanup later. It opens debt.

When work spans an async seam, such as CDC or a producer and consumer split
across repos, keep the capability in one tracer and ship it as a coordinated
rollout. The cross-seam contract is the thing that has to match, and you gain
by specifying both sides of it in one place. Keep distinct capabilities with
distinct signals in distinct tracers, even when they share tables.

## The brief

One per tracer, about a page: slug; kind (`probe` names its question);
a behaviour-facing description; the architectural target (citing the
feature debt or record where one exists); the observable signal, one
sentence; scope in/out; prerequisite slugs. The brief commits to shape —
flows, file pointers and verification belong in `to-tracers`' spec.

Briefs live in `projects/<name>/tracers/` (or the feature dir when no
project exists; emit to chat when neither is named). Propose the slices and
read the briefs back before writing — slice boundaries, "one tracer or
three", and what counts as the signal are grilling territory, and the user
cuts.
