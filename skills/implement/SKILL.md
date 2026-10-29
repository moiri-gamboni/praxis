---
name: implement
description: Use when a large task is ready to build and decomposes into independent units — dispatches sub-agents in worktrees, merges incrementally, ships one PR.
argument-hint: "<task description or path to plan file>"
allowed-tools: Agent, SendMessage, Bash, Read, Write, Edit, Glob, Grep, Skill, AskUserQuestion, Task
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

   **Workspace root**: plan file at `plans/<slug>.md` → workspace at `plans/<slug>/.workspace/`. Otherwise derive a kebab-case slug from the task. Worker logs: `<workspace>/workers/<unit>.md`. Ledger: `<workspace>/progress.md`, one line per event, in these formats: `integration: <branch> from <base>`, `dispatched <unit> (<agent id>, <branch>)`, `merged <unit> (<branch>, <merge-sha>)`, `phase4 step <n> done`, `Ruling: <what> — <why> — <cost if wrong>`, `pr <url>`. One ending in a `pr` line is a finished run: move it and `workers/` aside and start fresh. Any other is a run to resume from the ledger and the worker logs, never from recollection: a unit is merged only if the ledger says so, and a dispatched unit with a worker log is a return to process (Phase 3), not one to re-dispatch.

2. **Route based on what you found.** Before the first dispatch on any route, create the integration branch `batch/<batch-name>-integration` (the batch name is the workspace slug) from the base and start the ledger with its `integration:` line.
   - **Slice 0 first**: the plan's Task 1 is Slice 0, or (no plan) the task crosses a boundary whose shape nobody has observed. Dispatch it alone as one `praxis:implementer` (worktree) before decomposing and merge it into the integration branch; write the batch plan's integration contract from its captures; then route the widening units below. No boundary tagged `docs` or `assumed` → skip this. Slice 0 and the single-agent route get an E2E recipe too (step 4's rule).
   - **Parallel**: 2+ units, each with its own test surface, all buildable from a pinned contract. Continue with steps 3-5.
   - **Single agent**: no separable contract-able parts. Cases: wide-but-shallow refactors (rename, type change), structural reorganization, single dense file, whole-system invariant changes, or too small to orchestrate. Skip to Phase 2; spawn one `praxis:implementer` (`subagent_type: "praxis:implementer"`, `isolation: "worktree"`) with the Phase 2 prompt.

3. **Identify work units.** A unit is one or more consecutive plan Tasks sharing a test surface (with no plan, a separable slice of the task). Each unit needs:
   - Clear deliverable (files, behavior)
   - Own test surface (runs in isolation)
   - Minimal coupling (shared interfaces fine; shared mutable state not)

   Two units modifying same file → merge them or define a strict contract (one owns the interface, the other consumes; document direction).

4. **Write the batch plan to `<workspace>/batch-plan.md`.** Per unit: name, description, files, branch (`batch/<batch-name>/<unit-name>`), test command, dependencies (units to merge first: they set merge order in Phase 3, never dispatch order). Plus:
   - **Integration contract**: what must hold post-merge (interfaces, naming, config shape)
   - **Integration tests** to run after merge
   - **E2E recipe**: how a worker verifies its change works end-to-end, not just that unit tests pass: short concrete steps it can run alone, setup included (a browser-automation skill for a UI flow, a CLI or tmux driver, dev server + curl for an API, an existing e2e suite; surfaces per `${CLAUDE_SKILL_DIR}/../verification-before-completion/runtime.md`). None found → if the change has no runtime surface (per that file), record "skip e2e because …"; otherwise ask the user before dispatch, offering 2-3 concrete options; workers can't ask.
   - **Risks**: what could go wrong, what to check on failure

5. **Surface decisions, then proceed.** Present the batch summary inline (units, integration contract, key risks) and continue to Phase 2 — the decomposition is orchestration machinery, and "approve this batch plan?" is not a real question; the user redirects on the next turn if the split is wrong. Block for input only on genuine tradeoffs surfaced during research: decisions where no option is clearly better and the pick materially changes what gets built — present each with the options, the tradeoff, and a recommendation, before any workers dispatch. Decisions a `/praxis:design` plan already adjudicated are settled; don't re-ask them.

## Phase 2: Dispatch Workers

Launch all workers in parallel: a single message with multiple `Agent` tool calls. Each call: `subagent_type: "praxis:implementer"`, `isolation: "worktree"`, unique `name`; append a `dispatched` line to the ledger for each. Workers run independently and return when done — no inter-worker or back-channel communication.

The `praxis:implementer` agent owns the worker procedure (skill loop, commit, log, audit). Your dispatch prompt provides only the unit specifics — it must be **fully self-contained** (workers can't see your conversation or peer workers):

- Project language, framework, test runner, conventions
- The flow sketch, its boundary list with shape sources, and the capture paths from Slice 0
- The plan path as an **absolute path**, with whether `plans/` is tracked — a gitignored plans directory isn't in the worker's worktree
- Base: the integration branch (a local ref every worktree sees; a worktree otherwise starts from the default branch and misses Slice 0 and earlier merges)
- Unit's goal, deliverable, files, branch (`batch/<batch-name>/<unit-name>`), acceptance criteria, and the skills the plan lists under **Skills to activate** for its tasks
- The plan's fixed outcomes + epistemic status (outcomes, acceptance criteria, and integration contract binding; internal machinery right-sizeable with a logged deviation)
- Test command (the implementer's procedure runs this for the full-suite step)
- The E2E recipe from the batch plan, or why e2e is skipped
- Worker log path, absolute: `<WORKSPACE>/workers/<UNIT_NAME>.md`
- Integration contract (interfaces, naming, types other units expect), pinned from Slice 0's captures where the plan marked them provisional
- Inline interface definitions for any cross-unit dependency the worker can't see in its own files

## Phase 3: Process Returns, Merge

Workers run independently and return when done. Process each return as it arrives. If a worker returned blocked, partial or failed, diagnose and rule: re-dispatch with more context, re-scope, drop the unit, or keep it partial.

**Rulings, not stalls.** After dispatch you decide on the user's behalf: a blocked worker re-dispatched or re-scoped, a unit dropped or kept partial when no fixed outcome rides on it, a conflict the integration contract doesn't settle, a review finding, trim cut or spec gap declined. This holds inside the skills Phase 4 loads: their ask-the-user points become rulings. Log each as a `Ruling:` ledger line; Phase 5 lists every one. Stop for the user only before leaving a fixed outcome undelivered or partial, or before something irreversible, security-sensitive, paid beyond the plan's test and E2E recipes (a paid rehearsal included), or reaching beyond the batch's branches and PR.

**Context economy.** Yours is the only context that spans the batch; compacting mid-orchestration loses whatever the ledger doesn't hold. Spend it on coordination, not code: read worker logs, not merged diffs (Phase 4's reviewers and trimmer read the code themselves), and don't re-derive what a worker already reported. The fix split, for every phase: a few obvious lines → fix inline; anything more → an agent. For a unit-scoped fix, send the finding back to the owning worker via SendMessage — it still holds the unit's context, so it writes the fix and commits, and you re-merge (its tree predates peers' merges; fine for unit-scoped work). For cross-unit fixes, or once workers are swept, dispatch a fresh `praxis:implementer` (worktree, fix branch off the integration branch, self-contained brief listing the findings) and merge its branch like any unit.

On worker done:

1. Merge their branch into the integration branch, after the units its dependencies name (hold an early return until they are merged); append a `merged` line to the ledger
2. Run tests post-merge; a failure the base already has is reported in the PR's test results as pre-existing, not fixed. Resolve conflicts per the integration contract
3. **Keep the worktree + local branch** — the worker stays resumable for fixes; cleanup is one sweep at the end of Phase 4.
4. **Surface inline**: pull deviations, integration concerns, and follow-ups from the worker log into your update.

## Phase 4: Cross-Cutting Quality

After every unit is merged or ruled on (append a `phase4 step <n> done` line as each step finishes). Invoke `Skill: "praxis:receiving-code-review"` once now; it governs every finding adjudicated below. The integration branch's range is `<base>...<integration branch>`, both from the ledger's `integration:` line.

1. **Plan-completion check** (if plan file present): spawn `praxis:spec-reviewer` via Agent with plan as spec, on the merged integration branch. Fix Missing and Misunderstood gaps, building any missing task first (routed per Phase 3's context economy), merge and re-run tests; rule on the rest with a `Ruling:` line. A gap matching a worker-logged lean-out or a non-behavioral classification is adjudicated against the fixed outcomes, not auto-restored.
2. **Trim pass**: dispatch `praxis:trimmer` (diff mode) on the integration branch's full diff, with the plan's fixed outcomes (or the task's stated outcomes when there's no plan), test command, and report path `<workspace>/trim.md`. Adjudicate: apply an L1 cut only when its outcome-trace and falsifier hold up — for guard removals, verify unreachability (validated one frame up, type-guaranteed, or caller-audited) before deleting. L2 findings (the plan clause itself questioned) are never auto-applied; they go to the user in the PR. Each applied cut is its own commit (revivable via `git revert`); re-run tests after cuts.
3. `Skill: "praxis:simplify"` with that range as args. It edits in place (direct mode), so review its edits instead of applying findings: revert any that change behavior or fall outside the merged diff, commit the rest as one commit (revivable via `git revert`), re-run tests.
4. Resolve conflicting doc edits from workers
5. Run integration tests from the plan; fix failures (routed per Phase 3's context economy) before the review.
6. **Review the final shape**: invoke `Skill: "praxis:review"` with that range as args (once it returns, log `review <its reviews/ folder>` in the ledger, so a resumed run goes straight to the fix round), adding that step 1 already checked completeness against the plan (when it ran) so `praxis:spec-reviewer` isn't dispatched again. It sweeps by unit, then one `praxis:finding-verifier` rules on every finding and checks the boundaries between units (naming, patterns, interface mismatches, duplication). One fix round: fix the Confirmed Critical and Important findings, routed per Phase 3's context economy, re-run tests, then `Skill: "praxis:review"` once more as a Re-Review, with the fix diff as the range and the prior findings named. What the Re-Review still finds is not another round: a Critical or Important leftover is still fixed and re-tested, just not re-reviewed; the rest is declined with the reason as a ruling (Phase 3). Disputed findings are rulings too. The review's Not Worth Fixing list and the Suggestions not taken stay unfixed, logged as one `Ruling:` line naming the items with the verifier's reasons, so the PR shows them.
7. **Check nothing is left unmerged**: for each worker branch, `git log --oneline <integration>..<branch>`; commits on a unit not ruled dropped (a fix a resumed worker committed) are merged now and step 5 re-runs.
8. **Rehearse** when the batch crosses an external boundary or runs on infrastructure, per the Rehearsal section of `${CLAUDE_SKILL_DIR}/../verification-before-completion/runtime.md`. A rehearsal failure is fixed and rehearsed again, not sent to another review round.
9. **Invoke `Skill: "praxis:verification-before-completion"`** on the final state, before the PR and the sweep; any change after it means running it again.
10. **Sweep worker worktrees + local branches**: `git worktree remove <path>` then `git branch -d <branch>` for each, once every capture path in the worker's log is on the integration branch (removal deletes gitignored files without asking). A capture missing, or either command refusing (uncommitted or unmerged work) → keep that worktree and branch and list them in the final message; never `--force` or `-D`.

## Phase 5: Final PR

Push the integration branch and create the PR from it, then append `pr <url>` to the ledger:
- Not delivered: each unit dropped or kept partial, and the outcome it leaves unmet (first, when any)
- Summary of what was built
- List of units, what each did
- Test results
- Concerns/TODOs from workers, including their below-the-bar review findings, and unapplied L2 trim findings for the user's call
- Rulings: every `Ruling:` line from the ledger
- Links to plan/design artifacts

Present the PR URL with any not-delivered items and kept worktrees beside it.
