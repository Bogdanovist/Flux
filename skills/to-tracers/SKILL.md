---
name: to-tracers
description: Decompose a reviewed spine doc into implementer-ready tracer specs that cite the design's identifiers rather than restating its reasoning — probes for the open questions first, then the fewest reviewable slices, with an index, coverage manifest and runbook. Required argument: <project-name>.
argument-hint: "<project-name>"
---

# To Tracers

Turn a reviewed design into a sequence of tracers, and flesh each one out
until an implementer can build it. `shape-tracers` defines what a tracer is
and how big it should be. Cite that skill, and do not restate it. Confirm
first that the design passed `review-solution-design`. If the user wants to
proceed without that gate, that is their call.

Output: `projects/<name>/tracers/<slug>.md`, one file per tracer, plus
`projects/<name>/tracers.md` — the index, coverage manifest and runbook.

## The spec — cite, don't restate

If you copy design reasoning into a spec, the two drift apart at the design's
next revision, and the more prose you copy the further they drift. Keep the
rationale in the design alone. In the spec, write what an implementer needs in
order to *act*, plus identifiers for everything the slice must *honour*:

- **Slug, kind** — a probe names the design question it resolves and what
  evidence closes it.
- **Goal + danger** — one paragraph: the behaviour-facing slice, and the
  one worst thing a plausible implementation could silently get wrong,
  citing the danger ID where one applies.
- **Acceptance criteria** — verifiable bullets. Cite assertion IDs for
  design-level behaviour, and state slice-local criteria in full. Include the
  negative assertions.
- **Scope** in/out; **prerequisites** by slug.
- **Likely files/areas**, each repo-qualified — name the upstream writer
  and any scheduler touching the same data, not only the implementing repo.
- **Provenance** — 3–5 entries, each one fact with the repo-qualified path
  that enforces it and the command that re-verifies it. Apply the
  evidence-layer rule here. Keep measured facts the *design* depends on in the
  spine, and cite them downward. Put only slice-scoped facts in provenance.
  Citations point the same way authority does.
- **Read exactly** — the slice's complete reading list: spine top through
  the danger list, each cited assertion at its heading, sibling sections
  by name, and records only where the slice depends on one. An implementer
  must be able to build the slice from this list alone.

## The index, manifest and runbook

**Index** — one row per tracer: slug, kind, prerequisites, status
(`pending` / `in-progress` / `shipped <PR>` / `superseded`), in dependency
order. `implementer` flips status at ship.

**Coverage manifest** — one row per design commitment: every assertion,
danger, target-shape artefact, migration state and human step → the slug
delivering it, or an explicit `not delivered — <why>`. This table exists to
catch one defect that is otherwise invisible: a design decision that no slice
delivers.

**Runbook** — one row per step a person performs, grouped by the slice it
gates: step, actor, where, proves-it-worked, abort. Most of the steps an agent
cannot take are the irreversible ones. A slice is done when its runbook rows
are done. Merging its PR does not finish it.

The index in the spine tracks slice state. Keep the specs in git beside it,
and keep no second copy of that state anywhere else.

## Sequencing

Test each design open question against the probe definition. Do not inherit
the label the design gave it. If you can close a question by reading existing
code or data, that is research you do at decomposition time: do it now, record
the answer, and create no slice.

Put the genuine probes first, and put everything their answers shape behind
them. After that, start from one slice. Every boundary you add must earn its
place, either by resolving an uncertainty or by keeping a slice small enough
to review. If a boundary lines up with a structure the design already has — a
component, a layer, a migration state — it organises the design rather than
the learning. Suspect it by default.

Before you write any file, present the decomposition from first principles:
what is genuinely new, why this many slices, and why these boundaries. Then
grill on it. The implementer decides PR groupings, so keep them out of the
specs.

## Re-invocation

Invoke this skill again to add, re-sequence or reshape slices. One standing
trigger also calls it: a shipped tracer whose `Re-cut:` line reads `pending`
and names facts observed against the real system. Absorb those facts through
the design's refine pass, reshape the affected slices, update the manifest,
then close the line with what changed.

Amend only slices nobody has started. A shipped spec is history. If you edit
it to match what was built, you erase the evidence the re-cut depends on.
