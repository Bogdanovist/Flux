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
