# staging.md

Drained, validated lesson entries awaiting curation. `hooks/drain-to-staging.sh`
appends `pending/` here at session end, and `/curate` reads the entries, then
truncates this file back to this header once every entry has a disposition.

Entries appear below, each opening with a `---` fence. The schema they satisfy
is `scripts/lib/staging-schema.sh`.
---
uuid: 7935ff04-1ce5-4b12-b3a1-f34a14cea723
timestamp: 2026-10-07T10:40:16Z
proposed-text: |
  A solution design that pins a contract against a library on the other side
  of the wire must read that library's own implementation of the protocol
  before writing the contract, and cite the source lines as the fact's check.
  A Tend design wrote a sync contract for WatermelonDB 0.28 from memory of
  its documented shape. A cold review then found three blocking defects in
  node_modules/@nozbe/watermelondb alone: push payloads carry _status and
  _changed on every record and include empty arrays for every table; an
  empty migrations list throws "Missing migration" in development
  (adapters/common.js) where the design assumed a reset; and the losing
  device in a last-write-wins conflict never converges, because
  resolveConflict keeps locally changed columns on pull. The solution-design
  skill could name this as a standing step: for each external library a
  contract touches, read its implementation of that contract.
---
---
uuid: 7fcfe16f-8bcd-4620-b254-abd9ba73ff1b
timestamp: 2026-10-07T20:52:46Z
proposed-text: |
  Inside the Claude Code sandbox on this Mac, the Supabase CLI 
  (`supabase` or `npx supabase`) crashes with a Bun stack trace because 
  the sandbox blocks its write to ~/.supabase/telemetry.json. Pointing 
  HOME at a writable directory, for example HOME=$TMPDIR/sbhome npx 
  supabase db reset, makes it work. Outside the sandbox it needs nothing 
  special. The crash looks like a broken CLI, which it is not.
---
---
uuid: 13147d26-a92e-4719-99b1-510544697e57
timestamp: 2026-10-07T20:52:45Z
proposed-text: |
  Inside the Claude Code sandbox on this Mac, `gh run view --log-failed` 
  fails with "creating cache entry ... operation not permitted", because 
  gh writes its log cache under ~/.cache/gh. Setting 
  XDG_CACHE_HOME=$TMPDIR/ghcache for the command makes it work. A skill 
  or rule that tells agents to read failed CI logs should carry this.
---
---
uuid: 1bd04f4f-4151-4f9f-86d4-512ea69f727e
timestamp: 2026-10-09T10:13:17Z
proposed-text: |
  A nested `claude -p` cannot run inside the Bash sandbox. With
  api.anthropic.com in allowed_domains it still fails with "401 OAuth
  access token has expired", because it cannot refresh the token from the
  sandbox. The charter names `claude -p` as the way to invoke Claude Code
  directly. To compare model tiers on one prompt, the fallback is a
  subagent with a model override, and a subagent carries the house prose
  rules into its output, which contaminates a prompt experiment. A clean
  route needs either sandbox access to the OAuth refresh or a documented
  way to run a bare prompt against a named model.
---
---
uuid: 5d7c6be3-87ba-4654-b4b8-a23ba935ae46
timestamp: 2026-10-10T09:01:31Z
proposed-text: |
  As of October 2026, a new static site created in the Cloudflare 
  dashboard from a Git repo becomes a Worker with static assets, not a 
  Pages project. Its address is <name>.<account-subdomain>.workers.dev, 
  with no random part. Without a wrangler.jsonc, wrangler deploy 
  generates one that serves the output directory with no single-page 
  fallback, so deep links in a single-page app return 404 until the repo 
  carries a wrangler.jsonc with assets.not_found_handling set to 
  single-page-application. Builds of non-production branches run the 
  open-beta wrangler preview command. Turn them off unless previews are 
  actually used, or they leave a red check on every PR.
---
---
uuid: fb3af42b-0d30-4a06-896a-365af7f64fe5
timestamp: 2026-10-10T09:01:30Z
proposed-text: |
  To review a whole project's change after its tracer PRs have each 
  merged to main, push the commit just before the first merge as a base 
  branch and open a draft PR from main into it. The whole diff then has a 
  PR that reviewing-diff can anchor comments to. Close the PR and delete 
  the base branch once a remediation PR answers the findings. 
  reviewing-diff assumes one open PR, and stacked, already-merged slices 
  otherwise leave the combined diff with no place for anchored findings.
---
---
uuid: 24d17234-a240-4fd5-ba13-4edf603e5388
timestamp: 2026-10-10T09:01:29Z
proposed-text: |
  A runbook for a person must order its steps so that no step needs a 
  value a later step creates. A hosting runbook asked for the site's web 
  address in the auth and OAuth steps, while the step that creates the 
  address came after them. The person stopped and asked what the 
  placeholder meant. When writing a runbook, list each value every step 
  consumes and the step that produces it, and sort the steps by that 
  dependency.
---
---
uuid: 05e87835-79fe-494b-a63f-0351c025f0a5
timestamp: 2026-10-11T23:31:21Z
proposed-text: |
  An agent session cannot run a Claude Code config-dir cutover under the
  current Bash sandbox. The write allowlist denies mkdir in $HOME, writes to
  ~/.claude/settings.json and ~/.claude/skills, and any write to a new config
  dir such as ~/.claude-flux, and dangerouslyDisableSandbox is disabled. A
  task brief that moves config dirs must say up front that the person runs
  the write steps with the `!` prefix, or widens the write allowlist for
  that session first.

  The Flux/hooks deny in the sandbox's denyWithinAllow blocks shell writes
  only. The Edit tool wrote to Flux/hooks/*.sh with no prompt. A rule that
  must protect hook files from agent edits needs a permission deny on Edit
  and Write as well.
---
