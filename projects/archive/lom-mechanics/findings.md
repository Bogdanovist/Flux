---
started: 2026-09-25
repos: Lines-on-Maps
---

## Why

Lines On Maps started with three commitments (roguelite, turn-based, the
player is an actor in a crisis-bargaining dispute) and nothing else. Who the
player is, what a turn is, and how a run is won were all open. One concept sketch exists on paper
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

Findings go in this doc, one section per sketch: the idea, what Matt played,
what worked, what did not, and the verdict (keep, reshape, drop). A sketch that
earns a place becomes a concept file in `Lines-on-Maps/docs/concepts/`.

## Decisions

- **Sketches live on `main` behind a picker on the title screen** (Matt,
  2026-09-25). Switching between sketches takes one tap on the phone, which is
  what comparing them needs. The cost is accepted: `main` fills with throwaway
  code.
- **No foundations doc binds a sketch** (Matt, 2026-09-25). The early
  foundations and theory-to-mechanics mapping are legacy background in
  `Lines-on-Maps`. Each concept file records its own decisions.
- **Each sketch starts as a concept doc.** Matt and Claude agree the concept in
  `Lines-on-Maps/docs/concepts/` before any code for it is written.

## Out of scope

- The production stack and any native build.
- Roguelite structure across runs (procedural generation, meta-progression),
  unless a sketch needs a trace of it to feel right.
- Art, sound and polish.

## Sketches

### Concept 02: the emerging world

A map game of about a dozen fictional countries that start blank and take form
through roguelite draws: pick-one-of-three appointments to each government, and
developments such as oil discoveries or separatist movements. Crises and
alliances grow out of how the countries form.

Concept 02 (https://github.com/Bogdanovist/lines-on-maps/pull/3) records
Matt's decisions and the questions left open. Concept 03 forks it, settles
every open question with Claude's judgement, and is built as the first
playable sketch (https://github.com/Bogdanovist/lines-on-maps/pull/4).

Measured on the sketch's own simulation (90 seeded runs, 2026-09-25): a player
who only shores up support survives about half the runs, evenly across
democracy, kleptocracy and dictatorship; a player who does nothing survives
about one in ten. Whether that feels right in play is for Matt to judge.

Verdict: pending Matt's play.
