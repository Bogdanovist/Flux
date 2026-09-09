# evidence.md

The distilled ledger. One record per theme, carrying its recurrence count, up
to about five fingerprints, and its status. `/curate` reads it to judge whether
a theme has crossed the promotion bar, and writes it back at the end of a pass.

A theme record looks like this:

```markdown
## <theme name>
- count: <N>
- status: pending | promoted | rejected: <reason>
- fingerprints:
  - <YYYY-MM-DD> <uuid> — <one line of what happened>
```

Records appear below.
