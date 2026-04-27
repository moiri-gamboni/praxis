---
name: simplify
description: Run a simplification pass on recently modified code
argument-hint: "[file or scope]"
allowed-tools: Bash(git diff:*), Bash(git status:*), Read, Glob, Grep, Task
---

# Code Simplification

Run `code-simplifier` on recently modified code to improve clarity while preserving functionality.

**Scope override:** "$ARGUMENTS"

## Workflow

1. **Identify changed code.** User-specified scope wins. Otherwise:
   ```bash
   git diff --name-only HEAD
   ```
   No unstaged → check staged: `git diff --name-only --cached`

2. **Spawn `code-simplifier`** with: changed file list, the diff, instruction to focus only on recent changes.

   The agent will analyze for clarity/consistency improvements per CLAUDE.md, preserve functionality, and document significant changes.

3. **Report results.** Files modified, changes (with before/after), rationale per simplification. If clean, report so.

4. **Next:** "Simplification complete. /ship to commit and open a PR."
