---
name: solution-design
description: Design a project end-to-end into its spine doc — the heavyweight form of the working doc, for work whose risk sits in facts about existing systems or in many consumers and seams. Use at project open when `open-project` advises escalation, and for every refine pass.
argument-hint: "<project-name>"
---

# Solution Design

Produces `<repo>/context/projects/<name>/solution-design.md` — a working doc
grown heavyweight, carrying the same header contract as any plan
(`started:`) and committed to `main` in the repo's main checkout like any
other project doc. One
spine doc per project, edited in place; git history is the audit log. The spine supersedes and replaces `plan.md`: fold what the plan
still needs into the spine, and delete `plan.md` in the same change. A
project carries one working doc.

## Calibrate the depth first

Two questions: how much of the risk is facts about the existing system, and
how many consumers and seams does the change touch? Low on both → a plan
doc via `open-project` is the whole artefact and this skill stops there.
High on either → the spine below. Say which and why; the user can override.

**Name what you drop.** A project may adapt this discipline (a meta-project
with no code, a pure-data project with no migration), but the calibration
section must enumerate the dropped disciplines against this skill's full
list — an unnamed discipline drops silently, and the silence reads as
oversight at review.

## The spine

Content discipline, not a template — but these obligations all get an
answer, and an empty one is recorded as empty rather than padded:

1. **Narrative** — why (the problem, who feels it, what the status quo
   costs); how the system operates now, dated, with every current-state
   claim checked against observation; how it operates after; one flow
   followed end-to-end through the target state. Cold readers reconstruct
   the operating model from whatever exists — give them the model, or they
   assemble it wrongly from assertion fragments and reviews burn on
   reconstruction errors.
2. **Danger list** — `D1…Dn`, front-matter. Each entry leads with the
   requirement that must hold, then the foreseeable risk, then the pointer
   to the canonical statement. The bar: a violation would be silent and
   total. IDs are stable; leave gaps when one dies. One axis per entry.
3. **Design pressures** — why this shape, with evidence.
4. **Target design** — the shape and every contract that must be pre-agreed:
   what two implementers on different slices need pre-made to converge.
   One target-shape block per artefact (```lang target=<artefact>```) —
   the complete schema or signature set, stated once, that everything else
   references. **Stop and confirm before writing any contract**: a data
   model, an interface, an API shape, a persistence decision, a
   performance target, a migration strategy. Writing it settles it — a
   later agent reads it pre-blessed.
5. **Migration mechanics** — one rollback label per state (`reversible —
   precondition: <what must hold>` or `forward-only`); ordering as a
   numbered sequence; what goes dark during any pause; every knowable
   expected effect as an abort condition.
6. **Assertions** — the register, in the §Field forms below, stable
   IDs never renumbered. Each names its scope in contract vocabulary, its
   rule flat enough to execute cold, and what a check returns when the
   claim is false — a check that cannot fail proves nothing. Slices cite
   IDs; coverage becomes checkable instead of argued.
7. **Test policy** — the levels that exist and what each is for; what must
   have a test, what is deliberately untested and why; what happens to
   pre-existing tests in the area. Confirmed before writing, like any
   contract.
8. **Open questions** — what reasoning cannot settle, what would resolve
   each, and which design statements are `*Provisional on:*` it, marked at
   the point of use so nothing builds past an unresolved dependency.
9. **Reading order** — an implementer reads the spine top through the
   danger list, then their slice's spec, then exactly what it cites.

## Field forms

### Register entries

A register entry records one settled design decision, so that a future agent
does not decide it again. Write a Name and up to five fields, in this order.
So what and Test are optional. Leave out a field you are not using; never leave
one blank.

- **Name** — compress the Rule into one line. Name the subject, and say what
  holds for it. Reuse the Rule's own words. If the name still reads well after
  you delete the Rule, you have written an aphorism; rewrite it.
- **Scope** — name what the rule binds, using the agreed term. Use a glossary
  term for a component, or contract vocabulary for data: a table, a model, a
  column set. Do not say where the code lives. That belongs in the glossary
  entry's *Currently* line.
- **Rule** — state the invariant in one or two plain sentences. Put the
  positive statement first. Add a negative clause only when you can test it.
  Use contract vocabulary: tables, columns, keys, severities, channels,
  glossary terms. Do not use file paths or function names, because someone will
  refactor the code while the rule still holds.
- **So what** — say what the rule closes off: which action it now makes
  unnecessary, or puts out of bounds. This is the line that stops a future
  agent reopening the decision.
- **Test** — give the case that tells right from wrong: what you would observe
  when an implementation is wrong. Do not name fixtures, stubs or frameworks.
  The tracer spec that cites this entry carries the concrete test. Leave Test
  out when the Rule already says what you would observe.
- **Found** — record the observation that made the rule necessary. Give the
  date, what you measured, what it showed, and what it forced you to decide.
  Put the wrong state and the rejected alternative here, as history.

### Glossary entries

Every rule needs a subject that lasts. It must exist at design time, before
anyone writes code, and it must survive every refactor. Put that subject in
the glossary in the repo's `context/index.md`, in the form `records` §The
repo index gives.

`prose-checks.md`, beside this skill, shows how to catch the six habits
`AGENTS.md` names, and works one rewrite in full. Read it if you are meeting
these forms for the first time.

## The standing rules

- **State once, reference everywhere.** One canonical statement per fact;
  deliberate copies live only in the danger list, marked. A claim
  quantified over a set writes the set out, with the command that
  regenerates it.
- **Facts carry their checks.** Every claim about live state carries its
  re-verify command at the point of use; archive-sourced claims carry file
  pointers. Ground live-behaviour claims in observation, not recall.
- **Records are cited, never restated** — `records` owns the format and
  verify-at-cite; a cited record gets checked this pass, every pass.
- **Supersession repeals decisions, never findings.** Superseding an
  artefact means routing its recorded facts forward as inputs; deleting
  them re-discovers them at full price.
- **The repo layer stays thin** — `context/index.md` (purpose, glossary,
  record list) plus `decisions/` and `facts/`. No standing narrative docs; when a pass needs the current-state story, generate it
  from code and cited records, use it, discard it.

## Close and refine

Close by naming the records minted, confirmed, narrowed or overturned, then
hand to `review-solution-design` before decomposition. Refine passes absorb
what shipped slices taught — observed facts outrank design assumptions —
resolve the affected provisional markers, and edit forward: the doc is the
current shape, not the archaeology.
