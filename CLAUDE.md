## What This Is

Praxis is a Claude Code plugin: a collection of Markdown files (agents, commands, skills) that extend Claude Code's behavior. There is no compiled code, no build system, no tests, and no dependencies. The content *is* the product.

It was created by merging five upstream plugins (superpowers, feature-dev, pr-review-toolkit, commit-commands, frontend-design) plus content from Claude Code's bundled skills. `upstream.json` tracks the provenance and adaptation level of each file.

## Repository Layout

- `agents/*.md` -- Agent definitions (YAML frontmatter: `name`, `description`, `model`, `effort`, `color`, `tools`)
- `skills/*/SKILL.md` -- Auto-activating skills (YAML frontmatter: `name`, `description`; skills invocable as slash commands add `argument-hint` when they take arguments and `allowed-tools` when their tool needs are bounded), with optional supporting `.md` files in the same directory
- `.claude-plugin/plugin.json` -- Plugin identity and version
- `.claude-plugin/marketplace.json` -- Marketplace distribution config
- `upstream.json` -- Maps each praxis file to its upstream source(s) and adaptation level (`near-copy`, `moderate`, `significant`, `new`)
- `scripts/` -- Bash scripts for upstream tracking

## Conventions

- Every agent pins `model` and `effort` in frontmatter, matched to task shape (model = how hard the task is; effort = how far the agent travels — files read, verification depth). Current tiers: fable+high for generative full tracks (code-architect, implementer, trimmer) and for judgment-heavy review of scoped input (code-reviewer, red-team, plan-doc-reviewer, silent-failure-hunter, code-simplifier); sonnet+high for scoped single-dimension legs where travel is the job (code-explorer, spec-reviewer, test-analyzer, type-analyzer); sonnet+medium for near-mechanical checks (comment-analyzer). There are currently 13 agents.
- All agents have Bash (tests, git, checkouts as needed). Advisory agents never edit code — they report findings; source is modified only by implementer and by code-simplifier in direct mode.
- Skills invoked as slash commands restrict their tools via `allowed-tools` in frontmatter; keep tool lists minimal, but include every tool the workflow's own instructions call (a skill that says "invoke `Skill:`" or "spawn via Agent" needs `Skill` / `Agent, Task` in the list). `prototype` and `iterate` deliberately omit `allowed-tools` — full builds and open-ended iteration need unrestricted tools. `/praxis:implement` is the parallel orchestration command. There is no shipping or branch-cleanup command: commits, PRs, and stale-branch sweeps are handled directly.
- **Cross-plugin diataxis reference:** documentation work routes through the external `diataxis` plugin (`diataxis:diataxis`, repo `moiri-gamboni/diataxis-skill`) at four points — implementer step 8 (orchestrated path), design's doc-deliverable task template, review's documentation-unit briefing, and the `/praxis:document` command (corpus-scale: parallel classification → approval gate → per-kind writers → kind-purity review; the one component that hard-requires the plugin rather than degrading). Solo work outside these paths relies on the diataxis skill's own auto-activation. Praxis carries only the classification (which kind the change touches; the feature-work prior: how-to + reference, sometimes explanation, rarely tutorials); every rule about a kind's form lives in that skill, loaded fresh — mirroring how TDD rules live in `praxis:test-driven-development`, not inline. The name-resolution guard applies: unresolvable in namespaced or bare form → surface the plugin install, never substitute. Praxis stays functional without it (the docs steps still run, unguided).
- **Namespaced references:** praxis content refers to its own skills and agents with the `praxis:` prefix — `Skill: "praxis:review"`, `subagent_type: "praxis:implementer"`, `/praxis:design` — because that's the name they register under when the plugin is installed; a local checkout registers them bare. Dispatching skills and the implementer agent carry a name-resolution line: a reference that resolves in neither form is surfaced (to the user, or to the worker log), never silently replaced with a different skill or agent. Dispatch prose says "via Agent" (the current tool name); `allowed-tools` lists both `Agent, Task` so older builds still resolve.
- Skills activate automatically based on their `description` field; that description is effectively the trigger condition. Skills include ideate, prototype, and iterate alongside the original set.
- **Living decision record:** `/praxis:iterate` maintains the plan artifacts post-pipeline — Resolution Log entries (angle: iterate) for falsifier evidence and decisions, fixed-outcome amendments for scope changes, provenance-tagged constraints for clarifications — and lazily seeds a minimal `plans/<slug>.md` (header + constraints + Resolution Log, in the formats design and ideate define) when no artifacts exist. Entry bar: only what a future session would re-litigate; never a changelog. `/praxis:design` 1.1 reads such files and carries sticky rejections and `[user]` constraints forward.
- **CSO (Claude Search Optimization):** Skill descriptions should state WHEN to use the skill (trigger conditions), not WHAT the skill does or how the workflow works. When descriptions summarize the workflow, Claude follows the description shortcut instead of reading the full skill content.
- **Lean mandate:** user-stated outcomes are fixed, machinery is variable; minimum competent implementation; crash-loud for impossible states; defensive code needs scenario/likelihood/consequence; cut-proposals are first-class review findings; tests assert behavior (inputs/state → observable output/effect), never source text or shape. Both pipelines carry an explicit trim pass (the `praxis:trimmer` agent): `/praxis:design` Phase 3 on the plan, `/praxis:implement` Phase 4 on the merged diff. Canonical statement in `skills/design/SKILL.md`; rationale in `plans/lean-mandate.md`.
- **Token efficiency:** Keep skill content concise. Frequently activated skills: < 200 words getting-started section. Other skills: < 500 words for core content. Supporting files can be longer.
- The code-reviewer agent merges what were originally three upstream variants (one has since been deleted upstream; two remain tracked). It auto-detects plan context, applies confidence scoring (threshold >= 80), and ends with a "Ready to merge?" verdict.

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
