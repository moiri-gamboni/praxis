# Praxis v2 Redesign

## Target Workflow

The design is built around a three-phase development lifecycle:

### Phase 1: Design (human-in-the-loop, iterative)

```
Brainstorm (conversational, skill-guided)
  -> Architecture (multiple approaches)
  -> Red-team pushback (challenges the design)
  -> Iterate on tradeoffs
  -> Red-team validates final architecture
  -> Plan (with decision records, no placeholders)
```

The user drives this phase conversationally. Skills prime Claude to explore more broadly, surface assumptions, and consider failure modes without adding friction (no useless questions). A red-team agent challenges architecture decisions before and after the in-depth design process.

Design artifacts (rationale, rejected alternatives, tradeoffs) are captured in a plan file.

### Phase 2: Implement (parallel team, mostly autonomous)

```
Spawn workers in isolated worktrees (one per plan task)
  Each worker:
    -> Implement using TDD (red-green-refactor)
    -> Run /review on own changes
    -> Run /simplify
    -> Run tests (unit + e2e)
    -> Update docs (README, CLAUDE.md) relevant to their unit
    -> Commit, push, open PR
    -> Report status (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED)
```

Workers are fully autonomous and self-contained. Each produces a reviewed, simplified, tested PR. Skills auto-activate throughout: TDD guides implementation, systematic-debugging activates if stuck, verification-before-completion gates claims of "done."

### Phase 3: Integrate (team lead, then human review)

```
Team lead agent:
  -> Merge worker branches into one
  -> Cross-cutting review (consistency, naming, interface mismatches)
  -> Cross-cutting simplify (remove duplication between units)
  -> Integration tests
  -> Coherent doc updates (resolve conflicts between worker README edits)
  -> Produce one clean final PR

User:
  -> Final manual review of the PR
```

Two layers of quality: per-unit (workers) and cross-cutting (team lead). The team lead handles what only becomes visible when pieces combine.

---

## Problems with Current Praxis

### 1. Too many overlapping entry points
8 commands + 6 skills + 9 agents. Users choosing between `/commit`, `/ship`, and `/finish` face unclear boundaries. The distinction between commands (explicit) and skills (auto-activating) isn't obvious.

### 2. No workflow continuity
Commands operate in isolation. After `/explore`, no nudge toward `/architect`. After `/review`, no guidance toward `/ship`. The pipeline exists but isn't surfaced.

### 3. No design-phase support
The original design excluded brainstorming/planning skills in favor of built-in plan mode. But plan mode is just a UI affordance; it doesn't teach plan format, quality standards, or decision capture. No red-team capability exists.

### 4. No parallel orchestration
No `/orchestrate` command. No team lead integration pattern. The `team-workflows` skill describes patterns but doesn't orchestrate.

