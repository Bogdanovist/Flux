---
started: 2026-09-25
repos: voice-to-vibe
---

## Motivating Question

Can I drive a Claude Code session from my phone by voice alone, while I
drive a car, with no need to look at or touch the screen? If so, what is the
smallest harness that does it, and which platform carries it: mobile web or
a native app?

The harness must fit the way I already work. I want to talk to the same
sessions and repos I use at the desk, not to a separate tool with its own
copy of my setup.

## Why

Driving time is dead time for my evening-and-weekend projects. A voice loop
could turn it into review and steering time: hear what a session did, say
what to do next, approve or refuse a step. The cost of the status quo is
lost hours. The risk of a bad harness is worse than no harness: one that
makes me look at the phone, or approves an action I did not mean, is unsafe
at the wheel.

## Summary

No findings yet. The repo `Bogdanovist/voice-to-vibe` is empty (GitHub
reports `isEmpty: true`, created 2026-09-25) [OBSERVED].

## Questions to settle

Each question below is a thing the exploration must answer before a build
plan can fix it. None is decided.

1. **Where the phone connects to Claude Code.** The harness either drives
   an existing session, or it runs its own agent. Driving an existing
   session keeps my hooks, skills and permissions, and I can pick the
   session up at the desk later. Running its own agent is simpler to
   control, but it forks my setup. Candidates to test: Claude Code Remote
   Control and the Claude mobile app; the Claude Agent SDK behind a small
   server on the Mac; `claude -p --resume` per turn.
2. **Whether mobile web survives the car.** In the car the phone sits in a
   mount with the screen locked or asleep, and audio goes over Bluetooth.
   The exploration must measure whether a browser page keeps the microphone
   and speaker alive in that state on my phone. If it cannot, the platform
   question answers itself: native app.
3. **Speech in and speech out.** On-device speech recognition and synthesis
   cost nothing and work with poor signal. Cloud services are more accurate
   and sound better, and they add latency and a per-minute cost. Road noise
   and a car's Bluetooth microphone are the test conditions, not a quiet
   room.
4. **Turn-taking.** The harness must know when I have finished speaking,
   must not hear its own voice as mine, and must let me interrupt it. A
   long code change read aloud must stop when I say "stop".
5. **Making Claude Code's output speakable.** Diffs, file paths, tool calls
   and tables are unreadable aloud. Something must turn a turn's output into
   a short spoken summary. Candidates: an output style, a hook, or a cheap
   model that condenses each turn. The summary must still say plainly what
   changed and what is waiting on me.
6. **Approvals by voice.** Permission prompts need a spoken yes or no. A
   misheard "yes" on an irreversible step is the failure that matters most.
   The exploration must say which actions a voice approval may cover at
   all, and how the harness confirms what it heard.

## Findings

None yet.

## Out of scope

- Any build in `voice-to-vibe` before the questions above have answers and
  I have approved a plan.
- Visual interfaces for use while parked. The target is zero screen use.
- Other agents than Claude Code.
