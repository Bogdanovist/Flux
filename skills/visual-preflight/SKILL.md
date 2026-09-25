---
name: visual-preflight
description: "Render the local app in a headless browser, screenshot every page (default state + opened sidebar controls), dispatch parallel vision-capable review agents, and print a PASS/WARN/BLOCK report on visual issues — overflow, cutoff, contrast, palette deviation, broken interactive states. Use at end-of-session before raising or updating a PR that touches UI."
user_invocable: true
---

# Visual Preflight

Sibling to `reviewing-diff`. Where `reviewing-diff` reasons about a `git diff`, this skill reasons about pixels — what a human would see if they opened the running app. Closes the gap that lets visual regressions ship past unit tests, AppTest assertions, and "no exception" browser smoke (none of which can see overflow, cutoff, contrast, or layout breaks).

Invoke manually before raising or updating a PR that touches `src/pages/`, `src/components/`, `src/theme.py`, `.streamlit/config.toml`, or any equivalent UI surface.

**Scope (v1):** Streamlit dashboards. The capture phase boots `streamlit run` and uses Playwright to drive Chromium. The review phase is framework-agnostic — vision agents look at PNGs.

---

## Phase 1: Capture

Run the capture helper from the repo root:

```bash
uv run python $FLUX_DIR/skills/visual-preflight/capture.py \
    --app src/app.py \
    --out .visual-preflight-screenshots \
    [--mock <path-to-designer-mock.png>]
```

Helper behaviour:

