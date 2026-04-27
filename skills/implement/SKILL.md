---
name: implement
description: "Decompose a large task into independent units and implement them in parallel with a coordinated team"
argument-hint: "<task description or path to plan file>"
allowed-tools: Agent, Bash, Read, Glob, Grep, Skill, EnterPlanMode, ExitPlanMode, AskUserQuestion, Task, TeamCreate, SendMessage
---

# Parallel Implementation

Team lead role: decompose work, dispatch workers in worktrees, merge incrementally, cross-cutting quality pass, one clean PR.

**Instruction:** "$ARGUMENTS"

## When NOT to Use

- Deep sequential dependencies between units
- Total work under ~30 minutes serial
- No tests in codebase (workers can't verify)
- Scope unclear (use `/design` first)

## Phase 1: Decomposition (Plan Mode)

Enter plan mode. Research before planning.

1. **Understand the task.** Read the argument and any referenced plan/architecture doc. Use Glob/Grep/subagents to survey codebase, patterns, conventions, test infrastructure.

   **Workspace root**: plan file at `plans/<slug>.md` → workspace at `plans/<slug>/.workspace/`. Otherwise derive a kebab-case slug from the task. Worker logs: `<workspace>/workers/<unit>.md`.

2. **Identify work units.** Each unit needs:
   - Clear deliverable (files, behavior)
   - Own test surface (runs in isolation)
   - Minimal coupling (shared interfaces fine; shared mutable state not)

   Two units modifying same file → merge them or define a strict contract (one owns the interface, the other consumes; document direction).

3. **Write the batch plan.** Per unit: name, description, files, branch (`batch/<batch-name>/<unit-name>`), test command, dependencies. Plus:
   - **Integration contract**: what must hold post-merge (interfaces, naming, config shape)
   - **Integration tests** to run after merge
   - **Risks**: what could go wrong, what to check on failure

4. **Get approval.** Present the plan; ask about splits/merges/drops. No proceeding without explicit approval.

Exit plan mode.

## Phase 2: Dispatch Workers

Create a team via `TeamCreate`. Launch all workers simultaneously with `Agent` (`team_name`, `isolation: "worktree"`, unique `name` per worker).

Worker prompts must be **fully self-contained** (workers can't see your conversation or each other). Include:
- Project language, framework, test runner, conventions
- Unit's goal, deliverable, files, branch, acceptance criteria
- Integration contract (interfaces, naming, types other units expect)
- Inline interface definitions for any cross-unit dependencies

Worker instructions (include verbatim, with `<WORKSPACE>` resolved):

```
Your workflow:
1. Create your branch from current HEAD
2. Invoke Skill: "test-driven-development" for TDD guidance
3. Implement following TDD: failing test, make it pass, refactor
4. If stuck, invoke Skill: "systematic-debugging"
5. Invoke Skill: "verification-before-completion" before claiming done
6. Invoke Skill: "review" to review your changes. Fix what's flagged. If feedback seems unclear or technically questionable, invoke Skill: "receiving-code-review"
7. Invoke Skill: "simplify" to clean up
8. Run the full test suite: <TEST_COMMAND>
9. If documented behavior changed, update README.md and CLAUDE.md
10. Stage and commit in a single message with a clear, semantic message
11. Push: git push -u origin <BRANCH_NAME>
12. Write a work log to <WORKSPACE>/workers/<UNIT_NAME>.md:
    - Summary of what was implemented (1-2 paragraphs)
    - Deviations from spec and why
    - Test results (which tests, pass/fail counts)
    - Files changed
    - Anything the team lead needs during integration (gotchas, cross-unit deps, follow-ups)
13. Message the team lead with SHORT status: "Done. Log: <WORKSPACE>/workers/<UNIT_NAME>.md. Branch: <BRANCH_NAME>. Tests: passed." OR a request for help. Team lead reads the log only if needed.
```

## Phase 3: Monitor, Merge, Respond

Respond naturally as workers message. Provide help/context. Diagnose if stuck; guide or escalate to user.

On worker done:

1. Merge their branch into the integration branch
2. Run tests post-merge. Resolve conflicts per the integration contract
3. **Clean up worktree + local branch**: `git worktree remove <path>` then `git branch -d <branch>`. Remote stays for audit; `/clean-gone` sweeps after PR merge.

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

Shut down the team.
