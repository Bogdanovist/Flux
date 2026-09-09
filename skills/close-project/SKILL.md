---
name: close-project
description: Run the promotion gate when a project finishes or stops — decide per item what outlives it and where each survivor lives, then archive the project dir. Use when a working doc's work is done, when the work is abandoned or superseded, and before starting what depends on it.
---

# Close Project

A project that ends holds some context worth keeping, and some that should die
with it. Decide which is which. Do not let a default decide for you. Make that
decision here, item by item, and record it where others can see it.

## The inventory

Walk everything the project accumulated:

- decision records under `projects/<slug>/decisions/`
- fact records under `projects/<slug>/facts/`
- verified facts and open questions still loose in the working doc
- spikes the doc records, with their repo, branch and worktree
- anything the doc flags as outliving the work

## The decision, per item

Ask of each item: **does this outlive the project?** For most items the answer
is no, and dying with the archive is the right outcome. An archived project
directory stays retrievable forever, and if you promote everything, the
durable layer rots.

For each survivor, place it at the *lowest* level that can carry it, in
order:

1. **A rename or refactor** — the code tells the truth itself. Emit a small
   PR to that repo.
2. **A code comment** — a constraint the code cannot show. PR to that repo.
3. **A repo skill or that repo's AGENTS.md line** — task knowledge specific
   to one repo. PR to that repo.
4. **A feature record in Flux** — genuinely cross-repo, surprising, or a
   why-not. Mint via `records` at feature scope and add the index line.

If you promote an item upward, show which downward options you considered. The
close commit has to answer the question "why not a comment?".

## When the work stopped

A project stops without finishing when you drop it, or when another piece of
work takes over its ground. Close it through this same gate. The inventory
still runs, because a stopped project can hold a verified fact worth keeping,
and its spikes still hold branches on origin that read as live code.

Two things differ on this path. Write the reason it stopped in the close
commit, in one line that a reader who never saw the work can act on. Where
something else covers the ground, name it: `superseded-by: <slug>` or
`superseded-by: <record path>`.

Route every still-live open question out through `followup` before the
archive move. Nobody re-reads an archived directory, so a question left in one
is lost.

## The close commit

One commit closes the project: the archive move
(`git mv projects/<slug> projects/archive/<slug>`), plus a list of
dispositions in the commit message or in a `CLOSE.md` in the archived
directory, and on the abandon path the reason and the successor. List each
item and its fate, and for each upward promotion, list the downward homes you
ruled out. The shakedown checks two things: that you
made the placement decisions visible, and that you considered placing the item
lower.

## Loose ends

- Treat the PRs this gate emits downstream as ordinary PRs, reviewed and
  merged under their own repos' rules. The close does not wait for them.
- Route any unresolved open question that still matters through `followup`
  before you archive. If you archive an open question, you have buried it.
- Each spike the doc records is disposed here. Code that outlives the project
  leaves as a PR to its repo first; then `git worktree remove <path>`,
  `git branch -D spike/<slug>`, and `git push origin --delete spike/<slug>`. A
  spike branch left on origin is unowned code that reads as live.
