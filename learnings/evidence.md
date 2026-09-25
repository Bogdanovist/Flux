# evidence.md

The distilled ledger. One record per theme, carrying its recurrence count, up
to about five fingerprints, and its status. `/curate` reads it to judge whether
a theme has crossed the promotion bar, and writes it back at the end of a pass.

A theme record looks like this:

```markdown
## <theme name>
- count: <N>
- status: pending | promoted | rejected: <reason>
- fingerprints:
  - <YYYY-MM-DD> <uuid> — <one line of what happened>
```

Records appear below.

## gh clones over SSH, which the sandbox network proxy blocks
- count: 1
- status: rejected: better fixed — gh's per-host setting for github.com is `git_protocol: ssh`; set it to https
- fingerprints:
  - 2026-09-25 522241a6-1d3e-4f90-b7a7-16bbb6856d3d — `gh repo clone` fails in the sandbox with "ssh_dispatch_run_fatal ... Broken pipe"; `git clone https://...` works

## Sandbox blocks macOS file-system events, so watchers serve stale code without an error
- count: 1
- status: rejected: already fixed in code — Vite server.watch.usePolling in Lines-on-Maps (branch slice/phone-preview); reopen if that branch is abandoned or a non-Vite repo hits it
- fingerprints:
  - 2026-09-25 8bcb6297-5c9d-4566-8513-cdbbe5bd3177 — Node fs.watch fails with EMFILE and reports no events

## A detached process started from sandboxed Bash cannot be stopped later
- count: 1
- status: pending
- fingerprints:
  - 2026-09-25 8bcb6297-5c9d-4566-8513-cdbbe5bd3177 — a server started with `( cmd & )` outlived its call; kill gave "operation not permitted"; run_in_background with TaskStop works

## Sandbox blocks npm and Expo caches, the npm registry, and Node fetch
- count: 2
- status: promoted: e34f4b3 — settings.json allows writes to ~/.npm and ~/.expo, allowlists registry.npmjs.org, sets NODE_USE_ENV_PROXY=1
- fingerprints:
  - 2026-09-25 ff92f9cd-abd3-419b-af24-ac5c871958c0 — `npm create vite` failed; npm blamed root-owned cache files, but the sandbox denied writes to ~/.npm
  - 2026-09-25 36e65756-975c-4c0e-92be-6f6f1682833e — Expo upgrade: ~/.npm and ~/.expo denied, Node fetch ignored the proxy, npm retried a blocked registry for 30 minutes
