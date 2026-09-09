# Sweep ledger

The memory that keeps weekly sweeps from re-raising the same findings.
`context-sweep` diffs each pass against this file and surfaces only new and
changed findings. Every finding that reaches a pass leaves it with a
disposition: `deferred` with a revisit trigger, `wont-fix` with a one-line
reason, or `actioned` with the commit or PR.

```markdown
## <repo> — <location>
- class: stale | misplaced | bloat | dormant
- first-seen: <YYYY-MM-DD>
- evidence: <the claim, the command run, what it returned>
- disposition: deferred <trigger> | wont-fix <reason> | actioned <ref>
```

Entries appear below.
