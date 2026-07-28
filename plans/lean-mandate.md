# Lean Mandate — stop the design→implement pipeline from overbuilding

**Problem:** `/design` followed by `/implement` tends to way-overbuild: defensive code that
fails silently in unobservable ways, guards for states that can't occur, knobs with one
plausible value, instrumentation nobody reads. Root cause: the plan produced by Phase 3 is
treated downstream as a *contract* (spec-faithful implementer, exact-match spec-reviewer),
while nothing in the pipeline distinguishes the user's actual ask (fixed) from the plan's
operationalization of it (variable, challengeable).

**Model:** the apart-link MVP-trim brief
(`~/roost/apart-research/notes/apart-link-mvp-trim/brief.md`). Its principles, adapted:
specs are on trial, not in charge; code is a liability; crash-loud beats handle-quietly
for impossible states; a test can be behavioral and still unnecessary if the behavior it
locks is itself unnecessary.

**The unifying insight:** over-defensiveness and silent failure are the same bug.
A catch block for a state that can't occur doesn't add safety — it converts a loud crash
into quiet corruption. `silent-failure-hunter` already hunts the symptom; this change
removes the generator.

## Diagnosis — where overbuild enters

1. **No fixed-outcomes anchor.** `design` 1.2.8 restates the goal but never distills
   *what the user asked for* into a short list of fixed outcomes that the rest of the
   pipeline can trace against. The plan header has "Failure mode targeted" but nothing
   marking which requirements are the user's vs invented during design.
2. **The red-team fleet is additively biased.** Of the 5 standard angles (design SKILL
   1.5), four generate add-machinery findings (failure modes, operational, hidden
   complexity, security); none is a dedicated subtraction attacker. The red-team *agent*
   has an anti-complexity constraint on its proposed fixes, but no angle whose *findings*
   are cuts. Combined with 1.6's "silent acceptance not allowed" + iterate-until-clean,
   the resolution flow ratchets toward Fixed-by-adding.
3. **Forward-only traceability.** Self-Review checks "every requirement maps to a task";
   the 1.6 traceability check traces failure modes to closed gaps. Nothing ever runs the
   reverse direction: does every task/guard/knob/test trace to something the user asked
   for or a real external constraint?
