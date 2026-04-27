---
name: design
description: "Architecture design with competing approaches, adversarial review, test design, and implementation planning"
argument-hint: "<feature description>"
allowed-tools: Read, Write, Edit, Glob, Grep, Task, Skill, AskUserQuestion
---

# Design

Explore architectural approaches, challenge them adversarially, design tests, then write an implementation plan.

**Feature:** "$ARGUMENTS"

## Phase 1: Architecture

### 1.1 Validate Input + Read Ideation

A feature description is required. If not provided, ask the user what they want to build.

Check for an ideation file at `plans/<slug>-ideation.md` (where `<slug>` is the feature's kebab-case name). If present, read it — this is the output of `ideate` and contains the problem statement, prior art investigated, alternatives considered at concept level, the chosen concept, and key constraints. Use this as foundational context throughout Phase 1.

If no ideation file exists, the user has skipped ideate and gone straight to design. State this and ask: "Looks like there's no ideation file. Run `ideate` first, or proceed assuming we're building this from scratch (no prior art search, no build-vs-buy evaluation)?" Don't silently skip the build-vs-buy question.

### 1.2 Shared Exploration Wave

Dispatch 4 `code-explorer` agents in parallel, each focused on one **dimension** of codebase context. These dimensions are evaluation lenses — they appear here as exploration topics, then again in Phase 1.4 synthesis as scoring axes.

The four dimensions:

- **Architectural fit**: existing patterns, abstractions, conventions; what would a feature in this space need to fit with; what abstraction layers exist
- **Touchpoints**: files, modules, integration points the feature would cross; data flow boundaries; consumer/producer relationships
- **Risks & dependencies**: what could break; what's coupled; sequencing constraints; existing fragility in the area
- **Constraints**: performance, security, backward compat, observability requirements that apply

Each agent returns:
- Findings (the substantive analysis for its dimension)
- 5-10 essential files that downstream architects should read

Prior art is NOT one of these dimensions — that lives in `ideate`. If no ideation file exists and the user opted to proceed without prior art search, accept the limitation.

### 1.2.5 Synthesize Shared Context

Coordinate the four agents' outputs into a tight shared context document (1-2 pages):
- Per-dimension highlights
- Deduplicated essential file list (~15-20 unique paths after dedupe)
- Anything that surfaced across multiple dimensions (likely architectural pivots)

This context is what architects receive in Phase 1.3.

### 1.2.7 Optional Second Exploration Wave

After dialogue with the user (which happens organically as they react to findings), if the dialogue surfaces materially new context — a constraint not in scope of original exploration, a new alternative needing its own context, an integration with a system not yet examined — propose a second wave with concrete focus areas:

```
The dialogue surfaced changes that may benefit from re-exploration:

- <specific deviation 1> — original exploration didn't cover <area>
- <specific deviation 2> — original assumption invalidated

Proposed second-wave focus:
1. <Area 1>: <why>
2. <Area 2>: <why>

Run this? (y/n, or specify different focus)
```

Trigger only on materially new context, not refinements within existing scope. Cap at one re-exploration per `/design` run. Requires user approval — do not auto-fire.

### 1.3 Per-Architect Exploration + Design

Spawn 2-3 `code-architect` agents in parallel. Each receives the shared context document from 1.2.5 plus the ideation file (if any) plus their design philosophy:

- **Minimal changes**: smallest possible change set, maximum reuse, low risk
- **Clean architecture**: best possible design, maintainability, long-term extensibility
- **Pragmatic balance**: balance speed with quality, sweet spot between minimal and clean

Architects do their own narrower exploration on top of shared context — looking specifically at files relevant to their proposed approach, not broadly re-exploring. Be explicit: their job is "here's what my approach needs to touch," not "here's the lay of the land" (the shared context already answered that).

Each agent produces:
- Patterns and conventions specific to their approach (with file:line references)
- Architecture decision with rationale
- Component design (file paths, responsibilities, interfaces)
- Data flow from entry to output
- Build sequence as an ordered checklist
- Critical Files for Implementation (priority-ordered, no count cap — list every file that drives the design)

### 1.4 Synthesis (Merged Plan)

Coordinator-level synthesis. Does NOT fire any agents — operates on the architect outputs and the shared context.

Produce one merged plan, NOT a recommendation followed by user picks. Approach:

1. **Build the synthesis matrix**: rows are the 4 dimensions from 1.2, columns are the architect approaches. Each cell scores how well that approach handles that dimension, with specific evidence.

2. **Identify Sensitivity Points and Tradeoff Points** (ATAM vocabulary):
   - **Sensitivity Point**: a design decision that affects ONE dimension. Default OK to pick the best-scoring approach for it.
   - **Tradeoff Point**: a design decision that affects MULTIPLE dimensions in opposing directions. These are where the real architectural argument lives — don't gloss over them.

3. **Pick a winner OR hybridize** based on the matrix. Hybridizing is encouraged when a tradeoff point favors mixing approaches.

4. **For every cross-approach borrowing, fill in a Net statement**:
   ```
   ### Borrowed: <element> (from approach <X> into approach <Y>)
   
   **Type**: Sensitivity Point | Tradeoff Point
   **Costs**: <concrete: LoC, indirection layers, mixed patterns, perf impact>
   **Benefits**: <concrete: testability, extensibility, fit, etc.>
   **Net**: <why benefit > cost; specific reason this is the right call here>
   ```
   
   If you can't fill the Net line for a borrowing, that borrowing isn't actually justified — drop it.

5. **Write structured Alternatives Considered** to be carried into the plan's Decision Record:
   ```
   - **<Approach name>** — <2-3 sentence description>
     - Why rejected: <specific reason — "didn't fit" is not a reason>
     - Bits salvaged into chosen plan: <if any, with reference to the Net statement>
   ```

Output of Phase 1.4: a merged plan in prose with the matrix, Sensitivity/Tradeoff classifications, Net statements, and structured Alternatives Considered. This becomes input to Phases 1.5 and 3.

### 1.5 Red-Team Review

Spawn a `red-team` agent with the merged plan. Present red-team findings alongside the merged plan. Flag Critical Concerns prominently.

(This phase will expand to a multi-angle red-team fleet — see notes on the fleet structure in the agent's prompt.)

### 1.6 Get User Decision + Final Validation

Present the merged plan, matrix, and red-team findings together. Iterate based on user input — revise plan, re-run red-team. Once decided, run red-team one final time on the final shape to validate.

## Phase 2: Test Design

Invoke the `Skill` tool with `skill: "test-driven-development"` to load TDD guidance.

Before writing the implementation plan, design the test strategy for the chosen architecture:

1. **Identify key behaviors** that each component must exhibit
2. **Write test specifications** for each behavior (what to test, inputs, expected outputs, edge cases)
3. **Map tests to components** so each plan task starts with a clear failing test
4. **Identify integration tests** that verify components work together

Present the test strategy to the user. These tests become the acceptance criteria in the implementation plan.

## Phase 3: Implementation Plan

Write the plan to `plans/<slug>.md`. The slug is the feature's short kebab-case name; propose one if not obvious from the feature description, or ask the user.

**File discipline**: the only file `/design` writes during this skill is `plans/<slug>.md`. Any other file changes belong to `/implement`. Use Write to create the plan or Edit to revise it; never touch other source files.

Write the plan assuming the implementer has zero codebase context. Include:

### Plan Header

```markdown
# [Feature Name] Implementation Plan

**Goal:** [One sentence]
**Architecture:** [2-3 sentences]
**Tech Stack:** [Key technologies]
```

### Decision Record

Include at the top of the plan:
- Chosen approach and rationale
- Rejected alternatives with reasons
- Key tradeoffs
- Red-team findings and how each was addressed

### Task Structure

Each task targets one component. List files, then break into TDD steps. Each task header references the relevant skills explicitly so a downstream implementer activates them:

````markdown
### Task N: [Component Name]

**Skills to activate for this task:**
- `test-driven-development` (write failing test first; verify red; implement; verify green)
- `verification-before-completion` (before marking commit step complete, confirm tests pass with evidence, not assertion)

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

If the feature is a frontend component or page, the `frontend-design` skill activates automatically during implementation — no need to invoke it explicitly, but mention in the plan header so the implementer knows the aesthetic direction will be loaded.

### Quality Rules

- **No placeholders**: every step has actual content. Never write "TBD", "add appropriate error handling", "similar to Task N"
- **Bite-sized steps**: each step is one action (2-5 minutes)
- **Exact paths and code**: file paths, code blocks, commands with expected output

### Self-Review

After writing the plan, check:
1. **Spec coverage**: every requirement maps to a task
2. **Placeholder scan**: no patterns from the no-placeholders list
3. **Type consistency**: names match across tasks
4. **Scope**: each task touches 2-3 files max
5. **Ambiguity**: no requirement can be read two ways

Fix issues inline.

### Present for Approval

Present the plan to the user with the path (`plans/<slug>.md`) and a brief summary. Suggest:
- `/implement` for parallel implementation (independent tasks)
- Direct implementation for small plans (under ~5 tasks)
