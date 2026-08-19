---
name: implement
description: Use when a large task is ready to build and decomposes into independent units — dispatches sub-agents in worktrees, merges incrementally, ships one PR.
argument-hint: "<task description or path to plan file>"
allowed-tools: Agent, SendMessage, Bash, Read, Write, Glob, Grep, Skill, AskUserQuestion, Task
---

# Parallel Implementation

Decompose work, dispatch sub-agents in worktrees, merge incrementally, cross-cutting quality pass, one clean PR.

**Instruction:** "$ARGUMENTS"

**Name resolution:** `praxis:`-prefixed skill and agent names are the plugin registrations; a local checkout registers them bare. If a referenced skill or agent resolves in neither form, tell the user what's missing instead of silently substituting a different one.

## When to use

`/praxis:design` and Phase 1's batch plan pin integration contracts before workers spawn — sequential build-ups (data model → service → API → UI) parallelize cleanly because workers build to the pinned contract. Surface key findings inline either way; "merged ✓" hides what the worker found.

Scope unclear → `/praxis:design` first. No tests in the codebase → judgment call: route through `/praxis:design` (Phase 2 covers tests) if they fit; ask when not clear-cut; otherwise proceed with what doesn't gate on tests.

## Phase 1: Research & Decomposition

Research before routing — the single-vs-parallel call needs codebase context, not just the task description.

1. **Understand the task.** Read the argument and any referenced plan/architecture doc. Use Glob/Grep/subagents to survey codebase, patterns, conventions, test infrastructure.

   **Workspace root**: plan file at `plans/<slug>.md` → workspace at `plans/<slug>/.workspace/`. Otherwise derive a kebab-case slug from the task. Worker logs: `<workspace>/workers/<unit>.md`.

2. **Route based on what you found.**
   - **Parallel**: 2+ units, each with its own test surface, all buildable from a pinned contract. Continue with steps 3-5.
   - **Single agent**: no separable contract-able parts. Cases: wide-but-shallow refactors (rename, type change), structural reorganization, single dense file, whole-system invariant changes, or too small to orchestrate. Skip to Phase 2; spawn one `praxis:implementer` (`subagent_type: "praxis:implementer"`, `isolation: "worktree"`) with the Phase 2 prompt.

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

Launch all workers in parallel: a single message with multiple `Agent` tool calls. Each call: `subagent_type: "praxis:implementer"`, `isolation: "worktree"`, unique `name`. Workers run independently and return when done — no inter-worker or back-channel communication.

The `praxis:implementer` agent owns the worker procedure (skill loop, push, log, audit). Your dispatch prompt provides only the unit specifics — it must be **fully self-contained** (workers can't see your conversation or peer workers):

- Project language, framework, test runner, conventions
- Unit's goal, deliverable, files, branch (`batch/<batch-name>/<unit-name>`), acceptance criteria
- The plan's fixed outcomes + epistemic status (outcomes, acceptance criteria, and integration contract binding; internal machinery right-sizeable with a logged deviation)
- Test command (the implementer's procedure runs this for the full-suite step)
- Worker log path: `<WORKSPACE>/workers/<UNIT_NAME>.md`
- Integration contract (interfaces, naming, types other units expect)
- Inline interface definitions for any cross-unit dependency the worker can't see in its own files

## Phase 3: Process Returns, Merge

Workers run independently and return when done. Process each return as it arrives. If a worker returned blocked or failed, diagnose: re-dispatch with more context, or escalate to the user.

**Context economy.** Yours is the only context that spans the batch; compacting mid-orchestration loses coordination state nothing else records. Spend it on coordination, not code: read worker logs, not merged diffs (Phase 4's reviewers and trimmer read the code themselves), and don't re-derive what a worker already reported. The fix split, for every phase: a few obvious lines → fix inline; anything more → an agent. For a unit-scoped fix, send the finding back to the owning worker via SendMessage — it still holds the unit's context, so it writes the fix, commits, and pushes, and you re-merge (its tree predates peers' merges; fine for unit-scoped work). For cross-unit fixes, or once workers are swept, dispatch a fresh `praxis:implementer` (worktree, fix branch, self-contained brief listing the findings) and merge its branch like any unit.

On worker done:

1. Merge their branch into the integration branch
2. Run tests post-merge. Resolve conflicts per the integration contract
3. **Keep the worktree + local branch** — the worker stays resumable for fixes; cleanup is one sweep at the end of Phase 4.
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

1. Invoke `Skill: "praxis:review"` with args `all` — catch cross-unit inconsistencies (naming, patterns, interface mismatches, duplication). Before fixing, invoke `Skill: "praxis:receiving-code-review"`.
2. **Trim pass**: dispatch `praxis:trimmer` (diff mode) on the integration branch's full diff, with the plan's fixed outcomes (or the task's stated outcomes when there's no plan), test command, and report path `<workspace>/trim.md`. Adjudicate via `Skill: "praxis:receiving-code-review"`: apply an L1 cut only when its outcome-trace and falsifier hold up — for guard removals, verify unreachability (validated one frame up, type-guaranteed, or caller-audited) before deleting. L2 findings (the plan clause itself questioned) go to the user, never auto-applied. Each applied cut is its own commit (revivable via `git revert`); re-run tests after cuts.
3. `Skill: "praxis:simplify"` — apply each finding's fix. Skip findings that change behavior or fall outside the merged diff.
4. Run integration tests from the plan
5. **Plan-completion check** (if plan file present): spawn `praxis:spec-reviewer` via Agent with plan as spec. Address gaps after invoking `Skill: "praxis:receiving-code-review"`. Gaps matching a worker-logged lean-out, a non-behavioral classification, or an applied trim cut are adjudicated against the fixed outcomes — not auto-restored.
6. **Invoke `Skill: "praxis:verification-before-completion"`** before PR.
7. Resolve conflicting doc edits from workers
8. Fix remaining issues — routed per Phase 3's context economy — and re-run tests
9. **Sweep worker worktrees + local branches**: `git worktree remove <path>` then `git branch -d <branch>` for each. Remotes stay for audit; sweep them once the PR merges.

## Phase 5: Final PR

Create PR from integration branch:
- Summary of what was built
- List of units, what each did
- Test results
- Concerns/TODOs from workers
- Links to plan/design artifacts

Present PR URL. Worker remote branches still exist; sweep them once the PR merges.
