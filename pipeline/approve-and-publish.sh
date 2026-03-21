#!/usr/bin/env bash
set -euo pipefail

# ─── Approve and Publish ────────────────────────────────────────
# Checks if PR is merged, updates Paperclip status, cleans up branch.
# Usage: ./approve-and-publish.sh --issue CIT-1

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_CMD="docker exec paperclip-db-1 psql -U paperclip -d paperclip -t -A"
CITA_COMPANY_ID="ed133e66-a694-470e-8e94-4ea412647ce5"

ISSUE_KEY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --issue) ISSUE_KEY="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$ISSUE_KEY" ]]; then
    echo "Usage: $0 --issue CIT-N"
    exit 1
fi

echo "═══════════════════════════════════════════"
echo "  Approve & Publish: $ISSUE_KEY"
echo "═══════════════════════════════════════════"

BRANCH="review/${ISSUE_KEY}"

# 1. Find PR by branch
cd "$BASE_DIR"
PR_JSON=$(gh pr view "$BRANCH" --json number,state,url,mergedAt 2>/dev/null || echo "")

if [[ -z "$PR_JSON" ]]; then
    echo "ERROR: No PR found for branch $BRANCH"
    exit 1
fi

PR_STATE=$(echo "$PR_JSON" | jq -r '.state')
PR_URL=$(echo "$PR_JSON" | jq -r '.url')
PR_NUMBER=$(echo "$PR_JSON" | jq -r '.number')

echo "  PR: $PR_URL"
echo "  State: $PR_STATE"

if [[ "$PR_STATE" == "MERGED" ]]; then
    echo ""
    echo "  PR is merged. Updating Paperclip..."

    # Update issue in Paperclip DB
    $DB_CMD -c "UPDATE issues SET status='published', completed_at=now(), updated_at=now() WHERE identifier='$ISSUE_KEY' AND company_id='$CITA_COMPANY_ID';" >/dev/null

    # Delete remote branch (if exists)
    git push origin --delete "$BRANCH" 2>/dev/null || true

    echo ""
    echo "═══════════════════════════════════════════"
    echo "  Published! $ISSUE_KEY → status: published"
    echo "  Pages will update automatically."
    echo "═══════════════════════════════════════════"
elif [[ "$PR_STATE" == "OPEN" ]]; then
    echo ""
    echo "  PR not yet merged."
    echo "  Review at: $PR_URL"
    echo "  After approving, merge the PR, then run this script again."
else
    echo ""
    echo "  PR state: $PR_STATE (closed without merge?)"
    echo "  Check manually: $PR_URL"
fi
