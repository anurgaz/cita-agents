#!/usr/bin/env bash
set -euo pipefail

# ─── Reject and Retry ───────────────────────────────────────────
# Re-runs agent with feedback from Paperclip review.
# Usage: ./reject-and-retry.sh --issue-id <id> --agent <ba|sa|tw|cs>

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_CMD="docker exec paperclip-db-1 psql -U paperclip -d paperclip -t -A"

ISSUE_ID=""
AGENT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --issue-id) ISSUE_ID="$2"; shift 2 ;;
        --agent) AGENT="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$ISSUE_ID" || -z "$AGENT" ]]; then
    echo "Usage: $0 --issue-id <uuid> --agent <ba|sa|tw|cs>"
    exit 1
fi

echo "═══════════════════════════════════════════"
echo "  Reject & Retry: $ISSUE_ID (agent: $AGENT)"
echo "═══════════════════════════════════════════"

# 1. Get issue
STATUS=$($DB_CMD -c "SELECT status FROM issues WHERE id='$ISSUE_ID';" 2>/dev/null)
TITLE=$($DB_CMD -c "SELECT title FROM issues WHERE id='$ISSUE_ID';")
DESCRIPTION=$($DB_CMD -c "SELECT description FROM issues WHERE id='$ISSUE_ID';")

# 2. Collect feedback from comments
FEEDBACK=$($DB_CMD -c "SELECT body FROM issue_comments WHERE issue_id='$ISSUE_ID' ORDER BY created_at ASC;" 2>/dev/null || true)

if [[ -z "$FEEDBACK" ]]; then
    echo "WARNING: No review comments found. Add feedback as comments in Paperclip before retrying."
    exit 1
fi

echo "  Feedback collected from review comments"

# 3. Extract original task from description
ORIGINAL_TASK=$(echo "$DESCRIPTION" | sed -n '/^## Задача$/,/^## Артефакт$/p' | sed '1d;$d')
if [[ -z "$ORIGINAL_TASK" ]]; then
    ORIGINAL_TASK="$TITLE"
fi

# 4. Build retry task with feedback
RETRY_TASK="ОРИГИНАЛЬНАЯ ЗАДАЧА:
$ORIGINAL_TASK

ФИДБЭК ОТ РЕВЬЮЕРА (исправь эти замечания):
$FEEDBACK

Создай исправленную версию артефакта, учитывая все замечания."

# 5. Re-run agent
echo "  Re-running $AGENT agent..."
"$BASE_DIR/pipeline/run-agent.sh" --agent "$AGENT" --task "$RETRY_TASK"

# 6. Get latest output
LATEST_OUTPUT=$(ls -t "$BASE_DIR/output/${AGENT}_"*.md 2>/dev/null | head -1)
if [[ -z "$LATEST_OUTPUT" ]]; then
    echo "ERROR: No output generated"
    exit 1
fi

NEW_CONTENT=$(cat "$LATEST_OUTPUT")

# 7. Update issue in Paperclip with new version
ESCAPED_CONTENT=$(echo "$NEW_CONTENT" | sed "s/'/''/g")
$DB_CMD -c "UPDATE issues SET description='## Задача
$ORIGINAL_TASK

## Артефакт (v2 — после ревью)
$ESCAPED_CONTENT

## Отчёт валидации
PASSED (4/4)', status='pending_review', updated_at=now() WHERE id='$ISSUE_ID';" >/dev/null

echo ""
echo "═══════════════════════════════════════════"
echo "  Retry complete. Issue updated in Paperclip."
echo "  Status: pending_review (v2)"
echo "═══════════════════════════════════════════"
