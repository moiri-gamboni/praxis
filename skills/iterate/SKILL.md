---
name: iterate
description: Use when making small changes to something that already exists — a bug fix, a follow-up feature, a scope adjustment, a goal clarification — one item or a batch, whether or not the work came through /praxis:design or /praxis:implement. Not for building something new (that's /praxis:design or /praxis:prototype).
argument-hint: "[items to work through, or source of the list]"
---

# Iterate

Work through small changes to existing work: one item at a time, each routed to the right discipline, decisions recorded in the same artifacts the other workflows read.

**Items:** "$ARGUMENTS"

**Name resolution:** `praxis:`-prefixed skill and agent names are the plugin registrations; a local checkout registers them bare. If a referenced skill or agent resolves in neither form, tell the user what's missing instead of silently substituting a different one.

## Context (once per session)

Detect what exists for the work area:

- Plan file `plans/<slug>.md` (from `/praxis:design`, or a minimal one left by a prior iterate session) and ideation file `plans/<slug>-ideation.md`
- Prototype handoff doc (`plans/<slug>-handoff.md`), if the work came through `/praxis:prototype`
- Open PR (`gh pr view`), integration branch

Artifacts present → changes land on their branch and the artifact-effects table applies to the existing files. Nothing present → solo mode: same table, file created lazily (below).

## What done looks like

Restate each item in the user's terms — one line each, inline — before working it. Without a plan file this is the only requirements record; Wrap checks the batch against it on real input.

## Triage (more than one item)

Clarify ALL unclear items before working any — items may be related; partial understanding = wrong implementation. Order: blocking → simple → complex. One item at a time, one semantic commit each.

Items from a review or red-team round → invoke `Skill: "praxis:receiving-code-review"` first; findings verified wrong are pushed back on, not implemented.

## Route each item

Any item that touches an external boundary (API, SDK, CLI/subprocess, file format, database, queue, LLM) → `Skill: "praxis:observe-before-model"` first — docs, one captured call, raw logging — then its route below.

- **Bug / regression / test failure** → `Skill: "praxis:systematic-debugging"` (root cause before any fix; its 3-failed-fixes rule escalates here to a `/praxis:design` conversation, not fix #4), then `Skill: "praxis:test-driven-development"` (failing test reproducing the bug).
- **Small new behavior** → `Skill: "praxis:test-driven-development"`. If the "small" feature turns out to need contract decisions across components, stop: that's `/praxis:design` (or `/praxis:implement` if already designed).
- **Non-behavioral item** (docs, config, rename, cleanup) → no new test (the TDD gate: a test pinning source text or shape isn't behavior); the existing suite stays green; verify by running or rendering it.
- **Scope change** → amend the artifacts first (table below), then implement via the matching route above. A user-initiated change needs no confirmation; stop only when it collides with a prior `[user]` decision or sticky rejection — surface the collision in one line and let the user pick.
- **Goal clarification** → record it: a constraint with a provenance tag, or an `[assumed]` → `[user]` upgrade quoting their words. No code unless something now contradicts the clarified goal.

Per item, `praxis:verification-before-completion` gates on the item's tests and the typecheck; its end-to-end row is met once for the whole batch, at the Wrap.

Per item, before its commit: `Skill: "praxis:verification-before-completion"`. Delete the processed diagnostics added while investigating (prints of intermediate state), or demote the essential piece into the regression test; the raw capture at a boundary stays. Documented behavior changed → `Skill: "diataxis:diataxis"` (bare: `diataxis`; separate plugin — if it resolves in neither form, surface `/plugin marketplace add moiri-gamboni/diataxis-skill`), classify the kind(s) touched, update those docs.

## Artifact effects

Record only what a future session would otherwise re-litigate: decisions with rationale, rejections with stickiness, fixed-outcome amendments, constraints with provenance, falsifier evidence against prior entries. Everything else lives in commits — the file is not a changelog.

| Item outcome | Effect |
|---|---|
| A bug whose cause is machinery the plan trimmed or leaned out, or a Rejected/Deferred item | Falsifier evidence logged against that Resolution Log entry (angle: iterate) |
| Fix with no decision content | Commit only — nothing recorded |
| Design decision made along the way | Resolution Log entry (angle: iterate); new deliverable → Scope "Actually new" line |
| Scope change | **Fixed outcomes** amended, dated; check whether the new scope unsticks prior sticky rejections — the user contradicting their earlier self is the one legitimate unsticking event |
| Constraint / clarification | Key Constraints entry with provenance tag (`[user]` quoting their words / `[fact]` citing / `[assumed]`) |
| Prototype handoff exists | Keep its "Decisions + tradeoffs", "Solid vs provisional", and "Assumptions, limits, next" sections current |

**Lazy file (solo mode).** On the first entry-worthy event — not before — create `plans/<slug>.md` with only the sections other workflows consume, in the formats of `${CLAUDE_SKILL_DIR}/../design/plan-format.md` (read it; don't invoke `/praxis:design`): Plan Header (Goal + Fixed outcomes), Key Constraints (provenance-tagged), Resolution Log. No matrix, no tasks, no architect sections — those coordinate a pipeline that didn't run. A session with no entry-worthy events creates nothing; that is the correct outcome, not a gap.

## Wrap (after the batch, not per item)

Check the batch against the done-lines from above on real input, not only tests (how: `${CLAUDE_SKILL_DIR}/../verification-before-completion/runtime.md`). Then review scaled to the batch's risk: trivial → verification evidence suffices; error handling or fallbacks touched → one `praxis:silent-failure-hunter` via Agent on the batch diff; comments or docs added or changed → one `praxis:comment-analyzer` via Agent on the batch diff, whatever the size (these two report every finding with its confidence: fix those at or above 80, list the ones marked below the bar in the summary); multi-file or risky → `Skill: "praxis:review"` scoped to the batch range — in its Re-Review mode when the batch answers prior review findings.

Fixing what a Wrap `praxis:review` found is one fix round and gets one Re-Review (`Skill: "praxis:review"` on the fix diff plus the prior findings), not a fresh review. What the Re-Review still finds is not reviewed again: a Critical or Important leftover is still fixed and re-tested; the rest is declined with the reason, or put to the user when it collides with a `[user]` decision or a fixed outcome. Last, a batch that crosses an external boundary or runs on infrastructure is rehearsed per that file's Rehearsal section, after the fixes so they are rehearsed too.

A delegated build (a `praxis:implementer` or any other agent wrote the code) doesn't move the Wrap: this session runs it on the delegate's diff before the work lands (a PR opened or updated, a merge, a push to a shared branch). The delegate's own review pass and any CI review check are inputs to it, never substitutes.

Land where the work lives: open PR → push to its branch. Otherwise: "Commits are local; push when ready."
