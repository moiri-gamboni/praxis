---
name: clean-gone
description: Use when local branches whose remotes have been deleted should be cleaned up, along with any associated worktrees.
allowed-tools: Bash(git branch:*), Bash(git worktree:*)
---

## Task

Clean up local branches whose remote counterparts have been deleted.

## Commands

1. **List branches** to identify any with `[gone]` status:
   ```bash
   git branch -v
   ```
   Branches prefixed with `+` have associated worktrees that must be removed before deletion.

2. **List worktrees**:
   ```bash
   git worktree list
   ```

3. **Remove worktrees + delete `[gone]` branches**:
   ```bash
   git branch -v | grep '\[gone\]' | sed 's/^[+* ]//' | awk '{print $1}' | while read branch; do
     echo "Processing branch: $branch"
     worktree=$(git worktree list | grep "\\[$branch\\]" | awk '{print $1}')
     if [ ! -z "$worktree" ] && [ "$worktree" != "$(git rev-parse --show-toplevel)" ]; then
       echo "  Removing worktree: $worktree"
       git worktree remove --force "$worktree"
     fi
     echo "  Deleting branch: $branch"
     git branch -D "$branch"
   done
   ```

If no branches are `[gone]`, report no cleanup needed.

## Next

"Cleanup complete. <N> branches removed."
