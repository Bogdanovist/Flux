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

Q2 has a provisional answer: a native Android app, not mobile web. A
browser page cannot keep the microphone alive with the screen off, and
Chrome's continuous speech recognition stops after a few seconds of
silence. An Expo app with a microphone foreground service is the lightest
native path. A test on my phone confirms or overturns this. Q1 research
is still running.

The repo `Bogdanovist/voice-to-vibe` is empty (GitHub
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

Tags: [OBSERVED] means I read or ran it this session. [REPORTED] means a
research agent cited it on 2026-09-25 and I have not re-checked the source.

### Q2 — mobile web against native (researched 2026-09-25)

- **A web page cannot hold a screen wake lock in the background.** The
  browser releases the lock when the document is not active or not
  visible (MDN, Screen Wake Lock API) [OBSERVED]. So the page cannot keep
  itself awake with the screen locked.
- **Chrome throttles and freezes hidden tabs.** Timers run at most once a
  minute after five minutes hidden, and Energy Saver freezes busy
  background tabs from Chrome 133 (developer.chrome.com blog posts on
  timer throttling and freezing) [REPORTED].
- **Continuous speech recognition is broken on Chrome for Android.**
  `continuous: true` still stops after about 3–4 s of silence (Chromium
  issue 40324711). Chrome's Web Speech API also sends audio to Google's
  servers, so it needs signal [REPORTED].
- **`speechSynthesis` on Android has no true pause.** `pause()` acts as
  `cancel()`, and long utterances stall (Chromium issue 374263394)
  [REPORTED].
- **Screen-off microphone capture dies in Chrome for Android.** People
  report the WebRTC microphone track stops soon after the screen locks.
  No Chromium bug pins the cause [REPORTED].

**A native app must start its microphone service while it is on screen.**
From Android 14 the microphone is a while-in-use permission. A
microphone-type foreground service started from the background throws a
`SecurityException`. The app must start it while an activity is visible,
or from a notification or widget tap (developer.android.com, restrictions
on background starts) [OBSERVED]. C2 fits this rule: the setup step on the
screen starts the service, and it runs until voice mode ends. A
notification tap can restart it.

Native audio pieces the research names, all [REPORTED]:

- **Bluetooth microphone:** `AudioManager.setCommunicationDevice()` routes
  audio over Bluetooth HFP/SCO, which carries the headset microphone. HFP
  sounds worse than A2DP, but A2DP has no microphone.
- **Barge-in:** capture from `AudioSource.VOICE_COMMUNICATION` to get the
  platform echo canceller, so the harness does not hear its own voice.
- **Expo can reach this without ejecting.** A config plugin such as
  `react-native-audio-api` declares the microphone foreground service.
  This needs a development build, not Expo Go.

### Q3–Q4 — speech and turn-taking (researched 2026-09-25, all [REPORTED])

- **On-device recognition:** Android `SpeechRecognizer` has an on-device
  mode (API 31+), but availability varies by phone maker. sherpa-onnx ships
  Android packages for offline recognition. whisper.cpp and Vosk need more
  integration work.
- **Cloud recognition:** streaming services add turn detection and better
  accuracy. Rough prices cited: Deepgram streaming about $0.008/min, Google
  Cloud STT about $0.016/min, OpenAI Realtime about $0.02/min in and
  $0.08/min out. These came from third-party pricing posts. Check them
  before any cost decision.
- **End of turn:** Silero VAD runs on Android through ONNX Runtime. A
  common setting treats about 1 s of silence as the end of a turn.

### Next check for Q2

Run a probe on my phone: a minimal page, then a minimal Expo development
build, each capturing the Bluetooth microphone for 30 minutes with the
screen off. The page should fail and the app should hold. If the page
holds, reopen the platform question.

## Out of scope

- Any build in `voice-to-vibe` before the questions above have answers and
  I have approved a plan.
- iOS, and car-specific integrations (CarPlay, Android Auto).
- Other agents than Claude Code.
