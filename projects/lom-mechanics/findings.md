---
started: 2026-09-25
repos: Lines-on-Maps
---

## Why

Lines On Maps has three settled commitments (roguelite, turn-based, the player
is an actor in a crisis-bargaining dispute) and nothing else. Who the player
is, what a turn is, and how a run is won are all open
(`Lines-on-Maps/docs/foundations.md`). One concept sketch exists on paper
(`docs/concepts/concept-01-cabinet-desk.md`). No mechanic has been played.

Paper concepts cannot answer the question that matters: is this fun to play,
and does the theory come through as felt rather than shown? Only a playable
sketch on the phone answers that. The phone preview works as of 2026-09-25
(archived project `lom-mvp`), so a sketch can reach Matt within seconds of an
edit.

## Approach

Build several small, crude, playable sketches of different core mechanics, one
at a time. Matt plays each on the phone, reacts, and the sketch is reshaped or
dropped. Each sketch tests one idea about what the player does each turn. It
carries only enough game around that idea to feel it: placeholder visuals,
hard-coded scenarios, no persistence, no roguelite meta-layer.

Each sketch is judged against the design values and anti-patterns in
`foundations.md`, above all: no visible bargaining range, probability dials or
numeric resolve.

Findings go in this doc, one section per sketch: the idea, what Matt played,
what worked, what did not, and the verdict (keep, reshape, drop). A sketch that
earns a place becomes a concept file in `Lines-on-Maps/docs/concepts/`.
Nothing is promoted into `foundations.md` without Matt's explicit say.

## Open questions before the first sketch

- **How sketches live in the repo.** Either one branch and PR per sketch,
  with the phone showing whichever branch the dev server runs; or all sketches
  on `main` behind a picker on the title screen, so Matt can switch between
  them and compare. The first keeps `main` clean but makes side-by-side
  comparison need a branch switch. The second makes comparison one tap, and
  `main` fills with throwaway code.
- **Which mechanics to try first.** Matt names them, or picks from a short list
  of candidates Claude proposes.

## Out of scope

- The production stack and any native build.
- Roguelite structure across runs (procedural generation, meta-progression),
  unless a sketch needs a trace of it to feel right.
- Art, sound and polish.

## Sketches

None yet.
