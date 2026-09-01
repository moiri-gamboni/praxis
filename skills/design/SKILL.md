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

**Fixed outcomes vs variable means.** The features/results the user asked for are fixed; all machinery delivering them is variable. Design the minimum that delivers them competently — tested, sound seams, real errors surfaced, sensible performance. The floor is real: don't cut tests for reachable behavior, error surfacing for reachable failures, or the seams extension needs.

**Code is a liability.** Every guard, knob, fallback, abstraction, instrument, and test carries permanent comprehension and maintenance cost. A requirement that traces only to "the spec/design doc says so" is challengeable; one that traces to a fixed outcome or a real external constraint (law, data loss, PII, money) is not.

**Crash-loud beats handle-quietly for impossible states.** If a state can't happen, let it raise — don't catch, wrap, default, or re-validate what was validated one frame up. A guard for a state that cannot occur hides real failures. Defensive code needs all three: specific failure scenario, realistic likelihood, consequence if unhandled.

## Phase 1: Architecture

### 1.1 Validate Input + Read Ideation

Require a feature description; ask if missing.

Check for `plans/<slug>-ideation.md`. If present, read it (output of `praxis:ideate`: problem, prior art, alternatives, concept, constraints) and use as foundational context. If absent, ask: "No ideation file. Run `praxis:ideate` first, or proceed without prior-art search?"

Also check for an existing `plans/<slug>.md` — prior `/praxis:iterate` work leaves a minimal one (fixed outcomes, provenance-tagged constraints, Resolution Log). Read it and carry sticky rejections and `[user]` constraints forward: the new plan supersedes the file, never the user's recorded decisions.

### 1.2 Shared Exploration Wave

Dispatch 5 `praxis:code-explorer` agents in parallel, one per **dimension**:

- **Architectural fit**: existing patterns, abstractions, conventions
- **Touchpoints**: files, modules, integration points crossed; data flow boundaries
- **Risks & dependencies**: what could break, coupling, sequencing constraints, fragility
- **Constraints**: performance, security, backward compat, observability
- **Failure modes**: how the user-facing problem manifests (completion / abort / drop / crash); per mode: trigger, state, what the user sees. From logs/observations, not just code paths.

Each explorer writes findings to `plans/<slug>/.workspace/exploration/<dimension>.md` and returns: 1-paragraph overview + path + top 3 headlines + 5-10 essential files.

Prior art belongs to `praxis:ideate`, not here.

### 1.2.5 Synthesize Shared Context

