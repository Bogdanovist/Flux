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

## A repo an agent clones into the Flux root cannot reach GitHub from the sandbox
- count: 2
- status: rejected: better fixed — `gh auth setup-git` (global helper) and gh `git_protocol: https`; both unapplied 2026-10-05; follow-up 86d5f592 filed
- fingerprints:
  - 2026-09-25 522241a6-1d3e-4f90-b7a7-16bbb6856d3d — `gh repo clone` fails over SSH ("Broken pipe"); plain `git clone https://...` works
  - 2026-09-25 5c027644-3302-4432-83b8-8494c7c0f4b1 — a plain https clone cannot push (osxkeychain "failed to store: 100001"); working checkouts carry a local `!gh auth git-credential` helper of unknown origin

## Sandbox blocks macOS file-system events, so watchers serve stale code without an error
- count: 2
- status: promoted: bad584f — phone-prototype says an Expo/Metro dev server runs outside the sandbox as a bare `npm run web:phone` call; the bare-`cd` sequence is untested as of 2026-10-07
- fingerprints:
  - 2026-09-25 8bcb6297-5c9d-4566-8513-cdbbe5bd3177 — Node fs.watch fails with EMFILE and reports no events; Vite fixed with usePolling
  - 2026-09-26 20168976-6f4a-40ae-a748-41a168fb8958 — Expo/Metro 0.83 has no polling watcher; tend-to-do dev server excluded from the sandbox as `npm run web:phone`

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

## sandbox.excludedCommands applies only to a Bash call that is the excluded command alone
- count: 1
- status: promoted: bad584f — carried in phone-prototype for the dev server; Docker and Supabase calls fail loudly and are not covered
- fingerprints:
  - 2026-09-26 c23e2993-602d-4fdd-a71a-8d86a11ed699 — `cd dir &&`, `; echo rc=$?` or `| tail` puts an excluded command back in the sandbox; allowUnsandboxedCommands: false does not block the list
  - 2026-09-26 b3ff8bca-6782-42b3-8109-5bf575206ac3 — [superseded by c23e2993] misdiagnosed the same failure as allowUnsandboxedCommands disabling the list

## Hook command parser resolves the target directory from the last `cd` in the whole command
- count: 1
- status: rejected: better fixed — per-segment directory resolution in scripts/lib/bash-command.sh; the parser also fails open on `cd $FLUX_DIR && git add -A && cd /tmp`; follow-up ab4defe2 filed blocks-now
- fingerprints:
  - 2026-09-25 c7a7b421-7522-4d5e-829c-25676374281e — a worktree `git commit -qam` was blocked as a Flux commit because of a later `cd` in the same call

## A counterfactual check run against a removal that never happened
- count: 1
- status: promoted: 1c09ff5 — verification-before-completion requires `git diff` or a grep to show the removal before a counterfactual run counts
- fingerprints:
  - 2026-09-26 26f51d2f-dbda-439e-a541-c8dc0250c100 — a `git revert` failed on a dirty worktree; the fix stayed, the count read zero, the fix was dropped, and a crash followed

## A squash onto a moved origin/main records another session's context/ commit as a deletion
- count: 1
- status: pending
- fingerprints:
  - 2026-10-07 e5cd29db-07fb-46e8-b639-beae3fc1b920 — `git reset --soft origin/main` after a hook fetch deleted tend-to-do context/projects/tend-family-mvp/plan.md on the branch; caught before the PR opened
