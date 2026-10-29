#!/usr/bin/env bash
# Syncs upstream plugin sources into the 'upstream' branch.
# Fetches directly from GitHub repositories (no local plugin install needed).
# Reads source plugin locations from upstream.json.
# Uses a git worktree so the main working tree is never disturbed.
#
# Records per-source commit hashes in _source_commits.json on the upstream
# branch so analyze-upstream.sh can track what changed per source.
#
# A source with "builtin": true in upstream.json is not a GitHub repo: it lists
# Claude Code built-in "skills" whose prompts live inside the installed claude
# binary. They are extracted (scripts/extract-builtin-skills.py) from the newest
# version in $CLAUDE_VERSIONS_DIR (default ~/.local/share/claude/versions) into
# <source>/<skill>.md, and the version string is recorded where other sources
# record a commit hash. With no install, or only a version older than the
# recorded one, the files and recorded version are left as they are (a warning).
# An extraction error with an install present aborts the sync.
#
# Usage: scripts/sync-upstream.sh
# Requires: jq, python3, zstd (for built-in sources)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM_JSON="$REPO_ROOT/upstream.json"

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install it with your package manager."
  exit 1
fi

# --- Read sources from upstream.json ---
readarray -t PLUGINS < <(jq -r '.sources | to_entries[] | select(.value.builtin | not) | "\(.key) \(.value.repo) \(.value.path)"' "$UPSTREAM_JSON")
readarray -t BUILTINS < <(jq -r '.sources | to_entries[] | select(.value.builtin) | .key' "$UPSTREAM_JSON")

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

# --- Extract built-in skill prompts from the installed Claude Code binary ---
# With no install, or only one older than the version the last sync recorded, the
# source's files and recorded version stay as the upstream branch has them.
VERSIONS_DIR="${CLAUDE_VERSIONS_DIR:-$HOME/.local/share/claude/versions}"
for builtin_name in "${BUILTINS[@]}"; do
  recorded=""
  if [ -f "$WORK_DIR/_source_commits.json" ]; then
    recorded=$(jq -r --arg s "$builtin_name" '.[$s] // empty' "$WORK_DIR/_source_commits.json")
  fi
  version=""
  if [ -d "$VERSIONS_DIR" ]; then
    version=$(ls "$VERSIONS_DIR" | grep -E '^[0-9]+(\.[0-9]+)+$' | sort -V | tail -1 || true)
  fi

  if [ -z "$version" ]; then
    echo "WARNING: no Claude Code install found in $VERSIONS_DIR; $builtin_name stays at ${recorded:-nothing recorded yet}." >&2
  elif [ -n "$recorded" ] && [ "$(printf '%s\n%s\n' "$version" "$recorded" | sort -V | tail -1)" != "$version" ]; then
    echo "WARNING: newest installed Claude Code is $version, older than the recorded $recorded; $builtin_name stays at $recorded." >&2
  else
    readarray -t skills < <(jq -r --arg s "$builtin_name" '.sources[$s].skills[]' "$UPSTREAM_JSON")
    echo "Extracting $builtin_name $version (${#skills[@]} skills)..."
    rm -rf "${WORK_DIR:?}/$builtin_name"
    python3 -I "$REPO_ROOT/scripts/extract-builtin-skills.py" "$VERSIONS_DIR/$version" "$WORK_DIR/$builtin_name" "${skills[@]}"
    recorded=$version
  fi
  if [ -n "$recorded" ]; then
    SOURCE_COMMITS[$builtin_name]=$recorded
  fi
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
