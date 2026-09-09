---
name: open-project
description: Open a piece of work — create its working doc in Flux's projects/ with the header contract, and advise on the depth that fits the work. Use at the start of any non-trivial task, or when a task's right level of ceremony is unclear.
---

# Open project

If the work is more than trivial, give it a working doc in
`~/src/Flux/projects/<slug>/`. The doc records what you are attempting and
why, and a session six weeks from now must be able to read it with no memory
of this conversation. Write `<slug>` in kebab-case, and make it specific
enough to find later: `photo-import-dedupe`, not `photos`.

## The working doc

`projects/<slug>/plan.md` opens with the header, then free-form content:

```markdown
---
started: <YYYY-MM-DD>
repos: <checkout name(s) the work touches>
---

## Why — the problem, what the status quo costs
## Approach — what will be built and how, at the altitude a reviewer can act on
## Out of scope — what this deliberately does not touch
```

`started:` dates the doc, so a reader can weigh it against the commits under
it. `repos:` names where the code lands, which is what `context-sweep` reads
to check a doc's promises against real branches. Put no status field in the
header: git already says when the doc last moved, and a hand-maintained
status goes stale silently.

You choose how deep to go below the header. Write a paragraph for small work.
For work whose risk justifies it, write the full tracer-flow spine with
`solution-design`. The spine is this same doc grown heavyweight: it absorbs
`plan.md` and replaces it, so the project still carries one working doc.

## Advising depth

Advise the user, and let them choose. Never gate the work on their answer. Use
these heuristics:

- **Ship it** — the change is small enough that its diff is the review.
  Writing a plan for it is ceremony; say so.
- **A plan doc** — the work runs for days, crosses repos, or changes a
  contract: a schema, an interface, a message format. If the user starts this
  without a plan, warn them once and plainly. Reviewing the plan is cheap.
  Reviewing the built diff turns into a rubber stamp.
- **The full spine** — the risk sits in facts about existing systems, or in
  many consumers and seams. Recommend the optional `solution-design` spine,
  which absorbs and replaces `plan.md`.
- **An exploration** — the work delivers knowledge. It settles what is true,
  and it ships nothing. Run it with `explore-problem`, and write its working
  doc as `findings.md` in place of `plan.md`.

## Where the doc is written

Commit the doc straight to `main` in `~/src/Flux` and push it. Flux is your
own context repo: a branch and a PR here would buy a review nobody else is
waiting to give, and a plan stranded on a branch is a plan your other machines
cannot read.

Then run `plan-review` on it before the build starts, and edit the doc where
you accept a finding. A plan review costs little; reviewing a built diff for
the same question costs the build.

The code is the other story. Every change to a project repo lands as a feature
branch and a PR there, reviewed with `reviewing-diff` once it is raised, so the
diff carries its findings when the user reads it. Their merge is the approval.

If the work is small enough to skip the doc, skip all of this and let the code
PR carry the review.

## While the work runs

- Turn decisions and surprising verified facts into records. `records` gives
  you the format and the bar.
- Route incidental finds through `followup`, and lessons through `/learn`.
- Progress notes, tracer status, corrections: commit them to `main` as you go.
- When the work finishes, run `close-project`. It works the promotion gate and
  archives the doc.
