---
description: Run a simplification pass on recently modified code
argument-hint: "[file or scope]"
allowed-tools: Bash(git diff:*), Bash(git status:*), Read, Glob, Grep, Task
---

# Code Simplification

Run the code-simplifier agent on recently modified code to improve clarity and consistency while preserving functionality.

**Scope override:** "$ARGUMENTS"

## Workflow

### 1. Identify Changed Code

If user specified a file or scope, use that. Otherwise:

```bash
git diff --name-only HEAD
```

If no unstaged changes, check staged:
```bash
git diff --name-only --cached
```

### 2. Launch Code-Simplifier Agent

Spawn a code-simplifier agent with:
- The list of changed files
- The git diff showing what changed
- Instructions to focus only on recently modified code

The agent will:
- Analyze for opportunities to improve clarity and consistency
- Apply project-specific best practices from CLAUDE.md
- Ensure all functionality remains unchanged
- Document significant changes

### 3. Report Results

Present what was simplified:
- Files modified
- Changes made (with before/after)
- Rationale for each simplification

If no simplifications needed, report that the code is already clean.
