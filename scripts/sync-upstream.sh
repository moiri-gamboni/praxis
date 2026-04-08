#!/usr/bin/env bash
# Syncs upstream plugin sources into the 'upstream' branch.
# Fetches directly from GitHub repositories (no local plugin install needed).
# Reads source plugin locations from upstream.json.
# Uses a git worktree so the main working tree is never disturbed.
#
# Records per-source commit hashes in _source_commits.json on the upstream
# branch so analyze-upstream.sh can track what changed per source.
#
# Usage: scripts/sync-upstream.sh
# Requires: jq
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM_JSON="$REPO_ROOT/upstream.json"

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install it with your package manager."
  exit 1
fi

# --- Read sources from upstream.json ---
readarray -t PLUGINS < <(jq -r '.sources | to_entries[] | "\(.key) \(.value.repo) \(.value.path)"' "$UPSTREAM_JSON")

# --- Ensure upstream branch exists (prefer remote, fallback to create) ---
cd "$REPO_ROOT"
if ! git rev-parse --verify upstream &>/dev/null; then
  if git ls-remote --exit-code origin upstream &>/dev/null; then
    echo "Fetching upstream branch from remote..."
    git fetch origin upstream:upstream --quiet
  else
    echo "Creating upstream branch..."
    # Create orphan branch without touching the working tree
    empty_tree=$(git hash-object -t tree /dev/null)
    empty_commit=$(git commit-tree "$empty_tree" -m "Initialize upstream tracking branch")
    git branch upstream "$empty_commit"
  fi
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
declare -A SOURCE_COMMITS=()

for entry in "${PLUGINS[@]}"; do
  read -r plugin repo subpath <<< "$entry"
  repo_dir="$CLONE_DIR/$(echo "$repo" | tr '/' '_')"

  # Shallow-clone each unique repo once
  if [ -z "${CLONED[$repo]+x}" ]; then
    echo "Fetching $repo..."
    git clone --depth 1 --quiet "https://github.com/$repo.git" "$repo_dir"
    CLONED[$repo]=1
  fi

  # Record this source's HEAD commit
  SOURCE_COMMITS[$plugin]=$(git -C "$repo_dir" rev-parse HEAD)

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

# --- Write per-source commit hashes ---
{
  echo "{"
  first=true
  for plugin in $(echo "${!SOURCE_COMMITS[@]}" | tr ' ' '\n' | sort); do
    if [ "$first" = true ]; then
      first=false
    else
      echo ","
    fi
    printf '  "%s": "%s"' "$plugin" "${SOURCE_COMMITS[$plugin]}"
  done
  echo ""
  echo "}"
} > "$WORK_DIR/_source_commits.json"

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

# --- Push upstream branch ---
cd "$REPO_ROOT"
if git remote get-url origin &>/dev/null; then
  git push origin upstream --quiet 2>/dev/null && echo "Pushed upstream branch to remote." || echo "Warning: could not push upstream branch (no write access?)."
fi

echo "Run scripts/analyze-upstream.sh to evaluate changes for praxis."
