---
name: observe-before-model
description: Use when writing or changing code that calls an external API, SDK, CLI, subprocess, file format, database, queue, or LLM — or parses what comes back, or handles its errors — before writing the parser, the handler, or the test.
---

# Observe Before Model

Code that depends on the shape of something outside this codebase is written from an observed instance of that shape, never from memory.

## Before the parser

1. **Read the official docs for this exact call** — endpoint, parameters, response schema, error shapes, pagination, limits. Official means the vendor's current reference, fetched now (WebFetch); not memory, not a tutorial. "The library is already in the codebase" counts only if *this call* already is.
2. **Make one real call** — unless the codebase already makes this exact call and a capture on disk or its raw log shows the shape. Capture the raw result to a file under the project's fixtures or scratch directory, unedited. Redact credentials in the captured request; nothing else.
3. **Write the code against the capture.** The capture is the test fixture.
4. **Don't read a field you haven't seen** in a capture or the docs.
5. **Widen by observation.** The error response, the empty result, the pagination edge, the rate limit — each captured once before it is handled.

## Raw capture stays

Every boundary logs its full raw request and full raw response before any parsing — at debug level or to a file, so it doesn't drown stdout, but present, and kept after the feature ships. Log the raw thing, not a summary of it:

```python
log.debug("POST %s\n%s", url, body)                  # raw request
log.debug("%s %s\n%s", r.status_code, url, r.text)   # raw response, before .json()
```

never `log.info(f"fetched {len(data['items'])} items")` — the summary assumes the shape it claims to report, and can throw or lie.

This is not instrumentation without a reader: the reader is whoever debugs the next failure. Derived instrumentation — counters, metrics, summaries, alarms — still needs a named reader and stays a trim target.

## Errors propagate

The default response to a reachable failure is to let it raise, with the raw context attached: the request, the raw response body, the input. A traceback carrying the payload is the correct outcome for a script or pipeline; non-zero exit codes exist for this.

A catch block needs, beyond scenario / likelihood / consequence, a **named recovery that beats crashing**:

- bounded retry on a transient class, then re-raise;
- skip one item of a batch, with the raw failure recorded and the run ending non-zero;
- degrade a non-essential feature, with the failure logged at error level.

"Log and continue with a default" is a recovery only when the default is a correct answer. Catch narrowly — the class the recovery applies to; `except Exception` only at a top-level boundary that reports and exits non-zero. The handler never assumes the error's shape: log `repr(e)` and the raw body, never `e.response.json()["error"]["message"]`. Each catch carries one line: instead of crashing, this does X because Y.

## Spike, then TDD

The one real call is a spike. Its code is throwaway; its capture is not. TDD starts after: the first failing test uses the captured fixture — `praxis:test-driven-development`'s "mirror real data completely" is only possible from one.

## Common Rationalizations

| Excuse | Reality |
|---|---|
| "The library is already in the codebase" | This call isn't. The codebase proves the calls it makes, not the ones it doesn't. |
| "I know this API" | Knowledge has a cutoff; docs don't. Parameter names and response fields are exactly what drifts. |
| "Logging the body is noisy" | Debug level or a file. Noise beats blindness when the next failure hits. |
| "The user shouldn't see a traceback" | Then catch at the top level, report, exit non-zero. Not in the middle, not with a default. |
| "I'll add the error path later" | Capture it now; it's one more call. Later it's a production incident. |
| "One request isn't enough to know the shape" | It's infinitely more than zero. Widen by observation, not by guessing. |
| "There's no live endpoint to call" | Then the docs' example response is the capture, marked as such, and the first real run replaces it. |
