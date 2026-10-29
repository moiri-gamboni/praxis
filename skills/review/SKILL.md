---
name: review
description: Use when a body of code changes needs deep multi-dimensional review (correctness, quality, types, tests, error handling) — organized by logical code-path units, multi-wave with cross-unit pass and verification. Scopes to working tree, git range, or PR.
argument-hint: "[git range, e.g. main..HEAD]"
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git merge-base:*), Bash(git rev-parse:*), Bash(git ls-files:*), Bash(gh pr view:*), Glob, Grep, Read, Agent, Task, Skill, AskUserQuestion
---

# Code Review

Multi-wave review by logical code-path units (not files): per-unit deep review → cross-unit boundary review → verification of Critical findings.

**Name resolution:** `praxis:`-prefixed skill and agent names are the plugin registrations; a local checkout registers them bare. If a referenced skill or agent resolves in neither form, tell the user what's missing instead of silently substituting a different one.

**Optional git range:** "$ARGUMENTS"

## Step 1: Determine Scope

1. Git range argument provided → that range (`git diff <range>`).
2. Otherwise, the union of the branch's unpushed commits and the working tree: `git diff @{upstream}...HEAD` (an open PR, `gh pr view`, supplies its `base...head` instead; with no PR, when there is no upstream or that diff is empty because the branch is already pushed → from the merge base with the default branch (`origin/HEAD`; if that ref is missing, `main` or `master`)), plus `git diff HEAD` and the untracked files (`git ls-files --others --exclude-standard`) when the tree is dirty. Either half alone misses the other: a dirty tree hides committed work, and a clean branch with no PR otherwise has no scope.

Read the full diff for context.

## Re-Review Mode

Trigger: the caller says re-review, or the range is a fix round answering findings a prior `reviews/<timestamp>/` holds. An earlier review folder alone doesn't trigger it, and an explicit range in Step 1 still sets the scope. A re-run after a fix round is **scoped, not fresh**: take the fix diff as the range, verdict each prior finding (addressed / not addressed / superseded) and review only that diff for new breakage, then present the verdicts and any new findings in Step 7's format. The full review already happened; re-running it from scratch re-litigates settled findings and invites fabricated new ones. Skip Steps 2-6.

Otherwise continue with Step 2.

## Step 2: Identify Logical Units

Group by **code path**, not directory or file type. A unit is a set of files participating in one user-facing flow, background job, shared abstraction, or feature surface.

Examples:
- Auth flow: login + session refresh — auth router, session store, middleware
- Background ingestion job — scheduler, processor, error reporter
- Shared validation helper — one util used by both auth and ingestion
- Schema migration — migration file + ORM models
- Documentation update — README, docs

Per unit: name, files, brief description, complexity (small / medium / large).

## Step 3: State Units

State the units and proceed:
```
<N> logical units:
1. **<unit-name>** (<complexity>) — <files>: <description>
2. ...
```

Wrong grouping poisons downstream, so ask only when the grouping is genuinely ambiguous (a file that could sit in either of two units and changes which reviewers run).

## Step 4: Wave 1 — Per-Unit Deep Review

Per unit, dispatch the reviewer fleet in parallel via Agent:

- `praxis:code-reviewer` — general quality, guidelines, plan compliance
- `praxis:spec-reviewer` — implementation matches spec (when plan/spec present)
- `praxis:code-simplifier` — clarity, consistency
- `praxis:comment-analyzer` — comment accuracy
- `praxis:test-analyzer` — test coverage, behavioral focus
- `praxis:silent-failure-hunter` — swallowed errors, fallback misuse
- `praxis:type-analyzer` — type design (when types added/changed)

**Per-reviewer briefing**: the root (repo or worktree) to work from and the test command, plus what the tree can't reveal — the branch's base point relative to other in-flight work, and the provenance/freshness of any generated or snapshot data in the diff. When a plan has them, pass the flow sketch and the Slice 0 capture paths.

**Plan compliance**: when `praxis:spec-reviewer` is dispatched, brief `praxis:code-reviewer` that plan compliance is covered elsewhere (CLAUDE.md and bugs only). The two rule oppositely on a worker-logged lean-out (code-reviewer: justified deviation; spec-reviewer: Missing), so you adjudicate: a spec-reviewer Missing that matches a lean-out keeping the acceptance criteria green is judged against the fixed outcomes, as `/praxis:implement` Phase 4 does. No fixed outcome rides on it → Dropped as a justified lean-out, with that reason; otherwise it stands.

**Units crossing a trust boundary** (untrusted input reaching queries, commands, templates, file paths, HTML or deserializers; auth, session or permission logic; secrets or crypto): also dispatch a security reviewer, a `praxis:code-reviewer` briefed to read and follow `${CLAUDE_SKILL_DIR}/security.md` (pass that absolute path in the brief). Its output format and confidence rules replace code-reviewer's Output and Confidence Scoring sections, and it writes `security-reviewer.md`. Its findings go through Wave 3's security filter.

