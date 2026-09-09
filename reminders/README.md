# Reminders

Work already scheduled for a date, which nags from that date until it is done.

One `.md` file per reminder. `hooks/debt-review-nudge.sh` reads this directory at
session start and surfaces every reminder whose `due:` date has arrived, on the same
banner as the debt-review nudge. **Deleting the file is how a reminder is marked done** —
there is no `done:` field, because a reminder that stays on disk keeps firing and one
that is gone cannot.

```markdown
---
due: 2026-08-15
what: one line, enough to act on without opening the file
---

Body: what to confirm before starting, what the work is, and what to read.
```

`due:` is `YYYY-MM-DD`, compared as a string against today in UTC. `what:` is what the
banner shows; without it the banner falls back to the filename.

**Not the same store as `followups/inbox/`.** A follow-up is deferred work with no date,
triggered by how much has piled up (count or age) and disposed of in a `/triage` sitting
— it might be fixed, promoted to a tracer, or killed. A reminder is work already decided
and scheduled, and the only disposition is doing it. Put a thing here when you know when
it should happen; put it in `followups/inbox/` when you know it matters but not when.
