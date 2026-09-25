# Flux

Flux is the agent configuration repo for my personal projects. It holds the
global instructions, the skills, the subagents, the hooks, the model tiers, and
the version-controlled context that shape how agentic coding sessions behave.

It ships no product code. It is the operating system for the agent: how it
works, what it knows, and where its accumulated context lives.

## What's in here

| Path | What it is |
|---|---|
| `AGENTS.md` / `CLAUDE.md` | The charter. `AGENTS.md` is the provider-agnostic source; `CLAUDE.md` imports it and carries only Claude-specific loading notes. |
| `settings.json` | Claude Code settings, env vars, and hook wiring, merged into the user's own settings file. |
| `settings.local.json` | This machine's permissions, env and hooks, merged after `settings.json` — gitignored, never pushed. |
| `skills/` | Every skill, flat, one directory each. All of them install; nothing gates which are active. |
| `agents/` | Subagent definitions — researcher, debugger, verifier, curator, test-runner, and the rest. |
| `model-profiles.toml` | The `best` / `mid` / `cheap` tier contract and its provider mappings. |
| `hooks/` | Lifecycle hooks — checkout sync, skill relink, the debt-review nudge, the lessons drain, auto-commit-push, the shared-checkout guard, the secrets scan. |
| `projects/` | One directory per multi-session piece of work, archived on close. |
| `features/` | The durable cross-repo layer: feature indexes and their decision and fact records. |
| `learnings/` | The pipeline that turns session lessons into guidance changes. See `learnings/README.md`. |
| `followups/` | The inbox for deferred fixes and judgement calls, drained by `/triage`. See `followups/README.md`. |
| `reminders/` | Work already scheduled for a date, which nags from that date until the file is deleted. |
| `curation/` | The promotion bar, the sweep and code-review ledgers, and per-machine skill-usage telemetry. |
| `scripts/` | Worktree reaping, the skill-usage rollup, the curator's deterministic guards, and the shell test suites. |
| `setup.sh` | Installs the config onto a machine. |

## Install

```bash
git clone git@github.com:Bogdanovist/Flux.git ~/src/personal/Flux
~/src/personal/Flux/setup.sh
```

Clone Flux wherever suits the machine. The directory that holds the clone is
the Flux root: every repo Flux works on sits beside it there, and hooks and
scripts touch nothing outside it. `setup.sh` writes both paths into
`settings.local.json` as `FLUX_DIR` (the clone) and `FLUX_SRC_ROOT` (its
parent). Claude Code passes them to every hook and Bash command, and skills
name paths through them.

`setup.sh` links `AGENTS.md`, `CLAUDE.md`, `agents/` and `hooks/` into
`~/.claude`, links each skill into `~/.claude/skills/`, installs the repo's
pre-commit hook, and backs up anything it replaces. Re-run it any time; it
converges.

Claude Code reads one user-level settings file, `~/.claude/settings.json`.
A `settings.local.json` beside it applies only to sessions started in `~`.
So Flux merges into the user file: first the tracked `settings.json`, then
this machine's `settings.local.json`. `scripts/merge-settings.sh` holds the
rules. `setup.sh` runs the merge, and the SessionStart sync hook runs it
again after each pull. Claude Code reloads the user file when it changes, so
the running session picks up most changes, hooks and permissions included.

**On a machine that already carries another config repo**, give Flux its own
config dir instead, because two config repos cannot both own `~/.claude`:

```bash
FLUX_CLAUDE_DIR=~/.claude-flux "$FLUX_DIR/setup.sh"
CLAUDE_CONFIG_DIR=~/.claude-flux claude       # start a personal session
```

`CLAUDE_CONFIG_DIR` relocates the whole config dir the CLI reads, so the two
installs never see each other. Setup also refuses to replace a link that
points into another config repo, and says so rather than breaking that
install.

Pull updates with a normal `git pull`; the SessionStart hook fast-forwards the
checkout on its own, and changes take effect on the next session.

## How it works

**Flux ships straight to `main`.** Edit, commit by explicit path, push. A
branch here needs a stated reason. Project repos work the other way: a feature
branch, a PR raised when the slice is built, `reviewing-diff` posting its
findings as PR comments, and my merge as the approval. An agent never merges
and never approves.

**The Stop hook is a backstop, and it treats the two repo shapes
differently.** In Flux it pushes what the session committed and names what is
still uncommitted, because every session shares this one checkout and a sweep
here would commit another session's half-written file. In a project worktree
it moves uncommitted work onto a fresh branch and commits it there, so nothing
lands on `main` without a PR. Commit your own work by path as you go; the hook
is what gets it to origin.

**Skills carry the methodology; repo docs carry the specifics.** A skill here
is globally authoritative, and a project repo's `.claude/` does not shadow it.
Repo-specific guidance lives in that repo's `AGENTS.md`, its checked-in
`.claude/rules/*.md`, or its project docs.

**Model selection uses tiers, not provider names.** Skills request `best`,
`mid` or `cheap`; `model-profiles.toml` maps those to a provider's models.
Keep provider-specific model IDs in that file, never in skill prose.

**Context is version-controlled, not remembered.** Auto memory is off.
Anything worth persisting lands in one of the stores above: a project doc, a
feature record, or the `learnings/` pipeline when it is a behaviour change.

**The weekly pass is nudged, not scheduled.** `hooks/debt-review-nudge.sh`
reads the follow-up inbox, the lessons pile and the reminders at session start,
and says one line when any of them is due. `/triage` clusters the inbox and
`/curate` clears the lessons.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)
- Git and the [GitHub CLI](https://cli.github.com/) (`gh auth login` — the push path needs it)
- `jq`, which every hook uses to read and write its JSON
- Node.js 18+

## Tests

The shell suites cover the hooks and libraries that run on every session:

```bash
scripts/tests/run-all.sh
```

`hooks/pre-commit.sh` runs them whenever a commit touches `hooks/` or
`scripts/`. Two suites assert that a hook fails safely on an unwritable
directory, so run them as your own user: as root, the chmod they rely on does
not bite and both report a false failure.
