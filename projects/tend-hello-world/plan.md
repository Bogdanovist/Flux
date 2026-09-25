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

## Approach

Two paths, one slice each. The web path comes first because it is cheap
and it proves the backend reachability that the native path also needs.

1. **Mobile web over the LAN.** Serve the app with `expo start --web` bound
   to the Mac's LAN address. Point `EXPO_PUBLIC_SUPABASE_URL` at a backend
   the phone can reach. Open the page in the phone's browser. Fast Refresh
   pushes each save to the phone in seconds. Web cannot show native-only
   behaviour: the widget, notifications, native gestures and fonts may
   differ. Done when a save on the Mac changes the screen on the phone, and
   sign-in and one synced task work.
2. **Development build.** Add `expo-dev-client` and an `eas.json` with a
   `development` profile. Build once, install on the phone, and then load
   JavaScript from the Mac's Metro server, so only a native change needs a
   rebuild. Done when the dev build is on the phone, a JavaScript save
   reaches it through Fast Refresh, and the widget renders.

Each slice lands as a PR on `tend-to-do` with a short runbook in its
`AGENTS.md` §Commands: the one command to start, and what to open on the
phone.

## Open questions (Matt)

- **Q1 — Which phone?** iPhone or Android. The widget is iOS only. An
  iPhone dev build needs an Apple Developer account ($99 a year) to install
  on a device. It also needs the device registered with EAS, or a
  7-day free provisioning profile from local Xcode.
- **Q2 — Which backend does the phone talk to?** This is an architecture
  choice, and it sets how data flows in development.
  - *Local Supabase over the LAN.* The phone uses the Mac's LAN IP. It costs
    nothing and keeps test data off the internet. It works only on the home
    network, while the Mac runs `supabase start` (Docker). The LAN IP can
    change, so the URL in `.env` goes stale. Auth redirect URLs in
    `supabase/config.toml` also need the LAN address.
  - *A hosted Supabase dev project.* It works from any network and needs no
    Docker running. It costs a new project and its keys. Migrations then
    need a push step to a remote database.
- **Q3 — Where does the native build run?** EAS cloud build (free tier: a
  queue, about 10–20 minutes a build, no Xcode needed). Or install Xcode
  (about 15 GB) and build locally with `expo run:ios`. The dev build only
  rebuilds on a native change, so the build time matters less than it
  seems.
- **Q4 — Is the phone on the same network as the Mac?** The LAN path needs
  it. If not, `expo start --tunnel` works through a tunnel, at the cost of
  slower reloads.

## Out of scope

- Production builds, store submission, and a deployment pipeline.
- A hosted production backend. A hosted *dev* project (Q2) is in scope
  only if Matt picks it.
- Feature work and UI changes.
