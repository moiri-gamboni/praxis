---
description: Design feature architecture using code-architect agents with different approaches
argument-hint: "<feature description>"
allowed-tools: Read, Glob, Grep, Task
---

# Architecture Design

Launch code-architect agents to design implementation approaches for a feature.

**Feature:** "$ARGUMENTS"

## Workflow

### 1. Validate Input

A feature description is required. If not provided, ask the user what they want to build.

### 2. Launch Architect Agents

Spawn 2-3 code-architect agents in parallel, each with a different design philosophy:

- **Minimal changes**: "Design [feature] with the smallest possible change set. Maximum reuse of existing code and patterns. Prioritize low risk and fast delivery."
- **Clean architecture**: "Design [feature] with the best possible architecture. Prioritize maintainability, elegant abstractions, and long-term extensibility."
- **Pragmatic balance**: "Design [feature] balancing speed with quality. Find the sweet spot between minimal changes and clean architecture."

Each agent should analyze existing codebase patterns and produce:
- Patterns and conventions found (with file:line references)
- Architecture decision with rationale
- Component design (file paths, responsibilities, interfaces)
- Data flow from entry to output
- Build sequence as an ordered checklist

### 3. Compare and Recommend

After agents complete, present to the user:

1. **Brief summary of each approach** (2-3 sentences each)
2. **Trade-offs comparison table:**

   | Dimension | Minimal | Clean | Pragmatic |
   |-----------|---------|-------|-----------|
   | Files changed | | | |
   | Complexity | | | |
   | Maintainability | | | |
   | Risk | | | |

3. **Your recommendation** with reasoning (consider: is this a small fix or large feature? What's the urgency? How complex is it?)
4. **Concrete implementation differences** between approaches

### 3.5. Red-Team Review

Spawn a `red-team` agent with the recommended approach. Pass it the full architecture blueprint including component design, data flow, and build sequence.

Present the red-team findings to the user alongside your recommendation. If the red-team surfaced Critical Concerns, flag them prominently and note whether they apply to all approaches or only the recommended one.

### 4. Get User Decision

Present the recommendation and red-team findings together. Ask which approach the user prefers and whether to address any red-team concerns before proceeding. Don't proceed to implementation without explicit approval.

If the user wants to iterate on the design, revise and run the red-team agent again on the updated architecture. Repeat until the user is satisfied.

Once the user makes a final decision, run the red-team agent one more time on the chosen architecture to validate. Present any new findings; confirm when the design passes review.

### 5. Capture Decision Artifacts

Save the architecture decision as a plan file in the project directory (e.g., `./plans/architect-[feature-slug].md`). Include:

- **Chosen approach**: Which design was selected and a brief description
- **Rationale**: Why this approach was chosen over alternatives
- **Rejected alternatives**: Each alternative with the reason it was rejected
- **Key tradeoffs**: What was traded away and what was gained
- **Red-team findings**: Summary of concerns raised and how each was addressed or accepted
- **Component design**: File paths, responsibilities, interfaces (from the chosen approach)
- **Build sequence**: Implementation steps as an ordered checklist

### 6. Next Steps

Tell the user: "Architecture settled. Next: enter plan mode to write an implementation plan, or /orchestrate to implement in parallel."
