---
name: document
description: Use when a documentation corpus needs systematic work — auditing existing docs against reader needs, restructuring a docs tree, or producing the documentation set for a feature or product. Not for a single small doc edit.
argument-hint: "[docs path, feature, or git range]"
allowed-tools: Bash(git*), Read, Write, Edit, Glob, Grep, Agent, Task, Skill, AskUserQuestion
---

# Document

Corpus-scale documentation work: classify pages in parallel, confirm the move plan, write per kind, review for kind-purity.

**Scope:** "$ARGUMENTS"

**Name resolution:** `praxis:`-prefixed skill and agent names are the plugin registrations; a local checkout registers them bare. This workflow additionally requires the external `diataxis` plugin (`diataxis:diataxis`; bare: `diataxis`). If a referenced skill resolves in neither form, tell the user what's missing — for diataxis: `/plugin marketplace add moiri-gamboni/diataxis-skill` — instead of silently substituting or improvising the framework from memory.

## Step 0: Right-Size

A single document, or a couple of small edits → no orchestration: load `Skill: "diataxis:diataxis"` and do the work inline. This command earns its cost only at corpus scale — several documents or a whole tree.

## Step 1: Inventory

- Argument wins: a docs path, a feature name, or a git range whose diff names the docs to work on.
- Otherwise discover: `README*`, `docs/**`, root-level `*.md`, site sources. Present the inventory (path, rough size, one-line guess of what each is); confirm scope when ambiguous.
- Capture the product context every later brief needs: what the project is and who its practitioners are, in a paragraph.

## Step 2: Classify (Parallel)

Load `Skill: "diataxis:diataxis"` yourself — its compass and kind table govern the briefs below.

Dispatch parallel subagents via Agent, one per page (batch small related pages). Each brief is self-contained: product context + file path(s) + the instruction to load `diataxis:diataxis` and apply the compass per section. Each returns, per page:

- current kind(s) — dominant plus admixtures
- target kind, or a split (one kind per resulting document)
- misplaced content: section → destination kind and suggested location
- accuracy flags noticed in passing (docs asserting things false of the code — report, don't fix)
- gaps: questions a practitioner would ask this page that no kind currently answers

## Step 3: Assessment + Approval Gate

Aggregate into an assessment table: page | current kind | target | moves | gaps. Propose per-page rewrites, splits, and moves; structure changes only where the content demands them — **never empty tutorials/how-to/reference/explanation scaffolding**. "Fine as-is" is a legitimate verdict; list what stays untouched.

Present the table and get explicit approval before moving or rewriting anything — moves break inbound links, reader habits, and history. No proceeding without approval.

## Step 4: Execute (Parallel Writers)

One subagent per resulting document, brief self-contained: product context, source material (existing text plus where incoming misplaced content comes from), target kind, destination path, and the instruction to load `diataxis:diataxis` and read the reference file its routing table names for that kind **before writing**. Writers preserve accurate content — kind discipline governs form, not facts.

Docs are non-behavioral deliverables: each writer verifies by rendering/reading (links resolve, commands and code samples correct where cheap to check), never by manufactured tests.

Apply file moves and deletions yourself (`git mv`) so history stays intact; then integrate writer output.

## Step 5: Kind-Purity Review

Per changed document, dispatch a fresh reviewer — never its writer: load `diataxis:diataxis`, apply the compass per section (content informing a different need than the document's kind is a finding), and verify Step 2's accuracy flags were resolved or explicitly logged. Small corpus → one reviewer covers all. Fix findings before wrapping.

## Step 6: Wrap

Summary: documents table (path, kind, action taken), unresolved accuracy flags, and gaps deliberately left open — each with the trigger that would justify filling it, never pre-filled scaffolding.

**Next:** "/praxis:ship when ready."

## Relation to /praxis:review

`/praxis:review` already covers documentation units inside code diffs (kind-purity briefing in its Wave 1). This command is for docs-first work: the corpus is the deliverable, not a side effect of a code change.
