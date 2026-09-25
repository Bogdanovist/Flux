---
started: 2026-09-25
repos: tend-to-do
---

## Why

Tend (`tend-to-do`) is an Expo / React Native to-do app for recurring tasks
with adaptive cadence. Its last commit is 2026-04-12. Development moves to
Flux, and the repo still carries the agent process it had before Flux: a
forked `rpikit` skill set, a `research-plan-implement` pipeline, and a
half-built "stories" layer. Two processes in one session give an agent two
sets of rules to follow. The cost is drift and misalignment on every task.

The question this project answers: what is the least setup that lets Flux
drive Tend well? The answer may be small. When the setup is done, this
project closes and feature work starts.

## What the repo holds (measured 2026-09-25, `main` at `873bc14`)

- **Code health.** `tsc --noEmit` is clean. `npm test` passes 190 tests in
  25 suites. `npm run test:stories` finds no tests: `src/stories/` does not
  exist. The backend suite needs Docker and was not run. CI state is
  unknown, because the sandbox blocks `api.github.com`.
- **Stories layer.** `.claude/rules/story-testing.md` defines a story as a
  markdown file with YAML frontmatter, one-to-one with a Jest journey test
  whose `describe()` title quotes the story title. `docs/stories/_draft/`
  holds 42 drafts (34 baseline, 8 BUG) that nobody reviewed. No story is
  active, and no story test exists. The `auditing-stories` skill is the only
  check that the pairing holds.
- **Forked process.** `.claude/skills/` holds 17 skills and
  `.claude/agents/` holds 7 agents forked from `rpikit` 0.8.0. Ten of them
  share a name with a Flux skill or agent (`brainstorming`,
  `git-worktrees`, `receiving-code-review`, `systematic-debugging`,
  `verification-before-completion`, `debugger`, `verifier`, `test-runner`,
  `file-finder`, `web-researcher`).
- **Plans.** `docs/plans/` holds 20 research and plan files, 7,024 lines,
  from 2026-04-10 and 2026-04-11. The pipeline meant them to be archived
  after each feature shipped. None were.
- **`CLAUDE.md`** carries the product one-liner, a testing policy, the stack
  and the commands. The repo has no `AGENTS.md`.
- **Hygiene.** `.env` is tracked. It holds local-Supabase keys only
  (`127.0.0.1`), but `EXPO_PUBLIC_SUPABASE_ANON_KEY` holds an `sb_secret_`
  key and `SUPABASE_SERVICE_ROLE_KEY` holds an `sb_publishable_` key: the
  two look swapped. `git worktree list` shows two prunable worktrees at the
  pre-move path `~/src/tend-to-do/`. Commits prefixed `auto:` went straight
  to `main`.
- **A live bug.** `app/task/[id].tsx:114` saves `notes: notes || undefined`,
  so clearing a task's notes does not persist. The BUG draft
  `clear-notes-persists-on-save` found it.

## Stories against Flux

The stories layer solves two problems (design doc
`docs/plans/2026-04-11-spec-alignment-and-story-testing-design.md`):

1. **Spec alignment.** Matt had no place to read, or declare, what the app
   guarantees about ordinary to-do behaviour.
2. **Journey regressions.** Tests covered one unit at a time. No test ran a
   multi-step journey such as reorder, sign out, sign in.

Flux covers most of problem 1 in a different place:

- A plan doc, or a `solution-design` spine, states intent before the build.
  Matt confirms each contract at the point where it is written.
- The spine's assertion register holds each invariant as a Rule with a Test.
  Tracer specs cite register IDs, so coverage can be checked.
- `records` says that once a test holds an invariant, the test is the
  canonical statement ("absorbed → enforcer"). A prose file and a test that
  both state it are two sources of truth.
- Every change lands as a PR with a `reviewing-diff` pass. Matt reviews the
  diff.

Two parts of the stories design conflict with Flux:

- The story file and its test state the same behaviour twice. A skill
  (`auditing-stories`) must then police the pairing. Flux puts the
  statement in one place.
- The design makes stories the review surface "replacing code-diff
  review". The Flux charter has Matt stay on the diff.

Problem 2 is independent of the process. Journey tests are good tests, and
Flux keeps them. The 42 drafts hold real value: a reverse-engineered
description of current behaviour, eight open questions, and eight bugs.

## Decisions (Matt, 2026-09-25)

**D1 — The tests are the behavioural contract.** A test's `describe()` and
`it()` titles state the behaviour it guarantees, and `jest --verbose`
prints the full list. Journey tests live in `src/journeys/__tests__/` and
run under `npm test`. The story markdown, its frontmatter and the
`auditing-stories` skill go. New invariants start as register entries in a
Flux plan or spine, and the slice that builds them writes the test.

