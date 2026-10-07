# archive.md

Every staged lesson, verbatim, tagged with the disposition `/curate` gave it.
Nothing is deleted from here, and nothing is edited: git history is the audit
trail. Entries appear below, newest last.

---
disposition: rejected (better fixed: gh per-host git_protocol) — 2026-09-25
uuid: 522241a6-1d3e-4f90-b7a7-16bbb6856d3d
timestamp: 2026-09-25T04:23:18Z
proposed-text: |
  `gh repo clone` over SSH fails inside the Claude Code Bash sandbox with
  "ssh_dispatch_run_fatal: Connection to UNKNOWN port 65535: Broken pipe",
  because the sandbox network proxy passes HTTPS only. Clone with
  `git clone https://github.com/<owner>/<repo>.git` instead. Under the
  sandbox, the keychain credential helper also prints "failed to store:
  100001"; the clone still succeeds. A repo that an agent clones therefore
  gets an HTTPS origin, where Matt's own clones may use SSH.
---

---
disposition: split — watcher part rejected (already fixed in code); detached-process part pending — 2026-09-25
uuid: 8bcb6297-5c9d-4566-8513-cdbbe5bd3177
timestamp: 2026-09-25T04:55:59Z
proposed-text: |
  The Claude Code sandbox on macOS blocks file-system events. Node fs.watch
  fails with EMFILE and reports no events (measured 2026-09-25). A dev server
  or test watcher that an agent starts therefore serves stale code without any
  error. Lines-on-Maps sets Vite server.watch.usePolling to work under the
  sandbox.

  A process started with "( cmd & )" inside a sandboxed Bash call outlives the
  call, and later sandboxed calls cannot stop it (kill fails with "operation
  not permitted"). Start long-running servers with the Bash tool's
  run_in_background, so TaskStop can stop them.
---

---
disposition: fixed in config — e34f4b3 (sandbox allowWrite ~/.npm ~/.expo, registry.npmjs.org allowlisted, NODE_USE_ENV_PROXY=1) — 2026-09-25
uuid: 36e65756-975c-4c0e-92be-6f6f1682833e
timestamp: 2026-09-25T05:11:22Z
proposed-text: |
  Sandboxed Node tooling on this machine needs three workarounds, and one sandbox behaviour cost about 40 minutes of hung installs.
  (1) npm and Expo try to write ~/.npm and ~/.expo, which the sandbox denies; npm misreports this as "cache folder contains root-owned files". Use npm_config_cache=$TMPDIR/npm-cache and __UNSAFE_EXPO_HOME_DIRECTORY=$TMPDIR/expo-home.
  (2) Node's built-in fetch (used by the Expo CLI and expo-doctor) ignores HTTPS_PROXY and connects directly, failing with EPERM. Set NODE_USE_ENV_PROXY=1 (Node 24).
  (3) A Bash call whose command contained `rm -rf` had its allowed_domains grant withheld: every registry.npmjs.org connection was denied, and npm retried until it ran out of heap after about 30 minutes. The same npm command without `rm -rf` reached the registry. Run deletions as a separate Bash call.
  Observed 2026-09-25 while upgrading an Expo app in the tend-to-do repo.
---

---
disposition: rejected (better fixed: per-segment cd resolution in scripts/lib/bash-command.sh; follow-up ab4defe2) — 2026-10-07
uuid: c7a7b421-7522-4d5e-829c-25676374281e
timestamp: 2026-09-25T10:41:55Z
proposed-text: |
  hooks/shared-checkout-guard.sh can block a `git commit -a` that runs inside a
  project worktree, reporting it as a commit in the shared Flux checkout. Seen
  with a Bash command whose session cwd was Flux, which did `cd <worktree> && ...
  git commit -qam` and later `cd ..` in the same command. The same pattern
  without the later `cd` passed. The guard appears to resolve the repo from the
  session cwd or the last `cd` in the command, not from where the commit runs.
  Using `git -C <worktree> add <paths>` and `git -C <worktree> commit` avoids it.
---

---
disposition: rejected (better fixed: gh auth setup-git and gh git_protocol https; follow-up 86d5f592) — 2026-10-07
uuid: 5c027644-3302-4432-83b8-8494c7c0f4b1
timestamp: 2026-09-25T12:23:56Z
proposed-text: |
  A repo cloned into $FLUX_SRC_ROOT with plain `git clone https://github.com/...`
  cannot push from inside the Bash sandbox. Git's osxkeychain helper fails
  ("failed to store: 100001"), then "could not read Username for
  'https://github.com': Device not configured". The other checkouts
  (tend-to-do, harpastum and the rest) push because their own .git/config
  carries credential.https://github.com.helper set to '' and then to
  '!gh auth git-credential'. Nothing in Flux (setup.sh, scripts, hooks,
  skills) sets that, and how those checkouts got it is not known. The
  voice-to-vibe checkout was fixed on 2026-09-25 by adding those two local
  config entries. open-project tells agents to clone a missing repo beside
  Flux, so every new repo meets this. Candidate fix: find out how the
  existing checkouts got the helper, then make the clone step in
  open-project or git-worktrees set it.
---

---
disposition: promoted — 1c09ff5 (verification-before-completion) — 2026-10-07
uuid: 26f51d2f-dbda-439e-a541-c8dc0250c100
timestamp: 2026-09-26T01:13:46Z
proposed-text: |
  When proving a fix is needed by removing it and measuring again, confirm
  the removal actually happened before trusting the result. A git revert on
  a worktree with uncommitted changes can fail without a visible error; the
  fix then stays in place, and a count of the failure it prevents reads zero
  by construction. A real fix was dropped on such a false zero, and a later
  crash proved it was needed. Check git diff, or grep for the removed line,
  before running the counterfactual measurement.
---

---
disposition: promoted — bad584f (phone-prototype Expo/Metro paragraph) — 2026-10-07
uuid: 20168976-6f4a-40ae-a748-41a168fb8958
timestamp: 2026-09-26T04:30:27Z
proposed-text: |
  The phone-prototype skill makes hot reload work under the Claude Code
  sandbox with Vite's watch.usePolling. That fix does not carry to an Expo
  app. Metro 0.83 has no polling watcher: it watches through Watchman or
  through macOS file events (recursive fs.watch). Under the sandbox, fs.watch
  fails with EMFILE and reports no change (tested 2026-09-26 in tend-to-do),
  so a Metro server an agent starts never sends an edit to the phone. Flux
  settings.json now lists the repo's dev-server script, "npm run web:phone",
  in sandbox.excludedCommands, next to "docker *", "supabase *" and
  "open -a Docker" for a local Supabase stack. The skill should say how an
  Expo repo meets its hot-reload requirement.
---

---
disposition: superseded by c23e2993 — 2026-10-07
uuid: b3ff8bca-6782-42b3-8109-5bf575206ac3
timestamp: 2026-09-26T04:46:13Z
proposed-text: |
  A command listed in sandbox.excludedCommands in the merged
  ~/.claude/settings.json still ran inside the sandbox in a Claude desktop-app
  session (2026-09-26). The list held "docker *", "supabase *",
  "open -a Docker" and "npm run web:phone". "open -a Docker" failed with the
  Launch Services error -10810. "docker desktop start" failed with "operation
  not permitted" when it wrote
  ~/Library/Containers/com.docker.docker/Data/log/host/docker-desktop.log.
  The same settings file sets sandbox.allowUnsandboxedCommands to false. That
  setting is the likely cause: it may disable excludedCommands as well as the
  dangerouslyDisableSandbox escape. The effect is that an agent cannot start
  Docker Desktop or Supabase, so the tend-to-do phone dev loop needs a person
  to launch Docker Desktop by hand. Confirm which setting governs
  excludedCommands, then either set allowUnsandboxedCommands so the exclusion
  list applies, or remove the exclusion list that has no effect.
---

---
disposition: promoted — bad584f (carried in phone-prototype) — 2026-10-07
uuid: c23e2993-602d-4fdd-a71a-8d86a11ed699
timestamp: 2026-09-26T05:26:38Z
proposed-text: |
  Supersedes lesson b3ff8bca-6782-42b3-8109-5bf575206ac3, whose diagnosis is
  wrong; drop that entry. A sandbox.excludedCommands pattern such as
  "open -a Docker" or "docker *" takes a Bash call out of the sandbox only
  when the call is that command alone. A call that adds "; echo rc=$?",
  "2>&1 | tail" or a "cd dir &&" prefix runs inside the sandbox, and fails
  the way a sandboxed call fails: Launch Services error -10810 from open, or
  "operation not permitted" from Docker Desktop writing under
  ~/Library/Containers. The setting sandbox.allowUnsandboxedCommands: false
  does not block the exclusion list. To run an excluded command in another
  directory, give it a directory flag (supabase start --workdir <dir>), or
  grant the directory to the session so that a bare "cd" persists, then issue
  the excluded command as its own call.
---

---
disposition: recorded, not proposed (one-off, caught before PR) — 2026-10-07
uuid: e5cd29db-07fb-46e8-b639-beae3fc1b920
timestamp: 2026-10-07T09:38:46Z
proposed-text: |
  Squashing work-in-progress commits in a worktree with
  `git reset --soft origin/main` uses whatever origin/main the last fetch
  saw. A hook fetch can advance it while the branch is open, after another
  session has pushed a context/ commit. The squashed commit then records
  that session's new file as deleted, and a push carries the deletion on the
  feature branch. Seen in tend-to-do on 2026-10-07 with
  context/projects/tend-family-mvp/plan.md, caught before the PR opened,
  and fixed with `git checkout origin/main -- <path>` and an amend. Squash
  onto the branch's own base, `git reset --soft $(git merge-base HEAD
  origin/main)`, and check `git status --short` for D lines you did not
  make before committing.
---
