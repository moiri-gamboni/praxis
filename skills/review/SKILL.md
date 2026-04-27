---
name: review
description: Multi-dimensional code review using all specialized reviewer agents, organized by logical code path units rather than by file. Multi-wave with cross-unit pass and verification. Optional git range argument scopes the review.
argument-hint: "[git range, e.g. main..HEAD]"
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(gh pr view:*), Glob, Grep, Read, Task, Skill, AskUserQuestion
---

# Code Review

Comprehensive review across all quality dimensions, organized by logical code-path units (not by file). Multi-wave: per-unit deep review, cross-unit boundary review, then verification of findings.

**Optional git range:** "$ARGUMENTS"

## Step 1: Determine Review Scope

- If a git range is provided (e.g., `main..HEAD`, a SHA, branch name), use `git diff <range> --name-only` to scope
- Otherwise, check `git diff --name-only HEAD` for unstaged + staged changes
- If a PR exists (`gh pr view`), use the PR's `base..head` as the range
- Read the full diff for the scope to understand what changed

## Step 2: Identify Logical Units

Group the changed files by **code path**, not by directory or file type. A logical unit is a set of files that participate in one user-facing flow, one background job, one shared abstraction, or one feature surface. Examples:

- "Auth flow: login + session refresh" — touches auth router, session store, middleware
- "Background ingestion job" — touches scheduler, processor, error reporter
- "Shared validation helper" — touches one util file used by both auth and ingestion
- "Schema migration" — touches migration file + ORM models
- "Documentation update" — touches README, docs

Inspired by how human reviewers actually think: not "what's in this file" but "what code path is being modified."

For each unit, note:
- Unit name (descriptive)
- Files in the unit
- Brief description of what changes in this unit
- Approximate complexity (small / medium / large)

## Step 3: Confirm Units with User

Present the proposed unit grouping briefly:

```
Identified <N> logical units:
1. **<unit-name>** (<complexity>) — <files>: <description>
2. ...

Proceed with this grouping, or adjust?
```

If the grouping is obvious for small diffs (1-2 files, single unit), state your grouping and proceed without asking. If complex or ambiguous, wait for confirmation. Wrong grouping poisons everything downstream.

## Step 4: Wave 1 — Per-Unit Deep Review

For each unit, dispatch the **full reviewer fleet** in parallel via Task. The full fleet is:

- `code-reviewer` — general code quality, project guidelines, plan compliance (when present)
- `spec-reviewer` — implementation matches specification (when a plan/spec is present)
- `code-simplifier` — clarity, consistency, simplification opportunities
- `comment-analyzer` — comment accuracy and long-term maintainability
- `test-analyzer` — test coverage quality, behavioral focus
- `silent-failure-hunter` — swallowed errors, inappropriate fallbacks
- `type-analyzer` — type design quality (when types added/changed)

**Scale to unit complexity**: small unit (1-2 files, simple change) gets a reduced fleet — code-reviewer + the 1-2 most-relevant-by-file-content agents. Large or risky unit gets the full 7. Decide per unit; don't fire 7 reviewers on a 5-line documentation update.

Each reviewer returns findings tagged with the unit. Reviewers also empowered to return "no findings, this dimension isn't relevant" rather than fabricating issues to look thorough.

**Workspace file output**: each reviewer writes detailed findings to `reviews/<timestamp>/<unit>/<reviewer>.md`. Returns summary + path. (Workspace lives at `reviews/` not `plans/` since reviews aren't plans.)

## Step 5: Wave 2 — Cross-Unit Review

After Wave 1 completes, dispatch a smaller cross-unit fleet that looks at **boundaries between units**. Their job:

- Contracts between units: do shared interfaces match? Do producers and consumers agree on types and shapes?
- Naming consistency across units
- Duplication: is similar code in two units that should be unified?
- Shared invariants: do units that touch shared state respect each other's invariants?

Wave 2 reviewers see Wave 1's findings as input; they're looking for issues that any single-unit reviewer couldn't see.

Use `code-reviewer` and `type-analyzer` for cross-unit work; skip the others (their domains are within-unit).

## Step 6: Wave 3 — Verification Pass

For each **Critical** finding from Waves 1 and 2, dispatch a fresh second-pass agent (same reviewer type as the original finding) to independently reproduce the issue. They get only the diff and the finding's claim, not the original reviewer's reasoning.

- **Confirmed**: second agent reproduces the issue → mark confirmed
- **Disputed**: second agent doesn't reproduce → mark disputed, present both sides; user decides whether to drop or fix

Don't auto-drop disputed findings. False negatives (dropping real issues) hurt more than false positives (a few disputed findings the user resolves).

Verification only fires on Critical-severity findings. Important and Suggestion-severity findings skip verification (cost not justified at lower severity).

## Step 7: Aggregate and Present

Consolidate findings into a structured summary. Group by severity, then by unit:

```markdown
# Review Summary

**Range**: <git-range>
**Units reviewed**: <N>

## Critical Issues (<count>, <confirmed-count> confirmed, <disputed-count> disputed)

### Unit: <unit-name>
- **[reviewer]** [<status: confirmed|disputed>] [confidence: <0-100>]: <description> [file:line]
  - Why it matters: <consequence>
  - Proposed fix: <if reviewer proposed one, with cost>

## Important Issues (<count>)

[same structure]

## Suggestions (<count>)

[same structure, advisory only]

## Cross-Unit Findings

[Wave 2 findings — boundary issues, contract mismatches, etc.]

## Strengths

[What the diff gets right; preserve during fixes]

## Recommended Action

1. Fix Critical (confirmed) — block merge until resolved
2. Discuss Critical (disputed) — decide drop or fix
3. Address Important — should fix but not blocking
4. Consider Suggestions — advisory only
```

After presenting, **invoke `Skill: "verification-before-completion"`** if the user is about to act on findings (commit a fix, push, ship). Confirm fixes are evidence-backed before claiming resolution.

## Tips

- **Run early**: before creating PR, not after
- **Re-run after fixes**: verify issues are resolved (Wave 3 verification helps re-check whether fixes hold)
- **Trust the unit grouping**: if reviewers all flag the same boundary issue from within different units, that's a Wave 2 cross-unit finding — combine evidence rather than reporting three times

## Next Step

After presenting the summary:
- If Critical (confirmed) found: "Fix the critical confirmed issues, then re-run /review to verify."
- If only disputed Critical: "Decide on disputed findings (drop or fix), then re-run /review."
- If only Important / Suggestions: "Looking good. /ship when ready."
- If clean: "No issues. Ready to /ship."
