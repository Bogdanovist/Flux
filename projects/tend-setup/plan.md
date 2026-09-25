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

## Approach (proposed — decisions below need Matt)

Land the setup as one PR on `tend-to-do`, reviewed with `reviewing-diff`:

1. **Agent context.** Replace `CLAUDE.md` with `AGENTS.md` (product
   one-liner, stack, commands, test policy) and a thin `CLAUDE.md` that
   imports it, as Flux does. Point at `docs/prd.md` for the why.
2. **Remove the forked process.** Delete `.claude/skills/`,
   `.claude/agents/`, `.claude/README.md`, and the `rpikit` line in
   `.claude/settings.json`. Keep `.claude/rules/component-testing.md`,
   which is repo-specific.
3. **Delete `docs/plans/`.** Git history keeps the files.
4. **Hygiene.** Untrack `.env` and add it to `.gitignore`. `.env.example`
   holds placeholders only, so the swap is local: fix it in the local
   `.env`. Prune the two stale worktrees.
5. **Stories and test policy** — decision D1.
6. **The eight BUG drafts and eight OPEN drafts** — decision D2.

## Decisions for Matt

**D1 — Where does "what the app guarantees" live?** This sets the test
policy that every later feature follows.

- **(a) The journey test is the contract. Recommended.** Drop the story
  markdown, its frontmatter and the audit skill. A journey test keeps the
  readable shape: the `describe()` title states the behaviour, and a
  comment per step reads as the steps. `jest --verbose` prints the full
  list of guarantees, so a readable index comes from the tests and cannot
  drift. New invariants start as register entries in a Flux plan or spine,
  and the tracer that builds them writes the test. Cost: Matt reads
  behaviour in test files or test output, not in prose files, and has no
  editable place to declare a behaviour change outside a plan doc.
- **(b) Keep stories as the contract.** Promote the approved drafts, write
  a Tier-1 test for each, and keep `auditing-stories`. Cost: two sources
  of truth per behaviour, a repo skill that duplicates the Flux review
  loop, and 42 tests to write before feature work.
- **(c) Keep a few stories.** Stories only for cross-screen journeys, with
  no audit skill. Cost: the same two-source problem at a smaller size,
  and a line between "story" and "test" to argue on every change.

**D2 — The 42 drafts.** They must go somewhere before the directory is
removed, if D1 is (a) or (c).

- The bug `clear-notes-persists-on-save` is live. Fix it in the setup PR,
  with a test.
- The other seven BUG drafts and the eight OPEN questions go to Matt as a
  short list. Each one he accepts becomes a journey test (fixing the code
  where needed) or a note in the PRD. The rest go through `followup`.
- The 34 baseline drafts describe current behaviour. Where an existing test
  already covers one, it adds nothing. The rest are candidates for journey
  tests. Recommendation: do not backfill them all now. Write a journey
  test when a feature touches that behaviour.

**D3 — The testing policy in `CLAUDE.md`.** It mandates full-stack E2E for
every feature, a render test for every `.tsx` file, and Maestro flows in
CI on Android and iOS. Keep it as is, or trim it to what CI runs today?
The Maestro jobs are unverified (CI was not visible from here).

## Out of scope

- Feature work: adaptive cadence, "what should I do now", LLM onboarding.
- Changes to Flux skills. If Tend shows a gap in Flux, it goes through
  `/learn`.
- A `features/tend/` directory in Flux. Tend is one repo, so its context
  lives in the repo. Revisit only if a fact spans repos.
