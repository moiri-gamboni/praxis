#!/usr/bin/env bash
# Syncs upstream plugin sources into the 'upstream' branch.
# Fetches directly from GitHub repositories (no local plugin install needed).
# Uses a git worktree so the main working tree is never disturbed.
#
# Usage: scripts/sync-upstream.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Source plugins: name -> "github_owner/repo:subpath" ("." = repo root)
declare -A SOURCES=(
  [superpowers]="obra/superpowers:."
  [feature-dev]="anthropics/claude-plugins-official:plugins/feature-dev"
  [pr-review-toolkit]="anthropics/claude-plugins-official:plugins/pr-review-toolkit"
  [commit-commands]="anthropics/claude-plugins-official:plugins/commit-commands"
  [frontend-design]="anthropics/claude-plugins-official:plugins/frontend-design"
)

# --- Ensure upstream branch exists ---
cd "$REPO_ROOT"
if ! git rev-parse --verify upstream &>/dev/null; then
  echo "Creating upstream branch..."
  git checkout --orphan upstream
  git rm -rf . 2>/dev/null || true
  git commit --allow-empty -m "Initialize upstream tracking branch"
  git checkout - 2>/dev/null || git checkout master 2>/dev/null || git checkout main
fi

# --- Create temporary worktree and clone dir ---
WORK_DIR=$(mktemp -d)
CLONE_DIR=$(mktemp -d)
cleanup() {
  cd "$REPO_ROOT"
  git worktree remove --force "$WORK_DIR" 2>/dev/null || true
  rm -rf "$WORK_DIR" "$CLONE_DIR" 2>/dev/null || true
}
trap cleanup EXIT

git worktree add "$WORK_DIR" upstream --quiet

# --- Fetch repos and copy plugins into worktree ---
declare -A CLONED=()

for plugin in "${!SOURCES[@]}"; do
  spec="${SOURCES[$plugin]}"
  repo="${spec%%:*}"
  subpath="${spec##*:}"
  repo_dir="$CLONE_DIR/$(echo "$repo" | tr '/' '_')"

  # Shallow-clone each unique repo once
  if [ -z "${CLONED[$repo]+x}" ]; then
    echo "Fetching $repo..."
    git clone --depth 1 --quiet "https://github.com/$repo.git" "$repo_dir"
    CLONED[$repo]=1
  fi

  # Determine source directory
  if [ "$subpath" = "." ]; then
    src="$repo_dir"
  else
    src="$repo_dir/$subpath"
  fi

  if [ ! -d "$src" ]; then
    echo "Warning: $repo:$subpath not found, skipping $plugin"
    continue
  fi

  echo "Syncing $plugin..."

  rm -rf "$WORK_DIR/$plugin"
  cp -r "$src" "$WORK_DIR/$plugin"

  # Remove .git directories from copies
  find "$WORK_DIR/$plugin" -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
done

# --- Check for changes ---
cd "$WORK_DIR"
git add -A

if git diff --cached --quiet; then
  echo "No upstream changes detected."
  exit 0
fi

echo ""
echo "=== Upstream changes detected ==="
git diff --cached --stat
echo ""

git commit -m "Sync upstream plugins $(date +%Y-%m-%d)" --quiet
echo "Changes committed to 'upstream' branch."
echo "Run scripts/analyze-upstream.sh to evaluate changes for praxis."
