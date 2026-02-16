#!/usr/bin/env bash
# Syncs upstream plugin sources into the 'upstream' branch.
# Uses a git worktree so the main working tree is never disturbed.
#
# Usage: scripts/sync-upstream.sh
# Exit codes:
#   0 - no changes detected
#   1 - changes detected and committed to upstream branch
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_CACHE="$HOME/.claude/plugins/cache"

# The four source plugins and their cache subdirectories
declare -A SOURCES=(
  [superpowers]="claude-plugins-official/superpowers"
  [feature-dev]="claude-plugins-official/feature-dev"
  [pr-review-toolkit]="claude-plugins-official/pr-review-toolkit"
  [commit-commands]="claude-plugins-official/commit-commands"
)

# --- Ensure upstream branch exists ---
cd "$REPO_ROOT"
if ! git rev-parse --verify upstream &>/dev/null; then
  echo "Creating upstream branch..."
  # Create orphan branch with an empty initial commit
  git checkout --orphan upstream
  git rm -rf . 2>/dev/null || true
  git commit --allow-empty -m "Initialize upstream tracking branch"
  git checkout - 2>/dev/null || git checkout master 2>/dev/null || git checkout main
fi

# --- Create temporary worktree ---
WORK_DIR=$(mktemp -d)
cleanup() {
  cd "$REPO_ROOT"
  git worktree remove --force "$WORK_DIR" 2>/dev/null || true
  rm -rf "$WORK_DIR" 2>/dev/null || true
}
trap cleanup EXIT

git worktree add "$WORK_DIR" upstream --quiet

# --- Copy current plugin cache into worktree ---
changes_found=false

for plugin in "${!SOURCES[@]}"; do
  src_base="$PLUGIN_CACHE/${SOURCES[$plugin]}"

  # Find the latest version directory
  if [ ! -d "$src_base" ]; then
    echo "Warning: $src_base not found, skipping $plugin"
    continue
  fi

  src_dir=$(find "$src_base" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -1)
  if [ ! -d "$src_dir" ]; then
    echo "Warning: no version directory found in $src_base, skipping $plugin"
    continue
  fi

  version=$(basename "$src_dir")
  echo "Syncing $plugin ($version)..."

  # Remove old copy and replace with current
  rm -rf "$WORK_DIR/$plugin"
  cp -r "$src_dir" "$WORK_DIR/$plugin"

  # Remove any .git directories from the copy
  find "$WORK_DIR/$plugin" -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
done

# --- Check for changes ---
cd "$WORK_DIR"

# Stage everything
git add -A

if git diff --cached --quiet; then
  echo "No upstream changes detected."
  exit 0
fi

# Show summary of changes
echo ""
echo "=== Upstream changes detected ==="
git diff --cached --stat
echo ""

# Commit
git commit -m "Sync upstream plugins $(date +%Y-%m-%d)" --quiet
echo "Changes committed to 'upstream' branch."
echo "Run scripts/analyze-upstream.sh to evaluate changes for praxis."
exit 1
