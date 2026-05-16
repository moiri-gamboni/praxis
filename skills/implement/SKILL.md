---
name: implement
description: "Decompose a large task into independent units and implement them in parallel with sub-agents in worktrees"
argument-hint: "<task description or path to plan file>"
allowed-tools: Agent, Bash, Read, Write, Glob, Grep, Skill, AskUserQuestion, Task
---

# Parallel Implementation

Decompose work, dispatch sub-agents in worktrees, merge incrementally, cross-cutting quality pass, one clean PR.

**Instruction:** "$ARGUMENTS"

## When to use

`/design` and Phase 1's batch plan pin integration contracts before workers spawn — sequential build-ups (data model → service → API → UI) parallelize cleanly because workers build to the pinned contract. Surface key findings inline either way; "merged ✓" hides what the worker found.

Scope unclear → `/design` first. No tests in the codebase → judgment call: route through `/design` (Phase 2 covers tests) if they fit; ask when not clear-cut; otherwise proceed with what doesn't gate on tests.

## Phase 1: Research & Decomposition

Research before routing — the single-vs-parallel call needs codebase context, not just the task description.

1. **Understand the task.** Read the argument and any referenced plan/architecture doc. Use Glob/Grep/subagents to survey codebase, patterns, conventions, test infrastructure.

   **Workspace root**: plan file at `plans/<slug>.md` → workspace at `plans/<slug>/.workspace/`. Otherwise derive a kebab-case slug from the task. Worker logs: `<workspace>/workers/<unit>.md`.

2. **Route based on what you found.**
   - **Parallel**: 2+ units, each with its own test surface, all buildable from a pinned contract. Continue with steps 3-5.
   - **Single agent**: no separable contract-able parts. Cases: wide-but-shallow refactors (rename, type change), structural reorganization, single dense file, whole-system invariant changes, or too small to orchestrate. Skip to Phase 2; spawn one sub-agent (`Agent`, `isolation: "worktree"`) with the Phase 2 prompt.

3. **Identify work units.** Each unit needs:
   - Clear deliverable (files, behavior)
   - Own test surface (runs in isolation)
   - Minimal coupling (shared interfaces fine; shared mutable state not)

   Two units modifying same file → merge them or define a strict contract (one owns the interface, the other consumes; document direction).

4. **Write the batch plan to `<workspace>/batch-plan.md`.** Per unit: name, description, files, branch (`batch/<batch-name>/<unit-name>`), test command, dependencies. Plus:
   - **Integration contract**: what must hold post-merge (interfaces, naming, config shape)
   - **Integration tests** to run after merge
   - **Risks**: what could go wrong, what to check on failure

5. **Get approval.** Present the plan; ask about splits/merges/drops. No proceeding without explicit approval.

## Phase 2: Dispatch Workers

Launch all workers in parallel: a single message with multiple `Agent` tool calls (`isolation: "worktree"`, unique `name` per worker). They run independently and return when done — no inter-worker or back-channel communication.

Worker prompts must be **fully self-contained** (workers can't see your conversation or each other). Include:
- Project language, framework, test runner, conventions
- Unit's goal, deliverable, files, branch, acceptance criteria
- Integration contract (interfaces, naming, types other units expect)
- Inline interface definitions for any cross-unit dependencies

Worker instructions (verbatim, with `<WORKSPACE>` resolved):

```
Each `Skill: "X"` line below is a tool call — invoke the Skill tool to load skill X. Don't substitute remembered practice; load the skill content.

1. Create branch from HEAD
2. Skill: "test-driven-development" (failing test → pass → refactor)
3. Stuck → Skill: "systematic-debugging"
4. Skill: "verification-before-completion" before claiming done
5. Skill: "review". Fix flagged. Unclear/questionable → Skill: "receiving-code-review"
6. Skill: "simplify"
7. Full test suite: <TEST_COMMAND>
8. Documented behavior changed → update README.md, CLAUDE.md
9. Stage + commit in one message, clear semantic subject
10. git push -u origin <BRANCH_NAME>
11. Log to <WORKSPACE>/workers/<UNIT_NAME>.md:
    - Summary (1-2 paragraphs)
    - Deviations from spec, why
    - Skills invoked (which, when) — for self-audit
    - Test results (which, pass/fail)
    - Files changed
    - Integration notes (gotchas, cross-unit deps, follow-ups)
12. Return: "Done. Log: <WORKSPACE>/workers/<UNIT_NAME>.md. Branch: <BRANCH_NAME>. Tests: passed." If stuck, return early with the blocker described.
```

## Phase 3: Process Returns, Merge

Workers run independently and return when done. Process each return as it arrives. If a worker returned blocked or failed, diagnose: re-dispatch with more context, or escalate to the user.

On worker done:

1. Merge their branch into the integration branch
2. Run tests post-merge. Resolve conflicts per the integration contract
3. **Clean up worktree + local branch**: `git worktree remove <path>` then `git branch -d <branch>`. Remote stays for audit; `/clean-gone` sweeps after PR merge.
4. **Surface inline**: pull deviations, integration concerns, and follow-ups from the worker log into your update.

Status table:

```
Unit            | Merged | Notes
----------------|--------|-------
<unit-name>     | yes    |
<unit-name>     | no     | waiting on worker
```

If any unit fails irrecoverably, ask user: continue with partial results or abort.

## Phase 4: Cross-Cutting Quality

After all units merged:

1. `/review all` — catch cross-unit inconsistencies (naming, patterns, interface mismatches, duplication)
2. `/simplify` — remove cross-unit duplication
3. Run integration tests from the plan
4. **Plan-completion check** (if plan file present): spawn `spec-reviewer` via Task with plan as spec. Address gaps.
5. **Invoke `Skill: "verification-before-completion"`** before PR.
6. Resolve conflicting doc edits from workers
7. Fix issues, re-run tests

## Phase 5: Final PR

Create PR from integration branch:
- Summary of what was built
- List of units, what each did
- Test results
- Concerns/TODOs from workers
- Links to plan/design artifacts

Present PR URL.

**Invoke `Skill: "clean-gone"`** for opportunistic sweep of pre-existing `[gone]` branches. Worker remotes still exist; they'll be swept later when the PR merges.
