---
name: simplify
description: Use after finishing a coding task, when the code just written or changed should be made clearer and more consistent without changing behavior. For multi-dimension review use praxis:review; for cutting speculative machinery use praxis:trimmer.
argument-hint: "[git range or files]"
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git ls-files:*), Bash(git merge-base:*), Read, Glob, Grep, Edit, Agent, Task
---

# Code Simplification

Run `praxis:code-simplifier` on recently modified code to improve clarity while preserving functionality.

**Name resolution:** `praxis:`-prefixed skill and agent names are the plugin registrations; a local checkout registers them bare. If a referenced skill or agent resolves in neither form, tell the user what's missing instead of silently substituting a different one.

**Scope override:** "$ARGUMENTS"

## Workflow

1. **Identify changed code.** `$ARGUMENTS` wins: a git range (`git diff <range>`) or a file list. Otherwise the first of these that is non-empty:
   - uncommitted changes: `git diff HEAD`, plus the untracked files from `git ls-files --others --exclude-standard` (read them; the diff omits them)
   - with a clean tree, the branch's unpushed commits: `git diff @{upstream}...HEAD` (no upstream: `git diff $(git merge-base origin/HEAD HEAD)...HEAD`)

2. **Spawn `praxis:code-simplifier`** with `mode: direct (edit via Edit)`, the changed file list, the diff, and the instruction to focus only on recent changes.

   The agent will analyze for clarity/consistency improvements per CLAUDE.md, preserve functionality, and edit the files.

3. **Verify and report.** Run the project's tests and report the result, with the files modified and, per simplification, the before/after and rationale. If the agent found nothing to simplify, say so.
