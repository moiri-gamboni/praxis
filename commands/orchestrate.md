---
description: "Decompose a large task into independent units and implement them in parallel with a coordinated team"
argument-hint: "<task description or path to plan file>"
allowed-tools: Agent, Bash, Read, Glob, Grep, Skill, EnterPlanMode, ExitPlanMode, AskUserQuestion, Task, TeamCreate, SendMessage
---

# Parallel Batch Orchestration

You are the team lead. Decompose work into independent units, dispatch workers in isolated worktrees, merge their results incrementally, then do a cross-cutting quality pass before producing one clean PR.

**Instruction:** "$ARGUMENTS"

## When NOT to Use

- Units have deep sequential dependencies (one must finish before the next can start)
- Total work is under ~30 minutes of serial effort
- Codebase lacks tests (workers cannot verify their own output)
- Scope is unclear (use `/explore` or `/architect` first)

## Phase 1: Decomposition (Plan Mode)

Enter plan mode. Research thoroughly before planning.

1. **Understand the task.** Read the argument. If it references an architecture doc or plan, read that too. Use Glob, Grep, and subagents to survey the relevant codebase areas. Identify patterns, conventions, test infrastructure.

2. **Identify work units.** Break the task into units that can be implemented and tested independently. Each unit must have:
   - A clear deliverable (files created/modified, behavior added)
   - Its own test surface (tests it can run in isolation)
   - Minimal coupling to other units (shared interfaces are fine; shared mutable state is not)

   If two units must modify the same file, either merge them or define a strict contract (one defines the interface, the other consumes it). Document the dependency direction.

3. **Write the batch plan.** For each unit: name, description, files touched, branch name (`batch/<batch-name>/<unit-name>`), test command, dependencies (if any). Also include:
   - **Integration contract**: what must be true when all units are merged (shared interfaces, naming conventions, config shape)
   - **Integration test commands** to run after merge
   - **Risks**: what could go wrong, what to check if a unit fails

4. **Get approval.** Present the plan. Ask if units should be split, merged, or dropped. Do not proceed without explicit approval.

Exit plan mode after approval.

## Phase 2: Dispatch Workers

Create a team with `TeamCreate`. Then launch all workers simultaneously using the `Agent` tool with `team_name`, `isolation: "worktree"`, and a unique `name` per worker.

Each worker prompt must be **fully self-contained** (workers cannot see your conversation or other workers). Include:
- The project's language, framework, test runner, key conventions
- This unit's goal, deliverable, files, branch name, and acceptance criteria
- The integration contract (interfaces, naming, types other units expect)
- If this unit depends on another unit's interface, include the interface definition directly

Worker instructions (include verbatim):

```
Your workflow:
1. Create your branch from the current HEAD
2. Write failing tests first for the behavior you are adding
3. Implement until tests pass
4. Invoke the Skill tool with skill: "review" to review your changes. Fix anything flagged
5. Invoke the Skill tool with skill: "simplify" to clean up your changes
6. Run the full test suite (not just your tests): <TEST_COMMAND>
7. If your changes affect documented behavior, update README.md and CLAUDE.md
8. Invoke the Skill tool with skill: "commit" to commit your work
9. Push your branch: git push -u origin <BRANCH_NAME>
10. Message the team lead when done, or if you need help, have questions, or get stuck on something
```

## Phase 3: Monitor, Merge, Respond

As workers message you, respond naturally. If a worker needs help or context, provide it. If a worker is stuck, diagnose the issue and either guide them or ask the user.

When a worker reports they are done, merge their branch into the integration branch. Run tests after each merge. If merge conflicts arise, resolve them per the integration contract.

Track progress with a status table:

```
Unit            | Merged | Notes
----------------|--------|-------
<unit-name>     | yes    |
<unit-name>     | no     | waiting on worker
```

If any unit fails irrecoverably, ask the user whether to continue with partial results or abort.

## Phase 4: Cross-Cutting Quality

After all branches are merged into the integration branch:

1. `/review all` — catch inconsistencies between units: naming, patterns, interface mismatches, duplicated code
2. `/simplify` — remove duplication introduced across units
3. Run integration tests from the plan
4. Resolve conflicting documentation edits from different workers
5. Fix any issues found, run tests again

## Phase 5: Final PR

Create a PR from the integration branch. Include:
- Summary of what was built
- List of units and what each did
- Test results
- Any concerns or TODOs from workers
- Link to the plan/design artifacts if they exist

Present the PR URL to the user. Suggest `/clean-gone` to clean up worker branches after the PR is merged.

Shut down the team when complete.
