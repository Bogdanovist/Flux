---
name: learn
description: "Capture a single durable lesson from the current session into the learnings staging pipeline. Use when a reusable insight surfaces that doesn't naturally fit the automated emission sites — file it here in plain prose and the curator routes it on the next curation pass."
user-invocable: true
argument-hint: "<the lesson, in plain prose>   (leave blank for a one-line reminder)"
---

# /learn

Manual entry point into the lessons-curation pipeline. Writes one
pending file under `learnings/pending/`. The session-end drain validates
it and appends it to `learnings/staging.md`; `/curate` then has the
`curator` subagent cluster it by theme and propose where it should land.

This is the **only** way to file a lesson by hand — the automated
emission sites (`reviewing-diff`, `systematic-debugging`) cover
their own surfaces; this command covers
everything else.

Filing is deliberately quick: **type the lesson in plain prose.** You do
not need to name a destination file, a scope verb, or any structure. The
curator clusters by theme and picks the destination at promote time, so a
hand-supplied `target` was almost always wrong and is no longer asked
for. If you want to *suggest* a home or a reason, just say so in the
prose — the curator reads it.

## Invocation

```text
/learn                       # print a one-line reminder, then stop
/learn <the lesson, in plain prose>
```

## Behaviour

Read `$ARGUMENTS` first. Branch on whether it is empty or non-empty.

### Empty `$ARGUMENTS` — print the reminder

When the user invokes `/learn` with no arguments, print exactly:

> Type the lesson in plain prose: `/learn <what you learned>`. No
> destination or structure needed — just the insight, written so a
> future reader with no memory of this session understands it.

Then stop. Do not write a file.

### Non-empty `$ARGUMENTS` — write the lesson

1. **The whole of `$ARGUMENTS` is the lesson body.** No field splitting,
   no separators. The only check: it must be non-empty after trimming
   whitespace. If it is empty, print "Nothing to capture — give me the
   lesson in prose." and stop.

   Write it as evergreen prose: a future reader sees only this text, with
   no memory of the session that produced it. Avoid references to "this
   PR", "today", "the change above".

2. **Generate UUID and timestamp** with the Bash tool:

   ```bash
   uuid="$(uuidgen | tr 'A-Z' 'a-z')"
   timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   ```

3. **Write the pending file.** The pending directory is
   `~/src/Flux/learnings/pending` (`mkdir -p` it if missing) — always
   the Flux repo, whatever repo the session runs in: the drain reads only
   Flux's pending pile, so a capture written into a project repo's tree
   is a capture nothing ever reads. Filename:

   ```text
   <session-id>-<uuid>.md
   ```

   `<session-id>` is any short token unique within the directory —
   `head -c 4 /dev/urandom | xxd -p` is the documented fallback.

   Use the Write tool to create the file at the `.tmp` path. The body is
   three required fields — `uuid`, `timestamp`, and the `proposed-text`
   block scalar holding the lesson. **Indent every line of the lesson
   body by two spaces** (the `|` block-scalar contract):

   ```text
   ---
   uuid: <uuid>
   timestamp: <timestamp>
   proposed-text: |
     <the lesson prose, every line indented two spaces>
   ---
   ```

   (`target`, `scope`, and `rationale` are optional advisory hints. Omit
   them unless the user explicitly supplied one — a wrong hint is worse
   than none.)

4. **Validate the written file** against the same library the drain
   uses, so a green `/learn` is guaranteed to survive it. Run the
   validator **in a bash subshell** — the library is `#!/usr/bin/env
   bash` and sourcing it into the ambient zsh login shell mis-resolves
   its helpers (`command not found: head`) and falsely rejects a valid
   entry:

   ```bash
   bash -c 'source "$1"; validate_staging_entry "$2"' _ \
     $HOME/src/Flux/scripts/lib/staging-schema.sh \
     "$tmp_path"
   ```

   On non-zero exit, forward its stderr to the conversation, `rm
   "$tmp_path"`, and stop. Do NOT rename the file into place. (Exit 1 =
   schema, e.g. missing body; exit 2 = the content blocklist — a banned
   prompt-injection or verification-weakening phrase in the lesson.)

5. **Atomic rename into place.** Only on validator PASS:

   ```bash
   mv "$tmp_path" "$write_path"
   ```

   The atomic rename keeps the drain from racing a half-written
   file.

6. **Commit and push the capture**, by explicit path, so the lesson
   reaches main without depending on anything else happening:

   ```bash
   git -C ~/src/Flux add learnings/pending/<filename>
   git -C ~/src/Flux commit -m "learn: capture one pending lesson"
   git -C ~/src/Flux push || { git -C ~/src/Flux pull --rebase && git -C ~/src/Flux push; }
   ```

   A push that still fails leaves the commit local — say so when echoing
   the path; the session-end hook's push path carries it at the next
   opportunity.

7. **Echo the path back.** Print one line:

   > Wrote `<absolute-path>`. The next curation pass will pick it up.

## Examples

Empty invocation:

```text
/learn
→ (prints the one-line reminder)
```

Freeform lesson:

```text
/learn A background worker that emits idle pings is at rest between long
sub-agent calls, not dead — never spawn a replacement editor onto its branch.

→ Wrote /Users/.../learnings/pending/a1b2c3d4-<uuid>.md. The next
  curation pass will pick it up.
```

Lesson with an embedded hint (no special syntax — just prose):

```text
/learn Prefer CTEs over nested subqueries in SQL and qualify every column
with its table alias. This probably belongs in that repo's SQL
conventions.

→ Wrote /Users/.../learnings/pending/<session>-<uuid>.md. ...
```

## The filing contract

The lesson body is the only thing required, plus the auto-generated
`uuid` and `timestamp`. The schema validator — shared with the drain —
enforces exactly that, and applies the content blocklist.

`target`, `scope` and `rationale` stay available for the automated
emission sites that have a genuine destination in hand. They are
advisory everywhere: the curator clusters by theme, picks the
destination at promote time, and its edit-path guard re-checks the
destination it actually picked (`target_shape_valid` in
`scripts/lib/staging-schema.sh`).
