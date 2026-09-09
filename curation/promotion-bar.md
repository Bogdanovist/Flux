# The Promotion Bar

The standard a proposed change to durable context must clear before a
curation pass surfaces it. Written to be applied identically on every
pass, so a proposal's fate does not depend on the mood of the sitting.

## What a proposal must demonstrate — the three-part case

1. **Evidence it is enough of a problem.** A real recurrence count from the
   ledger, or a single case whose impact is self-evidently high. The theme
   stated in words a reader who has not opened the ledger can judge —
   identifiers support a case, they never carry one.
2. **The specific minimal change.** The exact artefact and the exact edit,
   current text quoted against replacement. The move named: tighten an
   existing rule, replace a stale one, remove, or — last resort — append.
3. **The consumption path.** The mechanism that loads the artefact and the
   moment it bites. A change nothing reads in the loop where the failure
   happens does not change operations, however true it is.

## The gates — every one, before a proposal surfaces

- **Load-bearing.** Plausibly recurring or high-impact, non-obvious from
  reading the code, and not already covered by something existing.
- **Consumption.** Lands where real operation actually loads it: a skill a
  flow invokes, an AGENTS.md, a hook, a rules file. No consumption path →
  rejected, recorded.
- **Better fixed than documented.** A lesson narrating a workaround for a
  repairable defect proposes the fix, never the workaround as guidance —
  a workaround that works is the reason a defect survives.
- **The form ladder.** An enforcer (hook, lint, test, gate) beats a decision
  record, which beats rule prose. Prose is for genuinely working-style
  guidance only — how we work, not what the system must guarantee.
- **Placement.** The lowest level of the context hierarchy that can carry
  it: a repo's own rules before Flux; code before either.
- **Net-new-context restraint.** Every appended line loads into every
  future session in its scope, forever. An append must name why nothing
  existing could be tightened to hold the lesson instead.

## The defaults

A one-off, low-impact lesson is recorded in the evidence ledger and not
proposed — its count keeps accumulating for the pass where its next cousin
arrives. Killing a weak proposal is cheap and reversible; shipping one is
neither. The measure of a good pass is not proposals shipped but the state
of the guidance: small, current, consumed.
