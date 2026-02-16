#!/usr/bin/env bash
# Analyzes upstream changes, applies worthwhile ones, and opens a PR.
#
# Uses a git tag (upstream-analyzed) to track what's already been analyzed.
# First run establishes the baseline. Subsequent runs diff from the last
# analysis point.
#
# Usage: scripts/analyze-upstream.sh [--auto]
#   --auto: non-interactive (for cron). Skips if no changes found.
#
# Prerequisites:
#   - upstream branch must exist (run sync-upstream.sh first)
#   - claude CLI must be available
#   - gh CLI must be authenticated (for PR creation)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUTO_MODE=false
TAG="upstream-analyzed"
DATE=$(date +%Y-%m-%d)
BRANCH="upstream-sync/$DATE"

for arg in "$@"; do
  case "$arg" in
    --auto) AUTO_MODE=true ;;
  esac
done

cd "$REPO_ROOT"

# --- Check upstream branch exists ---
if ! git rev-parse --verify upstream &>/dev/null; then
  echo "Error: upstream branch not found. Run scripts/sync-upstream.sh first."
  exit 1
fi

UPSTREAM_HEAD=$(git rev-parse upstream)

# --- Handle first run: establish baseline ---
if ! git rev-parse --verify "$TAG" &>/dev/null; then
  echo "First run: establishing baseline at current upstream state."
  echo "No changes to analyze yet."
  git tag "$TAG" "$UPSTREAM_HEAD"
  echo "Tagged $UPSTREAM_HEAD as $TAG."
  echo "Run sync-upstream.sh again after upstream plugins update, then re-run this script."
  exit 0
fi

# --- Check if there are new changes since last analysis ---
LAST_ANALYZED=$(git rev-parse "$TAG")

if [ "$UPSTREAM_HEAD" = "$LAST_ANALYZED" ]; then
  echo "No new upstream changes since last analysis."
  exit 0
fi

# --- Get the diff ---
DIFF_STAT=$(git diff --stat "$TAG".."$UPSTREAM_HEAD")
CHANGED_FILES=$(git diff --name-only "$TAG".."$UPSTREAM_HEAD")

echo "=== Upstream changes since last analysis ==="
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
PROVENANCE=$(cat "$REPO_ROOT/upstream.json")

PROMPT="You are analyzing upstream changes to Claude Code plugins that the \"praxis\" plugin was forked from. You will evaluate each change, apply the worthwhile ones to praxis, and commit the result.

## Your Task

For each upstream change, evaluate whether it should be incorporated into praxis. Be conservative: only apply genuine improvements (bug fixes, meaningful new content, better wording that changes meaning). Skip cosmetic changes (whitespace, minor rewording that doesn't change meaning, comment tweaks).

If you find changes worth incorporating, edit the praxis files directly and commit. If nothing is worth incorporating, just report that and make no changes.

## Context

Praxis was created by combining the best of 4 plugins: superpowers, feature-dev, pr-review-toolkit, and commit-commands. The provenance mapping below shows which praxis files came from which upstream sources and how much they were adapted.

Adaptation levels:
- \"near-copy\": praxis file is ~85-95% identical to upstream (minor namespace/model changes). Upstream improvements almost certainly apply.
- \"moderate\": praxis file was restructured or reformatted (~60-80% similar). Changes need careful evaluation.
- \"significant\": praxis file merges multiple upstream sources (~50% new). Changes need careful evaluation.
- \"new\": praxis file has no upstream equivalent. Upstream changes may inspire improvements but won't apply directly.

Also look for entirely NEW files upstream that don't map to any existing praxis file. These could be new skills, agents, or commands worth adding.

## Provenance Mapping

$PROVENANCE

## Upstream Changes

The diff is between commits $LAST_ANALYZED and $UPSTREAM_HEAD on the upstream branch.

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

Automated analysis of upstream changes from superpowers, feature-dev, pr-review-toolkit, and commit-commands.

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

# --- Move the tag forward ---
git tag -f "$TAG" "$UPSTREAM_HEAD"
echo ""
echo "Updated $TAG tag to $UPSTREAM_HEAD."
echo "Next run will only analyze changes after this point."
