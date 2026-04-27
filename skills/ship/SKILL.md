---
name: ship
description: PR-first shipping. On main, opens a PR. On feature branches, opens a PR or pushes to an existing one. With "merge" arg, performs an explicit local merge after acceptance.
argument-hint: "[merge] [test command]"
allowed-tools: Bash(git*), Bash(gh*), Bash(npm test:*), Bash(cargo test:*), Bash(pytest:*), Bash(go test:*), Bash(pnpm test:*), Bash(yarn test:*), Bash(bun test:*)
---

**Argument:** "$ARGUMENTS"

If the argument starts with `merge`, run the **Merge path** below. Any remaining argument is the test command override.

Otherwise the remaining argument (if any) is the test command override; run the **Default path**.

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Default branch: !`git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo main`

## Default path

Determine state and act. Do not menu, do not ask which option — the state determines the action.

### State 1: On main/master

Ship changes directly. In a single message, no questions asked:

1. Create a new branch with a descriptive name
2. Create a single commit with an appropriate message
3. Push the branch to origin
4. Create a pull request using `gh pr create`

You MUST do all of the above in a single message. Do not use any other tools or do anything else. Do not send any other text or messages besides these tool calls.

**Next step hint:** "PR created."

### State 2: On feature branch, no PR exists yet

Detect via `gh pr list --head <branch> --state open --json number --jq '.[0].number'`. If empty, no PR.

1. Verify tests pass (use detected test command or argument override). If tests fail, stop and surface failures — do not proceed.
2. **Invoke `Skill: "simplify"`** for a final polish pass before the world sees the diff. Skip this if the changes were just produced by `/implement` Phase 4 (which already simplifies)
3. Push the branch to origin
4. Create a pull request using `gh pr create`

**Next step hint:** "PR opened."

### State 3: On feature branch, PR exists

PR number returned by `gh pr list --head <branch> --state open --json number --jq '.[0].number'`.

1. Verify tests pass. If tests fail, stop and surface failures.
2. Show a brief summary first:

```
About to push <N> commits to PR #<number>:
<short list of commit subjects>

Proceed?
```

3. On confirmation: `git push origin <branch>`

**Next step hint:** "PR updated."

## Merge path

Triggered by `/ship merge` (positional argument).

This is a local merge into the base branch. Use only when you've decided not to go through PR review (small/local/private projects).

1. Determine base branch from `git symbolic-ref refs/remotes/origin/HEAD`
2. Verify tests pass (use detected test command or argument override). If tests fail, stop.
3. Show explicit acceptance prompt:

```
About to merge <feature-branch> into <base-branch>:
- Checkout <base>
- Pull latest
- Merge <feature-branch>
- Run tests on the merged result
- Delete <feature-branch> on success
- Clean up associated worktree
- Run /clean-gone to sweep stale branches

Proceed?
```

4. On confirmation, execute:

```bash
git checkout <base-branch>
git pull
git merge <feature-branch>
<test-command>
git branch -d <feature-branch>
```

5. If in a worktree, remove it: `git worktree remove <worktree-path>`
6. Invoke `Skill: "clean-gone"` to sweep any other stale branches

**Next step hint:** "Merged to <base-branch>. Worktree cleaned. Other stale branches swept."

## Test detection

If user provided a test command argument (after `merge` if present), use it. Otherwise detect:

```bash
# Try common test commands
npm test / cargo test / pytest / go test ./...
```

Show what you ran. On failure, surface output and stop.

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on the merged result
- Force-push without explicit request
- Use the merge path without the typed acceptance prompt

**Always:**
- Detect existing PR before opening a new one
- Verify tests on feature branches before any push
- Show a brief commit summary before pushing updates to an existing PR
- Run `/clean-gone` after a local merge
