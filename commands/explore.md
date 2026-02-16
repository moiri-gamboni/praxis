---
description: Deep codebase exploration using code-explorer agents
argument-hint: "[area or feature to explore]"
allowed-tools: Bash(git log:*), Bash(git diff:*), Read, Glob, Grep, Task
---

# Codebase Exploration

Launch code-explorer agents to deeply analyze a codebase area.

**Area to explore:** "$ARGUMENTS"

## Workflow

### 1. Determine Exploration Focus

If the user provided an area/feature, use that. Otherwise, ask what they want to explore.

### 2. Launch Explorer Agents

Spawn 2-3 code-explorer agents in parallel, each targeting a different aspect:

**Example agent focuses:**
- **Similar features**: "Find features similar to [target] and trace through their implementation comprehensively"
- **Architecture**: "Map the architecture and abstractions for [area], tracing through the code comprehensively"
- **Current implementation**: "Analyze the current implementation of [feature], tracing through the code comprehensively"
- **Patterns**: "Identify UI patterns, testing approaches, or extension points relevant to [feature]"

Each agent should return:
- Entry points with file:line references
- Step-by-step execution flow
- Key components and their responsibilities
- Architecture insights
- List of 5-10 essential files to read

### 3. Aggregate and Present

After agents complete:
1. Read all essential files identified by agents
2. Present a comprehensive summary:
   - **Entry Points**: Where the feature starts
   - **Architecture**: Layers, patterns, design decisions
   - **Key Components**: What each does and how they connect
   - **Data Flow**: How data moves through the system
   - **Conventions**: Patterns the codebase follows
   - **Essential Files**: Ranked by importance

### 4. Ask Follow-up

Ask if the user wants to explore any specific area deeper or proceed to architecture/implementation.
