---
name: prototype
description: Use when building the first working version of something real — a prototype, MVP, or proof-of-concept — quickly, but as a sound and extensible base rather than a throwaway. Covers timed or scoped builds like hackathons and take-homes. Not for hardening an established system or pure problem-space exploration.
argument-hint: "<what to prototype>"
---

# Prototype

Build the first working version of something real — fast, but as a base worth keeping. Speed comes from judicious choices (libraries, patterns, architecture that fit and last), not from cutting corners. The thin slice you ship is a sound foundation to extend, not a hack to tear down.

**Task:** "$ARGUMENTS"

## Working principle

Deliberate about what lasts, ruthless about scope. Spend judgment on the choices that are expensive to reverse — stack, data model, the seams between parts — and defer everything that isn't the core: features, edge cases, polish. Minimal tech debt by construction, not by later cleanup. Lean on parallel subagents for exploration and for separable building, so the main thread stays on decisions and its context stays clean.

Scale the deliberateness to the task. A one-file script with an obvious stack goes near-straight to building; a feature inside an unfamiliar codebase earns the full first two phases. Don't ceremony-up the trivial; don't wing the consequential.

## Phase 1: Understand

Gather the real information the Phase 2 decisions will rest on. Exploration and research run as parallel subagents — concurrent, and their findings return synthesized so the main context isn't flooded with raw output.

### 1.1 Frame

- The **real outcome** wanted, in a sentence — the result, not the literal feature. Open-ended task ("here's our situation, build something useful")? Then *what to build* is the first and highest-leverage decision; spend real thought there.
- The **deliverable type** — a script, a service, a patch to an existing system, a config, a one-off analysis. Don't default to greenfield.
- **Constraints**: budget (depth scales to it), the concrete end state ("working" = what, exactly), the environment and stack.
- Can't ask and can't check? **State an assumption and keep moving** — and surface the assumptions you make. A stated assumption is something the user can correct; a buried one is a trap.
- **Flag what's tricky** rather than smoothing it over: a goal underspecified in a way that changes *what* to build, considerations that genuinely pull against each other, footguns (the part that looks cheap but isn't — an auth handshake, a rate limit, a messy data format). These steer the slice and the choices.

### 1.2 Codebase (existing systems only)

Dispatch parallel subagents, one per dimension, each returning structured findings with `file:line`:

- **Patterns & conventions** — how this codebase does things; what to imitate.
- **Integration points** — where the new work plugs in; data flow across the boundary.
- **Reuse** — what already exists that this can build on or must not duplicate.
- **Constraints & risks** — what could break; what's fragile or load-bearing.

Synthesize into the brief. Skip the wave entirely when greenfield.

### 1.3 Prior art

Research what already exists before building it, in parallel subagents. Use **WebSearch** for known libraries, services, and tools; use **Exa** for descriptive discovery of less-obvious options. Prefer primary sources. Per candidate, capture what actually drives a choice:

- maturity · fit with the environment · license & cost · lock-in · how far it extends

Default leans reuse — adopting the right thing is a stronger base than rebuilding it worse — but reject a dependency that doesn't fit, and say why.

### Output: Brief

Capture it (scratch note or inline); it drives Phase 3 and seeds the handoff.

```
- Outcome — <real result; what "good" means / the metric>
- Deliverable — <type; greenfield or change to existing>
- Constraints — <budget · end state · environment/stack>
- Codebase — <patterns to fit · integration points · reuse · risks, file:line>   (omit if greenfield)
- Prior art — <option — maturity · fit · cost · lock-in · extensibility — verdict>
```

## Phase 2: Decide

Make the choices that let you build fast and leave a base that holds. Every pick traces to the brief — a finding, a real tradeoff, a constraint — not a default or a vibe.

### 2.1 Choices

The decisions expensive to reverse: stack, key libraries, data model, the seams between components, the load-bearing patterns.

**Right-size the toolchain.** Prefer the least machinery that fits. For web, a build-free page — plain HTML, CSS, and JS in separate files, CDN-loaded libraries — is usually faster and a cleaner base than scaffolding a framework; keep them split, not inlined into one page that muddies concerns as the logic grows. Reach for a build setup (SvelteKit, Vite, Next) only when this prototype is the seed of a product that will grow — that demo-now-versus-base-to-grow read sets how much structure to buy, here and elsewhere.

