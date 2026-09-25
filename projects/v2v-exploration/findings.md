---
started: 2026-09-25
repos: voice-to-vibe
---

## Motivating Question

Can I steer a Claude Code session by voice alone, hands-free and eyes-free,
from an Android phone over Bluetooth audio? If so, what is the smallest
harness that does it, and which platform carries it: mobile web or a native
app?

The harness must fit the way I already work. It steers the same sessions I
use at the desk, with my hooks, skills and permissions intact.

## Why

Time in the car, or at the washing with Bluetooth headphones on, is dead time
for my evening-and-weekend projects. A voice loop could turn it into review
and steering time: hear what a session did, say what to do next, approve or
refuse a step. A harness that makes me look at the phone, or acts on a
misheard word, is unsafe at the wheel and worse than no harness.

## Constraints (Matt, 2026-09-25)

- **C1 — Android, plain Bluetooth.** The target is my Android phone with any
  Bluetooth headset or car audio. Nothing ties the harness to CarPlay,
  Android Auto or a car. The car is the motivating case, and the washing
  with headphones on is an equal one.
- **C2 — Setup on screen, then voice only.** I set up each use on the
  screen: I pick the project or session and start voice mode. From then on
  the harness needs no touch and no look.
- **C3 — Existing sessions are enough.** Steering a session that already
  runs, on my Mac through Remote Control or in the cloud, meets the need.
  The exploration still reports what the harness would gain by running its
  own sessions, so I can judge the difference.
- **C4 — Full parity with the keyboard.** Voice must reach everything I can
  do with hands and eyes, approvals included. An extra, explicit spoken
  confirmation may guard risky steps. How that confirmation works is an
  open question (Q6).
- **C5 — Personal first.** The harness is for me. A commercial app is a
  possibility if it works, and it does not shape choices now.

## Summary

No findings yet. The repo `Bogdanovist/voice-to-vibe` is empty (GitHub
reports `isEmpty: true`, created 2026-09-25) [OBSERVED].

## Questions to settle

Each question below is a thing the exploration must answer before a build
plan can fix it. None is decided.

1. **Where the phone connects to Claude Code.** Candidates: Claude Code
   Remote Control and the Claude Android app; the Claude Agent SDK behind a
   small server on the Mac; `claude -p --resume` per turn. For each, the
   exploration reports what the harness can read (each turn's output,
   permission prompts) and what it can send (a prompt, an approval, an
   interrupt).
2. **Whether mobile web survives a locked screen.** With the screen off and
   audio on Bluetooth, does a browser page on Android keep the microphone
   and speaker alive? If it cannot, the answer is a native app.
3. **Speech in and speech out.** On-device recognition and synthesis cost
   nothing and work with poor signal. Cloud services are more accurate and
   sound better, and add latency and a per-minute cost. The test conditions
   are road noise, a washing machine, and a Bluetooth headset microphone.
4. **Turn-taking.** The harness must know when I have finished speaking,
   must not hear its own voice as mine, and must let me interrupt it. A
   long read-out must stop when I say "stop".
5. **Making Claude Code's output speakable.** Diffs, file paths, tool calls
   and tables are unreadable aloud. Something must turn a turn's output into
   a short spoken summary that still says plainly what changed and what
   waits on me. Candidates: an output style, a hook, or a cheap model that
   condenses each turn. Parity (C4) also needs a way to ask for detail: "read
   me the diff for that file".
6. **Approvals by voice.** Permission prompts need a spoken answer. A
   misheard "yes" on an irreversible step is the failure that matters most.
   The exploration proposes how the harness confirms what it heard, and
   which steps take the extra confirmation.

## Findings

None yet.

## Out of scope

- Any build in `voice-to-vibe` before the questions above have answers and
  I have approved a plan.
- iOS, and car-specific integrations (CarPlay, Android Auto).
- Other agents than Claude Code.
