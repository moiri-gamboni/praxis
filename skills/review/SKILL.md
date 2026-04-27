---
name: review
description: Multi-dimensional code review using all specialized reviewer agents, organized by logical code path units rather than by file. Multi-wave with cross-unit pass and verification. Optional git range argument scopes the review.
argument-hint: "[git range, e.g. main..HEAD]"
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(gh pr view:*), Glob, Grep, Read, Task, Skill, AskUserQuestion
---

# Code Review

Multi-wave review by logical code-path units (not files): per-unit deep review → cross-unit boundary review → verification of Critical findings.

**Optional git range:** "$ARGUMENTS"

## Step 1: Determine Scope

Precedence (first match wins):
1. Git range argument provided → `git diff <range> --name-only`
2. Working tree has changes → `git diff --name-only HEAD` (unstaged + staged)
3. PR exists (`gh pr view`) → use `base..head` as range

Read the full diff for context.

## Step 2: Identify Logical Units

Group by **code path**, not directory or file type. A unit is a set of files participating in one user-facing flow, background job, shared abstraction, or feature surface.

Examples:
- Auth flow: login + session refresh — auth router, session store, middleware
- Background ingestion job — scheduler, processor, error reporter
- Shared validation helper — one util used by both auth and ingestion
- Schema migration — migration file + ORM models
- Documentation update — README, docs

Per unit: name, files, brief description, complexity (small / medium / large).

## Step 3: Confirm Units

For obvious small diffs (1-2 files, single unit): state and proceed.

Otherwise present and ask:
```
<N> logical units:
1. **<unit-name>** (<complexity>) — <files>: <description>
2. ...

Proceed, or adjust?
```

Wrong grouping poisons downstream — ask when ambiguous.

## Step 4: Wave 1 — Per-Unit Deep Review

Per unit, dispatch the reviewer fleet in parallel via Task:

- `code-reviewer` — general quality, guidelines, plan compliance
- `spec-reviewer` — implementation matches spec (when plan/spec present)
- `code-simplifier` — clarity, consistency
- `comment-analyzer` — comment accuracy
- `test-analyzer` — test coverage, behavioral focus
- `silent-failure-hunter` — swallowed errors, fallback misuse
- `type-analyzer` — type design (when types added/changed)

**Scale to unit complexity**: small unit (1-2 files) → reduced fleet (code-reviewer + 1-2 most relevant). Large/risky → full 7. Don't fire 7 reviewers on a 5-line docs change.

Reviewers may return "no findings, this dimension isn't relevant" — preferred over fabrication.

Each reviewer writes detailed findings to `reviews/<timestamp>/<unit>/<reviewer>.md` and returns summary + path.

## Step 5: Wave 2 — Cross-Unit Review

After Wave 1, dispatch a smaller cross-unit fleet (`code-reviewer`, `type-analyzer`) that takes Wave 1 findings as input and looks at **boundaries between units**:

- Contract matching between units (interfaces, types, shapes)
- Naming consistency across units
- Duplication that should be unified
- Shared invariants respected by all units that touch shared state

Skip the other reviewers — their domains are within-unit.

## Step 6: Wave 3 — Verification

For each **Critical** finding from Waves 1-2, dispatch a fresh second-pass agent (same reviewer type) to independently reproduce. It gets only the diff and the claim, not the original reasoning.

- **Confirmed**: reproduced → confirmed
- **Disputed**: not reproduced → disputed; present both sides, user decides

Don't auto-drop disputed findings — false negatives hurt more than false positives.

Verification only on Critical (cost not justified at lower severity).

## Step 7: Aggregate and Present

```markdown
# Review Summary

**Range**: <git-range>
**Units reviewed**: <N>

## Critical Issues (<count>, <confirmed> confirmed, <disputed> disputed)

### Unit: <unit-name>
- **[reviewer]** [<confirmed|disputed>] [confidence: <0-100>]: <description> [file:line]
  - Why it matters: <consequence>
  - Proposed fix: <if any, with cost>

## Important Issues (<count>)
[same structure]

## Suggestions (<count>)
[same structure, advisory]

## Cross-Unit Findings
[Wave 2: boundary issues, contract mismatches]

## Strengths
[What the diff gets right; preserve during fixes]

## Recommended Action
1. Fix Critical (confirmed) — block merge
2. Discuss Critical (disputed) — drop or fix
3. Address Important — should fix
4. Consider Suggestions — advisory
```

After presenting, invoke `Skill: "verification-before-completion"` before the user acts on findings.

## Tips

- **Cross-unit deduplication**: if multiple Wave 1 reviewers (in different units) flag the same boundary issue, combine the evidence into one Wave 2 cross-unit finding rather than reporting 3x.

## Next Step

- Critical (confirmed) found → "Fix critical confirmed issues, re-run /review to verify."
- Only disputed Critical → "Decide on disputed findings, then re-run /review."
- Only Important / Suggestions → "/ship when ready."
- Clean → "Ready to /ship."
