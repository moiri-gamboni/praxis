---
name: ship
description: PR-first shipping. On main, opens a PR. On feature branches, opens a PR or pushes to an existing one. With "merge" arg, performs an explicit local merge after acceptance.
argument-hint: "[merge] [test command]"
allowed-tools: Bash(git*), Bash(gh*), Bash(npm test:*), Bash(cargo test:*), Bash(pytest:*), Bash(go test:*), Bash(pnpm test:*), Bash(yarn test:*), Bash(bun test:*)
---

**Argument:** "$ARGUMENTS"

Argument starts with `merge` → **Merge path**. Remaining argument (if any) is the test command override.

Otherwise → **Default path**. Argument (if any) is the test command override.

## Context

- Status: !`git status`
- Diff: !`git diff HEAD`
- Branch: !`git branch --show-current`
- Default branch: !`git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo main`

## Default Path

State determines action. No menu, no asking.

### State 1: On main/master

Single message, no questions:

1. Create new branch with descriptive name
2. Single commit with appropriate message
3. Push to origin
4. `gh pr create`

All in one message. No other tools, no other text besides these calls.

**Next:** "PR created."

### State 2: Feature branch, no PR

Detect: `gh pr list --head <branch> --state open --json number --jq '.[0].number'` returns empty.

1. Verify tests pass (detected command or argument override). On failure, stop and surface.
2. **Invoke `Skill: "simplify"`** for final polish before the world sees it. Skip if changes just came from `/implement` Phase 4 (already simplified).
3. Push to origin
4. `gh pr create`

**Next:** "PR opened."

### State 3: Feature branch, PR exists

PR number from `gh pr list ...`.

1. Verify tests pass. On failure, stop.
2. Brief summary first:

```
About to push <N> commits to PR #<number>:
<short list of commit subjects>

Proceed?
```

3. On confirmation: `git push origin <branch>`

**Next:** "PR updated."

## Merge Path

Triggered by `/ship merge`. Local merge into base branch — use when not going through PR review (small/local/private).

1. Base branch from `git symbolic-ref refs/remotes/origin/HEAD`
2. Verify tests pass. On failure, stop.
3. Explicit acceptance prompt:

```
About to merge <feature-branch> into <base-branch>:
- Checkout <base>, pull, merge <feature>
- Run tests on merged result
- Delete <feature> on success
- Clean up worktree
- Run /clean-gone to sweep stale branches

Proceed?
```

4. On confirmation:

```bash
git checkout <base-branch>
git pull
git merge <feature-branch>
<test-command>
git branch -d <feature-branch>
```

5. If in a worktree: `git worktree remove <path>`
6. Invoke `Skill: "clean-gone"` to sweep other stale branches

**Next:** "Merged. Worktree cleaned. Stale branches swept."

## Test Detection

User-provided argument (after `merge` if present) wins. Otherwise detect:

```
npm test / cargo test / pytest / go test ./...
```

Show what you ran. On failure, surface and stop.

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on the merged result
- Force-push without explicit request
- Use merge path without typed acceptance

**Always:**
- Detect existing PR before opening a new one
- Verify tests on feature branches before any push
- Show commit summary before pushing to existing PR
- Run `/clean-gone` after a local merge
