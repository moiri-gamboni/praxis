---
name: planning
description: Use when writing implementation plans, creating task decompositions, or in plan mode for a multi-step feature
---

# Writing Implementation Plans

Write plans assuming the implementer has zero context for the codebase. Document everything: which files to touch, exact code, how to test, what to check. Bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

## Scope Check

If the spec covers multiple independent subsystems, it should have been decomposed during design. If it was not, suggest breaking into separate plans, one per subsystem. Each plan should produce working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what each is responsible for. This is where decomposition decisions get locked in.

- Each file should have one clear responsibility
- Prefer smaller, focused files over large ones that do too much
- Files that change together should live together; split by responsibility, not by technical layer
- In existing codebases, follow established patterns; if a file you are modifying has grown unwieldy, including a split in the plan is reasonable

## Plan Document Format

Save the plan as a markdown file. Start with this header:

```markdown
# [Feature Name] Implementation Plan

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

Each task targets one component. List the files, then break into steps with checkboxes.

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## Bite-Sized Granularity

Each step is one action (2-5 minutes):
- "Write the failing test" is a step
- "Run it to confirm it fails" is a step
- "Implement the minimal code to pass" is a step
- "Run tests and confirm they pass" is a step
- "Commit" is a step

## No Placeholders

Every step must contain the actual content an implementer needs. These are plan failures:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" or "add validation" or "handle edge cases"
- "Write tests for the above" without actual test code
- "Similar to Task N" (repeat the content; tasks may be read out of order)
- Steps that describe what to do without showing how (code steps need code blocks)
- References to types, functions, or methods not defined in any task

## Self-Review

After writing the complete plan, review it with fresh eyes:

1. **Spec coverage:** Skim each requirement in the spec. Can you point to a task that implements it? List any gaps and add tasks for them.

2. **Placeholder scan:** Search the plan for any pattern from the "No Placeholders" list above. Fix every instance.

3. **Type consistency:** Do the types, method signatures, and property names in later tasks match what earlier tasks defined? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

4. **Scope check:** Is each task focused enough to implement independently? If a task touches more than 2-3 files, consider splitting it.

5. **Ambiguity check:** Could any requirement be interpreted two different ways? Pick one interpretation and make it explicit.

Fix issues inline. No need to re-review after fixes.

## Execution Handoff

After saving the plan, suggest next steps based on plan size:

- **Parallel implementation:** For plans with independent tasks, suggest `/orchestrate` to implement units in parallel with per-unit review
- **Direct implementation:** For smaller plans (under ~5 tasks), implement directly; the TDD skill will activate during implementation

In either case, `/review` after implementation catches cross-cutting issues that per-task work misses.
