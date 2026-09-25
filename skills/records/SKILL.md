---
name: records
description: The decision and verified-fact record — when one is minted, the format, where it lives, and the verify-at-cite lifecycle that keeps it honest. Cited by every skill that writes or reads a record; use directly when deciding whether a settled answer deserves one.
---

# Records

A record is the durable form of one settled decision, or one verified fact.
Write it so that a future session can rely on it without deriving it again,
and so that the same session can tell when it has stopped being true.

## The two kinds

A **decision** is a choice that could have gone the other way, and someone
made it. A **fact** is a measured property of a system that no choice
controls, settled by re-running the command that established it. The
directory a record sits in carries its kind: `decisions/` or `facts/`.

If one sentence holds both — a choice justified by a measurement — split it.
Give the fact its own record, and have the decision cite that record.

## When a decision or a fact clears the bar

Most answers belong inside the artefact you are writing, and they die with it.
Write a record only when the decision or the fact carries weight beyond the
sentence that states it. Three cases qualify: another artefact will cite it, a
future pass could break it without noticing, or arguing it again would cost
real time.

The bar changes with scope. A project-scoped record costs you the writing and
nothing after that, because it dies with the project unless the close gate
promotes it. Write one whenever deriving the fact again would cost more than
storing the command that re-verifies it.

Repo scope costs much more. Apply the placement test first: if a rename, a
comment or a repo rule could carry the fact, put it there and write no record.
Reach for a repo-scoped record only for a pivotal decision or fact that a
newcomer to the repo could not guess, and that nothing lower can hold.

## Scope, settled at minting

Paths are relative to the repo's main checkout, per `AGENTS.md` §Where
context lives.

- This project only → `context/projects/<slug>/decisions/<name>.md` or
  `context/projects/<slug>/facts/<name>.md`. Dies with the project unless
  promoted at close.
- Holds for the repo beyond any one project → `context/decisions/<name>.md`
  or `context/facts/<name>.md`, plus its one-line entry in
  `context/index.md`. A repo-scoped record taxes every future pass: each
  design in that repo has to verify it when it cites it. Write one only when
  you want a future project to stop and check it.

## The repo index

`context/index.md` is the entry point to a repo's context. Keep it short
enough to read in full at the start of any task:

```markdown
# <Repo name>

<One paragraph: what is being built, and for whom.>

## Glossary
## Decisions — one line per record: the canonical statement, then the path
## Facts — the same, one line per record
```

A glossary entry names a term in the repo's domain language, in two lines:

> **Backup Verification** — nightly checks of aggregate statistics over the
> archives the importer writes, reporting anomalies to the notification
> channel. *Currently:* `tools/backups/verify.py`, run by the nightly job.

- Write the definition line for purpose alone. Name no runtime and no paths.
  It should still be true after someone rewrites the code.
- The *Currently* line is the one part that goes stale. Leave it out until
  the thing is built. The change that builds it adds the line, and whoever
  renames the code updates it.
- Add an entry when a rule, a record or a design statement first cites the
  term. Delete it when nothing cites it. Do not add entries for
  completeness.

## The decision format

```markdown
---
name: <slug>
scope: project:<slug> | repo
status: held
built: yes | no | partial
verified: <YYYY-MM-DD>
---

**<The canonical one-line statement — the thing other artefacts cite.>**

## Question and context — what was asked, and how the answer shapes the artefact
## Facts considered — each with the command or query that re-verifies it
## Decision — with the trade accepted, concisely
## Overturned by — the observation that would reopen this
```

`built:` says whether the code matches the decision; anything but `yes` names
what is missing and the command that re-verifies its absence.

## The fact format

```markdown
---
name: <slug>
scope: project:<slug> | repo
status: held
verified: <YYYY-MM-DD>
---

**<The canonical one-line statement of what is true.>**

## Why it was established — the question that made this worth measuring
## Evidence — the command or query, what it returned, and what it ran against
## Overturned by — the observation that would make this false
```

A fact record carries no `built:`, because nothing is built from a fact.
§Evidence is what makes the record worth keeping. Give the command, its
output, and the anchor that bounds it: the date, the commit, and the window or
filter. If you record a number without its window, the next reader cannot
re-check it. They can only measure it again.

A record is not the same thing as a design document's assertion register
(`solution-design` §Field forms). A register entry pins a decision inside the
design that states it. A record carries a decision beyond the artefact that
settled it. Never mix the two formats.

## Verify at cite

When you cite a record, check it. Run its facts' re-verify commands, ask
whether the overturn condition has fired, and update `verified:`. If a record
fails the check, stop and put it to the user: update it, overturn it, or
accept that the work citing it is wrong. Never build on a record you have not
checked this pass.

## Lifecycle

- **held** — the record carries the canonical statement.
- **absorbed → \<enforcer\>** — a test, constraint, hook or lint now holds the
  invariant mechanically. Authority moves to the enforcer, which now carries
  the statement. Cut the record body down to the pointer. If a record and an
  enforcer both state the invariant, you have two sources of truth.
- **overturned → \<successor\>** — the overturn condition fired. When you
  overturn a record, hunt down its enforcers too, because authority had moved
  to them.

Claim enforcement only through `status`. If a Decision names a test or a
constraint while `status` stays `held`, it claims a mechanism that nothing
checks. That is worse than saying nothing, because a reader who believes it
stops looking.
