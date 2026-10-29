<!-- Claude Code built-in skill `code-review`, extracted from the binary: the string and template literals of its prompt code in source order, escapes decoded. In `${...}` interpolations minified identifiers are shown as `_`. -->

<!-- literal -->
## Phase 0 — Gather the diff

Run `git diff @{upstream}...HEAD` (or `git diff main...HEAD` / `git diff HEAD~1`
if there's no upstream) to get the unified diff under review. If there are
uncommitted changes, or the range diff is empty, also run `git diff HEAD` and
include the working-tree changes in scope — the review often runs before the
commit. If a PR number, branch name, or file path was passed as an argument,
review that target instead. Treat this diff as the review scope.


<!-- literal -->
Flag new code that re-implements something the codebase
already has — Grep shared/utility modules and files adjacent to the change,
and name the existing helper to call instead.


<!-- literal -->
### Simplification

Flag unnecessary complexity the diff adds: redundant or derivable state,
copy-paste with slight variation, deep nesting, dead code left behind. Name
the simpler form that does the same job.


<!-- literal -->
### Efficiency

Flag wasted work the diff introduces: redundant computation or repeated I/O,
independent operations run sequentially, blocking work added to startup or
hot paths. Also flag long-lived objects built from closures or captured
environments — they keep the entire enclosing scope alive for the object's
lifetime (a memory leak when that scope holds large values); prefer a
class/struct that copies only the fields it needs. Name the cheaper
alternative.


<!-- literal -->
### Conventions (CLAUDE.md)

Find the CLAUDE.md files that govern the changed code: the user-level
~/.claude/CLAUDE.md, the repo-root CLAUDE.md, plus any CLAUDE.md or
CLAUDE.local.md in a directory that is an ancestor of a changed file (a
directory's CLAUDE.md only applies to files at or below it). Read each one
that exists, then check the diff for clear violations of the rules they state.

Only flag a violation when you can quote the exact rule and the exact line
that breaks it — no style preferences, no vague "spirit of the doc"
inferences. In the finding, name the CLAUDE.md path and quote the rule so the
report can cite it. If no CLAUDE.md applies, return nothing for this angle.


<!-- literal -->
### Altitude

Check that each change fixes the root cause at the right depth rather than
patching a symptom with a fragile bandaid. Special cases layered on shared
infrastructure are a sign the fix isn't deep enough — prefer the simpler, more
general change to the underlying mechanism over adding special cases, and name
that change.


<!-- literal -->
### Angle A — line-by-line diff scan

Read every hunk in the diff, line by line. Then Read the enclosing function for
each hunk — bugs in unchanged lines of a touched function are in scope (the PR
re-exposes or fails to fix them). For every line ask: what input, state, timing,
or platform makes this line wrong? Look for inverted/wrong conditions,
off-by-one, null/undefined deref, missing `await`, falsy-zero checks,
wrong-variable copy-paste, error swallowed in catch, unescaped regex metachars.


<!-- literal -->
### Angle B — removed-behavior auditor

For every line the diff DELETES or replaces, name the invariant or behavior it
enforced, then search the new code for where that invariant is re-established.
If you can't find it, that's a candidate: a removed guard, a dropped error
path, a narrowed validation, a deleted test that was covering a real case.


<!-- literal -->
### Angle C — cross-file tracer

For each function the diff changes, find its callers (Grep for the symbol) and
check whether the change breaks any call site: a new precondition, a changed
return shape, a new exception, a timing/ordering dependency. Also check callees:
does a parallel change in the same PR make a call unsafe?


<!-- literal -->
### Angle D — language-pitfall specialist

Scan for the classic pitfalls of the diff's language/framework — for example:
JS falsy-zero, `==` coercion, closure-captured loop var; Python mutable default
args, late-binding closures; Go nil-map write, range-var capture; SQL injection;
timezone/DST drift; float equality. Flag any instance the diff introduces.


<!-- literal -->
### Angle E — wrapper/proxy correctness

When the PR adds or modifies a type that wraps another (cache, proxy, decorator,
adapter): check that every method routes to the wrapped instance and not back
through a registry/session/global — e.g. a caching provider holding a
`delegate` field that resolves IDs via `session.get(...)` instead of
`delegate.get(...)` will re-enter the cache or recurse. Also check that the
wrapper forwards all the methods the callers actually use.


<!-- literal -->
If the Agent tool is not available in your current tool set, do not error — perform each angle (and each verification) yourself, sequentially, in this context.

<!-- literal -->
### Reuse

The angles above hunt for bugs; this one and the next two hunt for cleanup in
the changed code. ${_}

<!-- literal -->
Cleanup, altitude, and conventions candidates use the same
`file`/`line`/`summary` shape; in `failure_scenario`, state the concrete
cost (what is duplicated, wasted, harder to maintain, or which CLAUDE.md rule
is broken) instead of a crash. Correctness bugs always outrank cleanup,
altitude, and conventions findings when the output cap forces a cut.


<!-- literal -->
- **CONFIRMED** — can name the inputs/state that trigger it and the wrong
  output or crash. Quote the line.
- **PLAUSIBLE** — mechanism is real, trigger is uncertain (timing, env,
  config). State what would confirm it.
- **REFUTED** — factually wrong (code doesn't say that) or guarded elsewhere.
  Quote the line that proves it.

<!-- literal -->
**PLAUSIBLE by default** — do not refute a candidate for being "speculative" or
"depends on runtime state" when the state is realistic: concurrency races,
nil/undefined on a rare-but-reachable path (error handler, cold cache, missing
optional field), falsy-zero treated as missing, off-by-one on a boundary the
code does not exclude, retry storms / partial failures, regex/allowlist that
lost an anchor. These are PLAUSIBLE.

**REFUTED** only when constructible from the code: factually wrong (quote the
actual line); provably impossible (type/constant/invariant — show it); already
handled in this diff (cite the guard); or pure style with no observable effect.

<!-- literal -->
## Phase 2 — Verify (1-vote, 3-state)

Dedup candidates that point at the same line/mechanism, keeping the one with
the most concrete failure scenario. For each remaining candidate, run **one
verifier** via the Agent tool: give it the diff, the relevant
file(s), and the candidate, and have it return exactly one of:

${_}

Keep candidates where the vote is CONFIRMED or PLAUSIBLE.


<!-- literal -->
## Phase 2 — Verify (1-vote, recall-biased)

Dedup near-duplicates (same defect, same location, same reason → keep one). For
each remaining candidate, run **one verifier** via the Agent tool:
give it the diff, the relevant file(s), and the candidate; it returns exactly
one of **CONFIRMED / PLAUSIBLE / REFUTED**.

${_}

Keep **CONFIRMED and PLAUSIBLE**. Drop REFUTED.


<!-- literal -->
moved/extracted code that dropped a guard
or anchor; second-tier footguns (dataclass default evaluated once, `hash()`
non-determinism, lock-scope shrink, predicate methods with side effects);
setup/teardown asymmetry in tests; config defaults flipped.

<!-- literal -->
## Phase 3 — Sweep for gaps

Run **one more finder** as a fresh reviewer who has the verified list. Re-read
the diff and enclosing functions looking ONLY for defects not already listed.
Do not re-derive or re-confirm anything already there — the job is gaps. Focus
on what the first pass tends to miss: ${_}

Surface **up to 8 additional candidates**, each naming a defect not already on
the list. If nothing new, return an empty sweep — do not pad.


<!-- literal -->
## Output

Return findings as a JSON array ${_==="all"?"with one object for every finding that survives, no maximum":`of at most ${_} ${_(_,"object")}`}:

```json
[
  {
    "file": "path/to/file.ext",
    "line": 123,
    "summary": "one-sentence statement of the bug",
    "failure_scenario": "concrete inputs/state → wrong output/crash"
  }
]
```

Ranked most-severe first. ${_==="all"?"Keep every finding that survives. There is no maximum.":`If more than ${_} survive, keep the ${_} most
severe.`} If nothing survives verification, return `[]`. Do not call the
ReportFindings tool even if it is available - this review's
output contract is the JSON block above.


<!-- literal -->
## Output

Call the ReportFindings tool once to report this review's results
with `{level, findings}`. `findings` is ${_==="all"?"every finding that survives, no maximum,":`at most ${_} ${_(_,"entry","entries")}`} ranked
most-severe first; each entry has `file`, `line`, `summary`,
`short_summary` — the claim compressed to ≤60 characters, no rationale
or consequence clause — `failure_scenario`, and `category` — a short kebab-case slug for the angle
that produced it (`correctness`, `simplification`, `efficiency`,
`reuse`, `altitude`, `conventions`, or a more specific slug like
`test-coverage` when one fits better) — plus `verdict` when a verify pass
produced one. ${_==="all"?"Keep every finding that survives. There is no maximum.":`If more than ${_} survive, keep the ${_} most severe.`} If
nothing survives verification, call it with an empty array. Do not also print
the findings as text, and do not create or publish an artifact of the review -
the tool call is the report.


<!-- literal -->
`low effort → 1 diff pass → no verify → ${_(_)}`

## Turn 1 — read

One tool call: read the unified diff (`git diff @{upstream}...HEAD; git diff HEAD`
to cover both committed and uncommitted changes, or `git diff main...HEAD` /
the target passed as an argument). Skip test/fixture
hunks (`test/`, `spec/`, `__tests__/`, `*_test.*`, `*.test.*`,
`fixtures/`, `testdata/`) — test-file changes are not reviewed at this level.
No subagents, no full-file reads.

## Turn 2 — findings

Flag runtime-correctness bugs visible from the hunk alone: inverted/wrong
condition, off-by-one, null/undefined deref where adjacent lines show the value
can be absent, removed guard, falsy-zero check, missing `await`,
wrong-variable copy-paste, error swallowed in a catch that should propagate.
Also flag — still from the hunk alone — new code that duplicates an existing
helper visible in the diff context, and dead code the diff leaves behind.

Do **not** flag style, naming, perf, missing tests, or anything outside the
hunk.

${_?`Report ${_(_)}, most-severe first, in one
ReportFindings call with `{level, findings}` — each entry has
`file`, `line`, `summary`, `short_summary` (≤60 characters), and
`failure_scenario`. If nothing qualifies, call it with an empty findings
array. Do not also print the findings as text.
`:`Output ${_(_)}, most-severe first, one line each:
`path/to/file.ext:123 — what's wrong and the concrete failure`. If nothing
qualifies, output exactly `(none)`. Do not call the
ReportFindings tool even if it is available.
`}

<!-- literal -->
`low effort → 1 diff pass → no verify → ≥min(files,4) findings`

## Turn 1 — read

One tool call: read the unified diff (`git diff @{upstream}...HEAD; git diff HEAD`
to cover both committed and uncommitted changes, or `git diff main...HEAD` /
the target passed as an argument). Skip test/fixture
hunks (`test/`, `spec/`, `__tests__/`, `*_test.*`, `*.test.*`,
`fixtures/`, `testdata/`) — test-file changes are not reviewed at this level.
No subagents, no full-file reads.

## Turn 2 — findings

Flag runtime-correctness bugs visible from the hunk alone: inverted/wrong
condition, off-by-one, null/undefined deref where adjacent lines show the value
can be absent, removed guard, falsy-zero check, missing `await`,
wrong-variable copy-paste, error swallowed in a catch that should propagate.
Also flag — still from the hunk alone — new code that duplicates an existing
helper visible in the diff context, and dead code the diff leaves behind.

Do **not** flag style, naming, perf, missing tests, or anything outside the
hunk.

${_?`Target **min(files_changed, 4) findings**, most-severe first, reported
in one ReportFindings call with `{level, findings}` — each
entry has `file`, `line`, `summary`, `short_summary` (≤60 characters),
and `failure_scenario`. If you have fewer, do one more pass focused on the
largest changed file and on any **removed** code blocks. Call it with an
empty findings array only if the diff is trivially correct after that pass.
Do not also print the findings as text.
`:`Target **min(files_changed, 4) findings**, most-severe first, one
line each: `path/to/file.ext:123 — what's wrong and the concrete failure`.
If you have fewer, do one more pass focused on the largest changed file
and on any **removed** code blocks. Output `(none)` only if the diff is
trivially correct after that pass.
`}

<!-- literal -->
The Agent tool isn't available in this context, so the usual
multi-agent fan-out and subagent verify pass can't run. Work through every
angle below yourself, in this same context, in one pass — do not skip angles
for lack of fan-out. Re-check each candidate against the diff before keeping
it; drop anything you can't back up with a concrete failure scenario.


<!-- literal -->

State clearly in your summary that this was a single-pass review done without
the Agent tool, not the full multi-agent fan-out, so whoever reads
it isn't misled about what actually ran.


<!-- literal -->

## Phase 3 — Sweep for gaps

Take one more pass yourself (same context, no subagent) as a fresh reviewer
who has the deduplicated list. Re-read the diff and enclosing functions
looking ONLY for defects not already listed: ${_}


<!-- literal -->
`${_}`

${_}

${_}
${_}## Phase 1 — Find candidates (${_} angles, single pass)

Work through **${_} angles** yourself, in sequence, in this same
context — do not spawn subagents. Each surfaces candidate findings with
`file`, `line`, a one-line `summary`, and a concrete `failure_scenario`.

${_}
${_}
## Phase 2 — Dedup and self-check (no subagent verify)

Dedup near-duplicates (same defect, same location, same reason → keep one).
Re-check each remaining candidate yourself against the diff before keeping it.
${_}
${_(_)}${_}

<!-- literal -->
medium effort → Agent tool unavailable → single-pass inline → ${_(_)}

<!-- literal -->
You are reviewing for **precision** at medium effort: every finding you surface
should be one a maintainer would act on.

<!-- literal -->
`medium effort → 3+5 angles × 6 candidates → 1-vote verify → ${_(_)}`

You are reviewing for **precision** at medium effort: every finding you surface
should be one a maintainer would act on.

${_}
## Phase 1 — Find candidates (3 correctness angles + 3 cleanup angles + 1 altitude angle + 1 conventions angle, up to 6 each)

Run **8 independent finder angles** via the Agent tool. Each
surfaces **up to 6 candidate findings** with `file`, `line`, a one-line
`summary`, and a concrete `failure_scenario`. ${_}

${_}
${_}
Pass every candidate with a nameable failure scenario through — finders that
silently drop half-believed candidates bypass the verify step and are the
dominant cause of misses.

${_}
${_(_)}

<!-- literal -->
high effort → Agent tool unavailable → single-pass inline → ${_(_)}

<!-- literal -->
You are reviewing for **recall** at high effort: catch every real bug a careful
reviewer would catch in one sitting. At this level, catching real bugs matters
more than avoiding false positives. Err on the side of surfacing.

<!-- literal -->
`high effort → 3+5 angles × 6 candidates → 1-vote verify (recall-biased) → ${_(_)}`

You are reviewing for **recall** at high effort: catch every real bug a careful
reviewer would catch in one sitting. At this level, catching real bugs matters
more than avoiding false positives. Err on the side of surfacing.

${_}
## Phase 1 — Find candidates (3 correctness angles + 3 cleanup angles + 1 altitude angle + 1 conventions angle, up to 6 each)

Run **8 independent finder angles** via the Agent tool. Each
surfaces **up to 6 candidate findings** with `file`, `line`, a one-line
`summary`, and a concrete `failure_scenario`. ${_}

${_}
${_}
Pass every candidate with a nameable failure scenario through — finders that
silently drop half-believed candidates bypass the verify step and are the
dominant cause of misses.

${_}
${_(_)}

<!-- literal -->
${_} effort → Agent tool unavailable → single-pass inline → ${_(_)}

<!-- literal -->
You are reviewing for **recall** at ${_==="max"?"maximum":"extra-high"} effort: catch every real bug. At
this level, catching real bugs matters more than avoiding false positives — a
missed bug ships. Err on the side of surfacing.

<!-- literal -->
`${_} effort → 5+5 angles × 8 candidates → 1-vote verify → sweep → ${_(_)}`

You are reviewing for **recall** at ${_==="max"?"maximum":"extra-high"} effort: catch every real bug. At
this level, catching real bugs matters more than avoiding false positives — a
missed bug ships. Err on the side of surfacing.

${_}
## Phase 1 — Find candidates (5 correctness angles + 3 cleanup angles + 1 altitude angle + 1 conventions angle, up to 8 each)

Run **10 independent finder angles** via the Agent tool. Each
surfaces **up to 8 candidate findings**. Do NOT let one angle's conclusions
suppress another's — if two angles flag the same line for different reasons,
record both. ${_}

${_}
${_}
${_}
This is recall mode — a single non-REFUTED vote carries the finding. Do NOT
drop on uncertainty.

${_}
${_(_)}

<!-- literal -->
### Reuse

The angles above hunt for bugs; this one and the next two hunt for cleanup in
the changed code. Flag new code that re-implements something the codebase
already has — Grep shared/utility modules and files adjacent to the change,
and name the existing helper to call instead.


<!-- literal -->
`low effort → 1 diff pass → no verify → ${_(_)}`

## Turn 1 — read

One tool call: read the unified diff (`git diff @{upstream}...HEAD; git diff HEAD`
to cover both committed and uncommitted changes, or `git diff main...HEAD` /
the target passed as an argument). No subagents, no full-file reads.

## Turn 2 — findings

Flag runtime-correctness bugs visible from the hunk alone: inverted/wrong
condition, off-by-one, null/undefined deref where adjacent lines show the value
can be absent, removed guard, falsy-zero check, missing `await`,
wrong-variable copy-paste, error swallowed in a catch that should propagate.
Also flag — still from the hunk alone — new code that duplicates an existing
helper visible in the diff context, and dead code the diff leaves behind.

Do **not** flag style, naming, perf, missing tests, or anything outside the
hunk.

${_?`Report ${_(_)}, most-severe first, in one
ReportFindings call with `{level, findings}` — each entry has
`file`, `line`, `summary`, `short_summary` (≤60 characters), and
`failure_scenario`.
Target at least min(files_changed, ${_}) findings — if you see fewer, widen to other hunks in the same diff before stopping. If fewer than ${_} genuine findings exist, report what you have. Do not also print the findings as text.
`:`Output ${_(_)}, most-severe first, one line each:
`path/to/file.ext:123 — what's wrong and the concrete failure`.
Target at least min(files_changed, ${_}) findings — if you see fewer, widen to other hunks in the same diff before stopping. If fewer than ${_} genuine findings exist, emit what you have.
`}

<!-- literal -->
## Output

Target **at least ${_} ${_(_,"finding")}**. If fewer genuine findings exist, emit what you have — do not invent to hit the floor.


<!-- literal -->
### Angle A — line-by-line diff scan

Read every hunk in the diff, line by line. Then Read the enclosing function for
each hunk — bugs in unchanged lines of a touched function are in scope (the PR
re-exposes or fails to fix them). For every line ask: what input, state, timing,
or platform makes this line wrong? Look for inverted/wrong conditions,
off-by-one, null/undefined deref, missing `await`, falsy-zero checks,
wrong-variable copy-paste, error swallowed in catch, unescaped regex metachars.

### Angle B — removed-behavior auditor

For every line the diff DELETES or replaces, name the invariant or behavior it
enforced, then search the new code for where that invariant is re-established.
If you can't find it, that's a candidate: a removed guard, a dropped error
path, a narrowed validation, a deleted test that was covering a real case.

### Angle C — cross-file tracer

For each function the diff changes, find its callers (Grep for the symbol) and
check whether the change breaks any call site: a new precondition, a changed
return shape, a new exception, a timing/ordering dependency. Also check callees:
does a parallel change in the same PR make a call unsafe?


<!-- literal -->
`${_} → ${_(_)}`

${_}

${_}
## Phase 1 — Find candidates (3 correctness angles + 3 cleanup angles + 1 altitude angle + 1 conventions angle, up to 6 each)

Run **8 independent finder angles** in sequence yourself, in THIS context — do NOT spawn subagents for them. Each
surfaces **up to 6 candidate findings** with `file`, `line`, a one-line
`summary`, and a concrete `failure_scenario`.

${_}
${_}
${_}
${_}
${_}
${_}
${_}
Pass every candidate with a nameable failure scenario through — finders that
silently drop half-believed candidates are the dominant cause of misses.

## Phase 2 — Dedup only (no verify)

Pool all candidates. Dedup near-duplicates only (same defect, same location, same reason → keep one). Do NOT run verifiers; do NOT re-judge. Sort by severity.

${_(_,_)(_)}

<!-- literal -->
medium effort → 8 inline angles → dedup (no verify)

<!-- literal -->
You are reviewing for **correctness bugs**: surface every plausible bug. At this
level, catching real bugs matters more than avoiding false positives — err on
the side of surfacing.

<!-- literal -->
high effort → 8 inline angles → dedup (no verify)

<!-- literal -->
You are reviewing for **recall** at high effort: catch every real bug a careful
reviewer would catch in one sitting. At this level, catching real bugs matters
more than avoiding false positives. Err on the side of surfacing.

<!-- literal -->
`xhigh effort → 10 inline angles → dedup (no verify) → sweep → ${_(_)}`

You are reviewing for **recall** at extra-high effort: catch every real bug. At
this level, catching real bugs matters more than avoiding false positives — a
missed bug ships. Err on the side of surfacing.

${_}
## Phase 1 — Find candidates (5 correctness angles + 3 cleanup angles + 1 altitude angle + 1 conventions angle, up to 8 each)

Run **10 independent finder angles** in sequence yourself, in THIS context — do NOT spawn subagents for them. Each
surfaces **up to 8 candidate findings**. Do NOT let one angle's conclusions
suppress another's — if two angles flag the same line for different reasons,
record both.

${_}
### Angle D — language-pitfall specialist

Scan for the classic pitfalls of the diff's language/framework — for example:
JS falsy-zero, `==` coercion, closure-captured loop var; Python mutable default
args, late-binding closures; Go nil-map write, range-var capture; SQL injection;
timezone/DST drift; float equality. Flag any instance the diff introduces.

### Angle E — wrapper/proxy correctness

When the PR adds or modifies a type that wraps another (cache, proxy, decorator,
adapter): check that every method routes to the wrapped instance and not back
through a registry/session/global — e.g. a caching provider holding a
`delegate` field that resolves IDs via `session.get(...)` instead of
`delegate.get(...)` will re-enter the cache or recurse. Also check that the
wrapper forwards all the methods the callers actually use.

${_}
${_}
${_}
${_}
${_}
${_}
## Phase 2 — Dedup only (no verify)

Pool all candidates. Dedup near-duplicates only (same defect, same location, same reason → keep one). Do NOT run verifiers; do NOT re-judge. Sort by severity. Do NOT drop on uncertainty.

## Phase 3 — Sweep for gaps

Take one more pass (same context — no subagent) as a fresh reviewer who has the deduplicated list. Re-read
the diff and enclosing functions looking ONLY for defects not already listed.
Do not re-derive or re-confirm anything already there — the job is gaps. Focus
on what the first pass tends to miss: moved/extracted code that dropped a guard
or anchor; second-tier footguns (dataclass default evaluated once, `hash()`
non-determinism, lock-scope shrink, predicate methods with side effects);
setup/teardown asymmetry in tests; config defaults flipped.

Surface **up to 8 additional candidates**, each naming a defect not already on
the list. If nothing new, return nothing from this phase — do not pad.

${_(_,15)(_)}

<!-- literal -->
`minimal prompt → single careful diff pass → ${_(_)}`

You are reviewing a pull request for real bugs. Run `git diff @{upstream}...HEAD` (or `git diff main...HEAD` / `git diff HEAD~1`
if there's no upstream) to get the unified diff under review. If there are
uncommitted changes, or the range diff is empty, also run `git diff HEAD` and
include the working-tree changes in scope — the review often runs before the
commit. If a PR number, branch name, or file path was passed as an argument,
review that target instead. Treat this diff as the review scope.

Review the diff as a careful senior engineer would: read every hunk, open the surrounding files for context as needed (Read, Grep, git log/blame/show), and hunt for correctness issues — wrong or inverted conditions, off-by-one, null/undefined dereference, missing `await`, dropped error handling, removed guards or validations, broken callers of changed functions, races. Prefer real failure modes over style; every finding needs a concrete scenario in which the code misbehaves.

When you are done, submit ${_==="all"?"every finding":`at most ${_} ${_(_,"finding")}`} via the ReportFindings tool, filling its fields as defined — for each: the file path and start line, a severity, and a comment that states the issue and the concrete scenario in which the code misbehaves. Quality over quantity: include everything you genuinely believe is a real issue, and nothing you don't.

After the tool call, also restate the findings in your final reply — one line each, `file:line — summary` — so they stay visible in sessions that do not render tool output.


<!-- literal -->


## Posting to GitHub (--comment)

The `--comment` flag was passed. After producing the findings list, if the
review target is a GitHub PR, post each finding as an inline PR comment via
`mcp__github_inline_comment__create_inline_comment` (one call per finding;
include a suggestion block only when it fully fixes the issue). If that tool
is not available in this session, fall back to `gh api` (repos/{owner}/{repo}/pulls/{pr}/comments)
or print the findings instead. If the target is not a PR, print the findings
to the terminal and note that `--comment` was ignored.


<!-- literal -->


## Posting to GitLab (--comment)

The `--comment` flag was passed. After producing the findings list, if the
review target is a GitLab merge request, post the findings as one general MR
note via `${`glab mr note${_?` ${_}`:""}${_} -m "<body>"`}`${_?"":" from inside that project's checkout"}
(every finding with its file:line, the issue, and the suggested fix). glab has no single verb for line-anchored
comments; those require `glab api projects/:id/merge_requests/:iid/discussions`,
so post the general note unless the user asks for inline threads. If glab is
not available in this session, print the findings instead. If the target is
not an MR, print the findings to the terminal and note that `--comment` was
ignored.


<!-- literal -->
call ReportFindings again with the same findings, each
carrying an `outcome`: `fixed`, `no_change_needed` (the finding was wrong or
already handled), or `skipped` (real but not applied). Do not repeat the
findings as text

<!-- literal -->


## If findings are fixed later

Whenever reported findings get fixed later in this session - the user asks you
to fix them, or later work fixes them incidentally - you MUST ${_}.
Make that call immediately after the fixes land, before any prose summary; the
host UI's per-finding status updates only from it, and without it the findings
stay marked unresolved.


<!-- literal -->


## Applying fixes (--fix)

The `--fix` flag was passed. After producing the findings list, apply the
findings to the working tree instead of stopping at the report: fix each one
directly — correctness bugs and reuse/simplification/efficiency cleanups alike.
Skip any finding whose fix would change intended behavior, require changes well
outside the reviewed diff, or that you judge to be a false positive — note the
skip rather than arguing with it. ${_?`Then ${_}; after the call, give one line per skipped finding saying why.`:`Finish with a brief summary of what was fixed
and what was skipped.`}


<!-- literal -->


## After the review

After the findings are reported (and applied, when --fix was passed): if `/verify` has not run this session and the diff has a runtime surface (not test-only or docs-only per the pre-ship exemptions), invoke `/verify` now — this review checks that the diff reads right; `/verify` checks that it runs right.


<!-- literal -->
`--max-findings` was ignored: type a whole number above zero, `all`, or `default` after it.${_?"":" Using the usual limit."}

<!-- literal -->
This review reports at most 32 findings, so the limit is 32 here.

<!-- literal -->
`--max-findings` does not change this review: low effort here has no maximum.

<!-- literal -->
${_==="you"?"You":"The user"} set `--max-findings ${_}` last time. ${_}

<!-- literal -->
Reporting every finding, as ${_} chose last time with `--max-findings all`.

<!-- literal -->
Reporting up to ${_} ${_(_,"finding")}, the limit ${_} set last time with `--max-findings`.

<!-- literal -->
; ultra: deep multi-agent review in the cloud${_()?"":" (requires claude.ai account access)"}

<!-- literal -->
 For ultra on a GitHub.com PR target, --post asks to post the finished review’s findings to the PR as a single comment from the user’s GitHub account (not a review; the launch dialog still confirms in interactive sessions, while non-interactive mode posts on the flag alone) and --no-post hides that option.

<!-- literal -->
Review the current diff, or a PR number/branch/path target, for correctness bugs (plus reuse/simplification/efficiency cleanups where the model's recipe covers them) at the effort level given first, before any target (${_.join("|")}: from few high-confidence findings to many, some uncertain${_}); with no level given, it reuses the level you typed last. Pass --comment to post findings as inline PR comments, or --fix to apply them to the working tree after the review. Pass --max-findings <n> to report up to n findings, or --max-findings all for every finding. The choice stays until you pass --max-findings default.${_}

<!-- literal -->
Use the max or ultra level only when the user, or instructions such as CLAUDE.md or a skill, explicitly ask for one, never on your own judgment: they are the costliest reviews and start many reviewer subagents.

<!-- literal -->
Use the max level only when the user, or instructions such as CLAUDE.md or a skill, explicitly ask for it, never on your own judgment: it is the costliest level and starts many reviewer subagents.

<!-- literal -->
[${_()?`${_.join("|")}|ultra`:_.join("|")}] [--fix] [--comment] [<pr#>|<branch>|<path>] [--max-findings <n>|all]

<!-- literal -->
passing `--max-findings default` goes back to the usual limit

<!-- literal -->
(${_} Open your report with one short line telling the user this${_?`, and that ${_}`:""}; that opening line reaches them with the findings.)



<!-- literal -->
(${_} Tell the user this in one short line as you begin${_?`, including that ${_}`:""}.)



<!-- literal -->


After you finish the review, end your response with this exact line on its own:
${_}

<!-- literal -->
${_}${_}${_}${_}${_.text}${_(_.cell,_,_,_,_.stated)}${_?_?_(_):_:""}${_?_(_):""}${_&&!_?_:""}${_}${_}

<!-- literal -->
The committed diff (@{upstream}...HEAD) is about ${_} lines. Uncommitted changes aren't counted here, so treat this as a floor — start with about ${_} finder subagents (min 2, max 8) and scale up if Phase 0 finds additional working-tree scope.



<!-- literal -->
This diff is about ${_} lines. Spawn about ${_} finder subagents (min 2, max 8) — scale your investigation depth to the diff size rather than using a fixed large fleet.



<!-- literal -->
when the target is a GitLab merge request, your `--comment` is what posts the findings as one general MR note via glab

<!-- literal -->
when the target is a GitHub PR, your `--comment` is what posts the findings as inline PR comments

<!-- literal -->
this local review will not post to GitLab; `--comment` is the flag that posts local findings as a general MR note

<!-- literal -->
this local review will not post to GitHub; `--comment` is the flag that posts local findings as inline PR comments

<!-- literal -->
${_}(The typed `--post` applies only to the `/code-review ultra` cloud review and was ignored — ${_}. Tell the user this in one short line.)



<!-- literal -->
(Running a local ${_}-effort review and applying its findings.)



<!-- literal -->
(${_} Falling back to a local ${_}-effort review.)



<!-- literal -->
(ultra (cloud review) requires claude.ai account access this session doesn't have — see https://code.claude.com/docs/en/ultrareview. Falling back to a local ${_}-effort review.)



<!-- literal -->
(ultra (cloud review) isn't available in this environment — see https://code.claude.com/docs/en/ultrareview. Falling back to a local ${_}-effort review.)



<!-- literal -->
(Claude can't launch the cloud review directly — type `/code-review ultra --fix` to review in the cloud and apply the findings locally when it completes. Running a local ${_}-effort review and applying its findings for now.)



<!-- literal -->
(Running a local ${_}-effort review and applying its findings.)



<!-- literal -->
(Claude can't launch the cloud review directly — type `/code-review ultra` to run it. Falling back to a local ${_}-effort review for now.)



<!-- literal -->
(Claude can't launch the cloud review directly — the user can run `claude ultrareview` from a terminal to start it. Falling back to a local ${_}-effort review for now.)



<!-- literal -->
typing a level (for example `/code-review high`) changes it

<!-- literal -->
(${_} Open your report with one short line telling the user this, and that ${_}; that opening line reaches them with the findings.)



<!-- literal -->
(${_} Tell the user this in one short line as you begin, including that ${_}.)



<!-- literal -->
Ignoring unrecognized effort "${_}"; valid: ${_.join(", ")}. Using ${_}${_===_?", the level the user typed last time":""}.

<!-- literal -->
reusing ${_}, the level the user typed last time${_!==_?`; running at ${_} here`:""}

<!-- literal -->
Review the current diff or a PR for bugs and cleanups

<!-- literal -->
${_.unrecognizedLevel!==void 0?`Ignoring unrecognized effort "${_.unrecognizedLevel}"; valid: ${_.join(", ")}. `:""}Reusing ${_} effort, the level you typed last time${_!==_?`; running at ${_} here`:""}. Type a level like `/code-review high` to change it.${_?` ${_}${_.reused?" Pass `--max-findings default` to go back to the usual limit.":""}`:""}
