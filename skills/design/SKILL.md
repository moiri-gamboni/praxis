---
name: design
description: "Architecture design with competing approaches, adversarial review, test design, and implementation planning"
argument-hint: "<feature description>"
allowed-tools: Read, Write, Edit, Glob, Grep, Task, Skill, AskUserQuestion
---

# Design

**Feature:** "$ARGUMENTS"

## Phase 1: Architecture

### 1.1 Validate Input + Read Ideation

Require a feature description; ask if missing.

Check for `plans/<slug>-ideation.md`. If present, read it (output of `ideate`: problem, prior art, alternatives, concept, constraints) and use as foundational context. If absent, ask: "No ideation file. Run `ideate` first, or proceed without prior-art search?"

### 1.2 Shared Exploration Wave

Dispatch 4 `code-explorer` agents in parallel, one per **dimension**:

- **Architectural fit**: existing patterns, abstractions, conventions
- **Touchpoints**: files, modules, integration points crossed; data flow boundaries
- **Risks & dependencies**: what could break, coupling, sequencing constraints, fragility
- **Constraints**: performance, security, backward compat, observability

Each explorer writes findings to `plans/<slug>/.workspace/exploration/<dimension>.md` and returns: 1-paragraph overview + path + top 3 headlines + 5-10 essential files.

Prior art belongs to `ideate`, not here.

### 1.2.5 Synthesize Shared Context

Coordinate the 4 outputs into a 1-2 page document: per-dimension highlights, deduped essential files (~15-20), cross-dimension findings. Architects in 1.3 consume this.

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

### 1.3 Per-Architect Exploration + Design

Spawn 2-3 `code-architect` agents in parallel, each with a different philosophy:

- **Minimal changes**: smallest change set, maximum reuse, low risk
- **Clean architecture**: best design, maintainability, long-term extensibility
- **Pragmatic balance**: sweet spot between minimal and clean

Each receives the shared context + ideation file (if any) + their philosophy. Architects do narrower exploration scoped to their approach (their job: "what my approach needs to touch," not "the lay of the land").

Each writes design to `plans/<slug>/.workspace/architects/<approach>.md` and returns: 1-paragraph overview + path + top 3 trade-offs vs others + Critical Files (count + 3-5 highest-priority).

### 1.4 Synthesis (Merged Plan)

Coordinator-level. No agent dispatch — operate on architect outputs and shared context.

1. **Synthesis matrix**: 4 dimensions × architect approaches. Score each cell with specific evidence.

2. **Classify decisions** (ATAM):
   - **Sensitivity Point**: affects ONE dimension. Default to best-scoring approach.
   - **Tradeoff Point**: affects MULTIPLE dimensions in opposing directions. Where the architectural argument lives.

3. **Pick winner OR hybridize** based on the matrix.

4. **For every cross-approach borrowing, write a Net statement**:
   ```
   ### Borrowed: <element> (from <X> into <Y>)
   **Type**: Sensitivity | Tradeoff
   **Costs**: <LoC, indirection, mixed patterns, perf>
   **Benefits**: <testability, extensibility, fit>
   **Net**: <why benefit > cost; specific reason>
   ```
   If you can't fill Net, drop the borrowing.

5. **Structured Alternatives Considered** (carries into Decision Record):
   ```
   - **<Approach>** — <2-3 sentences>
     - Why rejected: <specific reason; "didn't fit" doesn't qualify>
     - Bits salvaged: <if any, reference the Net statement>
   ```

Output: merged plan in prose with matrix, classifications, Net statements, Alternatives Considered.

### 1.5 Red-Team Fleet

Spawn `red-team` agents in parallel, one per attack angle. Standard angles:

1. **Architectural soundness** — abstraction violations, hidden coupling, pattern fit
2. **Failure modes** — error paths, silent swallowing, partial failures
3. **Operational concerns** — deploy, rollback, observability, scale behavior
4. **Hidden complexity** — looks simple but isn't, deferred decisions, magic
5. **Scope & assumptions** — solves stated problem? what's assumed? what's left out?