4. **Downstream spec lock.** After Phase 3 no praxis agent is empowered to challenge the
   plan: `implementer` is "procedure-faithful… implements to spec"; `spec-reviewer`
   verifies "matches spec exactly — nothing more, nothing less" and its Anti-Scope-Creep
   paragraph *blesses* defensive additions ("sensible additions (e.g., null-check the
   spec didn't require)… don't penalize"); `plan-doc-reviewer` explicitly declares design
   critique not-its-job; `code-reviewer`'s plan mode checks compliance.
5. **`defense-in-depth.md` teaches the archetype directly.** "Validate at EVERY layer",
   "All four layers are necessary", ship debug-stack-capture logging. This is the
   guard-recursion generator the brief names ("the pins justified the check, the check
   justified the fallback…"), presented as a virtue.
6. **No agent hunts existing bloat as findings.** The per-agent Anti-Complexity blocks
   gate *proposed* additions (good foundation) but only `code-simplifier` proposes
   removals — and its "never change what the code does" rule technically forbids removing
   a dead guard (behavior on an unreachable path is still behavior, read literally).
7. **Test volume unbounded.** Phase 2 test design and `test-analyzer` are purely additive:
   coverage gaps, missing edge cases. No behavior-only rule, no proportionality (suite
   size vs risk retired), no "don't lock behavior you'd cut".
8. **TDD's mandate manufactures ceremony tests.** The Iron Law is scoped to *code*, not
   *behavior* ("NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST"; "When to Use: Always —
   new features, bug fixes, refactoring, behavior changes"; checklist: "Every new
   function/method has a test"). For a change with no behavioral surface (docs, config,
   wiring, cosmetics, constants meant to change), the only way to comply is a test
   pinning source text or code shape — it fails red trivially, greens on paste, and locks
   implementation shape as a permanent speed bump. "Refactoring" under Always is
   internally incoherent: a *new failing* test for a behavior-preserving change can only
   fail by pinning the new shape (TDD's role in refactoring is existing tests staying
   green). The rationalization table blocks every exit, so the legitimate case ("no
   behavioral contract exists") is indistinguishable from the illegitimate one ("can't be
   bothered") — agents resolve the bind via ceremony. Design's task template ("Write
   failing test for [behavior]" on every task) and `implementer` step 2 (unconditional
   TDD skill invocation) propagate the mandate to every unit.

## The shared principle (canonical block)

Inserted, compressed per file, alongside the existing Anti-Complexity blocks:

> **Fixed outcomes vs variable means.** The user's requested features/outcomes are fixed;
> all machinery delivering them is variable. Build the minimum that delivers them
> *competently* — tested, sound seams, real errors surfaced, sensible performance. The
> floor is real: don't cut tests for reachable behavior, error surfacing for reachable
> failures, or the seams extension needs.
>
> **Code is a liability.** Every guard, knob, fallback, abstraction, instrument, and test
> carries permanent comprehension + maintenance cost. A requirement that traces only to
> "the spec/design doc says so" is challengeable; one that traces to a fixed outcome or a
> real external constraint (law, data loss, PII, money) is not.
>
> **Crash-loud beats handle-quietly for impossible states.** If a state can't happen, let
> it raise. Don't catch, wrap, default, or re-validate what was validated one frame up.
> A guard for a state that cannot occur hides real failures. Defensive code needs all
> three: specific failure scenario, realistic likelihood, consequence if unhandled.

## Per-file edits

### A. Design time

**`skills/design/SKILL.md`** (significant — free to edit)

1. **Working principle at top** (after `# Design`): the canonical block, ~8 lines.
2. **1.2.8 Goal Restatement**: add — "List the **fixed outcomes**: the features/results
   the user actually asked for, stated as results, not mechanisms. These are what the
   plan must deliver. Everything else — guard density, knobs, instrumentation, schema
   richness, test volume — is means, chosen lean." (Invite correction as today.)
3. **1.3 architect dispatch**: add one line — "All three philosophies share a floor
   (competent: tested, sound seams) and a ceiling (nothing that doesn't trace to a fixed
   outcome or real constraint). Clean means better factored, not more machinery."
   Pass the fixed outcomes to each architect.
4. **1.4 synthesis**: add tie-break — "When a matrix row is close (two `✓`, or all `✓`),
   default to the leaner pick; the crux-to-flip records what would justify the heavier
   one."
5. **1.5 angle 5** becomes **Scope & minimality**: "solves stated problem? what's
   assumed? what does the design build that no fixed outcome needs — guards for
   impossible states, single-value knobs, fallbacks for committed siblings,
   instrumentation with no named reader, duplicated machinery? **Cut-proposals are
   first-class findings.**"
6. **1.6 resolution triage**: add — "A resolution of Fixed-by-adding-machinery must carry
   the three-part articulation (scenario, likelihood, consequence). Rejected-by-analysis
   is a healthy, expected outcome — the funnel is meaningful. When architects were
   unanimous on a decision a finding contests, first ask: did the finding contest the
   choice, or identify a narrow add they missed? Treat the latter as auto-resolution, not
   a new decision point." (This also addresses feedback.md's over-escalation
   observations.)
7. **Phase 2 Test Design**: add — "Behavior-only rule: keep a test only if it exercises a
   code path and asserts its output or effect. Volume proportional to the risk retired.
   A test locks behavior — don't lock implementation shape, constants meant to change, or
   behavior the plan doesn't need." Plus per-task test scoping: "Not every task has a
   behavioral surface. Tasks whose deliverable is docs, config, wiring, or cosmetics get
   a **verification line** (run it / render it / review it) instead of a manufactured
   failing test — never a test that asserts source text or code shape to satisfy the
   red-green ritual."
7b. **Task Structure template**: the TDD checklist items ("Write failing test…") apply to
   tasks with acceptance criteria phrased as behavior. For tasks without one, the
   template's checklist swaps the TDD steps for `- [ ] Verify: <command/render/check +
   expected result>`. The skill activation line becomes conditional on the task having a
   behavioral deliverable.
8. **Phase 3 Plan Header**: add `**Fixed outcomes:**` (short list, from 1.2.8).
9. **Decision Record → Scope**: add subsection **"Left out (deliberately)"** (skip if
   empty): machinery considered and not built — guard/knob/fallback/instrument — one line
   each with the trigger that would justify adding it later. Pre-empts downstream
   re-adding and makes leanness auditable rather than a silent absence.
10. **Self-Review**: add check 6 — "**Outcome trace (reverse):** every task, guard, knob,
    field, and test serves a fixed outcome or named external constraint. Anything tracing
    only to a design doc's say-so gets cut or moved to Left-out."
11. **Plan epistemic status** (one paragraph, end of Phase 3 before plan-doc-reviewer):
    "Fixed outcomes, acceptance criteria, and integration contracts are binding
    downstream. The rest of the plan is the current best operationalization —
    implementers may right-size internal machinery, logging the deviation."

**`agents/code-architect.md`** (near-copy — conservative, upstream-friendly)

Add a short **Lean defaults** section: "Distinguish reachable failures (handle, surface
loudly) from impossible states (assert / let it raise — no catch, wrap, or default). No
single-value config knobs, no speculative abstraction for callers that don't exist, no
instrumentation without a named reader. Every guard in the blueprint carries its
three-part articulation." Reframe the "Critical Details: error handling" bullet
accordingly.

**`agents/red-team.md`** (new — free)

- Elevate over-engineering from a sub-bullet of step 3 to symmetric standing: "Findings
  that propose *removal* are first-class — 'nothing requires X; cut it' with confidence,
  same rigor as additions."
- Constrain step 4 "Missing pieces": each checklist item (error strategy, migration,
  backcompat, observability) is only *missing* if a stated outcome or real constraint
  needs it — the checklist is a prompt, not a quota.

**`agents/plan-doc-reviewer.md`** (moderate)

Add check row — "**Outcome trace**: every task serves a stated outcome or named
constraint; flag machinery that traces only to spec self-citation (impossible-state
guards, single-value knobs, readerless instrumentation)." Calibration note: an
over-specified plan is a real implementation problem — the implementer will faithfully
build the bloat.

### B. Implement time

**`agents/implementer.md`** (new — free)

- Add **Plan epistemic status** (in Invocation Context or step 2): "The plan
  operationalizes the user's fixed outcomes. Acceptance criteria and integration
  contracts are binding — never unilaterally droppable. Internal machinery (guards,
  knobs, fallbacks, instrumentation) is yours to right-size: if a planned guard protects
  a state that can't occur, build the lean version and log the deviation with reasoning.
  Never silently drop; never silently gold-plate."
- Step 2 scoping: "TDD applies to the unit's behavioral deliverables. For parts with no
  behavioral contract (docs, config, wiring, cosmetics), don't manufacture a test that
  pins source text or shape — verify by running/rendering (step 4 covers the evidence).
  Log which parts you classified as non-behavioral and why."
- Step 6 self-simplify additions: "Remove guards for states that can't occur
  (crash-loud); broad catches → specific, or delete and let it raise; no single-value
  config knobs; no process-residue comments (narrating how the code came to be, reviewer
  references, 'as requested')."

**`skills/implement/SKILL.md`** (new — free)

- Phase 2 dispatch prompt: include the plan's fixed outcomes + the epistemic-status line.
- Phase 4 step 4 (spec-reviewer plan-completion): "Gaps matching a worker-logged lean-out
  deviation are adjudicated against fixed outcomes — not auto-restored."

### C. Review time

**`agents/code-reviewer.md`** (significant)

- Responsibilities add: "**Overbuild**: guards for impossible states, catch-and-continue,
  fallbacks masking failures, single-value knobs, speculative abstraction, readerless
  instrumentation, process-residue comments — defects at the same confidence bar as
  bugs."
- Plan mode: "A logged lean-out that keeps acceptance criteria green is a justified
  deviation; judge it on the three-part test, not literal compliance."

**`agents/spec-reviewer.md`** (moderate)

Rewrite Anti-Scope-Creep: "Additions the code clearly needs (null-check on genuinely
nullable external input) aren't extras. Defensive machinery *is*: impossible-state
guards, catch-and-continue, fallbacks, knobs, unrequested instrumentation — flag as Extra
even when well-intentioned. Over-delivery is a spec deviation too." Keep the
compliance-verifier role otherwise; orchestrator adjudicates.

**`agents/silent-failure-hunter.md`** (near-copy — one line)

Under Anti-Complexity: "For a state that can't occur, the preferred fix is deleting the
handler and letting it raise — recommend removal over better logging."

**`agents/test-analyzer.md`** (near-copy — one clause)

Under Test quality: "Also flag over-testing: assertions that fire only when someone
deliberately, correctly changes something (speed bumps, not tests) — verbatim content
pins, implementation-shape assertions — and suites disproportionate to the risk they
retire."

**`agents/code-simplifier.md`** (near-copy — conservative)

- Enhance-clarity list add: "Remove guards for unreachable states and handling for errors
  that can't occur (crash-loud); remove process-residue comments."
- Calibration: "In advisory mode, propose such removals freely. In direct-edit mode,
  remove only when unreachability is provable (validated one frame up, type-guaranteed,
  or caller-audited); otherwise propose."

### D. Reference material

**`skills/systematic-debugging/defense-in-depth.md`** (near-copy → bump to
`significant`; recommended over a calibration-header contradiction)

Rewrite from "validate at EVERY layer / all four layers are necessary" to **"where to
validate vs assert"**:
- External/untrusted boundary → validate (real inputs go wrong).
- Internal invariant → assert, crash-loud, once, where it's relied on. Re-validating what
  was validated one frame up hides real failures and invites the guard-recursion spiral.
- Environment guards + debug instrumentation → *temporary diagnostics during the fix*;
  after root cause is fixed, remove them or demote to the bug's regression test.
- Permanent multi-layer validation only when layers genuinely see different callers or
  inputs, each layer justified by the three-part rule.

Update the pointer line in `systematic-debugging/SKILL.md` ("add validation at multiple
layers" → "where to validate vs assert after finding root cause").

**`skills/test-driven-development/SKILL.md`** (near-copy → bump to `moderate`; the
scope correction is the point)

Re-scope the mandate from *code* to *behavior* without reopening the skip-TDD loophole:

- **Iron Law** becomes "NO NEW BEHAVIOR WITHOUT A FAILING TEST FIRST". Companion rule:
  "The question is never whether testing is worth the effort (it is); it's whether a
  behavioral contract exists to test. If one does: TDD, no exceptions. If none does, a
  test could only pin source text or code shape — don't write it; verify by
  running/rendering instead."
- **Gate before writing the test**: "Name the behavior — inputs/state → observable
  output/effect — phrased without reference to the code's text or structure. Can't
  phrase it that way? There is no test to write here." Output text can be behavior
  (error messages, rendered templates, CLI output are contracts); *source* text never
  is. Prefer asserting the property of the output that matters over byte-pinning whole
  outputs, unless exact bytes are the contract (golden files).
- **Fix the Refactoring entry**: TDD's role in behavior-preserving change is *existing
  tests stay green* — never a new failing test (one can only fail by pinning the new
  shape). "Refactoring" moves out of the Always list into its own line saying exactly
  that.
- **Keep the rationalization table intact** — it's load-bearing against real
  rationalization. Add one row distinguishing the legitimate exit: "'No behavior here'
  (docs/config/cosmetics) → Legitimate ONLY if you can't phrase the deliverable as
  inputs → observable effect. That's a property of the deliverable, not of your effort
  budget. 'Too simple to test' is still not this."
- **Checklist**: "Every new function/method has a test" → "Every new behavior has a
  test; anything exempted is named as non-behavioral with the reason."

**`skills/test-driven-development/testing-anti-patterns.md`** (near-copy — additive,
upstream-friendly)

Append **Anti-Pattern 6: Speed-Bump Tests** — asserting source text, implementation
shape, or constants meant to change: "if an assertion fires only because someone
deliberately, correctly changed something, it is a speed bump, not a test." Includes
**manufactured red**: writing a text/shape assertion solely to have a failing test to
watch fail — the red-green ritual proves a test tests *something*; a test that can only
fail via text diff proves nothing about behavior. Narrow keep exception: a literal pin
whose silent change destroys or orphans data.

**`CLAUDE.md`** (praxis)

Conventions bullet so future edits stay aligned: "**Lean mandate:** user-stated outcomes
are fixed, machinery is variable; minimum competent implementation; crash-loud for
impossible states; defensive code needs scenario/likelihood/consequence; cut-proposals
are first-class findings. The canonical statement lives in `skills/design/SKILL.md`."

## Deliberately not changed

- **`prototype`** — already the exemplar (thin slice, no speculative abstraction,
  crash-loud-adjacent premortem). No edits.
- **`ideate`, `review`, `ship`, `receiving-code-review`,
  `verification-before-completion`** — no overbuild pressure found. (TDD's GREEN step
  already teaches minimal code + YAGNI; the problem addressed above is its mandate's
  scope, not its cycle.)
- **Design 1.2 exploration dimensions** — knowing existing constraints (incl.
  observability) is fine; the problem is generating new machinery, not surveying.
- **feedback.md's other items** (Phase 1.6 presentation format, silence=confirmation,
  worktree plan-path, implementer Agent-tool note) — separate queue; only the
  resolution-triage item rides along here (edit A.6) because it is overbuild-adjacent
  and already user-validated.

## Premortem

- **Overcorrection: agents flag legitimate error handling for removal.** Mitigation: the
  three-part rule cuts both ways (removal of a *reachable* failure's handler fails the
  test); silent-failure-hunter stays as counterweight; code-simplifier's direct-edit mode
  requires provable unreachability. Falsifier to watch: a lean-out deviation that later
  surfaces as a real unhandled failure.
- **Lean-out license abused to skip real spec items.** Bounded: acceptance criteria +
  integration contracts stay binding; lean-outs must be logged; Phase 4 adjudicates.
- **The behavioral-contract exemption becomes the new skip-TDD loophole.** Mitigations:
  the exemption keys on a property of the *deliverable* (can the contract be phrased as
  inputs → observable effect?), never on effort; the rationalization table stays intact
  with the distinction added as a row; implementer must log what it classified as
  non-behavioral and why, so misclassification is auditable at Phase 4. Falsifier: a
  logged "non-behavioral" part that later breaks in a way a behavioral test would have
  caught.
- **Upstream sync friction** on the near-copy edits. The silent-failure-hunter /
  test-analyzer / code-simplifier / testing-anti-patterns edits are small and
  upstream-plausible; defense-in-depth and TDD SKILL.md get explicit adaptation bumps in
  `upstream.json`, which is exactly what that field is for.
- **Prompt bloat irony.** Budget: ~8 lines for the design-skill principle, 1–4 lines per
  agent. If an insertion can't stay in that budget, it should reference, not restate.

**Cruxes:** if overbuild in practice originates mostly at *implementation* time (agents
adding unrequested guards not present in plans), the design-side edits matter less and
C-section review edits matter more — evidence would be lean plans producing bloated
diffs. My read of the pipeline says the plan is the main vector (implementer is
procedure-faithful by design), so A + B carry most of the value; C makes the net catch
what slips through.

## Bookkeeping

- Version: MINOR bump (behavior changes across skills/agents), both
  `.claude-plugin/plugin.json` and `marketplace.json`; hook adds patch on top.
- `upstream.json`: bump `defense-in-depth.md` to `significant` and
  `test-driven-development/SKILL.md` to `moderate`; others unchanged (edits stay within
  near-copy tolerance).
- Commits: one per concern group (design-time, implement-time, review-agents,
  reference-material, bookkeeping), per the small-semantic-commits convention.
