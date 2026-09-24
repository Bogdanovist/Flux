# learnings/

The staging area for lessons that Flux workflows propose adding to
repo guidance. Provider-neutral lessons usually land in `AGENTS.md` or
checked-in project docs; provider-specific lessons can still land in
Claude-specific rule files when that is the consumed surface.

## What lives here

```text
learnings/
├── README.md                 ← this file
├── ENTRY-TEMPLATE.md         ← the schema, with a worked example
├── pending/                  ← per-entry temp files awaiting drain
│   ├── <session-id>-<uuid>.md
│   └── .rejected/            ← entries the drain hook refused
│       └── <session-id>-<uuid>.md
├── staging.md                ← drained, validated entries awaiting curation
├── evidence.md               ← distilled ledger: one record per recurring
│                               theme; the only accumulated history a
│                               curation pass loads (see its own header)
└── archive.md                ← cold store: every processed lesson verbatim,
                                tagged by disposition; never read by a pass
```

Two filenames are **not** tracked in git (see `.gitignore`):

- `learnings/.curation-needed` — sentinel written by the
  curation-trigger script when the volume or time threshold is
  crossed. Its presence is a flag, not state; consumers read its
  existence, not its contents.
- `learnings/staging.lock` — `flock` file the drain hook uses to
  serialise appends across concurrent sessions.

## Who writes what

| Producer                         | Writes to                       |
| -------------------------------- | ------------------------------- |
| Emission-site skill (per-action) | `learnings/pending/*.md`        |
| `/learn` slash command (manual)  | `learnings/pending/*.md`        |
| Drain hook (Stop-hook)           | `learnings/staging.md`, removes the drained pending file, OR moves it under `learnings/pending/.rejected/` if validation fails |
| Curation-trigger script          | `learnings/.curation-needed`    |
| `curator` analyst (read-only)    | Reads a snapshot of `staging.md` + `evidence.md`, clusters lessons by theme, drafts ranked change proposals. Writes nothing. |
| `/curate` conductor              | Walks proposals past the user one at a time; raises one PR per approved proposal; writes the theme records to `evidence.md`, appends every processed lesson verbatim to `archive.md` (tagged `[promoted]`/`[rejected]`/`[pending]`), truncates `staging.md` |

Nothing else writes to `staging.md`, `evidence.md`, or `archive.md`
directly. Emission sites never bypass the drain hook — the drain hook is
the only validator-aware writer.

## Where do I put a lesson by hand?

Run `/learn` from inside an agent session. Without arguments it prints the
schema template for you to fill in and re-invoke. With arguments it
takes the four positional fields:

```text
/learn <target> <scope> <rationale> <proposed-text>
```

The slash command writes a fully-formed entry to
`learnings/pending/` using the same atomic-rename pattern as the
automated emission sites; the next Stop-hook cycle drains it.

You can also hand-author a file directly into `learnings/pending/` if
you prefer — name it `<session-id>-<uuid>.md` (any unique stem with
a `.md` extension will do for a manual entry; see
`ENTRY-TEMPLATE.md` for the full front-matter schema). The drain
hook is indifferent to provenance: any file under `pending/` that
matches the schema and clears the blocklist gets appended on the
next drain.

## What happens when staging gets big?

The drain hook calls `curation-trigger.sh` after every successful
append. The trigger writes the `.curation-needed` sentinel when:

- `staging.md` contains **15 or more entries**, OR
- the oldest entry in `staging.md` is **7 or more days old**.

When the sentinel exists, the `debt-review-nudge.sh` SessionStart hook
(registered in `settings.json`) injects a one-line `Run /curate`
directive into the next session before the user's first message is
processed. The same hook also surfaces the follow-ups inbox when it
crosses its own count/age threshold, so a single session-start banner
covers both stores feeding `/triage`. The reminder is a nudge, not a
gate — it never blocks the session.

Curation itself is invoked explicitly via the `/curate` slash command
(or as Stage 2 of `/triage`, the combined debt-review ritual). A
read-only `curator` analyst reads a copy-truncated snapshot of
`staging.md` plus the distilled `evidence.md` ledger, clusters the
lessons by **theme** (the captured `target` is only a hint), and drafts a
ranked queue of change proposals — each a three-part case: the evidence
it's worth fixing, the specific minimal change and where it lands, and why
that change will actually be consumed in operation. The `/curate`
conductor then walks the proposals past the user **one at a time**, and
raises **one PR per proposal the user approves** — there is no auto-PR and
no per-file dumping. Every lesson, proposed or not, folds into a theme
record in `evidence.md` so its evidence keeps accumulating across passes,
and is copied verbatim into the cold `archive.md`. Nothing auto-applies.

## Validation contract

`scripts/lib/staging-schema.sh` defines the gate every entry must
pass before being appended to `staging.md`:

- **Schema fail** (exit 1) — missing or malformed required field
  (`uuid`, `timestamp`, or `proposed-text`) or non-v4 UUID. `target`,
  `scope`, and `rationale` are advisory hints accepted at filing time;
  the curator's edit-path guard validates the destination it actually
  chooses later.
- **Blocklist hit** (exit 2) — `proposed-text` body contains a
  case-insensitive match for any operational-footgun phrase
  (`--no-verify`, `force push`, `skip tests`, `ignore failing
  tests`, `always override`, `disable tests`) or
  prompt-injection-shaped phrase (`ignore/disregard/forget …
  instructions`, `<system>`, `<instructions>` tag variants).
  Patterns are phrase-level, so discipline-strengthening lessons
  like "Never ignore type errors" pass cleanly.
- **PASS** (exit 0) — appended to `staging.md`, temp file removed.

Rejected entries are moved to `learnings/pending/.rejected/<name>`
with a `# REJECTED: <reason>` header prepended. They are never
silently dropped.

## Where a proposal can land

When you approve a proposal, `/curate` applies it to one of:

- **A project repo** — its `AGENTS.md`, `CLAUDE.md`, or
  `.claude/<path>.md`. The repo qualifies when it has a checkout under
  `$FLUX_SRC_ROOT`, which is also the only state in which the curator can read the
  text it proposes to change. The change goes on a `lessons/*` branch and
  through a PR, like any other change to that repo.
- **Flux** — additionally `agents/<name>.md`, `skills/<skill>/SKILL.md` and
  `model-profiles.toml`. The wider surface is needed because Flux's sources
  of truth load into every session from outside `.claude/`. These commit
  straight to `main`, as every Flux change does.

Both surfaces are enforced by `target_shape_valid` in
`scripts/lib/staging-schema.sh`, called by
`scripts/lib/assert-curator-edit-allowed.sh` before every edit the curator
makes. A path outside them fails closed.
