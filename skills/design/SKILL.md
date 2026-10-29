---
name: design
description: Use when starting a new feature that needs architectural design before implementation — works through competing approaches, adversarial review, test design, and implementation plan.
argument-hint: "<feature description>"
allowed-tools: Read, Write, Edit, Glob, Grep, Agent, Task, Skill, AskUserQuestion
---

# Design

**Feature:** "$ARGUMENTS"

**Name resolution:** `praxis:`-prefixed skill and agent names are the plugin registrations; a local checkout registers them bare. If a referenced skill or agent resolves in neither form, tell the user what's missing instead of silently substituting a different one.

## Working Principle

**Fixed outcomes vs variable means.** The features/results the user asked for are fixed; all machinery delivering them is variable. Design the minimum that delivers them competently (sensible performance included); the floor is real: tests for reachable behavior, surfaced errors for reachable failures, the seams extension needs.

**Code is a liability.** Every guard, knob, fallback, abstraction, instrument and test carries permanent cost. A requirement tracing only to "the spec/design doc says so" is challengeable; one tracing to a fixed outcome or a real external constraint (law, data loss, PII, money) is not.

**Crash-loud for impossible states.** If a state can't happen, let it raise: don't catch, wrap, default, or re-validate what was validated one frame up. Defensive code needs all three: specific failure scenario, realistic likelihood, consequence if unhandled.

**Reachable failures propagate; boundaries capture raw.** A failure that can happen still raises by default, raw request, response and input attached; a catch also needs a named recovery that beats crashing. Raw boundary capture is permanent, never a cut target; the named-reader test applies to *derived* instrumentation. Rules: `praxis:observe-before-model`.

**Where it stops.** Design stops for the user at 1.2.8 (end the turn there; the reply, or silence on the next turn, confirms) and at 1.2.7 for the user's yes, and at 1.6 when a disputed Critical remains (the user decides it before Phase 2). Every other presentation is inline and the run continues.

## Phase 1: Architecture

### 1.1 Validate Input + Read Ideation

Require a feature description; ask if missing. Fix the kebab-case `<slug>` now (an existing `plans/*-ideation.md` for this feature supplies it; otherwise derive it from the description, the user can override); every `plans/<slug>…` path below uses it. Read `plans/<slug>-ideation.md` if present. If absent, or its Prior Art Investigated section is empty, run a bounded prior-art pass (one subagent via Agent, WebSearch + Exa: canonical implementations, reference repos, documented pitfalls, libraries to adopt), reported in the 1.2.5 synthesis; don't offer to skip it. An existing `plans/<slug>.md` from `/praxis:iterate` (fixed outcomes, tagged constraints, Resolution Log): carry its sticky rejections and `[user]` constraints forward; the new plan supersedes the file, never the user's recorded decisions.

### 1.1.5 Flow Sketch

Before exploring, write the system as stages and boundaries: what enters, each transformation, what leaves. For each boundary (data crossing into or out of something this codebase doesn't own: HTTP API, SDK, CLI/subprocess, file format, database, queue, LLM), record what crosses and where its shape is known from: `codebase` (exercised here, `file:line`), `docs` (vendor's current reference, URL, unobserved), `capture` (raw response on disk, path), `assumed` (unchecked). Slice 0 goes first through every `docs` and `assumed` boundary. With no codebase to explore (greenfield, pipelines), the sketch replaces 1.2.

### 1.2 Shared Exploration Wave

Dispatch 5 `praxis:code-explorer` agents in parallel, one per dimension: **architectural fit** (patterns, abstractions, conventions), **touchpoints** (files, modules, integration points, data-flow boundaries), **risks & dependencies** (breakage, coupling, sequencing), **constraints** (performance, security, backward compat, observability), **failure modes** (how the user-facing problem manifests: completion / abort / drop / crash; per mode trigger, state and what the user sees, from logs, not just code paths). Each writes `plans/<slug>/.workspace/exploration/<dimension>.md` and returns an overview, the path, top 3 headlines and 5-10 essential files.

