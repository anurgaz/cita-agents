#!/usr/bin/env bash
set -euo pipefail

# ─── Approve and Publish ────────────────────────────────────────
# Publishes an approved Paperclip issue to the repo.
# Usage: ./approve-and-publish.sh --issue-id <id> --target-path <path>

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_CMD="docker exec paperclip-db-1 psql -U paperclip -d paperclip -t -A"

ISSUE_ID=""
TARGET_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --issue-id) ISSUE_ID="$2"; shift 2 ;;
        --target-path) TARGET_PATH="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$ISSUE_ID" || -z "$TARGET_PATH" ]]; then
    echo "Usage: $0 --issue-id <uuid> --target-path <path>"
    exit 1
fi

echo "═══════════════════════════════════════════"
echo "  Approve & Publish: $ISSUE_ID"
echo "═══════════════════════════════════════════"

# 1. Get issue from Paperclip DB
STATUS=$($DB_CMD -c "SELECT status FROM issues WHERE id='$ISSUE_ID';" 2>/dev/null)
if [[ -z "$STATUS" ]]; then
    echo "ERROR: Issue $ISSUE_ID not found"
    exit 1
fi

if [[ "$STATUS" != "approved" ]]; then
    echo "ERROR: Issue status is '$STATUS', expected 'approved'"
    echo "Change status to 'approved' in Paperclip first."
    exit 1
fi

# 2. Get title and description (artifact content)
TITLE=$($DB_CMD -c "SELECT title FROM issues WHERE id='$ISSUE_ID';")
DESCRIPTION=$($DB_CMD -c "SELECT description FROM issues WHERE id='$ISSUE_ID';")

# 3. Check for comments with revisions (use latest comment as content if exists)
LATEST_COMMENT=$($DB_CMD -c "SELECT body FROM issue_comments WHERE issue_id='$ISSUE_ID' ORDER BY created_at DESC LIMIT 1;" 2>/dev/null || true)

if [[ -n "$LATEST_COMMENT" && "$LATEST_COMMENT" != "" ]]; then
    echo "  Found review comment — using revised version"
    CONTENT="$LATEST_COMMENT"
else
    # Extract artifact from description (between "Содержимое:" and "Отчёт валидации:")
    CONTENT=$(echo "$DESCRIPTION" | sed -n '/^## Артефакт$/,/^## Отчёт валидации$/p' | sed '1d;$d')
    if [[ -z "$CONTENT" ]]; then
        CONTENT="$DESCRIPTION"
    fi
fi

# 4. Determine agent from title
AGENT=$(echo "$TITLE" | grep -oP '(?<=\[)\w+(?=\])' | head -1 | tr '[:upper:]' '[:lower:]')

# 5. Save file
mkdir -p "$BASE_DIR/$TARGET_PATH"
FILENAME=$(echo "$TITLE" | sed 's/\[.*\] //' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 60)
FILEPATH="$BASE_DIR/$TARGET_PATH/${FILENAME}.md"
echo "$CONTENT" > "$FILEPATH"
echo "  Saved: $FILEPATH"

# 6. Git commit and push
cd "$BASE_DIR"
git add "$FILEPATH"
COMMIT_MSG="docs: [$AGENT] $TITLE (approved via Paperclip #$ISSUE_ID)"
git commit -m "$COMMIT_MSG"
GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no' git push origin main

# 7. Update issue status to published
$DB_CMD -c "UPDATE issues SET status='published', completed_at=now(), updated_at=now() WHERE id='$ISSUE_ID';" >/dev/null

echo ""
echo "═══════════════════════════════════════════"
echo "  Published! Commit: $(git rev-parse --short HEAD)"
echo "  File: $FILEPATH"
echo "  GitHub Pages will update automatically."
echo "═══════════════════════════════════════════"
