---
name: writing-skills
description: The token-economy rules for a SKILL.md — what earns its place in a file that loads into a fresh subagent context on every invocation, and what is duplication paid for every run. Use when authoring a new skill, editing an existing one, or reviewing a PR that changes the skill corpus.
user-invocable: true
---

# Writing skills

Every `SKILL.md` is loaded into a fresh subagent context each time someone
invokes it. You pay for every line, on every run. Cut anything that repeats the
frontmatter, decorates the page, or says what another skill already says.

Write the body in plain English, as `AGENTS.md` §How we work requires. The
eight rules below are about what to include; that rule is about how to write
it.

## 1. Do not open with a "Purpose" paragraph

The Skill tool reads your frontmatter `description` before it processes the
body. A paragraph that says the same thing again costs tokens and teaches
nothing.

**Check:** make the first line after the frontmatter either a `##` heading, or
a sentence that adds something the description does not say.

## 2. Do not put agent invocations in code fences

Every agent already knows how to spawn a `file-finder` or a `web-researcher`. A
five-line fence showing the call adds weight to the page and no information.

**Check:** replace the fence with a sentence. "Spawn a `file-finder` agent with
the goal and the topic."

## 3. Give every rule one home

If you are about to write a rule, a table or a contract that another skill
already states, cite that skill by name instead. Two copies of one rule will
drift apart, and a reader cannot tell which copy is current.

**Check:** grep the skill corpus for the rule's title before you write it. If
it is there, cite it.

## 4. Keep an Anti-Patterns section only for surprises

A Wrong/Right pair earns its space when the correct behaviour surprises the
reader. If the pair repeats a checklist item from the same page, cut it.

**Check:** for each pair, ask whether a reader who just read your checklist
would still get it wrong. If they would not, delete the pair.

## 5. Do not say it in prose and then again in a fence

If you explain a step and then wrap the same content in a `text` fence, you
have said one thing twice.

**Check:** read the fence. If it paraphrases the prose above it, delete the
fence.

## 6. Cap research deliverables at about 200 lines

A research or evidence document feeds into another skill's context later, so
its length becomes someone else's cost. Include everything that decides
something. Leave out exploratory notes and raw file listings.

**Check:** if your skill produces a research-style document, or spawns a
research subagent, state the ≤200-line budget in the instruction.

## 7. Write process steps as a checklist

"Step N: [verb]" headings with a paragraph under each add a lot of whitespace
and no clarity. Use checklist bullets when the steps run in order and do not
branch.

**Check:** if a step heading is followed by a single paragraph, fold the two
into one bullet.

## 8. Say what to ask the user, never how to ask it

Name the input your skill needs. Do not name the mechanism that gathers it —
not `AskUserQuestion`, not a form, not a numbered prompt. Mechanism belongs to
the harness and to the person using it, and `AGENTS.md` §Personal layers binds
a personal preference to its owner alone. If you fix the mechanism in a shared
skill, every reader whose default differs has to fight your skill to use it.

One exception: name a tool when the constraint is architectural rather than a
preference. `agents/grilling-interviewer.md` forbids `AskUserQuestion` because
calling it from a subagent hands control back to the orchestrator, which
destroys the isolation the agent exists for. Say which constraint you are
naming, so that a reader can tell it from a preference.

**Check:** grep your skill for `AskUserQuestion` and for "ask the user". Each
hit should name inputs, not tools, unless it names an architectural
constraint. Rewrite "Use `AskUserQuestion` to ask the workflow name and
trigger" as "Gather from the user: workflow name, trigger event."

## The prose itself

`AGENTS.md` §How we work lists the six habits to keep out of normative prose,
and they bind a `SKILL.md` like anything else you write.
`skills/solution-design/prose-checks.md` shows how to catch each one.
