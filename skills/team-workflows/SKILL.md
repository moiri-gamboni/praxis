---
name: team-workflows
description: Use when working with agent teams on multi-step development tasks, to coordinate teammates effectively using commands and review agents
---

# Team Workflows

## Overview

Agent teams are powerful when teammates have clear roles and use composable commands. This skill teaches patterns for coordinating teams on development tasks.

**Core principle:** Each teammate does one thing well. Commands are the building blocks. The team lead orchestrates.

## When to Use

Use when:
- Implementing features that need exploration, design, AND implementation
- Multiple review dimensions needed (code quality, spec compliance, tests)
- Work can be parallelized across teammates
- Quality gates should be enforced between stages

## Workflow Recipes

### Significant Feature

Full lifecycle from exploration to ship-ready.

```
1. Team lead enters plan mode
2. Spawn explorer teammates:
   - Each runs /explore on a different codebase area
   - Report findings back to team lead
3. Spawn architect teammate:
   - Runs /architect with findings as context
   - Presents approaches to team lead
4. Team lead writes plan, gets user approval, exits plan mode
5. Spawn implementation teammates:
   - Each handles a task from the plan
   - Uses TDD skill throughout
6. Spawn reviewer teammate:
   - Runs /review code errors on completed work
   - Reports issues back to team lead
7. Team lead coordinates fixes
8. Run /commit or /ship when ready
```

### Per-Task Quality Loop

Three-agent review pattern for completed work. Use after any non-trivial implementation.

```
1. Implementation complete
2. Spec review:
   - Spawn spec-reviewer agent with task requirements
   - Verify implementation matches specification exactly
   - Fix any gaps
3. Code quality review:
   - Spawn code-reviewer agent
   - Check guidelines compliance, bugs, quality
   - Fix critical/important issues
4. Optional: additional focused reviews
   - /review tests (if test files changed)
   - /review errors (if error handling involved)
   - /review types (if new types introduced)
```

### Quick Fix

Single agent, no team needed. For bug fixes and small changes.

```
1. Systematic debugging skill activates
2. TDD skill activates (write failing test first)
3. Fix the bug
4. Verification skill activates (run tests, confirm)
5. /commit when done
```

### PR Preparation

Polish and ship. Use when work is complete but needs review before PR.

```
1. /review all - comprehensive review
2. Fix any critical/important issues
3. /simplify - clean up recently modified code
4. /commit - stage and commit
5. /ship - push and create PR
```

### Codebase Investigation

Deep understanding without implementation. Use before major refactors or when onboarding to unfamiliar code.

```
1. Spawn 2-3 explorer teammates, each focusing on:
   - Similar existing features
   - Architecture and abstractions
   - Testing patterns and conventions
2. Aggregate findings
3. Present summary to user
```

## Teammate Communication

### Assigning Work
When spawning teammates, give them:
- Clear, specific task description
- Relevant context (file paths, requirements)
- Which command or agent to use
- What to report back

### Collecting Results
- Teammates send findings via SendMessage
- Team lead aggregates and makes decisions
- Don't block on teammate idle state (it's normal)

### Handling Failures
- If a teammate reports issues, evaluate severity
- Critical issues: fix before proceeding
- Minor issues: note and continue, fix later
- If teammate is stuck: investigate root cause, don't just retry

## Anti-Patterns

| Anti-Pattern | Better Approach |
|-------------|-----------------|
| One teammate doing everything | Split by specialty (explore, implement, review) |
| Reviewing your own work | Always use a separate reviewer teammate |
| Skipping spec review | Spec review catches "built wrong thing" early |
| Broadcasting every message | Use direct messages, broadcast only for critical issues |
| Over-coordinating | Simple tasks don't need teams. Use /commit directly. |
| Implementing in plan mode | Plan mode is for planning. Exit before implementing. |

## When NOT to Use Teams

- Simple bug fixes (just use TDD + debugging skills)
- Single-file changes
- Configuration changes
- Documentation updates
- When the user asks for something quick

Teams add coordination overhead. Only use them when the task genuinely benefits from parallelism or specialized roles.
