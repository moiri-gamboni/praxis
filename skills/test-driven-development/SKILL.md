---
name: test-driven-development
description: Use when implementing any feature or bugfix, before writing implementation code
---

# Test-Driven Development (TDD)

## Overview

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

**Violating the letter of the rules is violating the spirit of the rules.**

## When to Use

**Always — when there's a behavioral contract:**
- New features
- Bug fixes (a behavioral bug gets a failing test that reproduces it before the fix)
- Behavior changes

**Refactoring:** TDD's role in a behavior-preserving change is that existing tests stay green — never a new failing test. A new test that fails before a refactor can only be failing because it pins the new shape.

**No behavioral contract, no test:** docs, config, wiring, cosmetics — anything whose contract you cannot phrase as inputs/state → observable output or effect. A test there could only pin source text or code shape: it fails red trivially, greens on paste, and proves nothing (see the Gate below). Verify by running/rendering instead.

**Exceptions (ask your human partner):**
- Throwaway prototypes
- Generated code

A scoped build under `praxis:prototype` applies TDD where its Phase 2 decided it pays.

**Worker context:** with no human to ask (an implementer or other subagent), every "ask your human partner" in this skill means: record the question as unresolved in your log and return Blocked.

Thinking "skip TDD just this once"? Stop. That's rationalization. The question is never whether testing is worth the effort (it is); it's whether a behavioral contract exists to test.

## The Iron Law

```
NO NEW BEHAVIOR WITHOUT A FAILING TEST FIRST
```

Wrote code for the new behavior before its test? Delete it. Start over.

**No exceptions:**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete

Implement fresh from tests. Period.

This covers code you wrote in this task for the new behavior. Pre-existing code without tests is not deleted: pin what it does now with characterization tests, then change it test-first.

## The Gate: Name the Behavior

Before writing the test, phrase the behavior: **inputs/state → observable output or effect**, with no reference to the code's text or structure.

- Can't phrase it that way? There is no test to write here — the deliverable is non-behavioral: say so, with the reason. Verify by running/rendering; don't manufacture a red test.
- **Output text is behavior** (error messages, rendered templates, CLI output are contracts). **Source text never is.** Prefer asserting the property of the output that matters over byte-pinning the whole output, unless exact bytes are the contract (golden files).
- A test that can only fail via text diff on the source proves nothing: watching it fail is ceremony, not verification.

## Red-Green-Refactor

### RED - Write Failing Test

Write one minimal test showing what should happen.

<Good>
```typescript
test('retries failed operations 3 times', async () => {
  let attempts = 0;
  const operation = () => {
    attempts++;
    if (attempts < 3) throw new Error('fail');
    return 'success';
  };

  const result = await retryOperation(operation);

  expect(result).toBe('success');
  expect(attempts).toBe(3);
});
```
Clear name, tests real behavior, one thing
</Good>

<Bad>
```typescript
test('retry works', async () => {
  const mock = jest.fn()
    .mockRejectedValueOnce(new Error())
    .mockRejectedValueOnce(new Error())
    .mockResolvedValueOnce('success');
  await retryOperation(mock);
  expect(mock).toHaveBeenCalledTimes(3);
});
```
Vague name, tests mock not code
</Bad>

**Requirements:**
- One behavior ("and" in the name? Split it)
- Clear name
- Real code (no mocks unless unavoidable)
- Real data: a fixture for an external shape is a capture, never invented

### Verify RED - Watch It Fail

**MANDATORY. Never skip.**

```bash
npm test path/to/test.test.ts
```

Confirm:
- Test fails (not errors)
- Failure message is expected
- Fails because feature missing (not typos)

**Test passes?** You're testing existing behavior. Fix test.

**Test errors?** Fix error, re-run until it fails correctly.

### GREEN - Minimal Code

Write simplest code to pass the test.

<Good>
```typescript
async function retryOperation<T>(fn: () => Promise<T>): Promise<T> {
  for (let i = 0; i < 3; i++) {
    try {
      return await fn();
    } catch (e) {
      if (i === 2) throw e;
    }
  }
  throw new Error('unreachable');
}
```
Just enough to pass
</Good>

<Bad>
```typescript
async function retryOperation<T>(
  fn: () => Promise<T>,
  options?: {
    maxRetries?: number;
    backoff?: 'linear' | 'exponential';
    onRetry?: (attempt: number) => void;
  }
): Promise<T> {
  // YAGNI
}
```
Over-engineered
</Bad>

Don't add features, refactor other code, or "improve" beyond the test.

### Verify GREEN - Watch It Pass

**MANDATORY.**

