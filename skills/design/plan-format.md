# Plan Format

The sections of `plans/<slug>.md`, in order: Plan Header, Key Constraints, Decision Record, then the tasks. `/praxis:design` Phase 3 writes them all; `/praxis:iterate` seeds a minimal file with the Plan Header (Goal and Fixed outcomes), Key Constraints and Resolution Log only.

## Plan Header

```markdown
# [Feature] Implementation Plan

**Goal:** [One sentence]
**Fixed outcomes:** [From 1.2.8; everything else is means]
**Flow:** [1.1.5 sketch, boundaries tagged codebase | docs | capture | assumed]
**Architecture:** [2-3 sentences]
**Failure mode targeted:** [from 1.2]
**Tech Stack:** [Key technologies]
```

## Key Constraints

The 1.2.8 constraint audit, plus constraints carried forward from the ideation file or an earlier plan file. Every item carries a provenance tag:

- `[user]`: the user decided it; quote their words.
- `[fact]`: verified against code or docs; cite where.
- `[assumed]`: an inference or conservative default; later phases treat it as challengeable.

## Decision Record

Canonical source for Present for Approval:

- **Chosen approach**: what won and why, one paragraph.
- **Scope**: **Already implemented** (skip if empty), **Actually new**, **Departures from brief** (drops and additions: `brief asked X → plan delivers Y → why`), **Left out (deliberately)**, skip if empty: machinery considered and not built, each with the trigger that would justify it.
- **Per-decision matrix**: `| Dimension (stakes) | Decides | M | P | C | Pick (conf). Rationale |`
- **Worth your input**: Net statements for medium-or-lower-confidence, material-stakes decisions; skip if none.
- **Architect approaches** (a paragraph each, chosen one marked), **Alternatives Considered**, **Synthesis shape** (label + coupling paragraph).
- **Resolution Log**, one entry per finding from 1.5 and the trim pass:
  ```
  - **<finding title>** (severity: Critical | Important | Suggestion; angle: <attack angle>)
    - Confidence: <0-100>
    - Resolution: Fixed (code | doc | framing | scope) | Deferred | Rejected (by analysis | by user direction; sticky)
    - Detail: <what was done; for "by user direction" quote the user's actual words>
    - Cost (if Fixed code): <LoC / complexity / perf>
    - Revisit trigger (if Deferred): <signal>
  ```
  Every finding gets a logged resolution; sticky rejections are never re-litigated, reframed or not. A re-run treats entries `/praxis:iterate` appended later (angle: iterate) as record, not corruption.

## Task template

````markdown
### Task N: [Component]

**Skills to activate:** [only skills the implementer would not load by itself, e.g. `diataxis:diataxis`, `praxis:frontend-design`; omit the line otherwise]
**Files:** Create `exact/path/file.py` · Modify `exact/path/existing.py` · Test `tests/exact/path/test.py`
**Interfaces** (only when other tasks depend on this one):
- Consumes: [exact signatures from earlier tasks]
- Produces: [exact names, parameter and return types later tasks rely on]

**Acceptance criteria:** [behavior]: [expected outcome] (a task that crosses an external boundary or runs on infrastructure also lists a passing rehearsal, per the Rehearsal section of `runtime.md` in the `praxis:verification-before-completion` skill's directory)

- [ ] Write failing test `test_name`: [assertions, with the design's exact values]
- [ ] Run `<test command>`; verify red
- [ ] Implement `function(arg: Type) -> Result` in `exact/path/file.py`
- [ ] Run `<test command>`; verify green
- [ ] Commit
````

Non-behavioral tasks (docs, config, wiring, cosmetics) swap the red-green steps for `- [ ] Verify: <command / render / check + expected result>`.

Tasks building web UI list `praxis:frontend-design` under **Skills to activate**.