Coordinate the 5 outputs into a 1-2 page document: per-dimension highlights, deduped essential files (~15-20), cross-dimension findings, **failure-mode coverage table** (per mode: covered today? if not, what's needed). Architects in 1.3 consume this.

### 1.2.7 Optional Second Wave

On materially new context (constraint outside original scope, alternative needing context, integration with unexamined system), propose a focused second wave:

```
Dialogue surfaced changes that may need re-exploration:

- <deviation 1> — original didn't cover <area>
- <deviation 2> — original assumption invalidated

Proposed focus:
1. <Area 1>: <why>
2. <Area 2>: <why>

Run? (y/n, or specify different focus)
```

Material changes only. Cap at one re-exploration. User approval required.

### 1.2.8 Goal Restatement

Restate the goal back to the user before architect dispatch:

1. **Goal + fixed outcomes**: paraphrase intent + scope; list the **fixed outcomes** — the features/results the user actually asked for, stated as results, not mechanisms; name the dominant failure mode. Invite correction. The plan must deliver the fixed outcomes; everything else — guard density, knobs, instrumentation, schema richness, test volume — is means, chosen lean.
2. **Constraint audit**: list every constraint the architecture will bend around, each with its provenance tag from the ideation doc — `[user]` (quote their words), `[fact]` (cite), `[assumed]`. **Batch-confirm the `[assumed]` ones with the user now**: each costs them one word to confirm or overturn; each wrong assumption that slips through becomes an invented contract that costs an architect round to build around and a red-team round to demolish. If the ideation doc carries no tags, derive them here — anything not traceable to the user's words or a cited fact is `[assumed]`.
3. **Architectural change appetite** (only if 1.2.5 coverage flags in-pattern gaps): "Should architects stay in-pattern, or is infrastructure in scope?"

Silence = confirmation.

### 1.3 Per-Architect Exploration + Design

Spawn 2-3 `praxis:code-architect` agents in parallel, each with a different philosophy:

- **Minimal changes**: smallest change set, maximum reuse, low risk
- **Clean architecture**: best design, maintainability, long-term extensibility
- **Pragmatic balance**: sweet spot between minimal and clean

Each receives the shared context + ideation file (if any) + the fixed outcomes from 1.2.8 + their philosophy. Architects do narrower exploration scoped to their approach (their job: "what my approach needs to touch," not "the lay of the land").

All three philosophies share a floor (competent: tested, sound seams) and a ceiling (nothing that doesn't trace to a fixed outcome or real constraint). Clean means better factored, not more machinery.

**Constraint bindingness follows provenance.** `[user]` decisions bind — a conflict is flagged explicitly, never silently obeyed into a worse design or silently violated. `[assumed]` constraints are challengeable by default, and the trigger is cost: the moment honoring one requires compensating machinery or a worse architecture (e.g. inventing a byte-identical-output contract to satisfy an assumed "never change this component"), escalate the question instead of paying the price. Do not brief architects with blanket "the ideation doc is binding" language — bindingness is per-constraint.

Each writes design to `plans/<slug>/.workspace/architects/<approach>.md` containing:
- Patterns & conventions found (with `file:line`)
- Architecture decision with rationale
- Component design (file paths, responsibilities, interfaces)
- Data flow from entry to output
- Build sequence as an ordered checklist
- Critical Files for Implementation (priority order, **no count cap** — list every file that drives the design)

Returns to coordinator: 1-paragraph overview + path + top 3 trade-offs vs others + Critical Files headline (count + 3-5 highest-priority; full list lives in the file).

### 1.4 Synthesis (Merged Plan)

Coordinator-level. No agent dispatch — operate on architect outputs and shared context.

1. **Per-decision matrix**. Decisions where architects diverged. Score each row: `✓✓` (clearly best), `✓` (acceptable), `✗` (problematic), relative within row.

2. **Per-row tags**:
   - **Stakes** (high/med/low): how bad if this pick is wrong. Consider feature impact, reversibility, and user-visibility.
   - **Confidence** (high/med/low): property of the pick; row pattern (one `✓✓` = clear, two = close call, all `✓` = doesn't matter)
   - **Crux to flip**: one line; what would change the pick
   - **Lean tie-break**: when a row is a close call (two `✓✓`) or doesn't matter (all `✓`), default to the leaner pick; the crux-to-flip records what would justify the heavier one
   - High stakes + medium-or-lower conf → user input matters here

3. **Sort** by stakes (high → low), then confidence (low → high).

4. **Coupling check**. Surface cross-decision dependencies (e.g. "coalescing only makes sense if cadence is all-emits").

5. **Synthesis shape** (architects work independently; convergence ≠ borrowing):
   - **Pick-per-dimension**: decisions independent; synthesis = matrix winners
   - **Base + borrow**: picks cluster around one architect; Net statement per adjustment
   - **True hybrid**: picks orthogonal; Net statement on integration cost

6. **Net statement** (per adjustment in base+borrow or true hybrid shapes; per high-stakes-medium-conf deep dive in pick-per-dimension):
   ```
   ### <decision>
   **In tension**: <dim A> ↔ <dim B>
   **Architect positions**: M=..., P=..., C=...
   **Net**: <direction + specific reason>
   **Crux to flip**: <signal>
   ```
   If Net is unfillable, drop the adjustment/deep-dive.

7. **Structured Alternatives Considered** (workspace, per-architect):
   ```
   - **<Approach>** — <2-3 sentence package description>
     - Diverges from chosen plan on: <matrix decisions>
     - Why rejected: <specific reason>
     - Bits salvaged: <if any>
   ```

Output: matrix, coupling, synthesis shape, Net statements, Alternatives.

### 1.5 Red-Team Fleet

Spawn `praxis:red-team` agents in parallel, one per attack angle. Standard angles:

1. **Architectural soundness** — abstraction violations, hidden coupling, pattern fit
2. **Failure modes** — error paths, silent swallowing, partial failures
3. **Operational concerns** — deploy, rollback, observability, scale behavior
4. **Hidden complexity** — looks simple but isn't, deferred decisions, magic
5. **Scope & minimality** — solves the stated problem? what's assumed? what does the design build that no fixed outcome needs — impossible-state guards, single-value knobs, fallbacks for committed siblings, instrumentation with no named reader, duplicated machinery? Cut-proposals are first-class findings. Includes the **invented-constraints hunt**: for each constraint the design pays a material price to honor, trace it to a user statement, code fact, or external reality (law, data loss, money); a constraint traceable only to a design/ideation doc's own phrasing is a finding — attack the premise, not just the machinery built to satisfy it.

Conditional:

6. **Security & abuse** — when feature involves user input, auth, data exposure, privilege boundaries, external integrations. Dispatch this angle with `model: opus` (the per-call override wins over the agent's `fable`): attack-surface analysis trips Fable's cybersecurity classifier, which hops the request to another model mid-review.
7. **Documentation currency** — when design names third-party libs/APIs. Agent uses WebSearch/WebFetch to verify each named dependency exists, usage matches current docs, no deprecations

Each returns findings with confidence (0-100 + justification).

**Aggregate**: dedupe across angles (cross-angle overlap = evidence-strengthening). Severity-rank: Critical / Important / Suggestion.

**Cross-reference user-direction rejections**: check each finding against the Resolution Log's existing "Rejected (by user direction; sticky)" entries. A finding that reintroduces user-rejected scope under a different framing (e.g. "session compromise" for what user rejected as "spoof-high griefing") gets Rejected automatically, with reference to the user's original direction. Reframing the motivation does not unreject the concern.

**Optional verification pass**: for Critical findings, dispatch a second red-team agent to independently reproduce. Mark **confirmed** or **disputed** (don't drop disputed; user decides).

### 1.6 Decision + Final Validation

Present merged plan + matrix + aggregated findings. Each finding gets severity (Critical / Important / Suggestion) AND resolution:

- **Fixed (code | doc | framing | scope)**: describe change + cost
- **Deferred**: real but out of scope; what, why, revisit trigger
- **Rejected**: not real; cite evidence

Iterate (revise plan, re-run affected angles). Severity and resolution stay separate; funnel ("1 Critical Fixed, 3 Important Deferred, 5 Suggestion Rejected") is meaningful.

**Resolution triage.** Fixed-by-adding-machinery requires the three-part articulation (scenario, likelihood, consequence) — without it, the finding resolves Rejected or Deferred, not Fixed. Rejected (by analysis) is a healthy, expected outcome; the funnel is meaningful precisely because not everything gets fixed. When a finding contests a decision the architects settled unanimously, first ask: did it actually contest the choice, or identify a narrow add they missed? The latter is an auto-resolution (apply the narrow fix), not a new decision point.

**Traceability check**. Trace the user-stated symptom through the plan: "User does X. Today: Y. After plan: Z." For every failure mode in 1.2 dimension 5. If any doesn't trace to a closed gap (or explicit deferral), return to architects/red-team.

Run the fleet one final time. Clean run = ready for Phase 2.

## Phase 2: Test Design

Invoke `Skill: "praxis:test-driven-development"`.

Design the test strategy for the chosen architecture:

1. Identify key behaviors per component
2. Write test specs (inputs, expected outputs, edge cases)
3. Map tests to components — each task with a behavioral deliverable starts with a clear failing test. Not every task has one: tasks whose deliverable is docs, config, wiring, or cosmetics get a **verification line** (run it / render it / review it), never a manufactured test asserting source text or code shape to satisfy the red-green ritual.
4. Identify integration tests across components

**Behavior-only rule**: keep a test only if it exercises a code path and asserts its output or effect. Volume proportional to the risk retired. A test locks behavior — don't lock implementation shape, constants meant to change, or behavior the plan doesn't need.

Present the strategy. These tests become the plan's acceptance criteria.

## Phase 3: Implementation Plan

Write to `plans/<slug>.md`. Propose a kebab-case slug if not obvious or ask the user.

**File discipline**: this skill writes only `plans/<slug>.md`. No other source files.

Write the plan assuming the implementer has zero codebase context.

**Plan epistemic status**: fixed outcomes, acceptance criteria, and integration contracts are binding downstream. The rest of the plan is the current best operationalization — implementers right-size internal machinery (guards, knobs, fallbacks, instrumentation) against the crash-loud principle, logging each deviation. Never silently dropped, never silently gold-plated.

Plan structure:

### Plan Header

```markdown
# [Feature] Implementation Plan

**Goal:** [One sentence]
**Fixed outcomes:** [Short list from 1.2.8: the features/results the user asked for — what the plan must deliver; everything else is means]
**Architecture:** [2-3 sentences]
**Failure mode targeted:** [The dominant failure mode this plan closes, from 1.2 dimension 5]
**Tech Stack:** [Key technologies]
```

### Decision Record

The Decision Record is the canonical source for everything Phase 3's Present for Approval renders inline. Same content, two consumption modes; future readers (cold reviewers, automated re-reviews) get the same context the user got.

**Chosen approach**: paragraph summarizing what was picked and why it won.

**Scope**:
- **Already implemented** (skip if empty): items found in exploration; no work needed.
- **Actually new**: genuine deliverables.
- **Departures from brief** (drops AND additions): `brief asked X → plan delivers Y → why diverged`. Load-bearing justification.
- **Left out (deliberately)** (skip if empty): machinery considered and not built — guard / knob / fallback / instrument — one line each with the trigger that would justify adding it later. Makes leanness auditable rather than a silent absence.

**Per-decision matrix** (from 1.4):
```
| Dimension | Decides | M | P | C | Pick |
| **<name>** (<stakes> stakes) | <question> | ✗/✓/✓✓ <stance> | ... | ... | **<pick>** (<conf> conf). <one-line rationale> |
```

**Worth-your-input** (skip if nothing is medium-or-lower conf AND material stakes):
```
### <decision>
- **In tension**: <dim A> ↔ <dim B>
- **Architect positions**: M=..., P=..., C=...
- **Net**: <direction + specific reason>
- **Crux to flip**: <signal>
```

**Architect approaches** (one short paragraph per architect describing the package; mark the chosen one):
- **Minimal**: ...
- **Pragmatic**: ...
- **Clean**: ...

**Alternatives Considered** (per non-chosen architect):
```
- **<Approach>**
  - Diverges from chosen plan on: <matrix decisions>
  - Why rejected: <specific reason tied to those divergences>
  - Bits salvaged: <if any, what was incorporated into the chosen plan>
```

**Synthesis shape**: label from 1.4 (pick-per-dimension / base + borrow / true hybrid) plus one paragraph on coupling.

**Resolution Log** (one entry per finding from 1.5 and from the Phase 3 trim pass, `angle: trim`):
```
- **<finding title>** (severity: Critical | Important | Suggestion; angle: <attack angle>)
  - Confidence: <0-100>
  - Resolution: Fixed (code | doc | framing | scope) | Deferred | Rejected (by analysis | by user direction; sticky)
  - Detail: <what was done; for "by user direction" quote the user's actual words>
  - Cost (if Fixed code): <LoC / complexity / perf>
  - Revisit trigger (if Deferred): <signal>
```

Silent acceptance not allowed; every finding gets a logged resolution. **Entries marked "Rejected (by user direction; sticky)" are not for re-litigation**: red-team agents re-running against the plan must check this section and treat reframed reintroductions of rejected concerns as Rejected, not Deferred.

The Resolution Log outlives the plan: `/praxis:iterate` appends entries (angle: iterate — falsifier evidence, scope amendments, post-ship decisions) as the work evolves. On a re-run of this skill, treat those entries as part of the record, not corruption.

### Truncated example plan file

(BYOK cost-stream recovery; one entry shown per section.)

```markdown
# BYOK Cost Stream Recovery — Implementation Plan

**Goal:** Make the displayed cost (UI pill + cap accounting) match what Anthropic actually billed, in all stream-end scenarios.
**Failure mode targeted:** Streams ending before `message_delta` arrives (user-initiated abort + isolate death), leaving the database at the pre-stream reservation only while Anthropic has already billed.
**Architecture:** Continuous delta-commit pattern. Every cost-write path (server per-update, post-stream reconcile, server abort handler, client-driven `/api/reconcile-cost` POSTs) runs the same idempotent SQL against `logging_messages.cost_settled_micro_usd` (new column) + `user_api_usage.cost_micro_usd`. Client estimates output cost per `content_block_delta` (character-count) for real-time UI updates.
**Tech Stack:** Cloudflare Workers + Neon serverless Postgres + Anthropic SSE. TypeScript, BigInt µUSD math. React 18 client.

## Decision Record

**Chosen approach**: Continuous delta-commit pattern replacing the post-stream-reconcile-only model. Five writers (server per-update emits, post-stream reconcile, abort handler, client periodic POSTs, client final POST on Stop) run the same idempotent SQL. Reservation kept as input-only baseline.

### Scope

**Already implemented (no new work):**
- Client parses `running_cost` SSE frames, captures the last value, POSTs to the reconcile endpoint on stream end with a retry queue.
- [... 1 more entry]

**Actually new:**
- Continuous server-side persistence on every authoritative SSE event.
- [... 2 more entries]

**Departures from brief:**

#### Drop: live writes to `user_api_usage`

You asked for live writes to both `user_api_usage` and `logging_messages`. Plan writes only to `logging_messages`.

The conflict is concrete. `user_api_usage.cost_micro_usd` uses additive delta semantics throughout its lifecycle: `reserveCost` pre-stream adds `projected`; the post-stream reconcile adds `actual - projected`, bringing the row to `prev + actual`. If we add a mid-stream GREATEST-clamp to the running cost on the same column, the row jumps to `max(prev, running)` mid-stream; the post-stream reconcile then adds `actual - projected` on top, double-counting by `running` worth of µUSD. [... rest of rationale]

Plan picks: don't write to `user_api_usage` live at all. The cap-bar tick during long streams stays as-is.

#### [... 1 more departure]

### Per-decision matrix

| Dimension | Decides | M | P | C | Pick |
|---|---|---|---|---|---|
| **Write cadence** (high stakes) | Which SSE events trigger a DB write to persist running cost? | ✓ `message_start` only; doesn't catch authoritative cost if reconcile dies. | ✓✓ `message_start` + `message_delta`; two writes/stream, delta is authoritative. | ✗ Plus 5s poller behind coalescing; ~60 writes/long stream. | **P** (high conf). P closes the documented failure mode (reconcile death after `message_delta`); M leaves the gap open; C overbuilds. |
| [... 6 more rows] |

### Worth your input

**Sanity ceiling on reconcile endpoint**
- *In tension*: defense-in-depth (security) vs ambiguous constant choice (false positives for BYOK users with legitimately high spend)
- *Why opposing*: a ceiling closes spoof-high griefing, but BYOK's effective cap is Anthropic's Console limit (not ours), so any constant we pick is somewhat arbitrary; values that are legitimate spend for one user are griefing-shaped for another
- *Architect positions*: M skip; P defer with documented rationale; C add `LIFETIME_CAP × 10` ($50)
- *Net (current)*: defer. The griefing vector requires session compromise (XSS, cookie theft), which is a much bigger problem on its own. The per-message cost field doesn't gate the cap (cap is gated by `user_api_usage`, which this endpoint never touches). The ceiling treats a downstream symptom of session compromise rather than the precondition.
- *Crux to flip*: griefing observed without session compromise (e.g. self-XSS from a malicious browser extension, shared device misuse). Then the ceiling becomes load-bearing as a non-session-compromise defense.

(only 1 entry here in this case — section skipped entirely if zero medium-conf material-stakes decisions)

### Architect approaches

**Pragmatic** (chosen): Two writes per stream (`message_start` + `message_delta`), `logging_messages` only. Cost math extracted to a shared module so client and server compute identically (BigInt symmetry on the wire). One ENV var for emergency rollback. Sanity ceiling deferred with documented rationale. Reconcile POST sites stay inline (different control flow). New diagnostic event `DiagnosticMessageDeltaPersist` parallel to existing floor. ~5 files.

[... 2 more architects: Minimal, Clean]

### Alternatives Considered

- **Minimal**
  - Diverges from chosen plan on: cost math sharing (duplicate), write cadence (no delta persist)
  - Why rejected: the cadence divergence alone disqualifies it. Without `message_delta` persist, server state is identical to today and the gap stays open.
  - Bits salvaged: "essentially free, two writes per stream" framing carried into the chosen plan.
- [... 1 more: Clean]

### Synthesis shape

**Effectively Pragmatic, no cross-architect borrowings.** Pragmatic's decisions cohere internally. Cadence (start + delta) is the load-bearing choice; coalescing falls out (no volume problem); diagnostic naming is downstream observability; kill-switch is independent operational concern. The only coupled pair is cadence → coalescing; Pragmatic picks the low-cadence side and coalescing falls out as unnecessary.

[... cross-cutting trigger to watch, if any]

### Resolution Log

26 findings: 17 Fixed, 4 Deferred, 5 Rejected.

- **D1: sanity ceiling on the reconcile endpoint** (severity: Important; angle: security)
  - Confidence: 70
  - Resolution: Rejected (by user direction; sticky)
  - Detail: user said "spoof-high griefing is not an issue at all, if users want to blow their free quota it's on them." Reframed reintroductions under "session compromise" or similar = also Rejected.
- [... 3 more Rejected entries; 4 Deferred; 17 Fixed]
```

### Task Structure

Each task targets one component. **Right-sizing:** a task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's gate — fold setup, configuration, scaffolding, and doc steps into the task whose deliverable needs them; split only where a reviewer could reject one task while approving its neighbor.

Task header references skills the implementer activates:

````markdown
### Task N: [Component]

**Skills to activate:**
- `praxis:test-driven-development` (failing test first; verify red; implement; verify green)
- `praxis:verification-before-completion` (confirm tests pass with evidence before commit)

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py`
- Test: `tests/exact/path/to/test.py`

**Interfaces** (only when other tasks depend on this one — an implementer sees only their own task, so this is how they learn neighboring names and types):
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter and return types]

**Acceptance criteria** (from test design):
- [behavior]: [expected outcome]

- [ ] Write failing test for [behavior]
- [ ] Run test, verify it fails (red)
- [ ] Implement minimal code to pass
- [ ] Run test, verify it passes (green)
- [ ] Commit with semantic message
````

For tasks without a behavioral deliverable (docs, config, wiring, cosmetics): drop the `praxis:test-driven-development` activation and swap the red-green checklist for `- [ ] Verify: <command / render / check + expected result>` — never a test pinning source text or shape.

For documentation deliverables specifically: list `diataxis:diataxis` under **Skills to activate** (ships as a separate plugin; the name-resolution rule applies — if it resolves in neither namespaced nor bare form, surface `/plugin marketplace add moiri-gamboni/diataxis-skill` as what's missing), and name the kind(s) the deliverable serves in the task title and acceptance criteria — "update the how-to for X", "extend the Y reference" — never a bare "update docs". Feature work almost always touches how-to guides and reference, sometimes explanation, almost never tutorials. The kind classification belongs in the plan; the form rules stay in the skill.

For frontend features, note in plan header that `praxis:frontend-design` skill auto-activates during implementation.

### Quality Rules

- **No placeholders**: never "TBD", "add appropriate X", "similar to Task N"
- **Bite-sized steps**: one action per step (2-5 minutes)
- **Exact paths and code**: file paths, code blocks, commands with expected output

### Self-Review

After writing, check:
1. Spec coverage: every requirement maps to a task
2. Placeholder scan: nothing from the no-placeholders list
3. Type consistency: names match across tasks
4. Scope: each task touches ≤2-3 files
5. Ambiguity: no requirement reads two ways
6. Outcome trace (reverse): every task, guard, knob, field, and test serves a fixed outcome or named external constraint; anything tracing only to a design doc's say-so gets cut or moved to Left-out

Fix inline.

### Trim Pass

Self-Review check 6 is your own reverse trace; this is the independent one. Dispatch `praxis:trimmer` via Agent (plan mode) with the plan path, the fixed outcomes from 1.2.8, the ideation file if any, and report path `plans/<slug>/.workspace/trim.md`. It returns cut-proposals — L1 (the plan delivers the same with less) and L2 (a plan clause itself doesn't earn its cost) — each with outcome-trace, counted cost, risk + falsifier, confidence.

Adjudicate each finding into the Resolution Log (angle: trim), same vocabulary as red-team findings:

- **L1 accepted** → edit the plan; machinery deliberately not built goes to Left-out with its re-add trigger.
- **L2** → judge against the fixed outcomes; material ones surface in Worth-your-input rather than being decided silently.
- **Rejected** → cite the outcome or constraint the machinery serves (three-part articulation for defensive code).

### Plan-Document Review

Runs only after the Trim Pass is fully adjudicated and accepted cuts are applied — never in parallel with the trimmer. The trimmer's cuts edit the plan; a reviewer dispatched alongside it verdicts the pre-trim document and is stale on arrival.

Dispatch `praxis:plan-doc-reviewer` via Agent with paths to the plan and ideation file. It returns Approved | Issues. On Issues: fix flagged items, re-run — passing the prior issues so the re-run verdicts each one and reviews the edits, not the whole plan afresh. Iterate to Approved. Recommendations are advisory.

### Present for Approval

Inline rendering of the Decision Record. Same content as the plan file; user shouldn't need to open the plan to know what you decided. **No code snippets, no exhaustive file lists, no path-by-path walkthroughs** — those live in the plan's Task Structure. Naming key files / types / functions in architectural prose is fine.

Sections (mirror Decision Record subsections):

1. **What and why** = renders Plan Header (Goal + Failure mode targeted + Architecture). 3-5 sentences, intent-level.
2. **Scope** = renders Decision Record's Scope (already implemented / actually new / departures).
3. **Per-decision matrix** = renders Decision Record's matrix.
4. **Worth your input** = renders Decision Record's Worth-your-input (skip if empty).
5. **Architect approaches** = renders Decision Record's Architect approaches (below matrix, since dimensions are now defined).
6. **Synthesis shape** = renders Decision Record's Synthesis shape.
7. **Resolution Log** = renders Decision Record's Resolution Log, **ordered Deferred → Rejected → Fixed** (user cares about Deferred/Rejected most; group Fixed by severity with Critical at full detail, Important+ collapsed).
8. **Plan path** + `/praxis:implement`.

Anti-patterns: code blocks, file lists, task numbers, implementation walkthroughs.
