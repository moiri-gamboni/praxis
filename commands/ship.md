---
description: Commit, push, and open a PR. On feature branches, offers merge/PR/keep/discard options with test verification
argument-hint: "[test command]"
allowed-tools: Bash(git*), Bash(gh*), Bash(npm test:*), Bash(cargo test:*), Bash(pytest:*), Bash(go test:*), Bash(pnpm test:*), Bash(yarn test:*), Bash(bun test:*)
---

**Test command override:** "$ARGUMENTS"

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Default branch: !`git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo main`

## Behavior

Check the current branch name against the default branch (main/master).

---

### Fast path: on main/master

You are on the default branch. Ship changes directly in a single message, no questions asked:

1. Create a new branch with a descriptive name
2. Create a single commit with an appropriate message
3. Push the branch to origin
4. Create a pull request using `gh pr create`

You MUST do all of the above in a single message. Do not use any other tools or do anything else. Do not send any other text or messages besides these tool calls.

**Next step hint:** "PR created. Run /clean-gone after merge to clean up branches."

---

### Feature branch path: on any other branch

#### Step 1: Verify Tests

Run the project's test suite. If user provided a test command argument, use that. Otherwise detect:

```bash
# Try common test commands
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before shipping:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Don't proceed to Step 2.

**If tests pass:** Continue to Step 2.

#### Step 2: Determine Base Branch

```bash
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Use the default branch detected in Context above.

#### Step 3: Present Options

Present exactly these 4 options:

```
Tests pass. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

Don't add explanation. Keep options concise.

#### Step 4: Execute Choice

##### Option 1: Merge Locally

```bash
git checkout <base-branch>
git pull
git merge <feature-branch>
<test command>  # Verify tests on merged result
git branch -d <feature-branch>
```

Then: Cleanup worktree (Step 5)

**Next step hint:** "Merged to <base-branch>. Branch cleaned up."

##### Option 2: Push and Create PR

```bash
git push -u origin <feature-branch>
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)"
```

Then: Cleanup worktree (Step 5)

**Next step hint:** "PR created. Run /clean-gone after merge to clean up branches."

##### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

Don't cleanup worktree.

**Next step hint:** "Branch preserved. Run /ship again when ready."

##### Option 4: Discard

Confirm first:
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:
```bash
git checkout <base-branch>
git branch -D <feature-branch>
```

Then: Cleanup worktree (Step 5)

#### Step 5: Cleanup Worktree

**For Options 1, 2, 4:**

Check if in worktree:
```bash
git worktree list | grep $(git branch --show-current)
```

If yes:
```bash
git worktree remove <worktree-path>
```

**For Option 3:** Keep worktree.

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without typed confirmation
- Force-push without explicit request

**Always:**
- Verify tests before offering options (feature branch path only)
- Present exactly 4 options on feature branches
- Get typed confirmation for Option 4
- Clean up worktree for Options 1, 2, and 4
