---
name: explore-problem
description: "Exploring a problem. Use when a solution is not yet known or a rough solution concept exists with considerable uncertainty. Use when wanting to understand a space and record structured findings for later reference."
user-invocable: true
argument-hint: problem or question to explore
---

# Explore

Use this skill to explore a problem before anyone builds a solution for it.
The work delivers one `findings.md` doc carrying what you learned. Capture
verified facts with `records`.

## The working doc

Treat an exploration as a project of its own. Give it its own `<slug>`, its
own Flux worktree and branch, and `projects/<slug>/findings.md` as the
working doc. `open-project` carries the header contract, the branch-and-PR
path and the depth advice, and `findings.md` takes all three unchanged. Once
you have answered the question, `close-project` archives the project.

Under that header, findings.md carries three sections:

```markdown
## Motivating Question
## Summary
Concise summary of the finding and how it answers the motivating question.
## Findings
The evidence, tagged [OBSERVED] where it was measured, citing the records it
rests on.
```

When a finding's re-verify command is worth storing, such as a query, a log
grep or a test, mint a project-scoped fact record under
`projects/<slug>/facts/` and cite it from §Findings. Storing the command is
what stops someone deriving the same fact again later in the exploration.
Leave a finding with no such command as prose here. `close-project` decides
which records outlive the project.

## The process

Use `grilling` to get problem context from the user and proceed iteratively to
explore the problem, returning to grilling to discuss and propose next steps
after each research step is complete and new information is available.

The user decides when an exploration stops. After each research step, report
what you now know, what the motivating question still lacks, and what the next
step would cost. Then ask. Deciding whether to continue means judging what an
answer is worth, and `grilling` puts that judgement with the user. Never close
an exploration on your own reading of "enough".

Use sub-agents extensively for research. Depending on the problem you may need
to use the `gathering-runtime-evidence-*`, `systematic-debugging` skills and/or
`codebase-researcher`, `web-researcher` agents. You may need to perform other
research tasks, especially exploring data. For code to be written as part of the
problem exploration, use `spike`.
