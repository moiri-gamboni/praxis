# Runtime Verification

How to get the "end-to-end run on real input" the gate asks for: build the thing, run it, drive it to where the changed code executes, and capture what you see. That capture is the evidence that the change works.

**This is in addition to the test suite and typecheck, never instead of them.** The gate still requires both. What it adds is that tests prove the code does what the tests say; only a run at the surface proves the change does what was asked. Test runs, typechecks and builds are setup here, not runtime steps.

**Don't import-and-call.** `import { foo } from './src/...'` then `console.log(foo(x))` is a unit test you wrote. The function did what the function does — you knew that from reading it. The app never ran. Whatever calls `foo` in the real codebase ends at a CLI, a socket, or a window. Go there.

## Find the change

The scope is what you're verifying — usually a diff, sometimes just "does X work." Establish the full range, not just the last commit: `git diff @{u}.. --stat`, `git diff origin/HEAD... --stat` with no upstream, `git diff HEAD --stat` for uncommitted work, `gh pr diff` in a PR. A diff too large for the output: redirect it to a file, then read the file.

**The diff is ground truth. Any description is a claim about it** — the commit message, the plan, a delegate's report. Read both. If they disagree, that's a finding.

## Surface

The surface is where a user — human or programmatic — meets the change. That's where you observe.

| Change reaches | Surface | You |
|---|---|---|
| CLI / TUI | terminal | type the command, capture stdout, stderr, exit code, or the pane |
| Server / API | socket | send the request, capture the full response (status, headers, body) |
| GUI | pixels | drive it in a headless browser or under xvfb, screenshot |
| Library | package boundary | sample code through the public export — `import pkg`, not `import ./src/...` |
| Prompt / agent config / skill | the agent | run the agent on a task that exercises the change, capture its behavior |
| CI workflow | Actions | dispatch it, read the run |

For a UI change, the states and accessibility checks to drive are in `skills/frontend-design/fundamentals.md`.

**Internal function? Not a surface.** Something in the repo calls it and that caller ends at one of the rows above. Follow it there. A bash security gate's surface isn't the function's return value — it's the CLI prompting or auto-allowing when you type the command.

**No runtime surface at all** — docs-only, tests-only, type declarations with no emit, build config that produces no behavioral diff — the runtime part is SKIP, one line why; the rest of the gate still applies. Mixed source and tests → verify the source. Reading a test to learn what to check is fine — it's a spec. Then go run the app.

## Get a handle

**Check `.claude/skills/` first — even if you already know how to build and run.** Probe the repo root **and** each package or app directory the diff touches; in a monorepo the recipe for `apps/desktop/` usually lives in `apps/desktop/.claude/skills/`.

- **`verifier-*` matching your surface** → invoke it with the Skill tool and follow its setup; it is the repo's evidence-capture protocol. A mismatched surface → try the next. A stale verifier (fails on mechanics unrelated to the change) → report it; don't FAIL the change for verifier rot.
- **`run-*` but no matching verifier** → use its build and launch primitives as your handle.
- **Neither** → `Skill: "run"` (the built-in launcher: it looks for a project recipe, then falls back to per-project-type patterns), else cold start from README, package.json, Makefile. Timebox it (~15 min). Stuck → BLOCKED, with exactly where it stopped.

**Isolate shared process state.** Parallel workers and the host session share tmux, ports, lockfiles and temp paths: `tmux -L <name>`, bind port `0` (or pick a free one), `mktemp -d` for working directories.

## Drive it

Smallest path that makes the changed code execute:

- Changed a flag? Run with it.
- Changed a handler? Hit that route.
- Changed error handling? Trigger the error.
- Changed an internal function? Find the CLI command, request or render that reaches it. Run that.

**Read your plan back before running.** If every step is build / typecheck / run a test file, you've planned a CI rerun, not a verification. Find a step that reaches the surface, or report BLOCKED.

**End-to-end, through the real interface.** Pieces passing in isolation doesn't mean the flow works — seams are where bugs hide. If users click buttons, test by clicking buttons, not by curling the API underneath.

**Destructive path?** If the change touches code that deletes, publishes, sends, or writes outside the workspace and there's no dry-run or safe target (a tmp dir, a mock, a dry-run flag), don't drive it live. Verify what you can around it and say which path you didn't exercise and why.

A server needs a lifecycle — start in the background, poll for readiness, stop it after:

```bash
tmp=$(mktemp -d)
<start-command> &> "$tmp/server.log" &
SERVER_PID=$!
for i in {1..30}; do curl -sf localhost:$PORT/health >/dev/null && break; sleep 1; done
# ... requests ...
kill $SERVER_PID
```

No readiness endpoint? Poll the route you're about to test until it stops refusing connections.

**Signs you didn't reach the change:** `unknown flag` (not wired up, or a stale build); the unchanged path's output where the changed one was expected (a 200 where the diff adds a 429 header — you never triggered the branch); the no-flag behavior changed too (a regression: the diff touched more than it should).

## Push on it

The claim checking out is the first half. Probe *around* the change, at the same surface you just drove:

- **New flag / option** → empty value, passed twice, combined with a conflicting flag, typo'd (does the error name it?)
- **New handler / route** → wrong method, malformed body, missing required field, oversized payload
- **Changed error path** → the adjacent errors it didn't touch — did the refactor catch them too, or only the one in the diff?
- **Interactive / TUI** → Ctrl-C mid-op, resize the pane, paste garbage, rapid-fire the key, Esc at the wrong moment
- **State / persistence** → do it twice, do it with stale state underneath, do it in two sessions at once
- **Wander** → what's adjacent? What looked off while you were confirming? Go back to it.

These aren't a checklist — pick the ones the change points at. A probe that finds nothing is still a step: "🔍 passed `--from ''` → clean `error: --from requires a value`, exit 2." A Steps list that's all ✅ and no 🔍 is a happy-path replay.

## Capture

Stdout, response bodies, screenshots, pane dumps — raw and unedited. Captured output is evidence; your memory isn't. Something unexpected? Don't route around it — capture it, note it, decide whether it's the change or the environment. Unrelated breakage is a finding, not noise. A run that crosses an external boundary for the first time also yields the capture `praxis:observe-before-model` asks for: keep it.

**Evidence has to reach the reader.** A file path is evidence only if the reader can open it; otherwise keep what matters inline — pane captures and response bodies travel in the report.

## Report

Each step is one thing you did to the **running app** and what it showed, marked ✅ / ❌ / ⚠️ / 🔍 (🔍 = a probe off the happy path; at least one), with the app's own output as evidence. Then the things you noticed: friction, surprises, a slow path, an unhelpful error, a claim/diff mismatch — anything that made you pause while running it, not while reading the diff. Each probe gets a line even when it held.

**Verdicts:**
- **PASS** — you ran it, the change did what it should at its surface. Not: tests pass, builds clean, code looks right.
- **FAIL** — you ran it and it doesn't. Or it breaks something else. Or claim and diff disagree materially.
- **BLOCKED** — couldn't reach a state where the change is observable (build broke, a dependency missing, the handle wouldn't come up). Not a verdict on the change, and not a completion: say exactly where it stopped and that the runtime behavior is unverified. Never call it blocked before checking the skills along the touched subtree.
- **SKIP** — no runtime surface exists. One line why.

No partial pass. "3 of 4 passed" is FAIL until 4 passes or is explained away.

**When in doubt, FAIL.** False PASS ships broken code; false FAIL costs one more look. Ambiguous output is FAIL with the raw capture attached — don't interpret.
