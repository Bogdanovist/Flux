---
started: 2026-09-25
repos: harpastum
---

## Why

Harpastum is a sports management sim set in the Roman world, built on the
ancient ball game harpastum. The player coaches a team of one people (Romans,
Greeks, Celts and others), sets tactics and formations, and watches a match
simulation play them out. The game design is still open. The first builds are
throwaway prototypes to find the design, so speed of iteration beats code
quality and stack choice.

Matt must see each change on his phone within seconds, without a deploy
step. This project ends when a stub title screen runs from the repo, Matt
opens it on his phone from a private URL, and an edit Claude makes on the
laptop shows on the phone without a manual reload.

## What the repo holds (measured 2026-09-25)

- `harpastum` on GitHub is `Bogdanovist/harpastum`: public, default branch
  `master`, last commit 2013-10-17.
- 17 Python files, 2,334 lines: the start of the match AI. Players are
  entities with roles (blocker, receiver, defender, utility), steering
  behaviours, move states, threat assessment and a message bus. `test.py`
  sets up an 11-a-side match on a 100 × 50 pitch and animates it with
  matplotlib.
- All 17 files parse as Python 3. They import numpy, scipy and matplotlib.
  `Pitch.py` imports a `Helper` module that is not in the repo, so the code
  does not run as committed.
- No README, no AGENTS.md, no dependency list.

## Approach

Reuse the setup that `projects/lom-mvp/plan.md` proved for Lines On Maps.
That plan carries the reasoning behind each choice below. This doc records
only what differs for Harpastum.

### Stack: Vite, React and TypeScript

The same stack as Lines On Maps. Vite pushes each saved edit to the phone
through hot module replacement. React fits the management screens (squad,
tactics, league tables).

Consequence: the match viewer, when it comes, draws to a `<canvas>` or SVG
inside React. A 2D canvas is enough for 22 dots and a ball. A game engine is
not needed for that and is not chosen now.

### The Python match AI stays in the repo, untouched

Move the 17 Python files into `legacy/` unchanged, with a short README that
says what they are and that they do not run (`Helper` is missing). The web
app starts in the repo root.

Consequence: the browser cannot run this code. When the match viewer needs a
simulation, it needs a TypeScript port of the parts worth keeping. That port
is a later project, and it can read `legacy/` as its spec.

Alternatives considered:

- **Run the Python in the browser with Pyodide.** It keeps the old code
  live. It adds a 10 MB+ download and numpy/scipy loading to every phone
  page load, and the code does not run today anyway.
- **A Python server that simulates and streams to the browser.** It keeps
  the old code live too. It adds a second process, a message format and a
  second language to every change, for code that is 13 years old and
  incomplete.
- **Delete the Python.** Git history keeps it, but a reader of the tree
  would not know it exists.

### Phone access: Tailscale, port 5174

Tailscale, as for Lines On Maps. The laptop's tailnet hostname is
`matt-human`, and `vite.config.ts` must list it in `server.allowedHosts`.
The dev server listens on port 5174 with `strictPort`, so it can run beside
the Lines On Maps server on 5173. The phone URL is
`http://matt-human:5174`. Vite's watcher polls every 200 ms, because the
Claude Code sandbox blocks macOS file-system events.

Consequence: two bookmarks on the phone, one per game, and neither server
blocks the other.

### Branches and guidance

Each change lands on a feature branch in a worktree, with a PR against
`main`. The session that edits code serves the dev server from its own
worktree, so the phone shows the branch under review. The repo gets an
`AGENTS.md` with the run command, the port, the phone URL and the checks,
and a one-line `CLAUDE.md` that imports it.

### Slices

1. **Title screen on the phone.** Move the Python to `legacy/`. Scaffold
   Vite + React + TypeScript with a stub title screen sized for a phone in
   portrait. `npm run dev`, `npm run build`, `tsc -b`, and one Vitest test
   that renders the title. Tailscale host, port and polling in
   `vite.config.ts`. `AGENTS.md` and `CLAUDE.md`. Prove it: Claude edits the
   title text, and the phone shows the new text without a reload. One PR.

One slice suffices here: the Lines On Maps work already settled the
Tailscale, sandbox and polling unknowns that justified two slices there.

## Decisions (Matt, 2026-09-25)

1. Stack: Vite + React + TypeScript.
2. The Python code moves to `legacy/` untouched.
3. The dev server uses port 5174.
4. The default branch is renamed from `master` to `main` before the slice
   starts, so the PR targets `main`.

## Out of scope

- Any gameplay, the match viewer, and any port of the Python AI.
- A production stack, native builds and app stores.
- Public hosting, accounts and any backend.
