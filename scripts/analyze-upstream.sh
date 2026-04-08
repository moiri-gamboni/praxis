#!/usr/bin/env bash
# Analyzes upstream changes, applies worthwhile ones, and opens a PR.
#
# Tracks analysis state via committed hashes in upstream.json (survives
# fresh clones). Per-source commit hashes identify which upstream repos
# changed; the upstream branch commit hash enables diffing.
#
# Usage: scripts/analyze-upstream.sh [--auto]
#   --auto: non-interactive (for cron). Skips if no changes found.
#
# Prerequisites:
#   - claude CLI must be available
#   - gh CLI must be authenticated (for PR creation)
#   - jq must be installed
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUTO_MODE=false
DATE=$(date +%Y-%m-%d)
BRANCH="upstream-sync/$DATE"
UPSTREAM_JSON="$REPO_ROOT/upstream.json"

for arg in "$@"; do
  case "$arg" in
    --auto) AUTO_MODE=true ;;
  esac
done

cd "$REPO_ROOT"

# --- Sync upstream first ---
"$REPO_ROOT/scripts/sync-upstream.sh"

UPSTREAM_HEAD=$(git rev-parse upstream)

# --- Read stored state from upstream.json ---
LAST_COMMIT=$(jq -r '.last_analyzed_upstream_commit // empty' "$UPSTREAM_JSON")

# --- Read per-source hashes from upstream branch and compare ---
NEW_SOURCE_COMMITS=$(git show upstream:_source_commits.json 2>/dev/null || echo "{}")

echo ""
echo "=== Source commit comparison ==="
changed_sources=()
for plugin in $(jq -r '.sources | keys[]' "$UPSTREAM_JSON"); do
  old_hash=$(jq -r --arg p "$plugin" '.sources[$p].last_analyzed // empty' "$UPSTREAM_JSON")
  new_hash=$(jq -r --arg p "$plugin" '.[$p] // empty' <<< "$NEW_SOURCE_COMMITS")

  if [ -z "$old_hash" ]; then
    echo "  $plugin: first analysis (${new_hash:0:8})"
    changed_sources+=("$plugin")
  elif [ "$old_hash" != "$new_hash" ]; then
    echo "  $plugin: changed (${old_hash:0:8} -> ${new_hash:0:8})"
    changed_sources+=("$plugin")
  else
    echo "  $plugin: unchanged (${old_hash:0:8})"
  fi
done
echo ""

