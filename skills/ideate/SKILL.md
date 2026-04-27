---
name: ideate
description: Use when the user is in problem-space exploration — figuring out what to build, whether to build it, or what existing solutions already address the problem. Stops before architecture/implementation planning (that's `/design`).
---

# Ideate

Turn ideas into approved design concepts through dialogue. Output: an ideation document `/design` reads.

## Hard Gate

No code, no source files, no implementation actions until the user approves a concept. Output is an ideation doc, not code.

## Scope

Covers: problem clarity, prior art, alternatives at concept level, build-vs-buy, scope decomposition.

Stops at: file paths, function signatures, integration points, implementation steps. Those are `/design`.

## Codebase Awareness

Build light awareness of the relevant area:

- Dispatch one `code-explorer` agent at start: "Lay of the land in [area]? Patterns, what's already built that might relate, what would a feature here need to fit with?"
- Inline lookups (Read, Grep, Glob) when user proposes specifics
- Don't go deep — that's `/design`. You're checking fit, not designing

If the codebase already addresses the problem (or part of it), surface immediately: "We already do X at file:line" beats reinventing.

## Prior Art Search

For non-trivial features, look for existing solutions before assuming custom is needed:

- Web search for libraries, services, canonical implementations (Exa for descriptive discovery; WebSearch for known entities)
- Evaluate: maturity, fit with codebase, license, operational cost
- Report in the ideation doc: what was considered, what was rejected, why

Default leans build-vs-buy in favor of buy unless there's clear reason to build.

## Conversation Shape

**Understand first.** Check CLAUDE.md, recent commits, area files. Clarifying questions one at a time, only for what code/context can't answer. Prefer multiple choice when options are known.

**Detect scope early.** If the request spans multiple independent subsystems, flag and decompose: identify dependencies, build order, ideate the first sub-project. Each sub-project gets its own cycle.

**Surface assumptions — content and framing.**

*Content checks* (codebase + prior art): tradeoffs not considered, implicit assumptions that don't hold, codebase pattern conflicts, existing solutions that match.

*Framing checks*: diminutives ("just", "quick") minimizing complexity, skipped reasoning between problem and solution, repeated framing despite alternatives, hedge/certainty mismatch, treating open things as fixed, vocabulary that imports a paradigm.

**Surface every consequential observation directly.** "Consequential" = would change the design if true. State issue and evidence:

- "X assumes Y. Codebase doesn't support Y because [file:line]."
- "You're treating Z as a fixed requirement. Is it?"
- "The framing imports paradigm P. If you mean something else, say so."

Don't soften, don't hedge, don't ask to verify what you can determine. Multiple observations: group by category (codebase / framing / prior art), lead with highest impact, no count cap.

Ask only for what you genuinely can't determine: priorities, external constraints, preferences.

**Explore alternatives.** 2-3 high-level approaches with tradeoffs. Lead with recommendation + reasoning. Don't settle on the first workable idea.

**Consider failure modes.** Per approach: what makes it fail? Maintenance costs? Behavior when requirements change? Proportional to complexity.

**Converge incrementally.** Present the concept in sections scaled to complexity. Ask after each section. Cover problem, alternatives, decision, constraints — not implementation detail.

## Output: Ideation Document

On approval, write to `plans/<slug>-ideation.md`:

```markdown
# <Feature> — Ideation

## Problem
<2-4 sentences: what, why now, who for>

## Prior Art Investigated
- **<Name>** — <2-line description>. <Maturity / fit / cost>. **Decision:** rejected / kept / adopted (reason)

## Alternatives Considered
- **<Approach>** — <description>. **Tradeoffs:** <wins/losses>. **Decision:** rejected / chosen / hybridized (reason)

## Concept
<1-3 paragraphs at concept level. NOT file paths, NOT signatures.>

## Key Constraints Surfaced
<From dialogue: perf, security/compliance, compat, integration boundaries>

## Open Questions
<Unresolved items for /design or implementation>
```

Slug: kebab-case, descriptive. Propose; user can override.

## After Approval

Suggest `/design`. It reads the ideation file and skips prior-art search (already done).
