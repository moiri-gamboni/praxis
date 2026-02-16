# Praxis

A unified Claude Code plugin combining behavioral discipline, composable commands, and specialized review agents.

Praxis consolidates the best of [superpowers](https://github.com/anthropics/claude-code-plugins), [feature-dev](https://github.com/anthropics/claude-code-plugins), [pr-review-toolkit](https://github.com/anthropics/claude-code-plugins), and [commit-commands](https://github.com/anthropics/claude-code-plugins) into one plugin that leverages plan mode and agent teams as first-class mechanisms.

## Installation

```bash
claude plugin add github:moiri-gamboni/praxis
```

Then disable the plugins it replaces:

- superpowers
- feature-dev
- pr-review-toolkit
- commit-commands

## Components

### Skills (always-active behavioral discipline)

| Skill | Triggers when... |
|-------|-----------------|
| **systematic-debugging** | Encountering any bug, test failure, or unexpected behavior |
| **test-driven-development** | Implementing any feature or bugfix |
| **verification-before-completion** | About to claim work is complete or passing |
| **receiving-code-review** | Receiving code review feedback |
| **team-workflows** | Working with agent teams on multi-step tasks |

Skills activate automatically based on context. They enforce methodology (how to debug, how to do TDD, how to handle feedback) without orchestrating workflow.

### Commands (composable building blocks)

| Command | Purpose |
|---------|---------|
| `/commit` | Create a git commit from current changes |
| `/ship` | Commit, push, and open a PR |
| `/finish` | Test gate + merge/PR/keep/discard options + worktree cleanup |
| `/clean-gone` | Clean up local branches deleted on remote |
| `/review [aspects]` | Multi-dimensional code review (code, tests, comments, errors, types, simplify) |
| `/explore [area]` | Deep codebase exploration with code-explorer agents |
| `/architect <feature>` | Design feature architecture with competing approaches |
| `/simplify [scope]` | Simplification pass on recently modified code |

Commands can be invoked directly by users or by agent teammates via the Skill tool.

### Agents (specialized autonomous reviewers)

| Agent | Purpose | Launched by |
|-------|---------|-------------|
| **code-explorer** | Trace execution paths, map architecture, document dependencies | `/explore` |
| **code-architect** | Design implementation blueprints from codebase patterns | `/architect` |
| **code-reviewer** | Review against guidelines and/or plans, confidence-scored | `/review code` |
| **spec-reviewer** | Verify implementation matches specification exactly | Team workflows |
| **code-simplifier** | Simplify code for clarity while preserving functionality | `/review simplify` |
| **comment-analyzer** | Check comment accuracy and long-term maintainability | `/review comments` |
| **test-analyzer** | Review test coverage quality, behavioral over line coverage | `/review tests` |
| **silent-failure-hunter** | Find silent failures and inadequate error handling | `/review errors` |
| **type-analyzer** | Analyze type design: encapsulation, invariants, enforcement | `/review types` |

All agents use the Opus model.

## Design Principles

**Plan mode replaces brainstorming and plan-writing.** Plan mode's built-in scaffolding (explore, design, review, write plan, get approval) covers what superpowers' brainstorming and writing-plans skills did.

**Agent teams replace workflow orchestration.** Subagent-driven-development's review loops and executing-plans' batched execution are replaced by agent teams with shared task lists. The team-workflows skill teaches patterns for composing commands into team workflows.

**Commands are composable building blocks.** Each command does one thing well and can be invoked standalone by users or by teammates via the Skill tool.

**Skills are behavioral discipline only.** No workflow orchestration in skills, just methodology enforcement.

**One unified code-reviewer.** Merges three near-identical versions: reviews against plans (auto-detected) AND guidelines, with confidence scoring (threshold >= 80) and a clear "Ready to merge?" verdict.

## Workflow Examples

### Significant feature (team)

1. Team lead enters plan mode, spawns explorers with `/explore`
2. Architect teammate runs `/architect` with findings
3. Team lead writes plan, gets approval, exits plan mode
4. Implementation teammates handle tasks using TDD skill
5. Reviewer teammate runs `/review code errors`
6. Fix issues, then `/ship`

### Quick fix (solo)

1. Debugging skill activates automatically
2. TDD skill activates (write failing test first)
3. Fix the bug, verification skill confirms
4. `/commit`

### PR preparation

1. `/review all`
2. Fix critical/important issues
3. `/simplify`
4. `/commit` then `/ship`

## Upstream Tracking

Praxis tracks changes to its source plugins so improvements can be incorporated.

```bash
# Check for upstream updates (uses worktree, safe)
scripts/sync-upstream.sh

# Analyze changes with Claude (interactive)
scripts/analyze-upstream.sh

# Or non-interactive for cron
scripts/analyze-upstream.sh --auto
```

The `upstream` branch stores verbatim copies of the 4 source plugins. `upstream.json` maps each praxis file to its source(s) with adaptation level. Reports are saved to `reports/`.

Weekly cron example:
```
0 9 * * 1  cd ~/Documents/Code/praxis && scripts/sync-upstream.sh && scripts/analyze-upstream.sh --auto
```

## File Structure

```
praxis/
  .claude-plugin/
    plugin.json
  skills/
    systematic-debugging/
      SKILL.md
      root-cause-tracing.md
      defense-in-depth.md
      condition-based-waiting.md
    test-driven-development/
      SKILL.md
      testing-anti-patterns.md
    verification-before-completion/
      SKILL.md
    receiving-code-review/
      SKILL.md
    team-workflows/
      SKILL.md
  commands/
    commit.md
    ship.md
    clean-gone.md
    finish.md
    review.md
    explore.md
    architect.md
    simplify.md
  agents/
    code-explorer.md
    code-architect.md
    code-reviewer.md
    spec-reviewer.md
    code-simplifier.md
    comment-analyzer.md
    test-analyzer.md
    silent-failure-hunter.md
    type-analyzer.md
  scripts/
    sync-upstream.sh
    analyze-upstream.sh
  upstream.json
```

## License

AGPL-3.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE) for details.

Incorporates MIT-licensed material from [superpowers](https://github.com/jesse-c/superpowers) by Jesse Vincent. Components from Anthropic's [claude-plugins-official](https://github.com/anthropics/claude-plugins-official) (no license specified as of 2026-02-16).