# --- Determine if there's anything to analyze ---
if [ ${#changed_sources[@]} -eq 0 ]; then
  echo "No upstream sources have changed since last analysis."
  exit 0
fi

# --- Get the diff ---
if [ -z "$LAST_COMMIT" ]; then
  echo "First analysis: comparing all upstream content against praxis."
  EMPTY_TREE=$(git hash-object -t tree /dev/null)
  DIFF_STAT=$(git diff --stat "$EMPTY_TREE" "$UPSTREAM_HEAD")
  CHANGED_FILES=$(git diff --name-only "$EMPTY_TREE" "$UPSTREAM_HEAD")
  DIFF_RANGE="(initial)"
elif ! git cat-file -e "$LAST_COMMIT" 2>/dev/null; then
  echo "Warning: stored commit $LAST_COMMIT not found in history."
  echo "Treating as first analysis."
  EMPTY_TREE=$(git hash-object -t tree /dev/null)
  DIFF_STAT=$(git diff --stat "$EMPTY_TREE" "$UPSTREAM_HEAD")
  CHANGED_FILES=$(git diff --name-only "$EMPTY_TREE" "$UPSTREAM_HEAD")
  DIFF_RANGE="(initial, previous commit lost)"
elif [ "$UPSTREAM_HEAD" = "$LAST_COMMIT" ]; then
  echo "Upstream branch unchanged since last analysis."
  echo "Updating source hashes in upstream.json..."
  for plugin in $(jq -r '.sources | keys[]' "$UPSTREAM_JSON"); do
    new_hash=$(jq -r --arg p "$plugin" '.[$p] // empty' <<< "$NEW_SOURCE_COMMITS")
    if [ -n "$new_hash" ]; then
      tmp=$(jq --arg p "$plugin" --arg h "$new_hash" '.sources[$p].last_analyzed = $h' "$UPSTREAM_JSON")
      echo "$tmp" > "$UPSTREAM_JSON"
    fi
  done
  echo "Done. No content changes to analyze."
  exit 0
else
  DIFF_STAT=$(git diff --stat "$LAST_COMMIT".."$UPSTREAM_HEAD")
  CHANGED_FILES=$(git diff --name-only "$LAST_COMMIT".."$UPSTREAM_HEAD")
  DIFF_RANGE="$LAST_COMMIT..$UPSTREAM_HEAD"
fi

echo "=== Upstream changes to analyze ==="
echo "Range: $DIFF_RANGE"
echo "$DIFF_STAT"
echo ""

# --- Ensure clean working tree ---
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: working tree has uncommitted changes. Commit or stash first."
  exit 1
fi

# --- Create sync branch ---
MAIN_BRANCH=$(git branch --show-current)
git checkout -b "$BRANCH" 2>/dev/null || {
  echo "Branch $BRANCH already exists. Delete it first or wait until tomorrow."
  exit 1
}

# Ensure we return to main branch on exit
cleanup() {
  cd "$REPO_ROOT"
  git checkout "$MAIN_BRANCH" --quiet 2>/dev/null || true
}
trap cleanup EXIT

# --- Build the analysis prompt ---
PROVENANCE=$(cat "$UPSTREAM_JSON")
SOURCES_CHANGED=$(printf '%s, ' "${changed_sources[@]}" | sed 's/, $//')

PROMPT="You are analyzing upstream changes to Claude Code plugins that the \"praxis\" plugin was forked from. You will evaluate each change, apply the worthwhile ones to praxis, and commit the result.

## Your Task

For each upstream change, evaluate whether it should be incorporated into praxis. Be conservative: only apply genuine improvements (bug fixes, meaningful new content, better wording that changes meaning). Skip cosmetic changes (whitespace, minor rewording that doesn't change meaning, comment tweaks).

If you find changes worth incorporating, edit the praxis files directly and commit. If nothing is worth incorporating, just report that and make no changes.

## Context

Praxis was created by combining the best of several upstream plugins. The provenance mapping below shows which praxis files came from which upstream sources and how much they were adapted.

Adaptation levels:
- \"near-copy\": praxis file is ~85-95% identical to upstream (minor namespace/model changes). Upstream improvements almost certainly apply.
- \"moderate\": praxis file was restructured or reformatted (~60-80% similar). Changes need careful evaluation.
- \"significant\": praxis file merges multiple upstream sources (~50% new). Changes need careful evaluation.
- \"new\": praxis file has no upstream equivalent. Upstream changes may inspire improvements but won't apply directly.

Also look for entirely NEW files upstream that don't map to any existing praxis file. These could be new skills, agents, or commands worth adding.

Sources that changed: $SOURCES_CHANGED

## Provenance Mapping

$PROVENANCE

## Upstream Changes

Diff range: $DIFF_RANGE

Read the changed files on the upstream branch and the corresponding praxis files to understand the full context.

\`\`\`
$DIFF_STAT
\`\`\`

Changed files:
\`\`\`
$CHANGED_FILES
\`\`\`

## Instructions

1. For each changed upstream file, read it: git show upstream:<path>
2. Check upstream.json to find the corresponding praxis file
3. If a praxis mapping exists, read the praxis file too
4. Compare and decide whether the upstream change is a genuine improvement
5. If yes, apply the change to the praxis file using Edit or Write
6. For NEW upstream files with no praxis mapping, evaluate if they'd be a useful addition and create the file if so
7. After all changes are applied, commit with a descriptive message summarizing what was incorporated and why
8. If no changes are worth incorporating, make no edits and explain why

IMPORTANT:
- Preserve praxis adaptations (model: opus, namespace changes, merged content). Don't revert those.
- For near-copy files, apply upstream changes directly.
- For moderate/significant files, adapt the upstream improvement to fit praxis's version.
- Do NOT make changes beyond what upstream changed. No opportunistic refactoring."

# --- Invoke Claude ---
echo "Analyzing upstream changes with Claude..."
echo ""

ALLOWED_TOOLS='Bash(git show:*),Bash(git diff:*),Bash(git log:*),Bash(git add:*),Bash(git commit:*),Read,Glob,Grep,Edit,Write'

if [ "$AUTO_MODE" = true ]; then
  echo "$PROMPT" | claude -p --allowedTools "$ALLOWED_TOOLS" 2>/dev/null
else
  echo "$PROMPT" | claude -p --allowedTools "$ALLOWED_TOOLS"
fi

# --- Check if Claude made any commits ---
COMMITS_AHEAD=$(git rev-list "$MAIN_BRANCH".."$BRANCH" --count)

if [ "$COMMITS_AHEAD" -eq 0 ]; then
  echo ""
  echo "No changes applied. Cleaning up branch."
  git checkout "$MAIN_BRANCH" --quiet
  git branch -D "$BRANCH" --quiet
  trap - EXIT
else
  echo ""
  echo "=== $COMMITS_AHEAD commit(s) on $BRANCH ==="
  git log "$MAIN_BRANCH".."$BRANCH" --oneline
  echo ""

  # Push and create PR
  git push -u origin "$BRANCH" --quiet
  PR_URL=$(gh pr create \
    --title "Upstream sync $DATE" \
    --body "$(cat <<EOF
## Upstream Plugin Changes

Automated analysis of upstream changes from source plugins.

### Sources changed
$SOURCES_CHANGED

### Changes since last analysis
\`\`\`
$DIFF_STAT
\`\`\`

Review the commits below. Each incorporates a specific upstream improvement that was evaluated as genuinely beneficial.

---
Generated by \`scripts/analyze-upstream.sh\`
EOF
)" 2>&1)

  echo "PR created: $PR_URL"

  # Return to main branch (trap will also do this, but be explicit)
  git checkout "$MAIN_BRANCH" --quiet
  trap - EXIT
fi

# --- Update upstream.json with new hashes ---
echo ""
echo "Updating upstream.json with analyzed hashes..."
cd "$REPO_ROOT"
CURRENT=$(git branch --show-current)
if [ "$CURRENT" != "$MAIN_BRANCH" ]; then
  git checkout "$MAIN_BRANCH" --quiet
fi

for plugin in $(jq -r '.sources | keys[]' "$UPSTREAM_JSON"); do
  new_hash=$(jq -r --arg p "$plugin" '.[$p] // empty' <<< "$NEW_SOURCE_COMMITS")
  if [ -n "$new_hash" ]; then
    tmp=$(jq --arg p "$plugin" --arg h "$new_hash" '.sources[$p].last_analyzed = $h' "$UPSTREAM_JSON")
    echo "$tmp" > "$UPSTREAM_JSON"
  fi
done
tmp=$(jq --arg c "$UPSTREAM_HEAD" '.last_analyzed_upstream_commit = $c' "$UPSTREAM_JSON")
echo "$tmp" > "$UPSTREAM_JSON"

git add "$UPSTREAM_JSON"
git commit -m "Update upstream.json with analyzed commit hashes" --quiet
echo "Committed updated hashes to upstream.json."
echo "Next run will only analyze changes after this point."
