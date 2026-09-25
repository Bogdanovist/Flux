---
started: 2026-09-25
repos: tend-to-do
---

## Why

Nobody has seen Tend (`tend-to-do`) run on a phone. Feature work needs a fast
look-change-look loop on a real device. If each look costs a long build and
manual steps, small UI fixes ("the button is a bit too big") become too
expensive to make. The measure of success is the time from saving a file to
seeing the change on the phone.

## What the repo holds (measured 2026-09-25, `main` at `47e6a74`)

- **Web already builds.** `app.json` sets `web.output: "single"` (commit
  `a644571`). WatermelonDB uses the LokiJS adapter on every platform, so the
  client database needs no native module. `npm run web` serves the app.
- **Native modules force a dev build.** `app.json` loads the `expo-widgets`
  config plugin (an iOS home-screen widget, `TendQuickAdd`). Expo Go cannot
  load a config plugin, so a native look needs a development build
  (`expo-dev-client`). The repo has no `eas.json`, no `ios/` and no
  `android/`, and `expo-dev-client` is not a dependency.
- **The backend lives on `127.0.0.1`.** `src/database/sync.ts:24` defaults
  `EXPO_PUBLIC_SUPABASE_URL` to `http://127.0.0.1:54321`. Every screen sits
  behind sign-in. A phone resolves `127.0.0.1` to itself, so neither path
  works on a phone until the app points at a backend the phone can reach.
- **This Mac has no full Xcode.** `xcode-select -p` returns
  `/Library/Developer/CommandLineTools`, and `/Applications` holds no
  `Xcode.app`. A local iOS build needs Xcode. An EAS cloud build does not.
  The `eas` CLI is not installed.

## Decisions (Matt, 2026-09-25)

- **D1 — Mobile web only.** The phone and the Mac share the home network.
  The app's fundamentals are still open, so native nuance waits. The
  development build is out of scope.
- **D2 — Local Supabase over the LAN.** The phone reaches the Mac's
  Supabase at the Mac's LAN address. No hosted project.

## Approach

One PR on `tend-to-do`. Serve the app with the Expo web dev server on the
Mac's LAN address, and point `EXPO_PUBLIC_SUPABASE_URL` at the Mac's LAN
address. Open the page in the phone's browser. Fast Refresh pushes each
save to the phone in seconds. Reuse `scripts/setup-user-test.sh`, which
already starts Supabase, detects the LAN IP and writes `.env.local`.

Web cannot show native-only behaviour: the widget, notifications, native
gestures and fonts may differ.

Done when a save on the Mac changes the screen on the phone, and sign-up,
sign-in and one synced task work from the phone. The runbook goes in the
repo's `AGENTS.md` §Commands.

## Out of scope

- The native development build (`expo-dev-client`, EAS or Xcode).
- Production builds, store submission, and a deployment pipeline.
- A hosted Supabase project.
- Feature work and UI changes.
