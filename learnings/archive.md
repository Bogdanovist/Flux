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
