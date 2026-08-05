## What This Is

Praxis is a Claude Code plugin: a collection of Markdown files (agents, commands, skills) that extend Claude Code's behavior. There is no compiled code, no build system, no tests, and no dependencies. The content *is* the product.

It was created by merging five upstream plugins (superpowers, feature-dev, pr-review-toolkit, commit-commands, frontend-design) plus content from Claude Code's bundled skills. `upstream.json` tracks the provenance and adaptation level of each file.

## Repository Layout

- `agents/*.md` -- Agent definitions (YAML frontmatter: `name`, `description`, `model`, `effort`, `color`, `tools`)
- `skills/*/SKILL.md` -- Auto-activating skills (YAML frontmatter: `name`, `description`; skills invocable as slash commands add `argument-hint` and `allowed-tools`), with optional supporting `.md` files in the same directory
- `.claude-plugin/plugin.json` -- Plugin identity and version
- `.claude-plugin/marketplace.json` -- Marketplace distribution config
- `upstream.json` -- Maps each praxis file to its upstream source(s) and adaptation level (`near-copy`, `moderate`, `significant`, `new`)
- `scripts/` -- Bash scripts for upstream tracking

## Conventions

- Every agent pins `model` and `effort` in frontmatter, matched to task shape (model = how hard the task is; effort = how far the agent travels — files read, verification depth). Current tiers: opus+high for generative full tracks (code-architect, implementer, trimmer); opus+medium for judgment-heavy review of scoped input (code-reviewer, red-team, plan-doc-reviewer, silent-failure-hunter, code-simplifier); sonnet+high for scoped single-dimension legs where travel is the job (code-explorer, spec-reviewer, test-analyzer, type-analyzer); sonnet+medium for near-mechanical checks (comment-analyzer). There are currently 13 agents.
- All agents have Bash (tests, git, checkouts as needed). Advisory agents never edit code — they report findings; source is modified only by implementer and by code-simplifier in direct mode.
- Skills invoked as slash commands restrict their tools via `allowed-tools` in frontmatter; keep tool lists minimal. `/ship` includes the finishing workflow (formerly `/finish`); `/implement` is the parallel orchestration command.
- Skills activate automatically based on their `description` field; that description is effectively the trigger condition. Skills include ideate and prototype alongside the original set.
- **CSO (Claude Search Optimization):** Skill descriptions should state WHEN to use the skill (trigger conditions), not WHAT the skill does or how the workflow works. When descriptions summarize the workflow, Claude follows the description shortcut instead of reading the full skill content.
- **Lean mandate:** user-stated outcomes are fixed, machinery is variable; minimum competent implementation; crash-loud for impossible states; defensive code needs scenario/likelihood/consequence; cut-proposals are first-class review findings; tests assert behavior (inputs/state → observable output/effect), never source text or shape. Both pipelines carry an explicit trim pass (the `trimmer` agent): `/design` Phase 3 on the plan, `/implement` Phase 4 on the merged diff. Canonical statement in `skills/design/SKILL.md`; rationale in `plans/lean-mandate.md`.
- **Token efficiency:** Keep skill content concise. Frequently activated skills: < 200 words getting-started section. Other skills: < 500 words for core content. Supporting files can be longer.
- The code-reviewer agent merges three upstream variants. It auto-detects plan context, applies confidence scoring (threshold >= 80), and ends with a "Ready to merge?" verdict.

## Upstream Tracking

Files with `near-copy` adaptation in `upstream.json` should stay close to their source. Be conservative when editing them; prefer changes that the upstream would also benefit from.

Files with `new` adaptation have no upstream counterpart and can be freely modified.

```bash
# Sync upstream, analyze changes, apply improvements, open a PR
scripts/analyze-upstream.sh

# Non-interactive (for cron)
scripts/analyze-upstream.sh --auto

# Sync only (no analysis)
scripts/sync-upstream.sh
```

The `upstream` branch stores verbatim copies. Synced commit hashes are recorded per-source in `_source_commits.json` on that branch.

### Adding a New Upstream Plugin

When incorporating a new source plugin into praxis:

1. Add an entry under `sources` in `upstream.json` (format: `{"repo": "owner/repo", "path": "subpath"}`)
2. Add mapping entries in `upstream.json` for each file taken from the plugin
3. Add attribution to `NOTICE` (include license text and list of derived files)
4. Update `README.md` (plugin count, skills/commands/agents tables, license section)
5. Copy the actual content files into the appropriate directories

## Versioning

The patch version in `plugin.json` and `marketplace.json` is auto-bumped by a pre-commit git hook. Claude Code uses the version string to detect plugin updates; without a bump, new content won't reach users.

Bump MAJOR or MINOR manually when appropriate:
- **MINOR**: new skills, commands, or agents; significant behavior changes to existing ones
- **MAJOR**: breaking changes (renamed/removed skills or commands, changed trigger conditions)

When bumping manually, update both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. The hook will still increment patch on top of whatever you set.

## License

AGPL-3.0. Incorporates MIT-licensed material from superpowers and Apache-2.0-licensed material from frontend-design. See NOTICE for attribution.
