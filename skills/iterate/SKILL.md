---
name: iterate
description: Use when working through a stream of small changes to something that already exists — bug fixes, follow-up features, scope adjustments, goal clarifications — whether or not the work came through /praxis:design or /praxis:implement. Not for building something new (that's /praxis:design or /praxis:prototype), and not for a lone one-off fix where the discipline skills suffice on their own.
argument-hint: "[items to work through, or source of the list]"
---

# Iterate

Work through small changes to existing work: one item at a time, each routed to the right discipline, decisions recorded in the same artifacts the other workflows read.

**Items:** "$ARGUMENTS"

**Name resolution:** `praxis:`-prefixed skill and agent names are the plugin registrations; a local checkout registers them bare. If a referenced skill or agent resolves in neither form, tell the user what's missing instead of silently substituting a different one.

## Context (once per session)

Detect what exists for the work area:

- Plan file `plans/<slug>.md` (from `/praxis:design`, or a minimal one left by a prior iterate session) and ideation file `plans/<slug>-ideation.md`
- Prototype handoff doc, if the work came through `/praxis:prototype`
- Open PR (`gh pr view`), integration branch

Artifacts present → changes land on their branch and the artifact-effects table applies to the existing files. Nothing present → solo mode: same table, file created lazily (below).

## Triage (more than one item)

Clarify ALL unclear items before working any — items may be related; partial understanding = wrong implementation. Order: blocking → simple → complex. One item at a time, one semantic commit each.

Items from a review or red-team round → invoke `Skill: "praxis:receiving-code-review"` first; findings verified wrong are pushed back on, not implemented.

## Route each item

- **Bug / regression / test failure** → `Skill: "praxis:systematic-debugging"` (root cause before any fix; its 3-failed-fixes rule escalates here to a `/praxis:design` conversation, not fix #4), then `Skill: "praxis:test-driven-development"` (failing test reproducing the bug).
- **Small new behavior** → `Skill: "praxis:test-driven-development"`. If the "small" feature turns out to need contract decisions across components, stop: that's `/praxis:design` (or `/praxis:implement` if already designed).
- **Scope change** → amend the artifacts first (table below), then implement via the lane the change lands in. A user-initiated change needs no confirmation; stop only when it collides with a prior `[user]` decision or sticky rejection — surface the collision in one line and let the user pick.
- **Goal clarification** → record it: a constraint with a provenance tag, or an `[assumed]` → `[user]` upgrade quoting their words. No code unless something now contradicts the clarified goal.

Per item, before its commit: `Skill: "praxis:verification-before-completion"`. Delete diagnostics added while investigating, or demote the essential piece into the regression test. Documented behavior changed → `Skill: "diataxis:diataxis"` (bare: `diataxis`; separate plugin — if it resolves in neither form, surface `/plugin marketplace add moiri-gamboni/diataxis-skill`), classify the kind(s) touched, update those docs.

## Artifact effects

Record only what a future session would otherwise re-litigate: decisions with rationale, rejections with stickiness, fixed-outcome amendments, constraints with provenance, falsifier evidence against prior entries. Everything else lives in commits — the file is not a changelog.

| Item outcome | Effect |
|---|---|
| Fix that fired through trimmed/leaned-out machinery or a Rejected/Deferred finding | Falsifier evidence logged against that Resolution Log entry (angle: iterate) |
| Fix with no decision content | Commit only — nothing recorded |
| Design decision made along the way | Resolution Log entry (angle: iterate); new deliverable → Scope "Actually new" line |
| Scope change | **Fixed outcomes** amended, dated; check whether the new scope unsticks prior sticky rejections — the user contradicting their earlier self is the one legitimate unsticking event |
| Constraint / clarification | Key Constraints entry with provenance tag (`[user]` quoting their words / `[fact]` citing / `[assumed]`) |
| Prototype handoff exists | Keep its "Decisions + tradeoffs", "Solid vs provisional", and "next" sections current |

**Lazy file (solo mode).** On the first entry-worthy event — not before — create `plans/<slug>.md` with only the sections other workflows consume, in their exact formats: Plan Header (Goal + Fixed outcomes), Key Constraints (provenance-tagged, per `praxis:ideate`'s template), Resolution Log (per `/praxis:design`'s entry format). No matrix, no tasks, no architect sections — those coordinate a pipeline that didn't run. A session with no entry-worthy events creates nothing; that is the correct outcome, not a gap.

## Wrap (after the batch, not per item)

Review scaled to the batch's risk: trivial → verification evidence suffices; error handling or fallbacks touched → one `praxis:silent-failure-hunter` via Agent on the batch diff; multi-file or risky → `Skill: "praxis:review"` scoped to the batch range — in its Re-Review mode when the batch answers prior review findings.

Land where the work lives: open PR → push to its branch. Otherwise: "Commits are local; push when ready."