### 1.2.5 Synthesize Shared Context

Merge into 1-2 pages: per-dimension highlights, deduped essential files (~15-20), cross-dimension findings, and a **failure-mode coverage table** (per mode: covered today? if not, what's needed).

### 1.2.7 Optional Second Wave

Materially new context from dialogue (a constraint outside scope, an unexamined system) → propose at most one focused re-exploration, naming the deviations and focus; run it only on the user's yes.

### 1.2.8 Goal Restatement

Before architect dispatch, restate to the user:

1. **Goal + fixed outcomes**: intent, scope, the fixed outcomes (results the user asked for, not mechanisms) and the dominant failure mode; invite correction. Everything else is means, chosen lean. For each `docs` or `assumed` boundary, name the observation that will pin it.
2. **Constraint audit**: each constraint the architecture bends around, tagged `[user]` (quote), `[fact]` (cite) or `[assumed]`. **Batch-confirm the `[assumed]` ones now** (a word each, against an architect and a red-team round spent on a wrong one; state, don't re-ask, picks the user handed over); anything not traceable to the user's words or a cited fact is `[assumed]`. The audit becomes the plan's Key Constraints.
3. **Change appetite** (only if 1.2.5 flags in-pattern gaps): stay in-pattern, or is infrastructure in scope?

Silence = confirmation.

### 1.3 Per-Architect Exploration + Design

Spawn 2-3 `praxis:code-architect` agents in parallel, one philosophy each: **Minimal** (smallest change set, maximum reuse), **Clean** (best design, extensibility), **Pragmatic** (between). Each gets the shared context, flow sketch, ideation file, fixed outcomes, the 1.2.8 constraint audit with its tags, and its philosophy, and explores only what its approach touches. Shared floor (tested, sound seams) and ceiling (nothing untraced to a fixed outcome or real constraint): clean means better factored, not more machinery.

**Bindingness follows provenance.** `[user]` decisions bind: flag a conflict, never silently obey it into a worse design or silently violate it. `[assumed]` constraints are challengeable once honoring one needs compensating machinery or a worse architecture (e.g. a byte-identical-output contract invented for an assumed "never change this component"): escalate instead of paying. Never brief architects that "the ideation doc is binding".

Each writes `plans/<slug>/.workspace/architects/<approach>.md` (patterns with `file:line`, decision and rationale, component design with paths and interfaces, data flow, build sequence, Critical Files in priority order, uncapped) and returns an overview, the path, top 3 trade-offs and the top Critical Files.

### 1.4 Synthesis (Merged Plan)

Coordinator-level, no agents:

1. **Per-decision matrix** over the decisions where architects diverged, cells `✓✓` / `✓` / `✗` relative within the row. Tag rows with **stakes** (high/med/low: cost of a wrong pick in feature impact, reversibility, visibility), **confidence** (high/med/low; one `✓✓` = clear, two = close call, all `✓` = doesn't matter) and **crux to flip**. Close calls and doesn't-matter rows take the leaner pick; the crux names what would justify the heavier one. High stakes + medium-or-lower confidence = user input matters. Sort by stakes (high first), then confidence (low first).
2. **Coupling check**: picks only sensible given another.
3. **Synthesis shape** (architects worked independently, so convergence isn't borrowing): **pick-per-dimension** (independent decisions; take the matrix winners), **base + borrow** (picks cluster on one architect), or **true hybrid** (orthogonal picks).
4. **Net statement** per adjustment (base + borrow, hybrid) or per high-stakes medium-confidence deep dive (pick-per-dimension); drop any you can't fill: `### <decision>` with **In tension** (dim A ↔ dim B), **Architect positions** (M=…, P=…, C=…), **Net** (direction + specific reason), **Crux to flip**.
5. **Alternatives Considered**, per non-chosen architect: package in 2-3 sentences, the matrix decisions it diverges on, why rejected (tied to those), bits salvaged.

### 1.5 Red-Team Fleet

Spawn `praxis:red-team` agents in parallel, one per angle: **architectural soundness** (abstraction violations, hidden coupling, pattern fit); **failure modes** (error paths, silent swallowing, partial failures); **operational** (deploy, rollback, observability, scale); **hidden complexity** (deferred decisions, magic); **scope & minimality**: what does it build that no fixed outcome needs (impossible-state guards, single-value knobs, fallbacks for committed siblings, readerless derived instrumentation, duplication; never raw capture)? Cut-proposals are first-class findings, and this angle hunts **invented constraints**: one the design pays for that traces to no user statement, code fact or external reality is a finding against the premise. Conditionally: **security & abuse** (user input, auth, data exposure, privilege boundaries, external integrations) and **documentation currency** (any `docs`/`assumed` boundary or named third-party API: check each with WebSearch/WebFetch (exists, usage current, not deprecated), given the boundary list).

Findings carry confidence (0-100 + justification). Dedupe across angles (overlap strengthens evidence); rank Critical / Important / Suggestion. A finding reintroducing scope the Resolution Log marks "Rejected (by user direction; sticky)" under a new framing is Rejected, citing the user's direction. A Critical on a high-stakes decision, or one whose fix is costly, is reproduced by a second red-team agent given the merged plan and the claim, replying **Confirmed** or **Disputed** with the evidence and no full review; disputed stays, and the user decides it at 1.6.

### 1.6 Decision + Final Validation

Present the merged plan, matrix and findings, each with a severity and a separate resolution (the funnel of counts is the point): **Fixed (code | doc | framing | scope)** with change and cost; **Deferred** with why and revisit trigger; **Rejected** with evidence. Fixed-by-adding-machinery needs the three-part articulation, else it's Rejected or Deferred; Rejected by analysis is healthy. A finding that only names a narrow add the architects missed is applied, not a new decision point.

**Traceability check**: for every failure mode from 1.2, "User does X. Today: Y. After plan: Z." Any not reaching a closed gap or explicit deferral goes back to architects or red-team. Re-run the fleet on the revised plan until it reports no Critical or Important finding the Resolution Log hasn't already resolved, at most twice; surface what remains to the user.

## Phase 2: Test Design

Invoke `Skill: "praxis:test-driven-development"`. For the chosen architecture:

1. Test specs per component's key behaviors (inputs, expected outputs, edge cases)
2. **Unexercised inputs**: up to five inputs or conditions the fixed outcomes imply, that a reasonable user will hit and no spec covers yet, most likely first; each gets a spec in the component owning the code. None found means checked, not skipped.
3. Each task with a behavioral deliverable starts with a failing test; docs, config, wiring and cosmetic tasks get a **verification line** (run / render / review it), never a test asserting source text or code shape
4. Integration tests across components
5. Specs for `docs`/`assumed` boundaries stay provisional until Slice 0's capture replaces the invented fixture; never mock a response nobody has seen

Present the strategy. **Behavior-only**: a test asserts a code path's output or effect, in volume proportional to the risk retired, never locking implementation shape or constants meant to change. These tests become the acceptance criteria.

## Phase 3: Implementation Plan

Write `plans/<slug>.md` (the 1.1 slug) and no source files. Read `${CLAUDE_SKILL_DIR}/plan-format.md` before writing the plan: it holds the Plan Header, Key Constraints, Decision Record (with the Resolution Log entry format) and task templates.

**The reader** is new to this codebase and design, writes idiomatic code given the exact interface and test, and chooses reasonably wherever the plan leaves room. The plan records what they can't know: your decisions (files, signatures, the design's values, the tests proving each task).

**Epistemic status**: fixed outcomes, acceptance criteria and integration contracts bind. The rest is current best operationalization: implementers right-size internal machinery against crash-loud and log each deviation; nothing silently dropped or gold-plated.

### Task Structure

A task is the smallest unit carrying its own test cycle and worth a fresh reviewer's gate: fold setup, config, scaffolding and doc steps into the task whose deliverable needs them; split only where a reviewer could reject one task while approving its neighbor.

**Task 1 is Slice 0** whenever any boundary is `docs` or `assumed`: the thinnest end-to-end path through every boundary with one real input, raw capture committed at each. Its acceptance criterion is the captures plus one real output checked against the fixed outcome, never a unit test against an invented response. Contracts later tasks build to come from its captures, marked `provisional until Slice 0`; `/praxis:implement` runs Slice 0 alone and pins them before dispatching the rest.

Write each task in `plan-format.md`'s task template.

For documentation deliverables specifically: list `diataxis:diataxis` under **Skills to activate** (ships as a separate plugin; the name-resolution rule applies — if it resolves in neither namespaced nor bare form, surface `/plugin marketplace add moiri-gamboni/diataxis-skill` as what's missing), and name the kind(s) the deliverable serves in the task title and acceptance criteria — "update the how-to for X", "extend the Y reference" — never a bare "update docs". Feature work almost always touches how-to guides and reference, sometimes explanation, almost never tutorials. The kind classification belongs in the plan; the form rules stay in the skill.

### Quality Rules

**A step is done when the implementer can write exactly one reasonable thing from it**: unambiguous, not complete. A test step gives the test's name and assertions with the design's exact values; a code step the signature, file and pinned values, with a body only for an algorithm those don't determine or exact user-facing text the design fixes; a verification step the command and its passing output; a reference to another task goes through its Interfaces block. Lines that decide nothing ("TBD", "handle edge cases", "similar to Task N", an undefined type) are the opposite failure to transcribing code.

**Plan vocabulary stays in the plan**: task numbers, finding IDs, matrix dimensions, mode labels and architect names never reach code, comments, commit messages or docs, which say the reason in the domain's words.

### Self-Review

After writing, check and fix inline: (1) every requirement maps to a task; (2) every step meets the Quality Rules: no gap, and no body the signature and tests already determine; (3) names match across tasks; (4) each task touches ≤2-3 files; (5) no requirement reads two ways; (6) reverse outcome trace: every task, guard, knob, field and test serves a fixed outcome or named external constraint, else cut it or move it to Left out; (7) Slice 0 captures every `docs`/`assumed` boundary before any task parses it; (8) code blocks dominating the plan → swap bodies for signatures and assertions.

### Trim Pass

The independent counterpart of check 6: dispatch `praxis:trimmer` via Agent (plan mode) with the plan path, fixed outcomes, ideation file if any, and report path `plans/<slug>/.workspace/trim.md`. Its cut-proposals, L1 (same delivery with less) and L2 (a plan clause not earning its cost), carry outcome-trace, cost, falsifier and confidence. Log each (angle: trim): **L1 accepted** → edit the plan, unbuilt machinery to Left out with its re-add trigger; **L2** → judge against the fixed outcomes, material ones to Worth your input; **Rejected** → cite the outcome or constraint served (three-part articulation for defensive code).

### Plan-Document Review

Only after the trim pass's cuts are applied (beside the trimmer it would verdict a stale plan): dispatch `praxis:plan-doc-reviewer` via Agent with the plan and ideation paths. On Issues, fix and re-run with the prior issues, so it verdicts each and reviews only the edits. Iterate to Approved; Recommendations are advisory.

### Present for Approval

Render the Decision Record inline in its order, opening with what and why (Goal, failure mode, Architecture; 3-5 intent-level sentences) and ordering the Resolution Log **Deferred → Rejected → Fixed** (Fixed by severity, Critical in full, the rest collapsed). End with the plan path and `/praxis:implement`. No code blocks, file lists, task numbers or walkthroughs.