Conditional:

6. **Security & abuse** — when feature involves user input, auth, data exposure, privilege boundaries, external integrations
7. **Documentation currency** — when design names third-party libs/APIs. Agent uses WebSearch/WebFetch to verify each named dependency exists, usage matches current docs, no deprecations

Each returns findings with confidence (0-100 + justification).

**Aggregate**: dedupe across angles (cross-angle overlap = evidence-strengthening). Severity-rank: Critical / Important / Suggestion.

**Optional verification pass**: for Critical findings, dispatch a second red-team agent to independently reproduce. Mark **confirmed** or **disputed** (don't drop disputed; user decides).

### 1.6 Decision + Final Validation

Present merged plan + matrix + aggregated findings. Each finding gets a resolution:

- **Fixed**: addressed; describe change + cost
- **Rejected**: not real; cite evidence
- **Deferred**: real but out of scope; track separately

Iterate (revise plan, re-run affected angles). Resolution Log captures every finding (see Decision Record).

Once decided, run the fleet one final time on the final plan. Clean run = ready for Phase 2.

## Phase 2: Test Design

Invoke `Skill: "test-driven-development"`.

Design the test strategy for the chosen architecture:

1. Identify key behaviors per component
2. Write test specs (inputs, expected outputs, edge cases)
3. Map tests to components — each plan task starts with a clear failing test
4. Identify integration tests across components

Present the strategy. These tests become the plan's acceptance criteria.

## Phase 3: Implementation Plan

Write to `plans/<slug>.md`. Propose a kebab-case slug if not obvious or ask the user.

**File discipline**: this skill writes only `plans/<slug>.md`. No other source files.

Plan structure:

### Plan Header

```markdown
# [Feature] Implementation Plan

**Goal:** [One sentence]
**Architecture:** [2-3 sentences]
**Tech Stack:** [Key technologies]
```

### Decision Record

**Chosen approach** with rationale.

**Alternatives Considered** (from 1.4):
```
- **<Approach>** — <2-3 sentences>
  - Why rejected: <specific>
  - Bits salvaged: <if any>
```

**Tradeoff Points** (from 1.4 matrix):
```
### <element> (Sensitivity | Tradeoff)
- **Costs**: <concrete>
- **Benefits**: <concrete>
- **Net**: <specific reason benefit > cost>
```

**Red-Team Resolution Log** (one entry per finding from 1.5):
```
- **Finding** (angle: <attack angle>): <description>
  - Severity: Critical | Important | Suggestion
  - Confidence: <0-100>
  - Resolution: Fixed | Rejected | Deferred
  - Detail: <what was done / why / where deferred>
  - Cost (if Fixed): <LoC / complexity / perf>
```

Silent acceptance not allowed; every finding gets a logged resolution.

### Task Structure

Each task targets one component. Task header references skills the implementer activates:

````markdown
### Task N: [Component]

**Skills to activate:**
- `test-driven-development` (failing test first; verify red; implement; verify green)
- `verification-before-completion` (confirm tests pass with evidence before commit)

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py`
- Test: `tests/exact/path/to/test.py`

**Acceptance criteria** (from test design):
- [behavior]: [expected outcome]

- [ ] Write failing test for [behavior]
- [ ] Run test, verify it fails (red)
- [ ] Implement minimal code to pass
- [ ] Run test, verify it passes (green)
- [ ] Commit with semantic message
````

For frontend features, note in plan header that `frontend-design` skill auto-activates during implementation.

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

Fix inline.

### Plan-Document Review

Dispatch `plan-doc-reviewer` via Task with paths to the plan and ideation file. It returns Approved | Issues. On Issues: fix flagged items, re-run. Iterate to Approved. Recommendations are advisory.

### Present for Approval

Present the plan path + brief summary. Suggest:
- `/implement` for parallel implementation
- Direct implementation for small plans (<5 tasks)
