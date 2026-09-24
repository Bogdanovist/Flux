---
name: spike
description: "Use when writing code to test an idea, reduce implementation risk, test how an unfamiliar library or area of the code works. Ideal for reducing implementation risk for large projects."
user-invocable: true
argument-hint: idea or risk to spike
---

# Spike

Write code to prototype an approach, test an idea, and reduce the
implementation risk in later work.

## When

Use a spike whenever you need code to explore something, find a fact, or
settle an implementation uncertainty.

## Where the code lives

One worktree per idea being spiked, in the repo the question is about:

```
git -C $FLUX_SRC_ROOT/<repo> worktree add $FLUX_SRC_ROOT/<repo>-worktrees/spike-<slug> \
  -b spike/<slug> origin/main
```

Push the branch. Pushing backs you up against losing the worktree, and it
gives the project doc a link that resolves from any machine. A worktree path
lives on one machine, and it means nothing from another. Never open a PR for a spike
branch, and never merge one.

Keep the worktree until the project closes. When the spike starts, record it
in the project's working doc: the question, the repo, and the branch URL.
`close-project` disposes of that line. If a spike has no project behind it,
delete it when the session ends, because nobody will come back for it.

## Coding standards

Spike code needs no tests, unless the tests are part of what you are spiking.
Keep comments to a minimum, and do not spend time on clean architecture unless
the architecture is the question. Never disable or delete an existing test.
Answer the question the spike was opened for. Once you have the answer, throw
the code away.

## Production data and operations

You may read production data in a spike. Never write to production. Spike code
carries no tests and no review, and writing to production is the one way it
escapes the branch that never merges. Take the same care with live operations:
size your queries and rate-limit your calls, so that a spike cannot degrade a
running service.

## What survives it

A spike answers a question, and that answer needs a home. If a finding's
re-verify command is worth storing, write a fact record with `records`. Put
anything lighter in the working doc as a line.

The code survives in one way only: `close-project` promotes it, as a PR to the
repo it belongs in. The gate then removes the worktree and deletes the branch
from origin.