```bash
npm test path/to/test.test.ts
```

Confirm:
- Test passes
- Before calling the change done, the project's whole suite shows no failure your change caused: run its test command (`pytest`, `npm test`, `cargo test`), not just your file, even when the task named one
- Output pristine (no errors, warnings)

**Test fails?** Fix code, not test.

**Other tests fail?** Fix the ones your change broke; one that also fails on the base commit is reported by name, not fixed. Establish that by running it on the base commit in a clean worktree (`git worktree add`), not by switching revisions in your working tree.

### REFACTOR - Clean Up

After green only:
- Remove duplication
- Improve names
- Extract helpers
- Comments: why only, in the domain's words — no process residue, no plan pointers

Keep tests green. Don't add behavior.

### Repeat

Next failing test for next feature.

## Good Tests

When writing or changing any test, read `writing-good-tests.md` in this skill's directory for the rules that keep tests honest:
- Name the production change that would make the test fail — before writing it
- Assert on real behavior, never on mock behavior
- Keep test-only code in test utilities, out of production classes
- Understand a dependency's side effects before mocking it

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests written after pass immediately — which proves nothing. They may test the wrong thing, test the implementation instead of the behavior, or miss the edge case you forgot. You never watched it fail, so you never proved it can catch the bug. Test-first forces that failure. |
| "Tests after achieve same goals (spirit not ritual)" | Tests-after answer "what does this do?"; tests-first answer "what should this do?" Tests written after are biased by the code you already wrote — you verify the cases you remembered, not the ones you'd have discovered. Coverage without proof the tests work. |
| "Already manually tested" | Manual testing is ad-hoc: no record of what you covered, no way to re-run it when the code changes, easy to forget cases under pressure. "Worked when I tried it" is not comprehensive. Automated tests run the same way every time. |
| "Deleting X hours is wasteful" | Sunk cost fallacy — that time is already spent either way. The real choice: rewrite with TDD (high confidence) vs. keep it and bolt tests on after (low confidence, likely bugs). Keeping code you can't trust is the waste. |
| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete. |
| "Need to explore first" | Yes — when a boundary's shape is unobserved, spike it via `praxis:observe-before-model`. Throw away the spike's code; keep its capture as the fixture. Then TDD. |
| "Test hard = design unclear" | Listen to test. Hard to test = hard to use. |
| "TDD will slow me down" | TDD IS the pragmatic path: catches bugs before commit, prevents regressions, lets you refactor without fear. "Pragmatic" shortcuts mean debugging in production — slower, not faster. |
| "Manual test faster" | Manual doesn't prove edge cases. You'll re-test every change. |
| "Existing code has no tests" | You're improving it. Pin its current behavior with characterization tests, then change it test-first. |
| "No behavior here" (docs/config/cosmetics) | Legitimate ONLY if the deliverable can't be phrased as inputs → observable effect. Property of the deliverable, not your effort budget. "Too simple to test" is still not this. |

## Red Flags - STOP and Start Over

- Code before test
- Test after implementation
- Tests added "later"
- Rationalizing "just this once"
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "It's about spirit not ritual"
- "Keep as reference" or "adapt existing code"
- "Already spent X hours, deleting is wasteful"
- "TDD is dogmatic, I'm being pragmatic"
- "This is different because..."

**All of these mean: Delete the code written for the new behavior. Start over with TDD.**

## Red Flags in the Test - STOP and Fix the Test

- Test passes immediately
- Can't explain why test failed
- Test asserts source text or code shape (manufactured red)

**These mean the test is wrong, not the code: fix it, or delete it if there is no behavior to name (The Gate). Keep the code.**

## Example: Bug Fix

**Bug:** Empty email accepted

**RED**
```typescript
test('rejects empty email', async () => {
  const result = await submitForm({ email: '' });
  expect(result.error).toBe('Email required');
});
```

**Verify RED**
```bash
$ npm test
FAIL: expected 'Email required', got undefined
```

**GREEN**
```typescript
function submitForm(data: FormData) {
  if (!data.email?.trim()) {
    return { error: 'Email required' };
  }
  // ...
}
```

**Verify GREEN**
```bash
$ npm test
PASS
```

**REFACTOR**
Extract validation for multiple fields if needed.

## When Stuck

| Problem | Solution |
|---------|----------|
| Don't know how to test | Write wished-for API. Write assertion first. Ask your human partner. |
| Test too complicated | Design too complicated. Simplify interface. |
| Must mock everything | Code too coupled. Use dependency injection. |
| Test setup huge | Extract helpers. Still complex? Simplify design. |