**D2 — The drafts.** The live bug `clear-notes-persists-on-save` is fixed
in the setup PR, with a test. The other seven BUG drafts and the eight OPEN
questions go to Matt as a short list; each accepted one becomes a journey
test or a PRD note, and the rest go through `followup`. The 34 baseline
drafts are not backfilled: a journey test is written when a feature
touches that behaviour. Git history keeps the drafts.

**D3 — End-to-end coverage is a goal.** Every feature gets the most
complete end-to-end test the current setup can run. Work does not stop
when the setup cannot run a test. The missing test goes on a "Test gaps"
list in the repo's `AGENTS.md`, with what it needs, and comes off when it
lands.

## Approach

One PR on `tend-to-do`, branch `flux-setup`, reviewed with
`reviewing-diff`:

1. **Agent context.** `AGENTS.md` carries the product one-liner, stack,
   commands, test policy and test gaps. `CLAUDE.md` imports it.
2. **Remove the forked process.** Delete `.claude/skills/`,
   `.claude/agents/`, `.claude/README.md`, `.claude/settings.json` (it
   only disabled `rpikit`, which this machine does not install) and
   `.claude/rules/story-testing.md`. Keep
   `.claude/rules/component-testing.md`.
3. **Delete `docs/plans/` and `docs/stories/`.**
4. **Rename the real-backend suite** from `stories-integration` to
   `journeys-integration`: directory, Jest config, npm script and CI job.
   Drop the `test:stories` script and its CI step.
5. **Hygiene.** Untrack `.env` and add it to `.gitignore`. The key swap
   is in the local `.env` only (`.env.example` holds placeholders), so
   Matt fixes it locally.
6. **Fix the notes bug** in `app/task/[id].tsx`, with a test.

The two stale worktrees at `~/src/tend-to-do/` were pruned with
`git worktree prune` on 2026-09-25, outside the PR.

## Out of scope

- Feature work: adaptive cadence, "what should I do now", LLM onboarding.
- Changes to Flux skills. If Tend shows a gap in Flux, it goes through
  `/learn`.
- A `features/tend/` directory in Flux. Tend is one repo, so its context
  lives in the repo. Revisit only if a fact spans repos.

## Progress

- 2026-09-25: setup PR raised, https://github.com/Bogdanovist/tend-to-do/pull/3.
- 2026-09-25: CI on `main` fails every nightly run (checked runs
  2026-09-20 to 2026-09-24):
  - The unit job runs `npx expo doctor`, which Expo no longer supports
    ("please use npx expo-doctor"). The job stops there, so no unit test
    has run in CI. PR #3 fails at the same step.
  - Run locally, `npx expo-doctor` reports duplicate `@expo/ui`:
    `expo-widgets@^55` (an SDK 55 package, `@expo/ui ~55.0.11`) beside
    the app's `@expo/ui ~0.2.0-beta.9` for SDK 54. No stable
    `expo-widgets` release exists for SDK 54; 55.0.0 shipped 2026-02-25.
  - The backend and nightly jobs hit Docker Hub rate limits on
    `supabase start`, then fail on missing `SUPABASE_*` env: the CI
    config reads them from repo secrets.
  - The nightly journeys job fails with
    `LokiMemoryAdapter is not a constructor`.
- 2026-09-25: PR #4, https://github.com/Bogdanovist/tend-to-do/pull/4,
  upgrades to Expo SDK 55, stacked on PR #3. Locally: tsc clean,
  expo-doctor 20/20, Jest 191/191, and the web export exits in about 15 s
  with single-page output. CI now runs on pull requests into any branch.
- 2026-09-25: CI run 36084066810 on PR #3 (`29c588e`): the key export
  works and `npm run test:backend` passes 46 of 47. The failure is a
  product bug. `public.tasks.id` is `UUID`
  (`supabase/migrations/00001_create_schema.sql:42`). WatermelonDB's
  default ids are 16-character strings (a client task got
  `vG7jsM2aNuwf5SaY`). The sync function inserts pushed records with the
  client id (`supabase/functions/sync/index.ts:232`), so pushing a
  device-created record fails with Postgres `22P02`. The other sync tests
  send `crypto.randomUUID()` ids and miss it. The Android Maestro smoke
  job hit its 30-minute limit.
- 2026-09-25: Matt chose client-side UUID ids, with no device data to
  migrate. PR #5, https://github.com/Bogdanovist/tend-to-do/pull/5,
  stacked on PR #4, registers `expo-crypto`'s `randomUUID` as
  WatermelonDB's id generator. The client sync tests no longer overwrite
  ids. Locally: Jest 192/192. The backend push tests run only in CI.
  Merge order: #3, #4, #5.
