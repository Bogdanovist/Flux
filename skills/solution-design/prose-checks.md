# Prose checks

`AGENTS.md` §How we work tells you to write plain English and lists six habits
to avoid. This file shows you how to catch each one in your own draft, then
works a full rewrite.

Read your draft once per check. Each check is mechanical: you apply it to a
sentence and get a yes or a no.

## 1. A rule written as a contrast

You wrote "not X, it's Y", or "X, never Y", and the negative half is doing the
work.

**Check:** delete the negative half. Does the sentence still state the rule? If
it does not, the positive half was never carrying it. Rewrite so it does.

Keep a negative only when you can test it. "No row on a keyless surface is
`false`" is a claim about the system, so it stays.

## 2. Undated present tense about a system

You wrote "today", "currently", "still flowing", "no longer", or "the existing
behaviour".

**Check:** find the date. Every observation of a system goes in **Found**, with
the date you measured it and what you saw. Rules and Tests carry no tense at
all, because they hold whenever anyone reads them.

## 3. A rule with nothing to check it against

Your Rule or Test names no table, no column, no key, no quantity, and no
glossary term.

**Check:** point at the noun a reader would open or query. If you cannot find
one, the sentence is commentary — move it or cut it.

Do not fix this with a file path. Code moves; the rule stays. Put the location
in the glossary entry's *Currently* line.

## 4. Answers to arguments the reader never heard

You wrote "rather than", "instead of", "deliberately declines", or "the
temptation is".

**Check:** read the sentence as someone who joined the week after. Does it make
sense? If it only makes sense to someone who sat through the discussion, cut
it. A rejected option that still matters goes in **Found**, with the date and
what you measured or tried.

## 5. Writing about the document from inside it

You wrote "this is a rule, not a preference", or "named here because".

**Check:** delete the sentence and reread. You usually wrote it because the
wording nearby invited a misreading. Fix that wording.

## 6. Two clauses balanced against each other

You wrote a pair that only works together, in timeless present.

**Check:** split the pair. Read each sentence alone. If one of them no longer
says what it applies to, or what must hold, it was leaning on the other one.
Give it its own subject and its own claim.

## A worked rewrite

The most common failure is architecture prose written under a **Rule:** label.
Here is one entry before and after.

Both texts are made up, to show the shape.

### Before

> - **Rule:** the report reaches the notification channel by posting to a
>   webhook.
> - **Rule:** a post that fails logs at ERROR, and the existing alert policy
>   carries that to the channel down a route that does not depend on the
>   webhook. A deleted channel and a revoked URL both surface this way, since
>   the host returns a non-2xx for each.
> - **Rule:** a run that crashed, or a scheduler that never fired, is reported
>   by the job-failure and scheduler-failure policies that already watch these
>   jobs.
>
> There is no all-clear post on a clean pass, so silence is not itself a
> signal: a scheduled job somebody disabled and did not re-enable goes
> unreported, and the human step that re-enables it is the only thing that
> catches that.

All three Rules describe how the report gets delivered. None of them says what
a future agent must not re-decide. The closing paragraph fails check 3: it
names nothing a reader can open or query.

### After

> ### A19 — A failed Backup Verification is a reported outcome
>
> - **Scope:** the [[Backup Verification]].
> - **Rule:** outcomes of the nightly verification are delivered as a text
>   report posted to the notification channel; a failed check is a reported
>   outcome inside that report — it raises no exception and does not fail the
>   run. An error that prevents the run from completing is logged at severity
>   ERROR; the log-based alert route matches on ERROR and carries those log
>   entries to the same channel.
> - **So what:** do not make a check raise on failure, and do not build a
>   dedicated error-notification channel.
> - **Found (2026-08-04 → 08-07):** the verifier raised exceptions on failed
>   checks, so a tripped check was indistinguishable from a failed run.

This entry has no Test. The Rule already states what you would observe, and the
tracer spec that cites A19 carries the concrete test.

The Scope points at a glossary entry. That is what gives the rule a subject
that survives a refactor:

> **Backup Verification** — nightly checks of aggregate statistics over the
> archives the importer writes, reporting anomalies to the notification
> channel. *Currently:* `tools/backups/verify.py`, run by the nightly job.
