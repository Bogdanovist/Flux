---
name: grilling
description: Interview discipline for tight alignment before acting — one question at a time with a recommended answer, the agent bringing facts and the human bringing judgement. Use when drafting a plan or spec, stress-testing an approach, or any moment "I think this is what you want" needs verifying.
---

# Grilling

Grilling is a technique you compose inside other skills. Walk the design tree
one branch at a time, until the alignment is concrete enough to act on. Use it
directly when no wrapper fits.

## The moves

- **Ask one question at a time.** Wait for the answer. If you ask five
  questions in one message, you have sent a survey, and survey answers come
  back shallow.
- **Carry a recommended answer**, with a one-line rationale. The user
  confirms or corrects faster than they answer cold, and your recommendation
  shows them exactly where to push back.
- **Offer 2–4 options** when you can list good ones. The options often
  surface a decision the user had not seen. Go open-ended when the space is
  genuinely large.
- **Walk the dependency tree.** Foundational decisions first — never the API
  shape before sync-vs-async, never retry strategy before whether failures
  are recoverable.
- **Bring the facts, and ask for the judgement.** Read the code and measure
  the data before you ask. If the code can answer a question, do not ask it.
  Ask the human for the judgement that facts cannot settle.

## Make questions land

- **Make each question self-contained.** The user must be able to answer it
  without reading anything else. Frame each option as the consequence the
  user would live with. Do not frame it as the implementation that produces
  that consequence.
- **Sharpen fuzzy terms.** When a word is overloaded — "account", "cancel",
  "the pipeline" — propose the precise alternatives and force the choice,
  checking terms against the glossary in the repo's `context/index.md`. A
  wrong term compounds through every sentence that follows.
- **Use concrete scenarios.** For a hand-wavy decision, invent the specific
  case that forces precision: "the upstream returns 500 mid-batch — retry
  the rows, drop the batch, or fail the job?" Agreeing on a fuzzy
  proposition gains you nothing.
- **Cross-reference the code.** When the user describes current behaviour,
  check whether the code agrees, and surface any contradiction immediately.
  Grilling is where you catch a wrong mental model, before anyone builds on
  it.

## Recording what settles

Most answers belong inside the artefact you are writing, and need nothing
more. If an answer carries weight beyond that artefact, it clears the record
bar. `records` owns the bar, the format, the scope choice and the lifecycle.
Mint the record through that skill, then cite it. Never restate it.

## When to stop, and where

Stop when you could write the next artefact without making a judgement call
the user has not seen. Do not wait until every question is answered. Write
down whatever remains as named open questions. Do not grill on work that is
small and reversible, on work you have delegated, or on anything the code
already answers.

Grilling is interactive. Run it in the main session, or in a subagent that
talks to the user directly. If an orchestrator relays questions between the
user and a subagent, you get the worst of both. When the harness forces a
relay, abort the subagent and grill in the main session.
