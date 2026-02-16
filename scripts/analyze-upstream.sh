#!/usr/bin/env bash
# Analyzes upstream changes and invokes Claude to evaluate what's worth
# incorporating into praxis.
#
# Uses a git tag (upstream-analyzed) to track what's already been analyzed.
# First run establishes the baseline. Subsequent runs diff from the last
# analysis point.
#
# Usage: scripts/analyze-upstream.sh [--auto]
#   --auto: non-interactive, save report only (for cron)
#
# Prerequisites:
#   - upstream branch must exist (run sync-upstream.sh first)
#   - claude CLI must be available
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUTO_MODE=false
TAG="upstream-analyzed"

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

# --- Build the analysis prompt ---
PROVENANCE=$(cat "$REPO_ROOT/upstream.json")

PROMPT="You are analyzing upstream changes to Claude Code plugins that the \"praxis\" plugin was forked from.

## Your Task

For each upstream change, evaluate whether it should be incorporated into praxis. Be conservative: only recommend genuine improvements (bug fixes, meaningful new content, better wording that changes meaning). Skip cosmetic changes (whitespace, minor rewording that doesn't change meaning, comment tweaks).

## Context

Praxis was created by combining the best of 4 plugins: superpowers, feature-dev, pr-review-toolkit, and commit-commands. The provenance mapping below shows which praxis files came from which upstream sources and how much they were adapted.

Adaptation levels:
- \"near-copy\": praxis file is ~85-95% identical to upstream (minor namespace/model changes)
- \"moderate\": praxis file was restructured or reformatted (~60-80% similar)
- \"significant\": praxis file merges multiple upstream sources (~50% new)
- \"new\": praxis file has no upstream equivalent

For \"near-copy\" files, upstream improvements almost certainly apply.
For \"moderate\" and \"significant\" files, changes need careful evaluation.
For \"new\" files, upstream changes to the original source may inspire improvements but won't apply directly.

Also look for entirely NEW files upstream that don't map to any existing praxis file. These could be new skills, agents, or commands worth adding.

## Provenance Mapping

$PROVENANCE

## Upstream Changes

The diff is between commits $LAST_ANALYZED and $UPSTREAM_HEAD on the upstream branch.

Read the changed files on the upstream branch and the corresponding praxis files on the main/master branch to understand the full context. The diff summary below shows which files to examine.

\`\`\`
$DIFF_STAT
\`\`\`

Changed files:
\`\`\`
$CHANGED_FILES
\`\`\`

## Instructions

1. For each changed upstream file, read it from the upstream branch: git show upstream:<path>
2. Check upstream.json to find the corresponding praxis file
3. If a praxis mapping exists, read the praxis file too
4. Compare and evaluate whether the upstream change is worth incorporating
5. For NEW upstream files with no praxis mapping, evaluate if they'd be a useful addition

## Output Format

For each relevant change, output:

### [plugin/path] -> [praxis/path or NEW]
- **Change**: What changed upstream (1-2 sentences)
- **Type**: bug-fix | improvement | new-content | cosmetic
- **Recommendation**: incorporate | skip | evaluate-manually
- **Rationale**: Why (1-2 sentences)
- **Action**: Specific edit to make in praxis (if incorporating)

End with a summary: how many changes reviewed, how many recommended for incorporation.

If no changes are worth incorporating, say so clearly."

# --- Invoke Claude ---
REPORT_DIR="$REPO_ROOT/reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/upstream-$(date +%Y-%m-%d).md"

echo "Analyzing upstream changes with Claude..."
echo ""

if [ "$AUTO_MODE" = true ]; then
  echo "$PROMPT" | claude -p --allowedTools 'Bash(git show:*),Bash(git diff:*),Read,Glob,Grep' > "$REPORT_FILE" 2>/dev/null
  echo "Report saved to $REPORT_FILE"
else
  echo "$PROMPT" | claude -p --allowedTools 'Bash(git show:*),Bash(git diff:*),Read,Glob,Grep' | tee "$REPORT_FILE"
  echo ""
  echo "Report saved to $REPORT_FILE"
fi

# --- Move the tag forward ---
git tag -f "$TAG" "$UPSTREAM_HEAD"
echo ""
echo "Updated $TAG tag to $UPSTREAM_HEAD."
echo "Next run will only analyze changes after this point."
