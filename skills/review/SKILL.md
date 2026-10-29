---
name: review
description: Use when a body of code changes needs deep multi-dimensional review (correctness, quality, types, tests, error handling) — organized by logical code-path units, with one verification pass over every finding. Scopes to working tree, git range, or PR.
argument-hint: "[git range, e.g. main..HEAD]"
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git merge-base:*), Bash(git rev-parse:*), Bash(git ls-files:*), Bash(gh pr view:*), Glob, Grep, Read, Agent, Task, Skill, AskUserQuestion
---

# Code Review

Review by logical code-path units (not files), in two passes: a per-unit sweep (Wave 1) whose reviewers report every finding with its confidence, then one verification pass that rules on each of them, checks the boundaries between units and sweeps for what nobody listed. Findings reach the user verdicted, not filtered by a confidence bar.

**Name resolution:** `praxis:`-prefixed skill and agent names are the plugin registrations; a local checkout registers them bare. If a referenced skill or agent resolves in neither form, tell the user what's missing instead of silently substituting a different one.

**Optional git range:** "$ARGUMENTS"

## Step 1: Determine Scope

1. Git range argument provided → that range (`git diff <range>`).
2. Otherwise, the union of the branch's unpushed commits and the working tree: `git diff @{upstream}...HEAD` (an open PR, `gh pr view`, supplies its `base...head` instead; with no PR, when there is no upstream or that diff is empty because the branch is already pushed → from the merge base with the default branch (`origin/HEAD`; if that ref is missing, `main` or `master`)), plus `git diff HEAD` and the untracked files (`git ls-files --others --exclude-standard`) when the tree is dirty. Either half alone misses the other: a dirty tree hides committed work, and a clean branch with no PR otherwise has no scope.

Read the full diff for context.

## Re-Review Mode

Trigger: the caller says re-review, or the range is a fix round answering findings a prior `reviews/<timestamp>/` holds. An earlier review folder alone doesn't trigger it, and an explicit range in Step 1 still sets the scope. A fix round gets **one** Re-Review, **scoped, not fresh**: no units and no Wave 1, because re-running the full review re-litigates settled findings and invites fabricated new ones. Dispatch `praxis:finding-verifier` once via Agent in its re-review mode: the fix diff as the range, the prior findings (the earlier folder's `verifier.md`, its Wave 1 reports behind it) and the report path `reviews/<new timestamp>/verifier.md`. It verdicts each prior finding Addressed or Not addressed, then sweeps the fix diff only for breakage the fix introduced. Skip Steps 2-5.

What it still finds, a prior finding not addressed or new breakage, is not another round: present it in Step 6's format (new findings by severity, the prior verdicts one line each) for the caller's ruling or the user's decision, and stop. Another Re-Review or a fresh Wave 1 happens only if the user asks.

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

## Step 4: Wave 1 — Per-Unit Sweep

Per unit, dispatch the reviewer fleet in parallel via Agent:

- `praxis:code-reviewer` — general quality, guidelines, plan compliance
- `praxis:spec-reviewer` — implementation matches spec (only when a plan or spec is present and the caller hasn't already checked completeness against it)
- `praxis:comment-analyzer` — comment accuracy
- `praxis:test-analyzer` — test coverage, behavioral focus
- `praxis:silent-failure-hunter` — swallowed errors, fallback misuse
- `praxis:type-analyzer` — type design (when types added/changed)

**Per-reviewer briefing**: the root (repo or worktree) to work from and the test command, plus what the tree can't reveal — the branch's base point relative to other in-flight work, and the provenance/freshness of any generated or snapshot data in the diff. When a plan has them, pass the flow sketch and the Slice 0 capture paths.

**Plan compliance**: when plan compliance is covered elsewhere, by `praxis:spec-reviewer` here or by the caller's completeness check (`/praxis:implement` Phase 4 runs one before this review and says so), brief `praxis:code-reviewer` accordingly (CLAUDE.md and bugs only). When spec-reviewer ran, the two rule oppositely on a worker-logged lean-out (code-reviewer: justified deviation; spec-reviewer: Missing), so you adjudicate in Step 6, after the verifier's verdict: a spec-reviewer Missing that matches a lean-out keeping the acceptance criteria green is judged against the fixed outcomes, as `/praxis:implement` Phase 4 does. No fixed outcome rides on it → Dropped as a justified lean-out, with that reason; otherwise it stands.

**Units crossing a trust boundary** (untrusted input reaching queries, commands, templates, file paths, HTML or deserializers; auth, session or permission logic; secrets or crypto): also dispatch a security reviewer, a `praxis:code-reviewer` briefed to read and follow `${CLAUDE_SKILL_DIR}/security.md` (pass that absolute path in the brief). Its output format and confidence rules replace code-reviewer's Output and Confidence Scoring sections, and it writes `security-reviewer.md`. Its findings go through Step 5's security filter.

**Documentation units**: additionally brief the dispatched reviewer(s) to load `Skill: "diataxis:diataxis"` (bare: `diataxis`; separate plugin — if it resolves in neither form, surface `/plugin marketplace add moiri-gamboni/diataxis-skill` instead of substituting) and review for kind-purity — the compass applied per section: content that informs a different need than its document's kind belongs elsewhere — on top of the accuracy and completeness checks the fleet already runs.

**Scale to unit complexity**: trivial diff → inline, with Step 5 only if the inline pass has findings. Sequential chain (one logical thread across files) → single code-reviewer. Small unit (1-2 files) → code-reviewer + 1-2 relevant others. Large/risky → the full fleet. Anything beyond trivial dispatches at least one agent. `praxis:comment-analyzer` dispatches whenever the diff adds or changes comments or docs, at any unit size.

Reviewers may return "no findings, this dimension isn't relevant" — preferred over fabrication. Otherwise they report everything, each finding with its confidence, those under 80 marked below the bar; a low score is not a reason to omit, because Step 5 rules on each one.

Each reviewer writes detailed findings to `reviews/<timestamp>/<unit>/<reviewer>.md` (`security-reviewer.md` for the security one) and returns summary + path.

**Severity mapping** — the reviewers' formats differ; Step 6 uses Critical / Important / Suggestion. A Confirmed finding takes the verifier's severity; the others (Disputed, Not worth fixing, Dropped) show the severity this table maps from the reviewer's own label, with the agent's own confidence:

| Reviewer | Critical | Important | Suggestion |
|---|---|---|---|
| code-reviewer | Critical | Important | — |
| silent-failure-hunter | CRITICAL | HIGH | MEDIUM |
| spec-reviewer | — | Missing, Misunderstood | Extra |
| test-analyzer | Critical Gaps (8-10) | Important Improvements (5-7) | Below the Bar (1-4), Test Quality Issues |
| comment-analyzer | — | Critical Issues | Improvement Opportunities, Recommended Removals |
| type-analyzer | — | a concern that is a bug | other Concerns, Recommended Improvements |
| security reviewer | High | Medium | Low |

comment-analyzer's "Critical Issues" are misleading comments, not broken behavior, so they don't block merge. test-analyzer reports criticality, not confidence: carry it as `criticality N/10` in the confidence slot, its 1-4 ratings being its below-the-bar findings. A security finding's confidence is its filter score × 10 (Step 5).

## Step 5: Verification

One verifier rules on every finding. Reviewer confidence gates nothing here: a finding of any score gets a verdict.

**Security filter first.** Per security finding, every severity: dispatch a fresh agent via Agent, in parallel, with only the diff, the finding, and the text of `${CLAUDE_SKILL_DIR}/security.md` from `FALSE POSITIVE FILTERING:` to the end of the file pasted into its brief. It scores the finding 1-10. Below 8 → Dropped, with the score and the filter's reason; 8 or more → passes, its confidence the score × 10, and reaches the verifier like any other finding.

**Then dispatch `praxis:finding-verifier`** once via Agent, over all units. Brief it with: the root, the test command and the range from Step 1; the review workspace `reviews/<timestamp>/` (every Wave 1 report there, below-the-bar findings included); the security findings the filter dropped, which it skips; the plan's fixed outcomes when a plan exists; whatever you briefed Wave 1 with beyond the tree (base point, data provenance); and the report path `reviews/<timestamp>/verifier.md`. A very large diff gets several verifiers in parallel, one per group of units, each told its group and writing `verifier-<n>.md`, each still reading the whole diff for the boundaries its group touches.

It returns a verdict per finding: **Confirmed** (real, with quoted evidence and a severity: Critical / Important / Suggestion), **Disputed** (refuted by a quoted line or invariant), or **Not worth fixing** (real, but the scenario is unreachable or unlikely in this code's use, or the fix costs more than the failure). Then it reports the cross-unit findings (contracts, naming, duplication, shared invariants between units) and any defects its sweep found that no reviewer listed. Read `verifier.md` itself, not only the returned summary.

Don't auto-drop Disputed findings: false negatives hurt more than false positives, so the report shows both sides and the user decides.

## Step 6: Aggregate and Present

Every finding lands in your message (the user only sees what's here), once, in the section its verdict names. A Confirmed finding goes by the verifier's severity whatever the reviewer's confidence, since the verifier's quoted evidence is what the 80 bar approximated. The verifier's cross-unit and sweep findings go in the severity sections like Confirmed ones, under `### Across units` when no single unit owns them. Adjudicate spec-reviewer Missing items against worker-logged lean-outs here (Step 4). Counts in section headers must match the bullets.

```markdown
# Review Summary

**Range**: <git-range>
**Units reviewed**: <N>

## Critical Issues (<count>)

### Unit: <unit-name>
- **[reviewer]** [confidence: <0-100>]: <description> [file:line]
  - Verified: <the verifier's quoted evidence>
  - Why it matters: <consequence>
  - Proposed fix: <if any, with cost>

## Important Issues (<count>)
[same structure]

## Suggestions (<count>)
[same structure, advisory]

## Not Worth Fixing (<count>)
- **[reviewer]** <description> [file:line] — <the verifier's reason>

## Disputed (<count>)
- **[reviewer]** [confidence: <0-100>]: <claim> [file:line]
  - For: <the reviewer's evidence>
  - Against: <the verifier's quoted line or invariant>

## Strengths
[What the diff gets right; preserve during fixes]

## Dropped (<count>)
[Security findings the filter dropped (score and reason); spec-reviewer Missing items judged justified lean-outs (reason). User can override.]

## Recommended Action
- **Fix**: Critical + Important. Block merge on Critical.
- **Decide together**: Disputed findings and real tradeoffs. Ask the user; skip trivial choices. Not Worth Fixing is decided already: not fixed unless the user overrides.
- **Defer (with reason)**: out of scope, depends on unmerged work, needs unavailable input. Default to not deferring.
```

After presenting, invoke `Skill: "praxis:verification-before-completion"` before the user acts on findings, on what the summary claims: a test result it cites comes from a command run in this review (rerun it, or mark it as a reviewer's unverified report), and the reviewed range ends at the current `HEAD` (`git rev-parse HEAD`; if it doesn't, say so in the summary).

## Next Step

- Critical found → "Fix the Critical and Important issues, then re-run /praxis:review scoped to the fixes: one Re-Review, whose leftovers go to a ruling or you."
- Only Disputed Critical → "Decide on the disputed findings; fixing any gets the same one Re-Review."
- Only Important / Suggestions → "Fix the Important issues, then commit when ready."
- Clean → "Ready to commit."