### 5. Worker quality is incomplete
`/orchestrate` workers (as currently spec'd) only run `/simplify` and tests. They should also run `/review`, update docs, and use TDD throughout.

## What works well

- `/review` is well-designed: single entry point, orchestrates agents, clear output
- Skills auto-activate well (TDD, debugging, verification)
- Agents are properly hidden behind commands
- The pipeline exists (explore -> design -> implement -> review -> ship)

---

## Proposed Design

### Commands (8)

| Command | Phase | Purpose |
|---------|-------|---------|
| `/explore [target]` | Design | Deep codebase exploration via explorer agents. Ends with "next: /architect" |
| `/architect [feature]` | Design | Architecture via architect agents + red-team agent. Captures decision artifacts. Ends with "next: write plan" |
| `/orchestrate [instruction]` | Implement | Parallel orchestration: decompose into units, spawn workers (each does TDD + review + simplify + test + docs), team lead integrates, produce final PR |
| `/review [scope]` | Quality | Multi-agent review (code, tests, comments, errors, types). Used by workers per-unit and team lead cross-cutting |
| `/simplify [scope]` | Quality | Simplification pass. Used standalone by workers and during review |
| `/commit` | Deliver | Just commit. Lightweight, for solo work and edge cases |
| `/ship` | Deliver | Branch lifecycle: commit + push + PR. Absorbs current `/finish` (test, choose disposition, cleanup). Context-aware (main vs feature branch) |
| `/clean-gone` | Utility | Clean up stale local branches and worktrees. Useful post-batch |

**Changes from v1:**
- `/finish` removed (absorbed by `/ship`)
- `/orchestrate` added (parallel orchestration with team lead integration)
- `/architect` expanded (red-team agent, decision artifact capture)
- All commands end with "next step" suggestion

### Skills (7)

| Skill | Trigger | Purpose |
|-------|---------|---------|
| `design-exploration` | When brainstorming, exploring design options, or starting a new feature conversationally | Primes Claude for structured exploration: consider failure modes, surface assumptions, explore alternatives before converging, flag scope creep. Light touch, no extra questions |
| `planning` | When writing implementation plans or in plan mode | Plan format template, no-placeholders rule, task decomposition, scope detection (multi-subsystem -> break into sub-specs), self-review checklist, decision record format |
| `test-driven-development` | When implementing any feature or bugfix | TDD cycle (red-green-refactor), anti-patterns, "no production code without failing test" |
| `systematic-debugging` | When encountering bugs, test failures, unexpected behavior | Root cause investigation, pattern analysis, hypothesis testing. Supporting files: root-cause-tracing, defense-in-depth, condition-based-waiting |
| `verification-before-completion` | When about to claim work is complete | Evidence-before-assertion gate. Run verification commands, read output, confirm before claiming |
| `receiving-code-review` | When receiving code review feedback | Evaluate before implementing: verify technically, push back if wrong, implement in priority order |
| `frontend-design` | When building web components, pages, or applications | Distinctive design direction, anti-generic-AI-aesthetics |

**Changes from v1:**
- `team-workflows` removed (orchestration logic moves into `/orchestrate` command and the workflow awareness is distributed across command "next step" hints)
- `design-exploration` added (brainstorming guidance, from upstream brainstorming process minus the visual server)
- `planning` added (from upstream writing-plans content plus scope decomposition from brainstorming)

### Agents (10)

| Agent | Used by | Purpose |
|-------|---------|---------|
| `code-architect` | `/architect` | Designs feature architectures with implementation blueprints |
| `code-explorer` | `/explore` | Traces execution paths, maps architecture layers |
| `code-reviewer` | `/review` | Reviews code against guidelines and plans, confidence scoring |
| `code-simplifier` | `/simplify` | Simplifies code for clarity and maintainability |
| `comment-analyzer` | `/review comments` | Checks comment accuracy against actual code |
| `silent-failure-hunter` | `/review errors` | Finds swallowed errors, inadequate error handling |
| `spec-reviewer` | `/orchestrate` workers | Verifies implementation matches specification |
| `test-analyzer` | `/review tests` | Reviews test coverage quality and completeness |
| `type-analyzer` | `/review types` | Evaluates type design quality |
| `red-team` (new) | `/architect` | Adversarially challenges architecture decisions: weak assumptions, missing failure modes, over-engineering, under-engineering |

**Changes from v1:**
- `red-team` agent added

---

## How `/orchestrate` Works (Revised)

### Phase 1: Research and Plan (plan mode)

1. **Understand scope.** Launch explorer subagents to research what the instruction touches.
2. **Decompose into units.** Break into 5-30 independent, worktree-isolatable units. `planning` skill auto-activates to guide format and quality.
3. **Determine e2e test recipe.** Find concrete verification path (browser automation, curl, test suite). Ask user if unclear.
4. **Write plan.** Summary, numbered units (title, files, description), e2e recipe, worker instructions, decision record (why this decomposition).
5. **Get approval.** Exit plan mode, present to user.

### Phase 2: Spawn Workers

One background agent per unit, all with `isolation: "worktree"`. Worker instructions:

```
1. Implement using TDD (write failing test first, then make it pass, refactor)
2. Run /review on your changes
3. Run /simplify
4. Run unit tests + e2e test recipe
5. Update README and CLAUDE.md if your changes affect documented behavior
6. Commit with a clear message, push, open PR with gh pr create
7. Report: PR: <url> and status (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED)
```

Skills auto-activate: `test-driven-development` during implementation, `systematic-debugging` if stuck, `verification-before-completion` before reporting done.

### Phase 3: Team Lead Integration

After all workers report, spawn a team lead agent:

1. **Merge** worker branches into a single integration branch
2. **Cross-cutting review** via `/review all` (catches inconsistencies between units: naming, patterns, interface mismatches)
3. **Cross-cutting simplify** via `/simplify` (remove duplication across units)
4. **Integration tests** (do the pieces work together?)
5. **Doc coherence** (resolve conflicting README/CLAUDE.md edits from workers)
6. **Produce final PR** with clean commit history, linking to design artifacts

### Phase 4: Track and Report

Status table throughout:

| # | Unit | Worker | Team Lead | PR |
|---|------|--------|-----------|-----|
| 1 | title | DONE | merged | — |
| 2 | title | DONE_WITH_CONCERNS | reviewing | — |

Final output: one PR URL for user's manual review.

---

## How Commands Chain

The "next step" suggestions create a navigable pipeline without forcing a rigid sequence:

```
/explore "auth system"
  -> "Found 3 key areas. Next: /architect to design your approach"

/architect "add OAuth support"
  -> Red-team challenges assumptions
  -> Iterate with user
  -> Red-team validates
  -> "Architecture settled. Next: enter plan mode to write implementation plan"

(plan mode, planning skill activates)
  -> Write plan with task decomposition
  -> "Plan ready. Next: /orchestrate to implement in parallel, or implement directly"

/orchestrate "implement OAuth per the plan"
  -> Workers implement, review, simplify, test
  -> Team lead integrates
  -> "Final PR ready: <url>. Review and merge when satisfied."

(or for smaller changes, skip /orchestrate)
  -> Implement directly (TDD skill activates)
  -> /review
    -> "2 critical issues found. Fix them, then /ship"
  -> /ship
    -> "PR created: <url>"
```

---

## Upstream Content Incorporation

| Source | Content | Destination |
|--------|---------|-------------|
| brainstorming SKILL.md | Structured exploration process: surface assumptions, explore alternatives, flag scope creep, scope decomposition heuristic | `design-exploration` skill |
| brainstorming SKILL.md | Spec self-review checklist (placeholder scan, consistency, ambiguity) | `planning` skill |
| writing-plans SKILL.md | Plan format template, no-placeholders rule, task structure, self-review | `planning` skill |
| SDD implementer-prompt | Status protocol (DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED) | `/orchestrate` worker instructions |
| SDD implementer-prompt | "When you're in over your head" escalation pattern | `/orchestrate` worker instructions |
| writing-skills SKILL.md | CSO principle: description = trigger conditions only | CLAUDE.md conventions |
| writing-skills SKILL.md | Token efficiency targets (< 200 words frequent skills) | CLAUDE.md conventions |
| dispatching-parallel SKILL.md | "When NOT to dispatch" criteria (shared state, related failures) | `/orchestrate` Phase 1 decomposition guidance |

---

## Summary: What Changes

| Component | v1 (current) | v2 (proposed) | Change |
|-----------|-------------|---------------|--------|
| `/finish` | Standalone command | Absorbed by `/ship` | Removed |
| `/orchestrate` | Does not exist | Parallel orchestration + team lead | Added |
| `/architect` | Spawns architects only | Spawns architects + red-team agent | Expanded |
| `/ship` | Commit + push + PR | Branch lifecycle (absorbs /finish) | Expanded |
| `team-workflows` | Skill (team-only trigger) | Removed; content distributed | Removed |
| `design-exploration` | Does not exist | Brainstorming guidance skill | Added |
| `planning` | Does not exist | Plan-mode guidance skill | Added |
| `red-team` | Does not exist | Adversarial architecture agent | Added |
| Worker quality | simplify + tests | TDD + review + simplify + tests + docs | Expanded |
| Command chaining | None | "Next step" suggestions in every command | Added |
| CLAUDE.md | Current | + CSO principle, token targets | Updated |

Net: 8 commands (same count, better set), 7 skills (+1), 10 agents (+1).

## Upstream Tracking Plan

### Source Registry

`upstream.json` sources are unchanged from v1 (superpowers, feature-dev, pr-review-toolkit, commit-commands, frontend-design). No new sources added.


### Mapping Table: v2 Files to Upstream Sources

Each praxis file maps to zero or more upstream sources. The adaptation level indicates how much the praxis version diverges.

#### Commands

| Praxis file | Upstream source(s) | Adaptation | Notes |
|---|---|---|---|
| `commands/explore.md` | `feature-dev/commands/feature-dev.md` | new | Split from feature-dev into explore+architect |
| `commands/architect.md` | `feature-dev/commands/feature-dev.md` | new | Split from feature-dev; adds red-team |
| `commands/orchestrate.md` | none | new | Praxis original, uses TeamCreate for coordinated teams |
| `commands/review.md` | `pr-review-toolkit/commands/review-pr.md` | moderate | Restructured, git range support |
| `commands/simplify.md` | none | new | Praxis original |
| `commands/commit.md` | `commit-commands/commands/commit.md` | near-copy | Added git diff/log to allowed-tools |
| `commands/ship.md` | `commit-commands/commands/commit-push-pr.md`, `superpowers/skills/finishing-a-development-branch/SKILL.md` | significant | Merged two sources; absorbs /finish |
| `commands/clean-gone.md` | `commit-commands/commands/clean_gone.md` | near-copy | Added allowed-tools |

#### Skills

| Praxis file | Upstream source(s) | Adaptation | Notes |
|---|---|---|---|
| `skills/design-exploration/SKILL.md` | `superpowers/skills/brainstorming/SKILL.md` | significant | Process extracted; visual server, announcements, worktree setup removed |
| `skills/planning/SKILL.md` | `superpowers/skills/writing-plans/SKILL.md`, `superpowers/skills/brainstorming/SKILL.md` | significant | Plan format + no-placeholders from writing-plans; scope decomposition + self-review from brainstorming |
| `skills/test-driven-development/SKILL.md` | `superpowers/skills/test-driven-development/SKILL.md` | near-copy | Minor namespace changes |
| `skills/test-driven-development/testing-anti-patterns.md` | `superpowers/skills/test-driven-development/testing-anti-patterns.md` | near-copy | Condensed formatting |
| `skills/systematic-debugging/SKILL.md` | `superpowers/skills/systematic-debugging/SKILL.md` | near-copy | Removed graphviz, namespace changes |
| `skills/systematic-debugging/root-cause-tracing.md` | `superpowers/skills/systematic-debugging/root-cause-tracing.md` | near-copy | Inlined find-polluter script |
| `skills/systematic-debugging/defense-in-depth.md` | `superpowers/skills/systematic-debugging/defense-in-depth.md` | near-copy | Removed session-specific examples |
| `skills/systematic-debugging/condition-based-waiting.md` | `superpowers/skills/systematic-debugging/condition-based-waiting.md` | near-copy | Removed graphviz |
| `skills/verification-before-completion/SKILL.md` | `superpowers/skills/verification-before-completion/SKILL.md` | near-copy | Emoji -> text labels |
| `skills/receiving-code-review/SKILL.md` | `superpowers/skills/receiving-code-review/SKILL.md` | near-copy | Trimmed authorial voice |
| `skills/frontend-design/SKILL.md` | `frontend-design/skills/frontend-design/SKILL.md` | near-copy | Byte-identical minus license field |

#### Agents

| Praxis file | Upstream source(s) | Adaptation | Notes |
|---|---|---|---|
| `agents/code-architect.md` | `feature-dev/agents/code-architect.md` | near-copy | model: opus, trimmed tools |
| `agents/code-explorer.md` | `feature-dev/agents/code-explorer.md` | near-copy | model: opus, trimmed tools |
| `agents/code-reviewer.md` | `pr-review-toolkit/agents/code-reviewer.md`, `superpowers/agents/code-reviewer.md`, `superpowers/skills/requesting-code-review/code-reviewer.md` | significant | Merged three sources |
| `agents/code-simplifier.md` | `pr-review-toolkit/agents/code-simplifier.md` | near-copy | Genericized project-specific standards |
| `agents/comment-analyzer.md` | `pr-review-toolkit/agents/comment-analyzer.md` | near-copy | model: opus |
| `agents/test-analyzer.md` | `pr-review-toolkit/agents/pr-test-analyzer.md` | near-copy | Renamed, model: opus |
| `agents/silent-failure-hunter.md` | `pr-review-toolkit/agents/silent-failure-hunter.md` | near-copy | Removed project-specific refs |
| `agents/type-analyzer.md` | `pr-review-toolkit/agents/type-design-analyzer.md` | near-copy | Renamed, model: opus |
| `agents/spec-reviewer.md` | `superpowers/skills/subagent-driven-development/spec-reviewer-prompt.md` | moderate | Converted template to agent |
| `agents/red-team.md` | none | new | Praxis original |

### What the Analyze Script Sees

When `analyze-upstream.sh` runs after a sync, it now tracks:

1. **Existing near-copy files** -- upstream changes apply directly (same as v1)
2. **New upstream files not yet mapped** -- flagged for evaluation (the new-files gap from v1 is fixed)
3. **Per-source granularity** -- if only superpowers changed, only superpowers files are analyzed (from the per-source commit hashes)

### Content Extracted from Upstream (Summary)

For reference, this is what v2 takes from each upstream source that wasn't already mapped in v1:

| Upstream file | What we extract | Destination |
|---|---|---|
| `superpowers/skills/brainstorming/SKILL.md` | Exploration process (surface assumptions, alternatives, failure modes), scope decomposition heuristic, spec self-review checklist | `design-exploration` skill, `planning` skill |
| `superpowers/skills/writing-plans/SKILL.md` | Plan format template, no-placeholders antipatterns, task structure with checkboxes, self-review checklist | `planning` skill |
| `superpowers/skills/writing-plans/plan-document-reviewer-prompt.md` | Plan review criteria | `planning` skill (inline or as supporting file) |
| `superpowers/skills/subagent-driven-development/implementer-prompt.md` | Status protocol (DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED), escalation pattern, self-review checklist | `/orchestrate` worker instructions |
| `superpowers/skills/subagent-driven-development/code-quality-reviewer-prompt.md` | Review structure for subagent output | `/orchestrate` team lead instructions (or code-reviewer agent) |
| `superpowers/skills/dispatching-parallel-agents/SKILL.md` | "When NOT to dispatch" criteria | `/orchestrate` Phase 1 decomposition guidance |
| `superpowers/skills/writing-skills/SKILL.md` | CSO description principle, token efficiency targets | CLAUDE.md conventions |

Files tracked but only partially used (we extract specific content, not the whole file):

| Upstream file | What we use | What we skip | Praxis destination |
|---|---|---|---|
| `superpowers/skills/brainstorming/SKILL.md` | Exploration process, scope decomposition, self-review checklist | Visual server setup, worktree creation, announcement boilerplate | `design-exploration`, `planning` |
| `superpowers/skills/writing-plans/plan-document-reviewer-prompt.md` | Review criteria | Superpowers-specific template vars | `planning` |
| `superpowers/skills/subagent-driven-development/SKILL.md` | Two-stage review insight, model selection heuristic | Full SDD pipeline (replaced by `/orchestrate`) | `/orchestrate` |
| `superpowers/skills/subagent-driven-development/implementer-prompt.md` | Status protocol, escalation pattern, self-review | Superpowers-specific context loading | `/orchestrate` worker instructions |
| `superpowers/skills/subagent-driven-development/code-quality-reviewer-prompt.md` | Review structure | Template placeholders | `/orchestrate` team lead or code-reviewer |
| `superpowers/skills/dispatching-parallel-agents/SKILL.md` | "When NOT to dispatch" criteria | Dispatch mechanics (common sense) | `/orchestrate` Phase 1 |
| `superpowers/skills/writing-skills/SKILL.md` | CSO description principle, token targets | TDD-for-docs methodology, graphviz conventions | CLAUDE.md |

These should all have entries in `upstream.json` mappings so the analyze script flags changes to them. The adaptation level for partial extractions is `significant` since we're cherry-picking content, not tracking the whole file.

Files evaluated and fully excluded (no content extracted, no tracking needed):
- `superpowers/skills/executing-plans/SKILL.md` -- thin orchestration glue, Claude Code has better primitives
- `superpowers/skills/using-git-worktrees/SKILL.md` -- infrastructure-specific, Claude Code has built-in EnterWorktree
- `superpowers/skills/requesting-code-review/SKILL.md` -- already incorporated via agents/code-reviewer.md
- `superpowers/skills/brainstorming/visual-companion.md` -- non-portable server component
- `superpowers/commands/brainstorm.md`, `execute-plan.md`, `write-plan.md` -- deprecated stubs redirecting to skills

## Open Questions

1. **Red-team scope.** Currently proposed for architecture only. Should it also challenge review findings? (User mentioned "maybe review" too.) Risk: adds latency to every review. Possible compromise: red-team in `/architect` always, in `/review` only when invoked as `/review --red-team`.

2. **Design artifact format.** Plan files in `plans/` with a decision record section? ADR (Architecture Decision Record) format? Or just freeform markdown? Not critical for v2 launch.

3. **`design-exploration` skill weight.** Must be light enough that it doesn't add friction to casual brainstorming. The upstream brainstorming skill is ~164 lines; we'd want maybe 30-50 lines of behavioral priming. Core: explore alternatives before converging, surface assumptions, flag scope creep, consider failure modes.

4. **Worker `/review` cost.** Full `/review` spawns 5+ agents per worker. With 20 workers, that's 100+ agent invocations. Possible mitigations: workers run only `code-reviewer` (skip specialized agents), or workers run full review only if their unit is > N lines changed.

5. **`development-workflow` skill removal.** The plan removes `team-workflows` and distributes its content into `/orchestrate` and command chaining hints. Is anything lost? The "when to use teams vs solo vs batch" heuristic might need a home. Could go in CLAUDE.md or a lightweight routing skill.

6. **`/clean-gone` relevance.** More useful post-batch (many branches). Could auto-suggest after batch completion instead of being a standalone command.
