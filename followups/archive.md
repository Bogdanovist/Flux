# archive.md

Every follow-up that left the inbox, with the disposition `/triage` gave it.
Written only during a triage pass, so that one writer appends at a time.
Entries appear below, newest last.

---
disposition: fix-now — e34f4b3 adds ~/.npm and ~/.expo to sandbox allowWrite (Matt approved 2026-09-25)
---
uuid: ff92f9cd-abd3-419b-af24-ac5c871958c0
timestamp: 2026-09-25T05:17:50Z
repo: flux
kind: fix-followup
urgency: whenever
summary: Sandboxed npm cannot write its cache in ~/.npm, so every install fails until npm_config_cache is overridden
---

## Evidence

- `npm create vite@latest` inside the sandbox failed (2026-09-25), and npm
  advised `sudo chown -R 502:20 "/Users/matthumanhealth/.npm"`. That advice
  is wrong for this machine: `ls -lnd ~/.npm ~/.npm/_cacache` shows owner
  502, and `find ~/.npm/_cacache -maxdepth 3 ! -user 502` finds 0 files.
- `touch ~/.npm/_cacache/.probe` in the sandbox gives `Operation not
  permitted`. The sandbox write allowlist names only `~/.npm/_logs`.
- Workaround used: `npm_config_cache=$TMPDIR/npm-cache` on each command.
  Every session downloads every package again, and each agent has to
  rediscover the workaround.

Fix options: add `~/.npm` to `sandbox.filesystem.allowWrite` in Flux
`settings.json`. That widens the sandbox, so Matt decides. The other
option is to set `npm_config_cache` to a writable path in the settings
`env` block.

## Source

Found while scaffolding the Lines-on-Maps web prototype (project lom-mvp,
Lines-on-Maps PR 1).

Not this work's business because it is Flux sandbox configuration that
affects every repo, and the choice between the fixes is Matt's.

---
disposition: killed: already fixed in 291e814 — explore-problem now points at <repo>/context/projects/<slug>/ and the open-project contract
---
uuid: 53bb16c8-abb7-4c6b-82b5-f46fda682e8b
timestamp: 2026-09-25T05:54:21Z
repo: flux
kind: fix-followup
urgency: whenever
summary: explore-problem tells explorations to take a Flux branch; open-project and the charter say commit project docs to main
---

## Evidence

`skills/explore-problem/SKILL.md` §The working doc: "Give it its own `<slug>`, its
own Flux worktree and branch", and claims `open-project` carries "the
branch-and-PR path". `skills/open-project/SKILL.md` §Where the doc is written
says to commit the doc straight to `main`, and AGENTS.md §Review says Flux
ships straight to `main`. The two skills contradict each other.

## Source

While opening `projects/v2v-exploration/findings.md` (commit 87aea22). I
followed open-project and the charter and committed to `main`.

Not this work's business because the fix is an edit to a checked-in skill,
which the charter reserves for a deliberate pass.

---
disposition: killed: already decided — tend-to-do context/projects/tend-dev-flow/findings.md D4 (2026-10-07)
---
uuid: b59370ff-9ee7-4b20-89fc-ccb7466e72e1
timestamp: 2026-09-25T05:25:10Z
repo: tend-to-do
kind: flag-human
urgency: whenever
summary: tend-to-do behaviour questions from the retired draft stories — 7 proposed bug fixes and 8 open questions await Matt's call
---

## Evidence

The draft story index at tend-to-do commit `873bc14`,
`docs/stories/_draft/INDEX.md` (read with
`git -C $FLUX_SRC_ROOT/tend-to-do show 873bc14:docs/stories/_draft/INDEX.md`),
lists behaviour an agent reverse-engineered from the code on 2026-04-11.
PR #3 (merged 2026-09-25) removed the drafts. PR #3 fixed one BUG story,
`clear-notes-persists-on-save`. These remain undecided:

Proposed bug fixes (each draft has a "Current buggy behaviour" section):
- `auth/duplicate-email-signup-shows-clear-error` — sign-up with a
  registered email creates a silent shadow user.
- `task-crud/uncomplete-restores-pending-reminder` —
  `src/database/operations/tasks.ts`: completeTask cancels the reminder;
  uncompleteTask does not re-arm it.
- `task-crud/empty-notes-stored-canonically` — `null` and `''` both
  mean "no notes" (createTask stores `''` as given; saving a cleared
  field stores `null`).
- `task-crud/new-task-appears-at-end-of-current-list` — new-task
  `sort_order` is computed across all lists, not within the list.
- `task-crud/uncomplete-is-idempotent` — un-completing an active task.
- `search/search-excludes-completed-by-default` — search returns
  completed tasks.
- `sync/sync-indicator-visible-on-every-screen` — the sync indicator is
  mounted only on the main tasks tab.

Open questions: whether search includes completed tasks (3 stories
depend on it); whether sign-out keeps the local database (2 stories);
whether quick-add should stay open for repeated adds; whether the reorder
API should skip a same-position move; whether title trimming belongs in
one layer; which task-to-list assignment path a journey test covers.

Each accepted item becomes a journey test in
`src/journeys/__tests__/` (fixing the code where needed) or a PRD note.

## Source

Found while closing the Flux project `tend-setup`, which retired the
story layer. Not that project's business because it set up how Tend is
worked on; these are product behaviour decisions for Matt.

