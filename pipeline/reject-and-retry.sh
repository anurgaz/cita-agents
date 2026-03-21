#!/usr/bin/env bash
set -euo pipefail

# ─── Reject and Retry ───────────────────────────────────────────
# Gets feedback from PR comments, closes PR, re-runs agent.
# Usage: ./reject-and-retry.sh --issue CIT-1 --agent ba

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_CMD="docker exec paperclip-db-1 psql -U paperclip -d paperclip -t -A"
CITA_COMPANY_ID="ed133e66-a694-470e-8e94-4ea412647ce5"

ISSUE_KEY=""
AGENT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --issue) ISSUE_KEY="$2"; shift 2 ;;
        --agent) AGENT="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$ISSUE_KEY" || -z "$AGENT" ]]; then
    echo "Usage: $0 --issue CIT-N --agent <ba|sa|tw|cs>"
    exit 1
fi

echo "═══════════════════════════════════════════"
echo "  Reject & Retry: $ISSUE_KEY (agent: $AGENT)"
echo "═══════════════════════════════════════════"

BRANCH="review/${ISSUE_KEY}"

# 1. Get PR comments as feedback
cd "$BASE_DIR"
PR_JSON=$(gh pr view "$BRANCH" --json number,body,comments,reviews 2>/dev/null || echo "")

if [[ -z "$PR_JSON" ]]; then
    echo "ERROR: No PR found for branch $BRANCH"
    exit 1
fi

PR_NUMBER=$(echo "$PR_JSON" | jq -r '.number')

# Collect review comments
FEEDBACK=""
REVIEW_COMMENTS=$(echo "$PR_JSON" | jq -r '.reviews[]?.body // empty' 2>/dev/null || true)
PR_COMMENTS=$(echo "$PR_JSON" | jq -r '.comments[]?.body // empty' 2>/dev/null || true)

# Also get inline review comments from the API
INLINE_COMMENTS=$(gh api "repos/anurgaz/cita-agents/pulls/${PR_NUMBER}/comments" --jq '.[].body' 2>/dev/null || true)

FEEDBACK="${REVIEW_COMMENTS}
${PR_COMMENTS}
${INLINE_COMMENTS}"
FEEDBACK=$(echo "$FEEDBACK" | sed '/^$/d')

if [[ -z "$FEEDBACK" ]]; then
    echo "WARNING: No review comments found in PR #${PR_NUMBER}."
    echo "Add comments to the PR before rejecting, or provide feedback manually."
    exit 1
fi

echo "  Feedback collected from PR #${PR_NUMBER}:"
echo "$FEEDBACK" | head -10 | sed 's/^/    /'
echo ""

# 2. Get original task from Paperclip
ORIGINAL_TASK=$($DB_CMD -c "SELECT title FROM issues WHERE identifier='$ISSUE_KEY' AND company_id='$CITA_COMPANY_ID';" 2>/dev/null || echo "$ISSUE_KEY")
# Strip [AGENT] prefix from title
ORIGINAL_TASK=$(echo "$ORIGINAL_TASK" | sed 's/^\[.*\] //')

# 3. Close PR without merge
echo "  Closing PR #${PR_NUMBER}..."
gh pr close "$PR_NUMBER" 2>/dev/null || true

# 4. Delete branch
git push origin --delete "$BRANCH" 2>/dev/null || true
git branch -D "$BRANCH" 2>/dev/null || true

# 5. Update Paperclip issue status
$DB_CMD -c "UPDATE issues SET status='rejected', updated_at=now() WHERE identifier='$ISSUE_KEY' AND company_id='$CITA_COMPANY_ID';" >/dev/null

# 6. Re-run agent with feedback
echo "  Re-running $AGENT agent with feedback..."
echo ""

RETRY_TASK="${ORIGINAL_TASK}

ФИДБЭК ОТ РЕВЬЮЕРА (исправь эти замечания):
${FEEDBACK}

Создай исправленную версию артефакта, учитывая все замечания ревьюера."

"$BASE_DIR/pipeline/run-agent.sh" --agent "$AGENT" --task "$RETRY_TASK"
