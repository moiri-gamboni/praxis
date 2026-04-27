---
name: ideate
description: Use when the user is in problem-space exploration — figuring out what to build, whether to build it, or what existing solutions already address the problem. Stops before architecture/implementation planning (that's `/design`).
---

# Ideate

Help turn ideas into approved design concepts through dialogue. Understand the problem, explore prior art, surface hidden assumptions, propose alternatives, converge on a concept the user approves. Output goes to a file `/design` reads.

## Hard Gate

Do NOT write code, create source files, or take implementation actions until the user approves a concept. The concept can be brief, but it must exist and be approved. The output of this skill is an ideation document, not code.

## Scope

Ideate covers: problem clarity, prior art, alternatives at concept level, build-vs-buy, scope decomposition. It hands off to `/design` for technical implementation planning (architecture, file paths, tasks).

If you find yourself reasoning about specific files, function signatures, integration points, or implementation steps, stop — that's `/design`'s job.

## Codebase Awareness

Before proposing anything, build light awareness of the relevant codebase area:

- Dispatch one `code-explorer` agent at the start with a broad-scope prompt: "What's the lay of the land in [area]? What patterns exist, what's already built that might relate, what would a new feature in this space need to fit with?"
- Do inline lookups (Read, Grep, Glob) during dialogue when the user proposes something specific
- Don't go deep — that's `/design`'s job. You're checking whether ideas fit the existing world, not designing them

If the codebase already has something that addresses the user's problem (or part of it), surface that immediately. "We already do X at file:line" beats reinventing.

## Prior Art Search

For non-trivial features, look for existing solutions in the world before assuming we need to build:

- Web search for libraries, services, canonical implementations
- Use Exa for descriptive discovery queries; WebSearch for known-entity lookups
- Evaluate what you find on: maturity, fit with our codebase, license, operational cost
- Report findings in the ideation document — both what was considered and what was rejected, with reasons

If a mature off-the-shelf solution covers the problem, surface that and ask whether building custom is justified. Default lean is build-vs-buy in favor of buy unless there's a clear reason.

## Conversation Shape

**Understand first.** Check project context (CLAUDE.md, recent commits, area files). Ask clarifying questions one at a time, only for what you genuinely cannot determine from code or context. Prefer multiple choice when options are known.

**Detect scope early.** Before diving into details, assess whether the request describes multiple independent subsystems. If it does, flag this immediately: help decompose, identify dependencies and build order, then ideate the first sub-project. Each sub-project gets its own ideation cycle.

**Surface assumptions, content and framing.**

*Content checks* (codebase + prior art): tradeoffs the user may not have considered, implicit assumptions that don't hold, conflicts with codebase patterns, existing solutions that match the proposal.

*Framing checks*: diminutives ("just", "quick") that minimize complexity, skipped reasoning between problem and solution, repeated framing despite alternatives, hedge/certainty mismatch, treating things as fixed that may be open, vocabulary that imports a specific paradigm.

**Surface every consequential observation directly.** "Consequential" = would change the design or proceed differently if true. State the issue and evidence:

- "X assumes Y. Codebase doesn't support Y because [file:line]."
- "You're treating Z as a fixed requirement. Is it?"
- "The framing imports paradigm P, which constrains the design space. If you mean something else, say so."

Don't soften with "worth checking" or "you might be." Don't preemptively hedge. Don't ask questions to verify what you can determine yourself; assert and let the user correct. If multiple observations surface, group by category (codebase / framing / prior art) and lead with highest impact. No artificial cap on count — relevance is the filter.

Asking is reserved for what you genuinely cannot determine: priorities, external constraints, user preferences.

**Explore alternatives.** Propose 2-3 high-level approaches with tradeoffs. Lead with your recommendation and reasoning. Do not settle on the first idea that seems workable.

**Consider failure modes.** For each approach, ask: what would make this fail? What are the maintenance costs? What happens when requirements change? Proportional to complexity.

**Converge incrementally.** Once you understand the problem, present the concept in sections scaled to complexity. Ask after each section whether it looks right. Cover problem statement, alternatives, decision, key constraints — not implementation detail.

## Output: Ideation Document

When the user approves the concept, write to `plans/<slug>-ideation.md` with this structure:

```markdown
# <Feature Name> — Ideation

## Problem
<2-4 sentences: what's being solved, why now, who for>

## Prior Art Investigated
<For each existing solution evaluated:>
- **<Name>** — <2-line description>. <Maturity / fit / cost assessment>. **Decision:** rejected / kept under consideration / adopted (with reason)

## Alternatives Considered
<For each high-level approach considered (not technical detail — that's /design's job):>
- **<Approach name>** — <description>. **Tradeoffs:** <key wins/losses>. **Decision:** rejected / chosen / hybridized (with reason)

## Concept
<What we're building, at concept level. 1-3 paragraphs. NOT file paths, NOT function signatures.>

## Key Constraints Surfaced
<Constraints from dialogue that /design needs to know about: perf needs, security/compliance, backwards compat, integration boundaries, anything user revealed during back-and-forth>

## Open Questions
<Anything still unresolved that should be addressed during /design or implementation>
```

Slug: kebab-case, descriptive (per global CLAUDE.md preference). Claude proposes; user can override at start.

## After Approval

Once the user approves the concept and the ideation file is written, suggest `/design` to handle the technical implementation planning. `/design` will read the ideation file as input and skip the prior-art search (already done here).