---
disposition: fix-now — 3b0c88a resolves each git segment's directory in shell order (Matt approved 2026-10-07)
---
uuid: ab4defe2-f125-45f5-9b3c-83a15e85423c
timestamp: 2026-10-07T10:22:49Z
repo: flux
kind: fix-followup
urgency: blocks-now
summary: resolve_command_dir takes the last cd in the whole command, so shared-checkout-guard fails open on a sweep that ends with cd elsewhere
---

## Evidence

`scripts/lib/bash-command.sh:77-111` — `resolve_command_dir` returns the
directory of the last `cd` anywhere in the command (a `git -C` overrides
it). It does not check whether the `cd` comes before or after the git
segment. A relative `cd` resolves against the hook process's own cwd.
`scripts/tests/test-bash-command.sh:67` encodes this as "last cd wins".

The curator analyst fed `hooks/shared-checkout-guard.sh` synthetic hook
JSON with `.cwd` = Flux on 2026-10-05:

- `cd /…/Flux && git add -A && git commit -m x && cd /tmp` → allowed (fails open)
- `git add -A && cd /tmp` → allowed (fails open)
- `cd <worktree> && git commit -qam msg && cd -` → blocked (false block)
- `cd <worktree> && git commit -qam msg && cd $FLUX_DIR` → blocked (false block)

Lesson c7a7b421 (2026-09-25) reported the false block in real use.
`hooks/git-fetch-freshness.sh` uses the same function.

Fix: resolve the directory per git segment. Walk the segments in order,
track the running directory from `.cwd`, resolve a relative `cd` against
it, and apply a `git -C` override per segment. Replace the "last cd wins"
test with tests for the four cases above.

## Source

A /curate pass on 2026-10-05, while the analyst checked lesson c7a7b421.

Not this work's business because a curation pass lands guidance edits.
A parser rewrite with tests is a code change that needs its own diff.

---
disposition: fix-now — Matt ran gh auth setup-git and set gh git_protocol https (2026-10-08); a sandboxed gh repo clone used https and a dry-run push authenticated
---
uuid: 86d5f592-7d89-4b7d-b45a-4adc690f80ca
timestamp: 2026-10-07T10:22:49Z
repo: flux
kind: fix-followup
urgency: before-this-project-ends
summary: a repo an agent clones into the Flux root cannot push from the sandbox (no global gh credential helper), and gh still clones over SSH
---

## Evidence

- Lesson 5c027644 (2026-09-25): a plain `git clone https://…` of
  voice-to-vibe could not push. osxkeychain gave "failed to store: 100001",
  then "could not read Username … Device not configured". It was fixed by
  hand with a local credential helper.
- `git config --show-scope` (2026-10-05): tend-to-do and Flux carry a
  *local* `credential.helper` = `''` then `!gh auth git-credential`.
  The global config holds only the system `osxkeychain` helper. Nothing in
  Flux sets the helper (`grep -rn git-credential` found nothing).
- `~/.config/gh/hosts.yml` still has `git_protocol: ssh`, so
  `gh repo clone` fails over SSH in the sandbox (lesson 522241a6,
  rejected 2026-09-25 as "better fixed" with no fix applied).
- `skills/open-project/SKILL.md:10` tells agents to "clone it beside Flux
  first", so every new repo meets both failures.

Fix: Matt runs `gh auth setup-git` and
`gh config set -h github.com git_protocol https` outside the sandbox. Both
write outside the sandbox's write allowlist. Optionally `setup.sh` checks
both and warns. No skill prose needs to change.

## Source

A /curate pass on 2026-10-05, from lessons 5c027644 and 522241a6.

Not this work's business because the fix is machine config that only Matt
can apply.

---
disposition: killed: the hooks/ write protection is a side effect of the ~/.claude links, not a Flux boundary; diff review and the pre-commit suites guard scripts/lib (Matt, 2026-10-08)
---
uuid: 88c533e9-b5d8-4e7b-a808-89623485ce8c
timestamp: 2026-10-07T11:05:21Z
repo: flux
kind: flag-human
urgency: whenever
summary: the sandbox write-protects hooks/ but not scripts/lib/, which the hooks source, so an agent can change a guard's behaviour without touching hooks/
---

## Evidence

On 2026-10-07 an edit to `scripts/lib/bash-command.sh` succeeded from
sandboxed Bash. A write to `hooks/shared-checkout-guard.sh` in the same
session failed with "Operation not permitted". `hooks/shared-checkout-guard.sh`
and `hooks/git-fetch-freshness.sh` both `source` the library from the
checkout, so the uncommitted library edit changed the live guard for every
session until it was restored. The sandbox `denyWithinAllow` list names
`Flux/hooks` and `Flux/agents`; it does not name `Flux/scripts/lib`.
`hooks/drain-to-staging.sh` sources `scripts/lib/staging-schema.sh` the same way.

Options: add `Flux/scripts/lib` (or the files the hooks source) to the
sandbox write deny list, which also blocks curator and triage edits to the
validators; or accept the gap, because hooks/ protection guards against
accidents and the library change still needs a commit.

## Source

Triage pass on 2026-10-07, while fixing follow-up ab4defe2 (per-segment
directory resolution).

Not this work's business because the choice is a sandbox setting, which is Matt's.
