# Praxis

A Claude Code plugin for software development. Skills teach Claude structured approaches to debugging, testing, and code review. Commands give you `/commit`, `/ship`, `/review`, `/explore`, and more. Agents handle specialized analysis tasks like hunting silent failures or evaluating type design.

Praxis is built from four existing plugins ([superpowers](https://github.com/jesse-c/superpowers), [feature-dev](https://github.com/anthropics/claude-plugins-official), [pr-review-toolkit](https://github.com/anthropics/claude-plugins-official), [commit-commands](https://github.com/anthropics/claude-plugins-official)), picking the best version of each component and filling gaps between them.

## Installation

```bash
# Add the marketplace
/plugin marketplace add moiri-gamboni/praxis

# Install the plugin
/plugin install praxis@praxis-marketplace
```

Updates are applied automatically, or manually with `/plugin marketplace update`.

## Skills

Skills activate automatically based on context. They guide how Claude approaches a class of problem without you having to ask.

| Skill | Activates when... |
|-------|-----------------|
| **systematic-debugging** | Encountering a bug, test failure, or unexpected behavior |
| **test-driven-development** | Implementing a feature or bugfix |
| **verification-before-completion** | About to claim work is complete or passing |
| **receiving-code-review** | Receiving code review feedback |
| **team-workflows** | Working with agent teams on multi-step tasks |

## Commands

| Command | What it does |
|---------|---------|
| `/commit` | Create a git commit from current changes |
| `/ship` | Commit, push, and open a PR |
| `/finish` | Run tests, then merge/PR/keep/discard with worktree cleanup |
| `/clean-gone` | Delete local branches whose remote counterpart is gone |
| `/review [aspects]` | Code review across multiple dimensions (code, tests, comments, errors, types, simplify) |
| `/explore [area]` | Deep codebase exploration via code-explorer agents |
| `/architect <feature>` | Design a feature with competing architectural approaches |
| `/simplify [scope]` | Simplification pass on recently modified code |

Commands work standalone or as building blocks in agent team workflows.

## Agents

| Agent | What it does | Invoked by |
|-------|---------|-------------|
| **code-explorer** | Traces execution paths, maps architecture, documents dependencies | `/explore` |
| **code-architect** | Designs implementation blueprints from codebase patterns | `/architect` |
| **code-reviewer** | Reviews code against project guidelines and plans, with confidence scoring | `/review code` |
| **spec-reviewer** | Verifies implementation matches a specification | Team workflows |
| **code-simplifier** | Simplifies code while preserving functionality | `/review simplify` |
| **comment-analyzer** | Checks comment accuracy and long-term maintainability | `/review comments` |
| **test-analyzer** | Reviews test coverage quality, prioritizing behavioral coverage | `/review tests` |
| **silent-failure-hunter** | Finds swallowed errors and inadequate error handling | `/review errors` |
| **type-analyzer** | Evaluates type design: encapsulation, invariants, enforcement | `/review types` |

All agents run on Opus.

## Design

**Plan mode for planning.** Instead of dedicated brainstorming or plan-writing skills, praxis relies on Claude Code's built-in plan mode (explore, design, get approval).

**Agent teams for coordination.** Complex multi-step work uses agent teams with shared task lists. The team-workflows skill teaches patterns for composing commands into team workflows.

**One code-reviewer.** The three source plugins each had their own code-reviewer. Praxis merges them: it auto-detects whether a plan exists, applies confidence scoring (>= 80 threshold), and ends with a "Ready to merge?" verdict.

## Example Workflows

### Large feature (team)

1. Team lead enters plan mode, spawns explorers with `/explore`
2. Architect teammate runs `/architect` with findings
3. Team lead writes plan, gets approval, exits plan mode
4. Implementation teammates work from the task list, TDD skill activates
5. Reviewer teammate runs `/review code errors`
6. Fix issues, then `/ship`

### Bug fix (solo)

1. Debugging skill activates automatically
2. TDD skill activates (write a failing test first)
3. Fix the bug, verification skill confirms tests pass
4. `/commit`

### Before opening a PR

1. `/review all`
2. Fix critical issues
3. `/simplify`
4. `/ship`

## Upstream Tracking

Praxis tracks changes to its source plugins and can automatically incorporate improvements via PR.

```bash
# Snapshot current plugin cache into the upstream branch
scripts/sync-upstream.sh

# Analyze changes, apply improvements, and open a PR
scripts/analyze-upstream.sh

# Non-interactive (for cron)
scripts/analyze-upstream.sh --auto
```

The `upstream` branch stores verbatim copies of the 4 source plugins. `upstream.json` maps each praxis file to its source(s) with adaptation level. When changes are found, Claude evaluates them conservatively (only genuine improvements, not cosmetic changes), applies them to a sync branch, and opens a PR for review.

Weekly cron example:
```
0 9 * * 1  cd ~/Documents/Code/praxis && scripts/sync-upstream.sh && scripts/analyze-upstream.sh --auto
```

## License

AGPL-3.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE) for details.

Incorporates MIT-licensed material from [superpowers](https://github.com/jesse-c/superpowers) by Jesse Vincent. Components from Anthropic's [claude-plugins-official](https://github.com/anthropics/claude-plugins-official) (no license specified as of 2026-02-16).
