---
name: phone-prototype
description: Run a web prototype so Matt can play it on his phone over Tailscale, with each saved edit reaching the phone by hot reload. Use when starting, restarting or debugging the dev server of a phone-played prototype, or when setting one up in a new repo.
---

# Phone prototype

Matt plays a prototype in his phone's browser at `http://matt-human:<port>`.
`matt-human` is the laptop's Tailscale name. Each repo owns one fixed port, so
the phone's bookmark never changes and two prototypes can run at once:

| Repo | Port |
|---|---|
| Lines-on-Maps | 5173 |
| harpastum | 5174 |
| tend-to-do | 5175 |

A new prototype takes the next free port and adds its row here.

## Running it

- Start the dev server from your own worktree, so the phone shows the branch
  under work. Run it as a background task that your session can stop, and
  stop it when the session ends. One dev server runs per repo at a time.
- If the port is taken, `lsof -t -iTCP:<port> -sTCP:LISTEN` gives the process
  ID. If you cannot stop that process, ask Matt to stop it.

## The server config

A Vite prototype needs four `server` settings in `vite.config.ts`. Each one
carries a comment saying why:

- `host: true` — listen on all interfaces, so the phone can reach the laptop.
- `port: <port>` and `strictPort: true` — fail on a taken port. A server that
  drifts to another port breaks the phone's bookmark.
- `allowedHosts: ['matt-human']` — Vite refuses requests for a hostname it
  does not know.
- `watch: { usePolling: true, interval: 200 }` — the Claude Code sandbox blocks
  macOS file-system events, so without polling an agent's edits never reach
  the phone.
