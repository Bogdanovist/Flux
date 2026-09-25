---
name: open-project
description: Open a piece of work — create its working doc in the repo's context/projects/ with the header contract, and advise on the depth that fits the work. Use at the start of any non-trivial task, or when a task's right level of ceremony is unclear.
---

# Open project

If the work is more than trivial, give it a working doc in
`<repo>/context/projects/<slug>/`, in the main checkout of the repo the work
lands in. If that repo has no local checkout, clone it beside Flux first. If
it does not exist yet, ask the user to approve creating it. The doc records what you are attempting and
why, and a session six weeks from now must be able to read it with no memory
of this conversation. Write `<slug>` in kebab-case, and make it specific
enough to find later: `photo-import-dedupe`, not `photos`.

## The working doc

`context/projects/<slug>/plan.md` opens with the header, then free-form
content:

```markdown
---
started: <YYYY-MM-DD>
---

## Why — the problem, what the status quo costs
## Approach — what will be built and how, at the altitude a reviewer can act on
## Out of scope — what this deliberately does not touch
```

`started:` dates the doc, so a reader can weigh it against the commits under
it. The repo that holds the doc is the repo the work lands in. Put no status
field in the header: git already says when the doc last moved, and a
hand-maintained status goes stale silently.

You choose how deep to go below the header. Write a paragraph for small work.
For work whose risk justifies it, write the full tracer-flow spine with
`solution-design`. The spine is this same doc grown heavyweight: it absorbs
`plan.md` and replaces it, so the project still carries one working doc.

## Advising depth

Advise the user, and let them choose. Never gate the work on their answer. Use
these heuristics:

- **Ship it** — the change is small enough that its diff is the review.
  Writing a plan for it is ceremony; say so.
- **A plan doc** — the work runs for days or changes a contract: a schema,
  an interface, a message format. If the user starts this without a plan,
  warn them once and plainly. Reviewing the plan is cheap.
  Reviewing the built diff turns into a rubber stamp.
- **The full spine** — the risk sits in facts about existing systems, or in
  many consumers and seams. Recommend the optional `solution-design` spine,
  which absorbs and replaces `plan.md` and which `review-solution-design`
  then gates in a cold context.
- **An exploration** — the work delivers knowledge. It settles what is true,
  and it ships nothing. Run it with `explore-problem`, and write its working
  doc as `findings.md` in place of `plan.md`.

## Where the doc is written

Commit the doc by explicit path straight to `main` in the repo's main
checkout, and push it. A plan stranded on a feature branch is a plan your
other sessions and machines cannot read. The worktree a slice is built in
holds a copy of `context/` from the moment its branch was cut, so read and
edit the plan in the main checkout only.

Then put it to the user before the build starts, and say what you want them
to look at: the contracts it touches, the risks you could not settle, the
scope you drew. A `solution-design` spine takes `review-solution-design`
instead, in a cold context.

The code is the other story. Every change outside `context/` lands as a
feature branch and a PR, reviewed with `reviewing-diff` once it is raised,
so the diff carries its findings when the user reads it. It merges only on their
explicit approval.

If the work is small enough to skip the doc, skip all of this and let the code
PR carry the review.

## While the work runs

- Turn decisions and surprising verified facts into records. `records` gives
  you the format and the bar.
- Route incidental finds through `followup`, and lessons through `/learn`.
- Progress notes, tracer status, corrections: commit them to `main` as you go.
- When the work finishes, run `close-project`. It works the promotion gate and
  deletes the project directory.