**Documentation units**: additionally brief the dispatched reviewer(s) to load `Skill: "diataxis:diataxis"` (bare: `diataxis`; separate plugin — if it resolves in neither form, surface `/plugin marketplace add moiri-gamboni/diataxis-skill` instead of substituting) and review for kind-purity — the compass applied per section: content that informs a different need than its document's kind belongs elsewhere — on top of the accuracy and completeness checks the fleet already runs.

**Scale to unit complexity**: trivial diff → inline. Sequential chain (one logical thread across files) → single code-reviewer. Small unit (1-2 files) → code-reviewer + 1-2 relevant others. Large/risky → full 7. Anything beyond trivial dispatches at least one agent. `praxis:comment-analyzer` dispatches whenever the diff adds or changes comments or docs, at any unit size.

Reviewers may return "no findings, this dimension isn't relevant" — preferred over fabrication.

Each reviewer writes detailed findings to `reviews/<timestamp>/<unit>/<reviewer>.md` (`security-reviewer.md` for the security one) and returns summary + path.

**Severity mapping** — the reviewers' formats differ; Waves 2-3 and Step 7 use Critical / Important / Suggestion, with each agent's own confidence:

| Reviewer | Critical | Important | Suggestion |
|---|---|---|---|
| code-reviewer | Critical | Important | — |
| silent-failure-hunter | CRITICAL | HIGH | MEDIUM |
| spec-reviewer | — | Missing, Misunderstood | Extra |
| test-analyzer | Critical Gaps (8-10) | Important Improvements (5-7) | Test Quality Issues |
| comment-analyzer | — | Critical Issues | Improvement Opportunities, Recommended Removals |
| type-analyzer | — | a concern that is a bug | other Concerns, Recommended Improvements |
| code-simplifier | — | — | every change |
| security reviewer | High | Medium | Low |

comment-analyzer's "Critical Issues" are misleading comments, not broken behavior, so they don't block merge. test-analyzer reports criticality, not confidence: carry it as `criticality N/10` in the confidence slot. A security finding's confidence is its filter score × 10 (Wave 3).

## Step 5: Wave 2 — Cross-Unit Review

After Wave 1, dispatch a smaller cross-unit fleet (`praxis:code-reviewer`, `praxis:type-analyzer`) that takes Wave 1 findings as input and looks at **boundaries between units**:

- Contract matching between units (interfaces, types, shapes)
- Naming consistency across units
- Duplication that should be unified
- Shared invariants respected by all units that touch shared state

Skip the other reviewers — their domains are within-unit. With one unit there are no boundaries: skip Wave 2.

Deduplicate: if multiple Wave 1 reviewers (in different units) flag the same boundary issue, combine the evidence into one cross-unit finding rather than reporting it 3x.

## Step 6: Wave 3 — Verification

**Critical findings** from Waves 1-2 (security findings take the branch below): dispatch a fresh agent of the same reviewer type with only the diff and the claim, not the original reasoning, and this brief, which replaces its usual Output section, verdict and confidence threshold:

> Here is a diff and one claim about it. Try to reproduce the claim from the code. Reply `Confirmed` or `Disputed`, with the evidence: for Disputed, the quoted line or the invariant that contradicts the claim. Nothing else — no other findings, no verdict block.

- **Confirmed**: reproduced → confirmed
- **Disputed**: not reproduced → disputed; present both sides, user decides

Don't auto-drop disputed findings — false negatives hurt more than false positives. Verification only on Critical (cost not justified at lower severity).

**Security findings**, every severity, replace the same-type repro with a filter: per finding, dispatch a fresh agent via Agent, in parallel, with only the diff, the finding, and the text of `${CLAUDE_SKILL_DIR}/security.md` from `FALSE POSITIVE FILTERING:` to the end of the file pasted into its brief. It scores the finding 1-10. Below 8 → Dropped, with the score and the filter's reason; 8 or more → confirmed, its confidence the score × 10.

## Step 7: Aggregate and Present

Every reviewer finding lands in your message (user only sees what's here), placed by its mapped severity. False positives, filtered security findings and justified lean-outs go under **Dropped** with reasoning. Counts in section headers must match the bullets.

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

## Dropped (false positives) (<count>)
[Findings you judged wrong, with reason. User can override.]

## Recommended Action
- **Fix**: Critical (confirmed) + Important. Block merge on Critical.
- **Decide together**: real tradeoffs. Ask the user; skip trivial choices.
- **Defer (with reason)**: out of scope, depends on unmerged work, needs unavailable input. Default to not deferring.
```

After presenting, invoke `Skill: "praxis:verification-before-completion"` before the user acts on findings, on what the summary claims: a test result it cites comes from a command run in this review (rerun it, or mark it as a reviewer's unverified report), and the reviewed range ends at the current `HEAD` (`git rev-parse HEAD`; if it doesn't, say so in the summary).

## Next Step

- Critical (confirmed) found → "Fix critical confirmed issues, then re-run /praxis:review scoped to the fixes."
- Only disputed Critical → "Decide on disputed findings, then re-run /praxis:review."
- Only Important / Suggestions → "Commit when ready."
- Clean → "Ready to commit."
