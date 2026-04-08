---
name: design-exploration
description: Use when brainstorming features, exploring design options, or starting a new feature conversationally, before implementation begins
---

# Design Exploration

Help turn ideas into designs through collaborative dialogue. Understand context, surface assumptions, explore alternatives, then converge on a design the user approves.

## Hard Gate

Do NOT write code, create files, or take implementation actions until the user approves a design. This applies regardless of project size. "Simple" projects are where unexamined assumptions waste the most work. The design can be brief, but it must exist and be approved.

## Conversation Shape

**Understand first.** Check project context (files, docs, recent commits). Then ask clarifying questions one at a time to understand purpose, constraints, and success criteria. Prefer multiple choice when the options are known.

**Detect scope early.** Before diving into details, assess whether the request describes multiple independent subsystems. If it does, flag this immediately: help decompose into sub-projects, identify dependencies and build order, then design the first sub-project through the normal flow. Each sub-project gets its own design-then-plan cycle.

**Explore alternatives.** Propose 2-3 approaches with trade-offs. Lead with your recommendation and reasoning. Do not settle on the first idea that seems workable.

**Surface assumptions.** Name what you are assuming about the user's goals, the codebase, and the environment. Ask whether those assumptions hold. Unspoken assumptions are the primary source of wasted implementation work.

**Consider failure modes.** For each approach, ask: what would make this fail? What are the maintenance costs? What happens when requirements change? Proportional to complexity; a config change needs less failure analysis than a new service.

**Converge incrementally.** Once you understand the problem, present the design in sections scaled to complexity. Ask after each section whether it looks right. Cover architecture, components, data flow, error handling, and testing as relevant.

## Working in Existing Codebases

Explore the current structure before proposing changes. Follow established patterns. If existing code has problems that affect the work (overgrown files, tangled responsibilities), include targeted improvements in the design. Do not propose unrelated refactoring.

## Design for Isolation

Break systems into units that each have one clear purpose, communicate through well-defined interfaces, and can be understood independently. For each unit: what does it do, how do you use it, what does it depend on? Prefer smaller, focused units; they are easier to reason about and less error-prone to implement.

## After Approval

Once the user approves the design, transition to planning. For multi-step features, write an implementation plan (the planning skill covers format and structure). For small changes, implement directly.

Suggest `/architect` if the design needs deeper technical exploration with multiple architectural perspectives.
