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

### 1.1 Validate Input

A feature description is required. If not provided, ask the user what they want to build.

### 1.2 Launch Architect Agents

Spawn 2-3 code-architect agents in parallel, each with a different design philosophy:

- **Minimal changes**: smallest possible change set, maximum reuse, low risk
- **Clean architecture**: best possible design, maintainability, long-term extensibility
- **Pragmatic balance**: balance speed with quality, sweet spot between minimal and clean

Each agent should produce:
- Patterns and conventions found (with file:line references)
- Architecture decision with rationale
- Component design (file paths, responsibilities, interfaces)
- Data flow from entry to output
- Build sequence as an ordered checklist

### 1.3 Compare and Recommend

Present:
1. Brief summary of each approach (2-3 sentences each)
2. Trade-offs comparison table (files changed, complexity, maintainability, risk)
3. Your recommendation with reasoning
4. Concrete implementation differences between approaches

### 1.4 Red-Team Review

Spawn a `red-team` agent with the recommended approach. Present red-team findings alongside the recommendation. Flag Critical Concerns prominently.

### 1.5 Get User Decision

Present recommendation and red-team findings together. If the user wants to iterate, revise and re-run red-team. Once decided, run red-team one final time to validate.

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
