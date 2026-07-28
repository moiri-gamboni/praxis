# Where to Validate vs Assert

## Overview

After root-causing a bug caused by bad data, the reflex is to add validation everywhere the data flows. Resist it: a guard for a state that cannot occur hides real failures, invites tests that pin implementation shape, and recursively justifies more machinery — the pins justify the check, the check justifies the fallback, the fallback justifies the injection point, the injection point justifies the tests.

**Core principle:** Validate at the trust boundary, assert internal invariants where they're relied on, let impossible states crash.

## The Decision

For each point the bad data passed through, classify:

### 1. Trust boundary
User input, API request, file/config read, external service response: **validate**. Real inputs go wrong; reject with a clear error naming what was expected.

```typescript
function createProject(name: string, workingDirectory: string) {
  if (!existsSync(workingDirectory)) {
    throw new Error(`workingDirectory does not exist: ${workingDirectory}`);
  }
  // ... proceed
}
```

### 2. Internal invariant
A caller already validated it; the type system constrains it; construction guarantees it: **assert, once, where the invariant is relied on** — or nothing at all, if violation already crashes loudly at the point of use. Don't re-validate what was validated one frame up. Don't catch, wrap, or default: a quiet fallback converts a loud crash into silent corruption.

### 3. Cannot occur
No code path produces it: **no guard**. If you're wrong about "cannot occur," a crash tells you immediately; a defensive default hides it indefinitely.

## Temporary Diagnostics Are Temporary

Environment guards ("refuse git init outside temp dirs during tests") and debug instrumentation (entry/exit logging, stack capture) are legitimate **while diagnosing** — that's Phase 1 of systematic debugging. After the root cause is fixed:

- Remove them, or
- Demote the essential piece into the bug's regression test.

Shipping them permanently is how codebases accrete guard recursion.

## When Multiple Layers Are Right

Permanent validation at more than one layer is justified only when the layers genuinely see different inputs or callers (a public API and a message queue feeding the same handler; a library boundary with external consumers). Each layer must independently earn its place with the three-part articulation:

1. **Specific failure scenario** at *this* layer
2. **Realistic likelihood** (often "negligible" — then say so, and skip it)
3. **Consequence if unhandled** (data loss? recoverable error? log line nobody reads?)

"A refactor might bypass the other check someday" fails the test — that hypothetical refactor should move the validation, and the crash from the missing check is what tells you it didn't.

## Applying After a Fix

1. **Trace the data flow** — where does the bad value originate? Where is it relied on?
2. **Find the trust boundary** it crossed unvalidated; validate there.
3. **Fix the root cause** at the source (see `root-cause-tracing.md`).
4. **Write the regression test** for the behavior that broke.
5. **Delete the diagnostics** you added while investigating.
