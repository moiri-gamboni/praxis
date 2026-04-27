# Praxis

A Claude Code plugin for software development. Skills teach Claude structured approaches to ideation, design, implementation, and code review. They invoke as slash commands (`/design`, `/implement`, `/review`, `/ship`, etc.) and auto-trigger when relevant. Specialized agents handle parallel exploration, adversarial design review, multi-dimensional code review, and plan-document review.

Praxis incorporates material from [superpowers](https://github.com/obra/superpowers), Anthropic's [claude-plugins-official](https://github.com/anthropics/claude-plugins-official) (feature-dev, pr-review-toolkit, commit-commands, frontend-design), and Claude Code's [built-in skills](https://github.com/anthropics/claude-code), picking the best version of each component and filling gaps between them.

## Installation

```bash
# Add the marketplace
/plugin marketplace add moiri-gamboni/praxis

# Install the plugin
/plugin install praxis@praxis-marketplace
```

Updates are applied automatically, or manually with `/plugin marketplace update`.

## Skills

Per Claude Code's unified skills/commands architecture, every skill is also a slash command. Auto-activating skills (no manual trigger needed) and slash-invoked skills are listed together.

| Skill | Trigger / Use |
|-------|-----------------|
| **ideate** | Auto-activates when in problem-space exploration: figuring out what to build, whether to build it, what existing solutions cover the problem |
| **systematic-debugging** | Auto-activates on bugs, test failures, unexpected behavior |
| **test-driven-development** | Auto-activates when implementing a feature or bugfix |
| **verification-before-completion** | Auto-activates when about to claim work is complete or passing |
| **receiving-code-review** | Auto-activates when receiving code review or red-team feedback |
| **frontend-design** | Auto-activates when building web components, pages, or applications |
| **`/design <feature>`** | Architecture design: 4-dim shared exploration → competing architects → synthesis matrix → red-team fleet. Reads `plans/<slug>-ideation.md` if present. Writes `plans/<slug>.md`. |
| **`/implement <task or plan>`** | Parallel work orchestration: decompose, spawn workers in worktrees (each with TDD + review + simplify gates), team lead integrates with spec-reviewer + verification-before-completion. |
| **`/review [git-range]`** | Multi-wave code review by logical units: per-unit deep review with full reviewer fleet → cross-unit boundary review → verification pass on Critical findings. |
| **`/simplify [scope]`** | Simplification pass on recently modified code. |
| **`/ship [merge] [test cmd]`** | PR-first shipping. State-driven default: opens or updates a PR. With `merge` arg: explicit local merge after acceptance prompt. |
| **`/clean-gone`** | Delete local branches whose remote counterpart is gone, plus their worktrees. Auto-fires after `/ship merge` and at the end of `/implement`. |

Skills chain naturally: each suggests a next step based on context. The intended pipeline is **ideate → /design → /implement → /review → /ship**.

## Agents

| Agent | What it does | Invoked by |
|-------|---------|-------------|
| **code-explorer** | Traces execution paths, maps architecture, documents dependencies. Dimensional invocation in `/design` Phase 1.2 (architectural fit / touchpoints / risks-deps / constraints). | `/design` Phase 1.2, `ideate`, manual |
| **code-architect** | Designs implementation blueprints. Dispatched in parallel with different philosophies (minimal / clean / pragmatic) from `/design` Phase 1.3. | `/design` Phase 1.3 |
| **red-team** | Adversarially challenges design. Dispatched as a fleet in `/design` Phase 1.5 (architectural soundness / failure modes / operational / hidden complexity / scope-assumptions / conditional security / conditional doc-currency). Per-finding confidence scores + anti-complexity bias. | `/design` Phase 1.5 |
| **plan-doc-reviewer** | Reads plan + ideation file, returns Approved or Issues. Independent second pair of eyes on plan completeness, spec alignment, buildability. Calibrated to flag only real implementation problems. | `/design` Phase 3 self-review |
| **code-reviewer** | Reviews code against project guidelines and plans, with confidence scoring (>= 80 threshold) and anti-complexity bias on proposed fixes. | `/review` Wave 1, Wave 2 cross-unit |
| **spec-reviewer** | Verifies implementation matches a specification (which can be a `/design` plan file). Skeptical, independent reading. | `/implement` Phase 4 (when plan file present), `/review` Wave 1, manual |
| **code-simplifier** | Simplifies code while preserving functionality. Direct-modify in `/simplify` standalone, advisory in `/review`. | `/simplify`, `/review` Wave 1, `/implement` workers + Phase 4 |
| **comment-analyzer** | Checks comment accuracy and long-term maintainability. Anti-complexity: removing bad comments preferred over adding obvious ones. | `/review` Wave 1 |
| **test-analyzer** | Reviews test coverage quality, prioritizing behavioral coverage. Each proposed test must articulate failure scenario + likelihood + consequence. | `/review` Wave 1 |
| **silent-failure-hunter** | Finds swallowed errors and inadequate error handling. Each finding must articulate the actual failure mode, not abstract concern. | `/review` Wave 1 |
| **type-analyzer** | Evaluates type design: encapsulation, invariants, enforcement. Each improvement must articulate specific bug class prevented vs cost. | `/review` Wave 1, Wave 2 cross-unit |

All agents run on Opus. Reviewer agents use a per-finding confidence threshold (>= 80) and reject fabricating findings to look thorough.

## Design

**Ideation produces a file `/design` reads.** `ideate` covers problem-space exploration (whether to build, what already exists, build-vs-buy via prior-art search). It writes `plans/<slug>-ideation.md` with problem statement, prior art investigated, alternatives considered at concept level, and key constraints. `/design` reads this as foundational context, gating on its presence ("run ideate first or proceed without prior-art search?").

**Two-axis design space in `/design`.** Phase 1.2 dispatches 4 `code-explorer` agents along evaluation **dimensions** (architectural fit, touchpoints, risks/dependencies, constraints) — exploration topics. Phase 1.3 dispatches 2-3 `code-architect` agents along **approaches** (minimal-changes, clean, pragmatic) — strategic stances. Phase 1.4 synthesis builds a matrix (dimensions × approaches), classifies decisions as Sensitivity Points (one-dimension impact) or Tradeoff Points (multi-dimension opposing), produces one merged plan with structured Alternatives Considered.

**Adversarial review fleet.** Phase 1.5 dispatches `red-team` agents in parallel along attack angles (architectural soundness, failure modes, operational concerns, hidden complexity, scope/assumptions; conditional security; conditional documentation currency with web-tool verification of named libraries). Per-finding confidence scores. Optional verification pass on Critical findings. Resolution Log enforces explicit Fixed/Rejected/Deferred per finding — silent acceptance not allowed.

**Plan-doc reviewer.** After Phase 3 self-review, `plan-doc-reviewer` reads the plan + ideation file independently and returns Approved or Issues. Calibrated to only flag real implementation problems.

**Hybrid file-writing.** Explorer and architect agents write detailed outputs to `plans/<slug>/.workspace/exploration/<dimension>.md` and `plans/<slug>/.workspace/architects/<approach>.md`, returning summary + path. Coordinator context stays light.

**Parallel implementation.** `/implement` decomposes work into independent units, spawns workers in isolated worktrees (each using TDD + review + simplify + verification gates). Workers write structured logs to `<workspace>/workers/<unit>.md`. Team lead merges incrementally, runs cross-cutting `/review` + `/simplify` + `spec-reviewer` against the plan + `verification-before-completion`. Calls `/clean-gone` to sweep stale state at the end.

**Multi-wave code review.** `/review` identifies logical code-path units (not files), dispatches the full reviewer fleet per unit (scaled to complexity), runs a cross-unit boundary review, then a verification pass that re-runs each Critical finding through a fresh second agent. Confirmed/Disputed labels; never auto-drop disputed findings.

**PR-first shipping.** `/ship` is state-driven: on main fast-paths to PR creation; on feature branch opens a PR or pushes update to existing one with summary confirmation. `/ship merge` runs an explicit local merge with typed acceptance.

## Example Workflows

### Large feature (parallel team)

1. Conversational ideation (ideate skill activates) — produces `plans/<slug>-ideation.md`
2. `/design` reads ideation, runs shared exploration + architect approaches + red-team fleet, writes `plans/<slug>.md`
3. `/implement plans/<slug>.md` spawns workers in worktrees: each does TDD + review + simplify + verification + commit + push + log
4. Team lead merges incrementally, then cross-cutting `/review` + `/simplify` + `spec-reviewer` against plan + `verification-before-completion`, opens PR
5. PR feedback iteration via manual edits + `/ship` to push updates

### Bug fix (solo)

1. systematic-debugging skill activates automatically on the bug report
2. test-driven-development skill activates (write failing test for the bug)
3. Fix the bug; verification-before-completion confirms tests pass
4. `/ship` to open a PR

### Before opening a PR

1. `/review` (multi-wave by logical units)
2. Fix Critical confirmed findings
3. `/simplify` (cross-cutting)
4. `/ship` to open PR

## Upstream Tracking

Praxis tracks changes to its source plugins and can automatically incorporate improvements via PR.

```bash
# Sync upstream and analyze changes
scripts/analyze-upstream.sh

# Non-interactive (for cron)
scripts/analyze-upstream.sh --auto

# Sync only (no analysis)
scripts/sync-upstream.sh
```

The `upstream` branch stores verbatim copies of the source plugins. `upstream.json` maps each praxis file to its source(s) with adaptation level and tracks per-source commit hashes for incremental analysis.

## License

AGPL-3.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE) for details.

Incorporates MIT-licensed material from [superpowers](https://github.com/obra/superpowers) by Jesse Vincent. Components from Anthropic's [claude-plugins-official](https://github.com/anthropics/claude-plugins-official): frontend-design is Apache-2.0 licensed; other components had no license specified as of 2026-02-16. 
