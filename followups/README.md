# followups/

A central, Flux-wide inbox for things Claude (or you) noticed but
**correctly did not fix in the moment** — a deferred fix too big to fold
in, an ambiguous bit of code that needs human judgement, a "we keep doing
X wrong" smell. The companion to the *fix-broken-windows-inline* rule:
when a fix is genuinely too large or needs a judgement call, it lands
here instead of evaporating in a PR description or a chat scrollback.

This is the **work** sibling of `learnings/`. Where a lesson becomes a
`.claude/` rule (a behaviour change), a follow-up becomes real work — a
fix, a tracer, a flagged decision — or it gets consciously killed.
The inbox's job ends at "this is real."

## The one principle that stops this being a graveyard

Any file you create is a candidate graveyard. The only thing that
prevents it is a recurring ritual that **forces a decision per cluster,
where "kill it, with a one-line reason" is the cheap default.** Most
follow-ups *should* die — that's healthy. The win is that the 1-in-10
that matters becomes real work, and the other 9 die *on the record*
instead of haunting you.

Two forces hold the inbox honest:

- **The trigger** (surfaced by the session-start debt-review nudge)
  guarantees you're nudged to look before the pile rots — when the inbox
  crosses a count or age threshold.
- **Clustering** guarantees that looking is cheap *and* produces leverage:
  three "this is duplicated" / "this test is flaky" items that each die
  on their own merits can cluster into one worthwhile systematic fix. The
  trigger makes you look; clustering makes looking pay.

## The other failure mode: the inbox as escape hatch

A durable sink for deferrals has a second danger, the opposite of the
graveyard: agents punting **core requested work** into it and reporting
the task done. A silent, frictionless file is exactly what enables that —
a punt nobody sees is a punt nobody can challenge. Three guards keep the
inbox an *incidental*-only surface, never an out:

1. **The routing gate.** Only *genuinely unrelated* work reaches the
   inbox. Two things are turned away: work someone was asked to build (or
   an unmet acceptance criterion of it) — finish it; and anything that
   changes, or is already covered by, work already planned — that belongs
   in the plan, where it can still redirect what gets built. The
   route is canonical in `followup` (§The three destinations) and
   enforced by `/followup`.
2. **Announce, don't file silently.** Every agent-initiated filing is
   stated where the human will see it that turn, with a one-line
   non-relevance justification and an urgency — re-adding the friction
   that keeps deferral honest and lets the user veto on the spot.
3. **`/triage` audits for leakage first.** Before clustering, it pulls
   out both misroutes — punted deliverable work, and corrections that
   belonged to the plan they were filed from — and escalates them rather
   than dispositioning them.

## Layout

```text
followups/
├── README.md            ← this file
├── ENTRY-TEMPLATE.md     ← the per-item schema, with a worked example
├── inbox/                ← one file per open follow-up (accumulates)
│   └── <session>-<uuid>.md
└── archive.md            ← the disposition ledger: every item that left
                            the inbox, with what was decided and why
```

`inbox/` deliberately uses one file per item (not one shared append-only
file) so concurrent sessions never collide — each writes its own file,
the same way `learnings/pending/` works.

## Who writes what

| Producer | Writes to |
| --- | --- |
| `followup` (composed from any code-touching skill) | `inbox/*.md` — the durable sink for `[FIX-FOLLOWUP]` and `[FLAG-HUMAN]` tags |
| `/followup` slash command (manual) | `inbox/*.md` |
| `/triage` (the debt-review sitting) | clusters `inbox/`, acts on each cluster, moves processed items to `archive.md` with a disposition |

## The triage ritual — where these actually get dealt with

`/triage` is the combined debt-review sitting. It reads the **whole**
inbox at once, clusters by theme, and forces one disposition per cluster:

The dispositions and their conditions are `triage`'s table; it is the
source of truth for them. In short: **fix-now** lands a commit in the
repo it touches; **project-note** goes to a live project's doc;
**project** opens one with `open-project`; **record** mints one via
`records`; **rule** becomes a pending lesson for `/curate` in the same
sitting; **standing** proposes an edit to the feature index it belongs
to; **kill** archives with a one-line reason, and is the default.

Every item exits the inbox; `archive.md` records the disposition so
nothing silently evaporates and the kill:promote ratio stays visible.
The **rule** disposition is the bridge to `learnings/`: a follow-up
cluster that's really a recurring failure mode becomes a lesson, and
`/triage` runs the lessons curation in the same sitting so recurring
problems and the rules that prevent them are decided together.

## Putting a follow-up in by hand

Run `/followup` from inside Claude Code. With no arguments it prints the
template; with arguments it captures one item. You can also hand-author a
file straight into `inbox/` — any unique `<stem>.md` matching the schema
in `ENTRY-TEMPLATE.md` works. Unlike `learnings/`, capture is
deliberately low-ceremony: there's no schema validator gate, because the
disposition (target, scope, whether it's even worth keeping) is decided
at **triage**, not at capture. Guessing it at capture would be guessing
the answer before the question.
