---
name: simplify
description: Use when recently modified code should be simplified — dispatches a single praxis:code-simplifier agent.
argument-hint: "[file or scope]"
allowed-tools: Bash(git diff:*), Bash(git status:*), Read, Glob, Grep, Agent, Task
---

# Code Simplification

Run `praxis:code-simplifier` on recently modified code to improve clarity while preserving functionality.

**Name resolution:** `praxis:`-prefixed skill and agent names are the plugin registrations; a local checkout registers them bare. If a referenced skill or agent resolves in neither form, tell the user what's missing instead of silently substituting a different one.

**Scope override:** "$ARGUMENTS"

## Workflow

1. **Identify changed code.** User-specified scope wins. Otherwise:
   ```bash
   git diff --name-only HEAD
   ```
   No unstaged → check staged: `git diff --name-only --cached`

2. **Spawn `praxis:code-simplifier`** with: changed file list, the diff, instruction to focus only on recent changes.

   The agent will analyze for clarity/consistency improvements per CLAUDE.md, preserve functionality, and document significant changes.

3. **Report results.** Files modified, changes (with before/after), rationale per simplification. If clean, report so.

4. **Next:** "Simplification complete. /praxis:ship to commit and open a PR."
