# Observe Before Model — code that touches reality gets built from reality

**Goal:** Stop the pipeline from producing code that is designed against an imagined external world and then hides the mismatch.

**Fixed outcomes** (the user's nine complaints, stated as results the changed plugin must produce):

1. Reachable failures propagate by default; a catch block exists only with a named recovery that beats crashing.
2. Every external boundary logs its raw request and raw response, permanently.
3. Nothing parses, summarizes, or branches on a shape it hasn't observed in a capture or read in the docs — including the error-handling code itself.
4. Any call surface new to the codebase is checked against current official docs before it is written, at implementation time, by whoever writes it.
5. Prior and similar work is researched before building, on every path that builds something, not only when ideation ran.
6. The system-level flow (stages, boundaries, what crosses each, where its shape comes from) exists as an artifact before code exploration and before architects design.
7. Requirements and design goals are stated, recorded, and checked against on every path — including solo and iterate work — and "done" is demonstrated on real input, not only on tests.
8. Building is progressive: docs → one real call, captured → thin end-to-end slice → edge cases by observation → widen. Parallel work starts from observed contracts, not invented ones.
9. Comments and docs say why, in the domain's words; plan vocabulary (task numbers, finding IDs, matrix labels, mode names) never reaches code; comment and doc quality is checked at write time, per slice, not batched at the end.

**Provenance:** every outcome above is `[user]` (2026-09-15 conversation: "too much error catching, instead of failing loudly", "not enough instrumentation/logging, esp. raw logs/requests/responses", "too much processing of instrumentation/errors/logs… assumes some shape that is incorrect", "not enough check against official docs, esp. APIs", "not enough research of prior/similar work", "not enough focus on the general idea/design/pipeline/flow… before doing exploratory code work", "not enough focus on figuring out user requirement, design goals… recording and checking against those", "not enough progressive coding/enhancement", "not enough review of comments and docs… too much process notes are creeping in, references to acronyms from design docs, too much explanation of how and not why").

## Root causes

The nine complaints are all Claude tendencies. Praxis's job is to counter them. Reading every skill and agent, the tendencies fall into two groups: ones praxis is **silent** on (nothing counters them) and ones praxis **amplifies** (a specific line pushes the same way). Six shared causes, not nine:

**A. Reality is never observed before it is modeled.** Complaints 2, 3, 4, 8, and half of 1. The pipeline front-loads design (from codebase archaeology and memory) and back-loads verification (tests and reviewers). No step anywhere says: touch the real thing, capture what came back, build against that. TDD is progressive per *test* but not per *reality* — a red-green cycle against a mocked response you invented is progressive fiction. Amplifiers:
- `code-architect` step 3: "For deps already in the codebase, trust the existing version." A library already in the tree used on a new endpoint or parameter gets no docs check; "trust" is read as "trust my memory".
- Docs currency is a *conditional* red-team angle at design time only. The `implementer` has no WebFetch or WebSearch tool, so it cannot check docs even when it wants to; its only sub-agent is `code-reviewer`.
- `test-driven-development` rationalization table: "Need to explore first → Fine. Throw away exploration, start with TDD." A spike against a real API is exactly the code the Iron Law says to delete, and nothing says the *capture* it produced is the fixture to keep.
- `design` Phase 2 writes test specs ("inputs, expected outputs") and Phase 3 writes "exact paths and code… no placeholders" before any real response has been seen. `implement` then dispatches every worker in parallel from that pinned contract; if the contract encodes an invented shape, every worker builds on it.

**B. The lean mandate's instrumentation cut over-reached.** Complaint 2 directly. "Instrumentation with no named reader" is a cut target in `design` (Working Principle, angle 5, Self-Review 6), `trimmer`, `code-reviewer`, `red-team`, `code-architect`. It never distinguishes *derived* instrumentation (metrics, counters, summaries, alarms, dashboards — the real overbuild) from *raw capture* at a boundary (the request bytes, the response bytes, the exception with its payload — one line, obvious reader, highest debugging value per line in the codebase). `defense-in-depth.md` and `iterate` then say "delete the diagnostics you added while investigating" with no carve-out for keeping the raw capture. Falsifier evidence against the lean mandate's instrumentation clause: the user reports too little raw logging.

**C. "Handle" is the default verb for reachable failures.** Complaints 1 and 3. The mandate says crash-loud for *impossible* states and, for reachable ones, "handle, surface loudly" (`code-architect` Lean Defaults). Claude reads "handle" as `try/except → log → return default → continue`. The three-part articulation (scenario, likelihood, consequence) that gates defensive code is satisfiable by any reachable external error ("if the API returns 503…"), so it licenses the catch rather than blocking it. `silent-failure-hunter` principle 2 ("every error message tells users what went wrong and what they can do") pushes toward friendlier handlers, not fewer. Nothing says the default response to a reachable failure is *propagate with the raw context attached*, or that the handler itself must not assume the error's shape.

**D. Big-bang delivery is the pipeline's shape.** Complaints 8 and 6. Design → every task → all workers in parallel → review. The thin-slice / "committed end-to-end run early" idea exists only in `prototype`, positioned as the fast path for MVPs. No plan has a Slice 0; no integration contract is derived from an observed run.

**E. Design is bottom-up from the codebase, never top-down from the flow.** Complaint 6. `design` 1.2 dispatches five code-explorers before anything states what the system does as stages and boundaries. `code-architect` has "Data Flow" as one of eight output sections. `prototype` 1.1 frames the outcome but not the flow. For greenfield pipelines and scripts, design's whole Phase 1 is inapplicable and nothing replaces it. Without a flow artifact, there is nowhere to record which boundary shapes are known from docs, which from a capture, and which are assumed — so the assumed ones are never targeted first.

**F. Quality-of-prose and requirements rules are end-loaded and design-only.** Complaints 7 and 9. Fixed outcomes, provenance tags, and traceability live in `design`; `iterate` records only "entry-worthy events" and never restates what done looks like; `verification-before-completion` checks that tests pass, not that the outcome is achieved on real input. Comment rules (why-not-how, no process residue, no plan pointers) live in `comment-analyzer` and `trimmer` — end of pipeline — and `review` drops `comment-analyzer` for small units. Write-time has one bullet in `implementer` step 6 and nothing in the solo path. The plan template itself manufactures the vocabulary that leaks (task numbers, finding IDs like "D1", matrix dimension names, mode labels) and never says it stays in the plan.

**G. Prior art is gated on an optional phase.** Complaint 5. `design` 1.1: "No ideation file. Run `praxis:ideate` first, or proceed without prior-art search?" and 1.2: "Prior art belongs to `praxis:ideate`, not here." Say "proceed" once and prior art never happens. `iterate`, `implement`, and the solo path have none. Praxis's notion of prior art is also narrow — libraries to adopt — and omits reference implementations to read and documented pitfalls.

## Reconciliation with the lean mandate

The lean mandate stands. Three of its clauses get sharpened, none reversed:

- **Instrumentation.** The named-reader test applies to *derived* instrumentation. Raw capture at an external boundary — request, response, exception payload, before any parsing — is not instrumentation; it is the evidence every later debugging session starts from, and its reader is named: whoever debugs the next failure. One line per boundary, kept.
- **Crash-loud.** Extended from impossible states to the default for reachable ones. Impossible → no guard. Reachable → propagate with raw context. Catch → only with a named recovery that beats crashing, narrowly typed, never assuming the error's shape. The three-part articulation still gates *whether* a failure deserves code; a catch additionally needs the fourth part: what it does instead of crashing, and why that's better for the person running this.
- **Spikes and TDD.** A spike against a real boundary is *observation*, not implementation. Its code is thrown away (Iron Law intact); its capture is kept as the first test's fixture. This is stricter TDD, not looser: `writing-good-tests.md` already demands "mirror real data completely — all documented fields"; a capture is the only way to actually do that.

## The canonical block

New skill `skills/observe-before-model/SKILL.md`, auto-activating. Description (trigger only, per CSO): *Use when writing or changing code that calls an external API, SDK, CLI, subprocess, file format, database, queue, or LLM — or parses what comes back, or handles its errors — before writing the parser, the handler, or the test.* Core under 500 words:

> **Observe, then model.** Code that depends on the shape of something outside this codebase is written from an observed instance of that shape, never from memory.
>
> **Before the parser:** (1) Read the official docs for this exact call — endpoint, parameters, response schema, error shapes, pagination, limits. Official means the vendor's current reference, fetched now; not memory, not a tutorial, and not "the library is already in the codebase" unless *this call* already is. (2) Make one real call. Capture the raw result to a file under the project's fixtures or scratch directory, unedited. (3) Write the code against what you captured. The capture is the test fixture. (4) Don't read a field you haven't seen in a capture or the docs. (5) Widen by observation: the error response, the empty result, the pagination edge, the rate limit — each captured once before it is handled.
>
> **Raw capture stays.** Every boundary logs its full raw request and full raw response before any parsing, at a level that doesn't drown stdout but is present (debug level, or a file). Log the raw thing, not a summary of it: `log(response.text)`, never `log(f"got {len(data['items'])} items")` — the summary assumes the shape it claims to report and can throw or lie. This is not "instrumentation without a reader"; the reader is whoever debugs the next failure. Derived instrumentation — counters, metrics, summaries, alarms — still needs a named reader.
>
> **Errors propagate.** The default response to a reachable failure is to let it raise with the raw context attached (the request, the raw response body, the input). A traceback with the payload is the correct outcome for a script or pipeline; that is what non-zero exit codes are for. A catch block needs, beyond scenario / likelihood / consequence, a **named recovery that beats crashing**: bounded retry on a transient class then re-raise; skip one item of a batch with the raw failure recorded and the run ending non-zero; degrade a non-essential feature with the failure logged at error level. "Log and continue with a default" is not a recovery unless the default is a correct answer. Catch narrowly — the specific class the recovery applies to; `except Exception` only at a top-level boundary that reports and exits non-zero. The handler never assumes the error's shape: log `repr(e)` and the raw body, never `e.response.json()["error"]["message"]`. Each catch carries one line: instead of crashing, this does X because Y.
>
> **Spike, then TDD.** The one real call is a spike. Its code is throwaway; its capture is not. TDD starts after: the first failing test uses the captured fixture.

## Per-file edits

### New

**`skills/observe-before-model/SKILL.md`** — the canonical block above, plus a short "Common rationalizations" table in the house style ("The library is already in the codebase" → this call isn't; "I know this API" → knowledge has a cutoff, docs don't; "Logging the body is noisy" → debug level or a file, and noise beats blindness; "The user shouldn't see a traceback" → then catch at the top level, report, exit non-zero — not in the middle; "I'll add the error path later" → capture it now, it's one call).

### Design time

**`skills/design/SKILL.md`** (significant)

1. **Working Principle**: extend the crash-loud paragraph with the reachable-failure default and the raw-capture carve-out (three sentences; the operational rules live in the new skill).
2. **New 1.1.5 Flow sketch**, before exploration: stages → boundaries → per boundary: what crosses it, and its shape's source — `docs` (URL) | `capture` (path) | `codebase` (type, file:line) | `assumed`. Greenfield or pipeline work with no codebase to explore: the sketch replaces 1.2, and architects design against it. Every `assumed` boundary is where Slice 0 goes first.
3. **1.1**: replace "proceed without prior-art search?" with: no ideation file → run a bounded prior-art pass here (one subagent; WebSearch + Exa; canonical implementations to read, reference repos, documented pitfalls for this kind of system; libraries to adopt), reported in one section of the synthesized context. Delete "Prior art belongs to `praxis:ideate`, not here."
4. **1.2.8 fixed outcomes**: add "and, for each boundary the flow sketch marks `assumed`, the observation that will pin it" — so the goal restatement names where reality gets checked.
5. **1.5 angle 7** trigger: "when the flow sketch has any boundary whose source is `docs` or `assumed`" — concrete, from the artifact.
6. **Phase 2 Test Design**: "Test specs for a boundary marked `docs` or `assumed` are provisional until Slice 0 captures the real shape; the captured fixture replaces the invented one. Never mock a response nobody has seen."
7. **Phase 3 Plan Header**: add **Flow** (the sketch, with its source tags).
8. **Task Structure**: **Task 1 is Slice 0** whenever the sketch has any non-`codebase` boundary: the thinnest end-to-end path through every boundary with one real input, raw capture at each boundary, committed. Its acceptance criterion is the captured fixtures plus one real output. The integration contract other tasks build to is written *after* Slice 0, from the captures — the plan says so explicitly, and `implement` honors it.
9. **Task Structure, vocabulary rule**: "Plan vocabulary — task numbers, finding IDs, matrix dimensions, mode labels, architect names — is for the plan. Code, comments, commit messages, and docs use the domain's words. An implementer citing a plan ID in a comment is a defect; give it the reason in plain words instead."
10. **Self-Review**: add check 7 — every `assumed` boundary in the sketch is pinned by a Slice 0 capture before any task parses it.

**`agents/code-architect.md`** (near-copy — one paragraph)

Step 3: "For deps already in the codebase, trust the existing version" → "trust it for the calls the codebase already makes; any call surface new to the codebase — new endpoint, parameter, event, or output format — is verified against current official docs, and the blueprint names the doc URL and the capture Slice 0 will produce." Lean Defaults: "reachable failures (handle, surface loudly)" → "reachable failures (propagate with raw context; catch only with a named recovery)". Consume the flow sketch when present.

**`agents/red-team.md`** (new — free)

Failure-modes angle: add "handlers that assume the error's shape; boundaries with no raw capture; catches with no named recovery" as things to hunt. Documentation-currency angle: trigger from the flow sketch's boundary list.

**`agents/plan-doc-reviewer.md`** (moderate)

Check row: **Slice 0 present** when the flow has a non-codebase boundary; **no plan vocabulary** prescribed for code or comments.

**`agents/trimmer.md`** (new — free)

Under "Schema/record richness": "instrumentation with no named reader" → "*derived* instrumentation with no named reader — raw request/response capture at an external boundary is never a cut." Add to Borderline keeps guidance: raw capture is the canonical borderline keep.

### Implementation time

**`agents/implementer.md`** (new — free)

- `tools`: add `WebFetch, WebSearch`.
- Step 2 becomes two steps: **2. Boundaries.** For each external boundary in the unit: `Skill: "praxis:observe-before-model"` — docs fetched, one real call captured, raw logging in place — before any parser or handler. Log which boundaries were observed and where the captures are. **3. TDD** — the captured fixtures are the test data.
- Step 6 self-simplify: split the comments bullet into its own item: "Comments say why, never how or how-it-came-to-be. No plan IDs, task numbers, finding references, reviewer references, 'as requested'. Acronyms only if the codebase already uses them. Delete the rest."
- Step 5 review briefing: add "comments and docs: process residue, how-not-why, plan vocabulary".
- Log: add **Boundaries observed** (boundary → docs URL → capture path → raw log location) and **Catch blocks** (each with its named recovery). "None" is valid.

**`skills/implement/SKILL.md`** (new — free)

- Phase 1: when the plan (or the task, when there's no plan) has a Slice 0, it runs first as a single `praxis:implementer`; the batch plan's integration contract is written from its captures, then the widening units dispatch in parallel. Without external boundaries, current behavior.
- Phase 2 dispatch prompt: the flow sketch, the boundary list with sources, capture paths from Slice 0.
- Phase 2: state plans-directory status (tracked / gitignored) and pass an absolute plan path when gitignored — the worktree won't contain it. (The feedback.md worktree item; it rides along because dispatch is being edited anyway.)

**`skills/iterate/SKILL.md`** (new — free)

- Triage: "Restate, in the user's terms, what done looks like for each item — one line each, inline. Without a plan file this is the only requirements record; it gates the batch."
- Route: any item that touches an external boundary → `Skill: "praxis:observe-before-model"` before its TDD or debugging route.
- "Delete diagnostics added while investigating" → "Delete the *processed* diagnostics (prints of intermediate state); the raw boundary capture stays."
- Wrap: `comment-analyzer` on the batch diff whenever the batch added or changed comments or docs, regardless of size.

**`skills/prototype/SKILL.md`** (new — free)

- 1.1 Frame: add the flow sketch (stages, boundaries, shape sources).
- 1.3 Prior art: broaden to reference implementations and documented pitfalls, not only libraries to adopt.
- Phase 4: Slice 0 is the first commit; `praxis:observe-before-model` at each boundary; the "committed end-to-end run" is on real input with raw capture in place.

### Always-on skills

**`skills/test-driven-development/SKILL.md`** (moderate)

- "Need to explore first → Fine. Throw away exploration, start with TDD." → "Need to explore first → Yes, when a boundary's shape is unobserved: spike it via `praxis:observe-before-model`. Throw away the spike's code; keep its capture as the fixture. Then TDD."
- RED requirements: "Real code (no mocks unless unavoidable)" gains "Real data: fixtures for external shapes are captures, never invented."
- REFACTOR: add "Comments: why only, domain words only, no process residue or plan pointers."

**`skills/systematic-debugging/SKILL.md`** (near-copy — two lines)

Phase 1.4: "The raw capture at each boundary is the first evidence. If a boundary has none, add it now — and keep it after the fix; only the processed diagnostics are temporary." Phase 2.2 "Compare against references": include the vendor's current docs for any boundary in the path.

**`skills/systematic-debugging/defense-in-depth.md`** (significant)

"Temporary diagnostics are temporary" → distinguish: raw boundary capture is permanent; entry/exit prints of intermediate state and environment guards are temporary.

**`skills/verification-before-completion/SKILL.md`** (near-copy — one table row, one pattern)

Table row: **Outcome delivered** | End-to-end run on real input, output shown and compared to the fixed outcome | Tests green; a mocked run. Pattern block to match.

### Review time

**`agents/silent-failure-hunter.md`** (near-copy — principles reframed, hunt list extended)

Principle 1 → "Silent failures unacceptable — and the default fix is propagation with raw context, not a better handler." Principle 2 → "A catch block earns its place with a named recovery that beats crashing; the message is secondary." Hidden-failure patterns add: handlers that parse the error's shape (`e.response.json()[...]`); boundaries with no raw capture; `except Exception` below the top level; summaries logged where the raw thing should be.

**`agents/code-reviewer.md`** (significant)

Overbuild list: "readerless instrumentation" → "readerless *derived* instrumentation". Add a **Boundaries** responsibility: raw capture present; parsers trace to a capture or docs; catches have named recoveries. Add **Comments**: process residue, how-not-why, plan vocabulary, undefined acronyms — at the same confidence bar.

**`skills/review/SKILL.md`** (moderate)

Wave 1 scaling: "`comment-analyzer` dispatches whenever the diff adds or changes comments or docs, at any unit size." Reviewer briefing: pass the flow sketch and capture paths when a plan has them.

**`agents/comment-analyzer.md`** (near-copy — one list)

Misleading elements add: plan or design-doc pointers and IDs, acronyms the codebase doesn't define, narration of how the code came to be.

### Bookkeeping

- `CLAUDE.md` conventions: one bullet — "**Observe before model:** boundary shapes come from docs + one captured real call, never memory; raw capture at boundaries is permanent and never a trim target; reachable failures propagate, catches need a named recovery; Slice 0 precedes widening. Canonical statement in `skills/observe-before-model/SKILL.md`." Agent count unchanged; skill list gains one.
- `README.md`: skills table row; Design section paragraph on the flow sketch and Slice 0; the lean-mandate paragraph gets the raw-capture carve-out.
- `upstream.json`: new skill entry (`new`); `systematic-debugging/SKILL.md` stays near-copy (two lines); `silent-failure-hunter.md` → `moderate` (principles reframed); `verification-before-completion` stays near-copy.
- Version: MINOR bump (new skill + behavior changes) — 2.2 → 2.3, both manifests.
- `plans/lean-mandate.md`: append a Resolution Log entry — the instrumentation clause over-reached; falsifier: user reports too little raw logging (2026-09-15); resolution: carve-out, recorded here.
- Commits: one per concern group — new skill; design-time; implementation-time; always-on skills; review-time; bookkeeping.

## Deliberately not changed

- **`ideate`** — already does prior art and provenance; the flow sketch is design's, not ideation's (ideation stops before structure).
- **`document`, `simplify`, `frontend-design`, `receiving-code-review`, `code-explorer`, `type-analyzer`, `test-analyzer`, `spec-reviewer`, `code-simplifier`** — no pressure toward any of the nine found. `spec-reviewer` keeps flagging a dropped guard as Missing; the orchestrator adjudicates, as today.
- **The three-part articulation** — kept as the gate on whether a failure deserves code; the fourth part applies to catch blocks only.
- **feedback.md's remaining items** — 1.2.8 "in-pattern gaps" phrasing and "Silence = confirmation", Phase 1.6 presentation format. Separate queue; only the worktree plan-path item rides along.

## Premortem

- **Ceremony on internal-only work.** A refactor with no external boundary gets asked for Slice 0 and captures it doesn't need. Mitigation: everything keys on the flow sketch's boundary sources; all-`codebase` → no Slice 0, no spike, no docs fetch. Falsifier: an implementer log showing a spike against something already exercised in the codebase.
- **Raw logging leaks secrets or floods.** Mitigation: the skill says debug level or a file, and names the one exception — redact credentials in the captured request; that's a real external constraint (PII / money), the lean mandate's own category. Falsifier: a capture with a bearer token in it.
- **Propagate-by-default crashes a long batch on item 3.** That is the named-recovery case the skill spells out (skip with raw failure recorded, exit non-zero). If Claude still crashes the batch, the skill's example was not concrete enough — revise the example, not the rule.
- **The spike exemption becomes the new skip-TDD loophole.** Bounded the same way the non-behavioral exemption was: it keys on a property of the deliverable (an unobserved external shape), the spike's code is deleted, the capture must exist as a file, and the implementer logs each boundary with its capture path — misclassification is auditable.
- **Docs fetch on every call surface is slow.** It's one WebFetch per new surface, cached by the capture; the alternative is the shape bug the user is reporting. If it's still too slow, the crux below flips.
- **Prompt bloat.** Budget: the new skill under 500 words core; one to three lines per touched file; anything larger references the skill rather than restating it.

**Cruxes.** If the shape bugs originate mostly in *reading* code (parsing responses the codebase already receives correctly elsewhere), the docs and spike edits matter less and the raw-capture and propagate edits carry the value — evidence would be captures that match what Claude assumed. If they originate in *writing* calls (wrong parameter, wrong endpoint, deprecated field), the docs edits carry it — evidence would be a capture that is an error response Claude didn't expect. My read: both, roughly evenly, and both are cheap once the flow sketch names the boundaries.

## Resolution Log

- **Implementer tool grant** (severity: Suggestion; angle: iterate)
  - Confidence: 100
  - Resolution: Fixed (scope)
  - Detail: user said "I don't really want to restrict anything"; the `tools` field is dropped from all 13 agents so each inherits every tool, which covers the planned WebFetch/WebSearch grant. Skills keep `allowed-tools`: per the Claude Code docs it pre-approves the listed tools for the invoking turn and restricts nothing.
- **Boundaries as a separate implementer step** (severity: Suggestion; angle: iterate)
  - Confidence: 85
  - Resolution: Fixed (framing)
  - Detail: folded into step 2 as "Boundaries, then TDD" rather than inserted as its own step; the audit log still names the skill, and no cross-references needed renumbering.
- **Slice 0 and spike triggers stated two ways** (severity: Important; angle: review)
  - Confidence: 85
  - Resolution: Fixed (framing)
  - Detail: "not tagged `codebase`" (design Task Structure, plan-doc-reviewer, implement) and "`docs` or `assumed`" (everywhere else) disagree on a `capture` boundary, which is already observed. Both triggers now key on `docs` or `assumed`, and the skill's step 2 skips the real call when the codebase already makes it and a capture or raw log shows the shape — the premortem's ceremony falsifier, closed at the one site every caller loads.
- **Implementer hard rule stricter than the skill** (severity: Important; angle: review)
  - Confidence: 85
  - Resolution: Fixed (scope)
  - Detail: "no capture behind it is a procedure violation, whatever the docs say" contradicted the skill's "a capture or the docs" and was not in the plan. Deleted; step 2 and the Boundaries-observed log section already enforce the discipline.
- **spec-reviewer needed the derived qualifier** (severity: Suggestion; angle: review)
  - Confidence: 80
  - Resolution: Fixed (code)
  - Detail: listed under Deliberately not changed, but its "unrequested instrumentation" Extra would flag every mandated raw log line each batch. One word added.
