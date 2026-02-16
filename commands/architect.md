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

### 4. Get User Decision

Ask which approach the user prefers. Don't proceed to implementation without explicit approval.
