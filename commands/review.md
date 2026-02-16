---
description: Multi-dimensional code review using specialized agents
argument-hint: "[code|tests|comments|errors|types|simplify|all]"
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(gh pr view:*), Glob, Grep, Read, Task
---

# Code Review

Run a comprehensive code review using specialized agents, each focusing on a different quality dimension.

**Review aspects requested:** "$ARGUMENTS"

## Workflow

### 1. Determine Review Scope

- Check git status to identify changed files: `git diff --name-only`
- Parse arguments to see which review aspects were requested
- Default: Run all applicable reviews

### 2. Available Review Aspects

- **code** - General code review for project guidelines and bugs
- **tests** - Review test coverage quality and completeness
- **comments** - Analyze code comment accuracy and maintainability
- **errors** - Check error handling for silent failures
- **types** - Analyze type design and invariants (if new types added)
- **simplify** - Simplify code for clarity and maintainability
- **all** - Run all applicable reviews (default)

### 3. Determine Applicable Reviews

Based on changes:
- **Always applicable**: code-reviewer (general quality)
- **If test files changed**: test-analyzer
- **If comments/docs added**: comment-analyzer
- **If error handling changed**: silent-failure-hunter
- **If types added/modified**: type-analyzer
- **After passing review**: code-simplifier (polish and refine)

### 4. Launch Review Agents

Use the Task tool to launch appropriate agents. Launch agents in parallel for comprehensive review.

Each agent should be given:
- The list of changed files
- Context about what changed (from git diff)
- Any relevant CLAUDE.md guidelines

### 5. Aggregate Results

After agents complete, summarize findings:

```markdown
# Review Summary

## Critical Issues (X found)
- [agent-name]: Issue description [file:line]

## Important Issues (X found)
- [agent-name]: Issue description [file:line]

## Suggestions (X found)
- [agent-name]: Suggestion [file:line]

## Strengths
- What's well-done

## Recommended Action
1. Fix critical issues first
2. Address important issues
3. Consider suggestions
4. Re-run review after fixes
```

## Usage Examples

**Full review (default):**
```
/review
```

**Specific aspects:**
```
/review tests errors
/review comments
/review simplify
```

## Tips

- **Run early**: Before creating PR, not after
- **Focus on changes**: Agents analyze git diff by default
- **Address critical first**: Fix high-priority issues before lower priority
- **Re-run after fixes**: Verify issues are resolved
