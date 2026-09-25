---
started: 2026-09-25
repos: Lines-on-Maps
---

## Why

Lines On Maps is a roguelite crisis-bargaining strategy game. The long-term
target is a cross-platform mobile game for iOS and Android. The gameplay is
still open, so the first playable prototypes are throwaway: once the game is
known, a production build may start again in a different stack.

Matt develops mostly from the Claude Code mobile app, remote-controlling the
laptop. He must see each change on his phone's browser within seconds, without
a deploy step. The status quo (2026-09-25, `Lines-on-Maps` `main` at
`a0c25f4`) is design docs only: no code, no stack, and no way to look at
anything on the phone.

This project ends when a stub title page runs from the repo, Matt opens it on
his phone from a private URL, and an edit Claude makes on the laptop shows on
the phone without a manual reload.

## What the repo holds (measured 2026-09-25)

- `CLAUDE.md`, `README.md`, and `docs/`: foundations, theory-to-mechanics, one
  exploratory concept, and a Spaniel glossary. These came from the Claude chat
  project and are already committed. `CLAUDE.md` states "no code yet" and that
  no engine is chosen; both claims go stale in slice 1.
- The repo has no `AGENTS.md`, so a non-Claude agent reads none of its
  guidance.

## Machine facts (measured 2026-09-25)

- Node 24.14.0, npm 11.9.0.
- Tailscale, cloudflared and ngrok are not installed.
- The Claude Code sandbox refuses a local port bind (`bind 0.0.0.0:5199` gave
  `EPERM`). A dev server started by Claude cannot listen until
  `sandbox.network.allowLocalBinding` is `true`. That setting is Matt's to
  change.

## Approach

### Stack: Vite, React and TypeScript, served as a mobile web page

Vite's dev server pushes each saved edit to open browsers through hot module
replacement, in well under a second. That is the fastest loop available. The
game is turn-based and reads like documents, folders and a map, so DOM and SVG
fit it better than a canvas game engine. React is the common ground with the
eventual mobile build: React Native reuses the language, the component model
and most non-UI logic.

Consequence: nothing here runs as a native app. Going native later means a
port of the UI layer. That cost is accepted, because the prototype is expected
to be thrown away.

Alternative considered: Expo (React Native with a web target), which Tend
already uses. It keeps a path to a native build from day one. Its web output
is slower to iterate on and heavier to set up, and it constrains UI choices
before the game has any requirements.

### Phone access: Tailscale, private to Matt's devices

The laptop and the phone join one tailnet. The phone opens
`http://<laptop-name>:5173`. That URL is reachable only from Matt's devices,
works away from home Wi-Fi, stays the same between sessions, and carries hot
reload.

Consequences: Matt installs Tailscale on the Mac and the phone and signs in
(Claude cannot install system software). The page is plain HTTP inside the
tailnet, which is enough for a stub. Browser features that need HTTPS
(service workers, some sensors) need `tailscale serve` later.

Alternatives considered:

- **LAN IP only.** No install. Works only on the same Wi-Fi.
- **Cloudflare quick tunnel.** A public URL protected only by being hard to
  guess. The URL changes on every start.
- **Deploy previews (Vercel, Cloudflare Pages).** Needs a push and a build per
  change, which costs tens of seconds and breaks the live loop.

### Which checkout the phone shows

Changes land on a feature branch in a worktree, with a PR (charter §Review).
The session that edits code starts the dev server from its own worktree on
port 5173, so the phone shows the branch under work before it merges. One
session serves at a time. A second session on the same port fails to start
and says so. A repo rule, `.claude/rules/dev-server.md`, records the command
and the port.

### Repo guidance

Move `CLAUDE.md` to `AGENTS.md` and leave `CLAUDE.md` as a one-line
`@AGENTS.md` import, the same shape Flux uses. Update the "no code yet" and
"no engine chosen" claims, and add how to run the app and its checks.

### Slices

1. **Title page on the laptop.** Scaffold Vite + React + TypeScript. A stub
   title screen, sized for a phone in portrait. `npm run dev`, `npm run build`,
   `tsc --noEmit`, and one Vitest test that renders the title. The repo
   guidance change above. One PR.
2. **Title page on the phone.** Matt installs Tailscale and sets
   `allowLocalBinding`. Add the dev-server rule. Prove it: Claude edits the
   title text, and the phone shows the new text without a reload. PR carries
   the rule.

## Decisions Matt must make before slice 1

1. Stack: Vite + React + TypeScript (recommended), or Expo.
2. Phone access: Tailscale (recommended), LAN only, or a public tunnel.
3. Review flow: a PR per change, with the phone showing the branch
   (recommended), or straight to `main` for this prototype repo.
4. Sandbox: set `sandbox.network.allowLocalBinding: true`. Without it, no dev
   server started by Claude can listen, and the live loop cannot work.

## Out of scope

- Any gameplay. The title page is a stub.
- App store builds, native builds, and a production stack choice.
- Public hosting, accounts, and any backend.
- Changes to the design docs beyond the guidance move.