For each significant choice:

```
| Decision | Options weighed | Pick | Why — fit · maturity · cost · lock-in · extensibility | Conf | Crux to flip |
|---|---|---|---|---|---|
| Persistence | SQLite / Postgres / JSON files | SQLite | zero-ops, fits single-node scope, clean path to Postgres later | med | a second writer or service appears |
```

### 2.2 Thin slice

The **minimal end-to-end path** that runs and also seats future work — the right seams, no speculative abstraction, no hacks you'd rip out. Then **ship / skip**:

- **In** — the sound core.
- **Deferred** — features, edge cases, polish, scale-hardening. Never core soundness. Each becomes a line in the handoff's "next".

### 2.3 Tests (judgment, not ritual)

- **Test** where correctness is non-obvious or a contract others build on — test-first when writing the test clarifies that contract before the code, which is often faster.
- **Skip** glue, scaffolding, and anything a single run verifies — lean on Phase 5 instead.

### Output: Decision record

The Choices table + the slice + the test calls. Seeds the handoff's "decisions + tradeoffs".

## Phase 3: Premortem & confirm

### Premortem

Assume the built prototype failed to show the outcome — why? Name the likeliest failure modes: the integration that won't authenticate, data messier than assumed, a library that doesn't do the thing, scope quietly too big for the budget. On a simple build there may be none worth naming — say so, don't manufacture them. Fold cheap de-risks into the slice now; carry the rest to the gate.

### Confirm

The decision point. Present inline — the user shouldn't have to open the brief:

1. **Goal + slice** — the outcome, the sound core you'll build, what's deferred.
2. **Choices** — the decision table, consequential and high-debt-if-wrong ones first.
3. **Risks** — the premortem's top failure modes and how each is handled: de-risked in the slice, accepted, or still open.
4. **Worth your input** — genuinely-uncertain calls, each with its strongest alternative and the crux that would flip it, so the choice is made on merits rather than nodded through. Omit if none.

Stop for confirmation on the consequential or hard-to-reverse. Make reversible calls yourself and say you did; silence on those is assent.

## Phase 4: Build

Build the slice to the standard a maintainer would inherit cleanly — clear structure and naming, the abstractions the scope earns and no more.

- **Parallelize the separable.** A unit with a clean contract and its own surface → a subagent, the contract handed to it inline. Coupled, shared-state, or small → one tight session. Don't split what isn't separable; don't serialize what is.
- **TDD where Phase 2 said it pays** — failing test, minimal pass, refactor — on the core logic and contracts. Elsewhere, build and let Phase 5 carry correctness.
- **Reach a committed end-to-end run early.** That running version is your floor; after it you're never empty-handed. Keep it green; commit in small semantic steps.
- **Web UI?** It's usually the demo surface — make it credible and non-generic, not gold-plated. Use the `frontend-design` skill if it's available.

## Phase 5: Verify

Trust evidence, not the agent's own say-so about code it just wrote. Run it, show the actual output, and check it against something the code didn't generate:

- Deterministic logic → an input whose correct answer you fixed independently (from the spec, or worked by hand), shown matching.
- Non-deterministic or model output → spot-check against explicit criteria, validate shape and ranges, flag low-confidence cases for a human.
- Data → reconcile against the source of truth, not the pipeline's report of itself.

Leave no junk behind from runs against live resources. Report what you checked, what it establishes, and what it doesn't; keep verified separate from assumed. "It ran and looks right" is not a check.

## Phase 6: Iterate or wrap

- **Budget left** → the next slice with the most `impact × confidence ÷ time`, built to the same standard — not gold-plating a finished core.
- **Handoff** — the doc that makes this a base someone can build on:

```
- What it is + how to run — one-line command; input committed; a sample of real output
- Decisions + tradeoffs — the Phase 2 picks and what they cost later, so they aren't relitigated
- Solid vs provisional — what's foundation-grade, what's a known shortcut to revisit
- Assumptions, limits, next — what you assumed, where it breaks, the highest-leverage next slice
```
