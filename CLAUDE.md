## What This Is

Praxis is a Claude Code plugin: a collection of Markdown files (agents, commands, skills) that extend Claude Code's behavior. There is no compiled code, no build system, no tests, and no dependencies. The content *is* the product.

It was created by merging five upstream plugins (superpowers, feature-dev, pr-review-toolkit, commit-commands, frontend-design). `upstream.json` tracks the provenance and adaptation level of each file.

## Repository Layout

- `agents/*.md` -- Agent definitions (YAML frontmatter: `name`, `description`, `model`, `color`, `tools`)
- `commands/*.md` -- Slash commands (YAML frontmatter: `description`, `argument-hint`, `allowed-tools`)
- `skills/*/SKILL.md` -- Auto-activating skills (YAML frontmatter: `name`, `description`), with optional supporting `.md` files in the same directory
- `.claude-plugin/plugin.json` -- Plugin identity and version
- `.claude-plugin/marketplace.json` -- Marketplace distribution config
- `upstream.json` -- Maps each praxis file to its upstream source(s) and adaptation level (`near-copy`, `moderate`, `significant`, `new`)
- `scripts/` -- Bash scripts for upstream tracking

## Conventions

- All agents must specify `model: opus` in frontmatter.
- Commands restrict their tools via `allowed-tools` in frontmatter; keep tool lists minimal.
- Skills activate automatically based on their `description` field; that description is effectively the trigger condition.
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

The `upstream` branch stores verbatim copies. The `upstream-analyzed` git tag marks what has been processed.

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
