---
uuid: 00000000-0000-4000-8000-000000000000
timestamp: 1970-01-01T00:00:00Z
repo: sideproject
kind: fix-followup
urgency: whenever
summary: One line naming the thing — enough for clustering at triage.
---

## Evidence

<!-- The same evidence bar as `followup` §The evidence bar: what you
     actually saw. file:line references, trimmed command output,
     git-blame age, the contradictory test (or its absence). "Looks wrong
     to me" is not evidence — if that's all you have, the kind is
     flag-human. -->

`path/to/file.py:123` — what's there and why it surprised you.

## Source

<!-- Where this surfaced, so triage can recover the context fast:
     PR number, branch, the task you were doing when you hit it. Then the
     non-relevance statement — one line on why this is not the current
     work's business, which is what makes the filing legitimate rather
     than a punt. See `followup` §The three destinations. -->

While doing <X> on <branch / PR #>.

Not this work's business because <why — it neither changes nor is covered
by anything already planned>.

<!--
  Schema reference
  ----------------

  A follow-up entry is a YAML front-matter block (between the two `---`
  fences) plus a free markdown body. Six front-matter fields:

    uuid       RFC 4122 v4 UUID, lowercase. Provenance + de-dup key.
               Generated at capture: `uuidgen | tr 'A-Z' 'a-z'`.

    timestamp  ISO 8601 UTC (`YYYY-MM-DDTHH:MM:SSZ`) at the moment of
               capture: `date -u +%Y-%m-%dT%H:%M:%SZ`. Drives the inbox
               age signal that the session-start debt-review nudge uses
               to flag a triage.

    repo       Which repo the follow-up concerns — a project repo's
               checkout name, `flux`, or whatever is accurate. Not gated:
               a follow-up about any repo is valid, and where it can go is
               a triage decision rather than a capture one.

    kind       One of:
                 fix-followup — verified broken, too big / off-topic to
                                fold into the current change. Wants to
                                become work (a fix or a tracer).
                 flag-human   — ambiguous: maybe-broken, maybe-correct-
                                for-reasons-you-lack-context-for, load-
                                bearing-looking. Wants a human glance
                                that usually ends in kill. **Default
                                when in doubt** — same bias as
                                `followup`.

    urgency    One of `blocks-now`, `before-this-project-ends`,
               `whenever`. Unrelated is not the same as unimportant: an
               item filed here can still be a quick fix worth doing now,
               or a problem that outranks the work in flight. Without
               this field the inbox reads uniformly as "after the current
               work finishes", which is only true of `whenever`. Default
               `whenever`; set it deliberately when filing on someone's
               behalf.

    summary    One line. This is what clustering reads, so make it name
               the *thing* ("duplicate retry logic in X and Y"), not the
               feeling ("something off with retries").

  The body is free markdown. Keep the Evidence and Source headers — they
  are what makes a follow-up actionable at triage rather than a vague
  note that gets killed for lack of context.

  Why no validator gate (unlike learnings/)
  -----------------------------------------

  The lessons pipeline validates at capture because a lesson's fields
  (target file, scope verb, proposed prose) ARE the answer — the curator
  acts on them mechanically. A follow-up's answer (fix / tracer / rule /
  kill) is the *output* of triage clustering, not an input. Validating it
  at capture would force a guess. So capture here is intentionally cheap;
  the discipline lives in the triage ritual.

  How to emit a follow-up from a skill
  ------------------------------------

  1. uuid="$(uuidgen | tr 'A-Z' 'a-z')"
  2. timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  3. The inbox is ALWAYS Flux-central — never the repo you happen to
     be working in. Use the absolute path
     `~/src/Flux/followups/inbox` (mkdir -p it).
     Do NOT resolve via `$CLAUDE_PROJECT_DIR`: an implementer or session
     running in a project worktree would otherwise scatter follow-ups
     into that repo instead of the one central inbox.
  4. Write to "<inbox>/<session>-<uuid>.md.tmp" via the Write tool, then
     `mv` to drop the `.tmp` — the atomic rename keeps any reader from
     seeing a half-written file. `<session>` is any short unique token
     (e.g. `head -c 4 /dev/urandom | xxd -p`).

  The body is this front-matter block with the five fields filled in,
  plus the Evidence and Source sections.
-->