1. Subprocess `streamlit run <app> --server.headless=true` on a free port.
2. Poll `/_stcore/health` until 200.
3. Auto-discover pages from `src/pages/*.py` (filenames following Streamlit's `NN_slug.py` convention) plus the entry page `/`.
4. For each page, in a fresh Chromium context:
   - Navigate, wait for `networkidle`, settle 2.5s.
   - Screenshot full page → `<slug>__default.png`.
   - Open each `[data-testid="stSidebar"] [data-baseweb="select"]` control in turn; screenshot the page with the popover visible → `<slug>__sidebar_<n>.png`. Close after each.
   - Open each `details[data-testid="stExpander"]` element; screenshot → `<slug>__expander_<n>.png`. Close after each.
5. Tear down streamlit on exit.
6. Print the screenshot directory path to stdout.

If `streamlit run` fails to boot or Playwright/Chromium is unavailable, the helper exits non-zero with a clear message. The skill stops; surface the error, do not proceed to review.

---

## Phase 2: Launch THREE review agents in parallel

Use the Agent tool to launch all three agents concurrently in a single message. Each agent gets:

- The screenshot directory path (it will use `Read` on PNGs to view them).
- The list of screenshot filenames so it knows what to review.
- The path to the designer mock if `--mock` was passed (otherwise, reason from general design principles).
- A concise context blurb: branch name, commit log against `origin/main`, plan path if one exists at `<repo>/context/projects/<slug>/plan.md`, and any project-level design tokens referenced in `BRAND_COLOURS` or equivalent.

**Verify before flagging.** Each agent MUST cite a specific screenshot file (and approximate region — "top-right of the safety-signals tile", "x-axis tick labels of the ITS chart") for every finding. No flagging from memory. No findings without a citation.

### Agent 1: Layout & Overflow

Look for any pixel-level layout failure. Hints:

1. **Text overflow**: text spilling outside its colored background, pill, badge, card, or button. Includes KPI tile values overflowing colored pills, table cells overflowing column widths, breadcrumbs overflowing header bars.
2. **Cutoff / clipping**: chart axis labels truncated by a tight margin; long page titles cut off; dropdown popovers clipped by a parent container.
3. **Overlap**: x-axis tick labels overlapping each other or the chart drawing area; chart legends colliding with chart content; sidebar controls overlapping the page content.
4. **Misalignment**: cards/tiles in a row not aligning to a common baseline; KPI numbers and labels mis-stacked; padding inconsistencies that read as broken.
5. **Empty / dead space**: huge gaps where a chart didn't render but no error was shown; placeholder regions that should have content but don't.
6. **Aspect ratio breaks**: charts squashed too narrow or stretched too wide; images distorted.

### Agent 2: Readability & Contrast

Look for anything a viewer would struggle to read or interact with. Hints:

1. **Contrast**: text colour against its background — body text, secondary labels, button labels, dropdown popover text, chart annotations, hover tooltips. Flag anything where the contrast ratio looks below ~4.5:1 by eye. Sidebar dropdowns are a known failure mode: the sidebar may inherit one colour palette and the popover may render with a different one.
2. **Font size**: anything that looks unreadably small at the rendered viewport; numbers in stat tiles that are smaller than their labels (inverts the visual hierarchy).
3. **Active state visibility**: which sidebar item / tab / button is currently active should be obvious without effort.
4. **Hover/focus invisibility**: where possible to capture, do hover/focus states give visible feedback?
5. **Information hierarchy**: section titles, card titles, body text, and captions should be visually distinct. Flag cases where two levels read as the same weight/size.

### Agent 3: Design system adherence

Look for inconsistency with the design system or designer mock. Hints:

1. **Palette drift**: colours not from the project's design tokens (`BRAND_COLOURS` or equivalent) showing up in screenshots. The agent can check the palette by reading the project's theme module.
2. **Typography drift**: multiple fonts visible; weights and sizes not matching the documented hierarchy.
3. **Component pattern drift**: cards on different pages with visibly different radius, padding, shadow, or border treatments. KPI tiles styled inconsistently across pages. Buttons with mixed visual treatments.
4. **Mock-vs-actual divergence (if `--mock` provided)**: the mock is *directional* not literal — match the system (palette, spacing, component patterns, hierarchy), don't expect the actual composition to match the mock's exact charts/copy. Flag system-level deviations only; ignore content-level differences.
5. **Sidebar / header consistency**: the page-header banner and sidebar should look identical on every page.

---

## Phase 3: Synthesize findings

Wait for all three agents to complete. Aggregate their findings.

**Verify each finding.** Open the cited screenshot via `Read` and confirm the issue is visible before including it. Drop findings you cannot confirm.

**Severity tagging (required).** Same scale as `reviewing-diff`:

- **CRITICAL** — blocks merge. Page unrenderable, content unreadable, a feature non-functional.
- **SIGNIFICANT** — should fix before merge. Visible overflow/cutoff/contrast issue affecting a primary surface.
- **MODERATE** — fix in follow-up acceptable. Minor inconsistency, secondary surface.
- **MINOR** — polish nit.

**Separate systemic findings from local ones.** When the same finding appears on several pages, flag it once as **(systemic, N pages)**, and do not repeat it per page. Fix it upstream, in the theme, the component or the CSS. Do not fix it page by page.

### Output

Print to stdout in this structure:

```
# Visual Preflight Report

**Verdict**: PASS | WARN | BLOCK
**Confidence**: high | medium | low

## Overall assessment
(one short paragraph — what was captured, what's the overall visual state, is it safe to push)

## Captured
(N pages × M states each = K screenshots in <dir>)

## Assumptions
(what the agent treated as intentional, e.g. "rgba overlays on the gradient banner are intentional per BRAND_COLOURS comment", "mock divergences in chart composition are accepted as directional")

## Findings
(grouped by severity. Each finding includes screenshot file + region + description + suggested fix. Mark systemic ones explicitly.)

## Reusable lessons
(0–3 bullets max — patterns worth carrying forward into the design system or the visual-preflight skill itself. Omit if nothing rises to this bar.)
```

**Verdict rules:**

- **BLOCK** if any CRITICAL or SIGNIFICANT finding exists.
- **WARN** if only MODERATE or MINOR findings exist.
- **PASS** if no actionable concerns.
- If confidence is `low` (capture phase incomplete, agents disagreed substantially, screenshots unclear), do not emit a confident verdict — surface the uncertainty and ask the user before finalising.

---

## Sentinel write on PASS

On a **PASS** verdict — and only on PASS — write a sentinel at the repo root:

```bash
touch "$(git rev-parse --show-toplevel)/.visual-preflight-passed"
```

Sentinel conventions:

- **PASS only.** Do not write on WARN or BLOCK.
- **Repo root**, resolved via `git rev-parse --show-toplevel`.
- **Mtime-based staleness** is the consumer's contract (no hook gates `gh pr create` on this sentinel today; the file is informational).
- **Do not pre-create or touch on retry.** A second run that produces PASS writes the sentinel fresh.

---

## Scope guardrails

- This skill does NOT replace `reviewing-diff`. Different lenses on different artefacts.
- This skill does NOT post to GitHub — stdout only, for the user to read and act on.
- This skill does NOT auto-fix. It surfaces findings; humans (or downstream remediation agents) decide what to do.
- This skill assumes a Streamlit app at `src/app.py` for v1. Generalising to other frameworks (FastAPI + Jinja, Flask, Next.js, etc.) is a deliberate v2 — when a second repo needs it.
- This skill deliberately lists no specific failure modes in advance. Tell the agents to look for *anything* visually wrong. The prompt hints at common failure classes, and it does not restrict the agents to those. A fixed checklist would re-create the gap this skill was written to close.
