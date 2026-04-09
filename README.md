# Praxis

A Claude Code plugin for software development. Skills teach Claude structured approaches to debugging, testing, design, and code review. Commands give you `/commit`, `/ship`, `/review`, `/implement`, and more. Agents handle specialized analysis tasks like hunting silent failures or evaluating type design.

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

Skills activate automatically based on context. They guide how Claude approaches a class of problem without you having to ask.

| Skill | Activates when... |
|-------|-----------------|
| **ideate** | Brainstorming features, exploring design options, or starting a new feature conversationally |
| **systematic-debugging** | Encountering a bug, test failure, or unexpected behavior |
| **test-driven-development** | Implementing a feature or bugfix |
| **verification-before-completion** | About to claim work is complete or passing |
| **receiving-code-review** | Receiving code review feedback |
| **frontend-design** | Building web components, pages, or applications |

## Commands

| Command | What it does |
|---------|---------|
| `/explore [area]` | Deep codebase exploration via code-explorer agents |
| `/design <feature>` | Design a feature with competing approaches + red-team adversarial review |
| `/implement <instruction>` | Parallel work orchestration: decompose, spawn workers with TDD/review gates, team lead integration |
| `/review [aspects]` | Code review across multiple dimensions (code, tests, comments, errors, types, simplify) |
| `/simplify [scope]` | Simplification pass on recently modified code |
| `/commit` | Create a git commit from current changes |
| `/ship [test cmd]` | On main: commit, push, PR. On feature branch: test, then merge/PR/keep/discard with cleanup |
| `/clean-gone` | Delete local branches whose remote counterpart is gone |

Commands chain naturally: each suggests a next step based on context.

## Agents

| Agent | What it does | Invoked by |
|-------|---------|-------------|
| **code-explorer** | Traces execution paths, maps architecture, documents dependencies | `/explore` |
| **code-architect** | Designs implementation blueprints from codebase patterns | `/design` |
| **red-team** | Adversarially challenges architecture decisions | `/design` |
| **code-reviewer** | Reviews code against project guidelines and plans, with confidence scoring | `/review code` |
| **spec-reviewer** | Verifies implementation matches a specification | `/implement` team lead, manual |
| **code-simplifier** | Simplifies code while preserving functionality | `/simplify` |
| **comment-analyzer** | Checks comment accuracy and long-term maintainability | `/review comments` |
| **test-analyzer** | Reviews test coverage quality, prioritizing behavioral coverage | `/review tests` |
| **silent-failure-hunter** | Finds swallowed errors and inadequate error handling | `/review errors` |
| **type-analyzer** | Evaluates type design: encapsulation, invariants, enforcement | `/review types` |

All agents run on Opus.

## Design

**Design-first workflow.** The `ideate` skill primes Claude for structured brainstorming (surface assumptions, explore alternatives, consider failure modes). `/design` handles architecture, test design, and implementation planning with no-placeholder quality standards.

**Adversarial architecture review.** `/design` spawns competing design approaches, then a `red-team` agent challenges the chosen architecture before implementation begins.

**Parallel implementation.** `/implement` decomposes work into independent units, spawns workers in isolated worktrees (each using TDD, review, and simplify), then a team lead merges and does cross-cutting review.

**One code-reviewer.** Three source plugins each had their own code-reviewer. Praxis merges them: it auto-detects whether a plan exists, applies confidence scoring (>= 80 threshold), and ends with a "Ready to merge?" verdict.

## Example Workflows

### Large feature (parallel team)

1. Brainstorm conversationally (ideate skill activates)
2. `/design` designs approaches, red-team challenges them
3. Enter plan mode, write implementation plan (`/design` guides plan format)
4. `/implement` spawns workers: each does TDD, review, simplify, tests, docs
5. Team lead merges, cross-cutting review and simplify
6. Final PR for manual review

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
