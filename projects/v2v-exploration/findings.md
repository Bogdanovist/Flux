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
- **C5 — Personal use; adopt before building.** The harness is for me. If
  an existing open-source project meets C1–C4, I use or fork it, and
  `voice-to-vibe` stays empty or holds the fork.

## Summary

No existing project meets C1–C4 as it stands. `1nspectorCat/Claudio-Code`
comes closest. Its Android audio side handles Bluetooth, the screen-off
case and interrupting playback. Its gaps are spoken approvals (Q6), output
made for listening (Q5), and Russian hard-coded throughout. `mbailey/voicemode`
does not fit: it only uses the microphone and speaker of the Mac that runs
Claude Code.

Platform (Q2): a native Android app. A browser page cannot keep the
microphone alive with the screen off.

Connection (Q1): no documented interface lets a third-party app share a
live session with the terminal. A harness can drive a real session and hand
it back to the desk, through `claude -p --resume`, the Agent SDK, or hooks
plus a relay (the Claudio-Code approach).

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

### Q1 — where the phone connects (researched 2026-09-25)

- **Remote Control has no third-party interface.** The doc describes the
  local session polling the Anthropic API and serving claude.ai/code and
  the Claude iOS and Android apps. It names no API, SDK or protocol for
  other clients. It needs claude.ai subscription auth, and API keys do not
  work (code.claude.com/docs/en/remote-control) [OBSERVED]. The absence of
  an interface is a reading of the doc, not a statement in it.
- **Claude Code has no spoken output.** `/voice` is dictation only: speech
  to text into the CLI prompt, streamed to Anthropic's servers. It needs a
  local microphone and does not work in cloud or SSH sessions. The page
  says nothing about reading responses aloud
  (code.claude.com/docs/en/voice-dictation) [OBSERVED]. The research agent
  reports open requests for spoken output (anthropics/claude-code issues
  61574 and 42700) [REPORTED].
- **Headless mode steers a real session.** `claude -p --resume <id>` with
  `--input-format stream-json` and `--output-format stream-json` reads and
  writes the same session store as interactive use. stdout carries
  assistant text, tool calls and results. stdin takes further user
  messages, and SIGINT ends a turn. `--permission-prompt-tool` sends each
  permission prompt to an MCP tool I write, which is the hook a spoken
  approval needs (code.claude.com/docs/en/headless) [REPORTED].
- **The Agent SDK gives the same control as objects.** It streams
  messages, takes new prompts, answers permissions through `canUseTool`,
  and has `interrupt()`. It can resume a session by id
  (code.claude.com/docs/en/agent-sdk/typescript) [REPORTED].
- **Hooks push events out; they cannot send a prompt in.** A `Stop` or
  `Notification` hook can send a turn's result to the phone. A
  `PermissionRequest` hook can return allow or deny, so it could wait for
  a spoken answer (code.claude.com/docs/en/hooks-guide) [REPORTED].
- **Existing projects**, checked with `gh repo view` [OBSERVED]:
  - `1nspectorCat/Claudio-Code`: "Talk to your Claude Code sessions by
    voice, hands-free, from your phone". 1 star, last push 2026-09-24.
    The research agent reports it is Android-only [REPORTED].
  - `mbailey/voicemode`: voice conversations with Claude Code. 1375 stars,
    last push 2026-09-21. The agent reports it works through MCP
    [REPORTED].
  - `Archerkattri/clyde-android`: an Android assistant driven by the Agent
    SDK. 2 stars, last push 2026-09-18.
  - `abracadabra50/claude-code-voice-skill`: talk about a project over a
    phone call. 173 stars, last push 2026-07-25.
  - `Eduardomaia06/cc-voice`: voice control with live transcription.
    1 star, last push 2026-09-23.

**Open for Q1:** whether a headless `--resume` process and an interactive
terminal on the same session corrupt each other if both run at once. The
harness design must either forbid that or prove it safe.

### Existing projects evaluated (2026-09-25)

Two read-only research agents read each repo. I checked the claims marked
[OBSERVED] in a shallow clone of each.

**`1nspectorCat/Claudio-Code`** (MIT, created 2026-08-17, last commit
2026-09-24, one author):

- **Shape.** An Android app (`app/`, with `BridgeService.kt` at 4724
  lines [OBSERVED]), a self-hosted Node relay (`server/relay.js`), and Mac
  glue: a Stop hook that reads each reply aloud (`desktop/readback.py`) and
  a skill that polls the relay from inside the live Claude Code session
  (`desktop/skill/voice-bridge/SKILL.md`). The phone and the Mac meet only
  at the relay, which runs on the LAN at home or on a VPS or tunnel away
  from it [REPORTED].
- **Session.** It steers the live interactive session. Spoken text arrives
  as an ordinary user message on the session's next turn [REPORTED]. This
  is a live shared session, which Q1 found no official interface for.
- **Screen off.** A foreground service with a partial wake lock
  [REPORTED]. The Mac-side poller runs as a Claude Code Monitor. The skill
  says some Claude Code versions stop a Monitor after 30 minutes and
  describes re-arming it (`SKILL.md:64-66`) [OBSERVED].
- **Turn-taking.** Half-duplex: playback pauses while it listens. A
  headset button or a stop word interrupts playback [REPORTED]. The README
  says the stop word fails in strong wind, and the headset button does not
  reach the app while the whisper recorder holds the headset [OBSERVED].
- **Approvals.** Nothing answers Claude Code's permission prompts.
  `desktop/` and `server/` contain no mention of "permission" [OBSERVED].
  A session that stops on a prompt stalls. The only guard is a skill
  instruction to act on destructive requests only when the phrase carries
  an agreed code word (`SKILL.md:81-92`) [OBSERVED].
- **Output.** `readback.py` strips Markdown and reads the reply as written.
  It does not summarise diffs or tool calls [REPORTED].
- **Language.** Russian is hard-coded in four places, two of them in the
  Android app, and the app UI is Russian throughout (README §Using another
  language) [OBSERVED]. English use needs a rebuilt APK.
- **Services.** Android's `SpeechRecognizer` (usually Google) or local
  whisper.cpp for recognition. Microsoft `edge-tts`, a free unofficial
  service, for speech [REPORTED].
- **Security.** One shared token in the URL query string, and a pinned
  self-signed certificate. A leaked token lets someone inject messages into
  every session [REPORTED].

**`mbailey/voicemode`** (MIT, 1375 stars, active): an MCP server that
speaks through the Mac's own microphone and speaker. Its changelog records
the removal of LiveKit rooms and the web frontend, and says "Local
microphone transport remains the default and only transport option"
(`CHANGELOG.md:668-676`) [OBSERVED]. A phone cannot join a session. Not
suitable.

**Build tooling on this Mac (2026-09-25)** [OBSERVED]: no Android SDK
(`~/Library/Android/sdk` absent), no `adb`, no `gradle`. `tailscale` and
Node 24 are installed. Rebuilding the Claudio-Code APK needs the Android
SDK first.

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
