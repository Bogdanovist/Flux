# Code review ledger

`codebase-review`'s memory, on the same protocol as `sweep-ledger.md`. It is a
second ledger because a code finding stays true until the code changes, while a
context-rot finding dies with its subject.

```markdown
## <repo> — <path>:<line>
- class: correctness | security | efficiency | complexity
- severity: CRITICAL | SIGNIFICANT | MODERATE | MINOR
- first-seen: <YYYY-MM-DD>
- evidence: <what was read, what it showed>
- disposition: deferred <trigger> | wont-fix <reason> | actioned <ref>
```

Entries appear below.
