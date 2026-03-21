#!/usr/bin/env bash
set -euo pipefail

# ─── Agent Pipeline Runner ──────────────────────────────────────
# Usage: ./run-agent.sh --agent ba --task "Create user story for..." [--context file1.md file2.md] [--mode post-deploy]

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$BASE_DIR/output"
VALIDATE_SCRIPT="$BASE_DIR/validation/validate.sh"
MAX_RETRIES=3

# ─── Parse arguments ────────────────────────────────────────────
AGENT=""
TASK=""
CONTEXT_FILES=()
MODE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)
            AGENT="$2"
            shift 2
            ;;
        --task)
            TASK="$2"
            shift 2
            ;;
        --context)
            shift
            while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                CONTEXT_FILES+=("$1")
                shift
            done
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$AGENT" || -z "$TASK" ]]; then
    echo "Usage: $0 --agent <ba|sa|tw|cs> --task \"task description\" [--context file1.md ...] [--mode post-deploy]"
    exit 1
fi

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "ERROR: ANTHROPIC_API_KEY environment variable is not set"
    exit 1
fi

# ─── Resolve agent ───────────────────────────────────────────────
AGENT_DIR="$BASE_DIR/agents/${AGENT}-agent"
SYSTEM_PROMPT_FILE="$AGENT_DIR/system-prompt.md"

if [[ ! -f "$SYSTEM_PROMPT_FILE" ]]; then
    echo "ERROR: Agent not found: $AGENT (expected $SYSTEM_PROMPT_FILE)"
    exit 1
fi

echo "═══════════════════════════════════════════"
echo "  Agent: $AGENT"
echo "  Task: ${TASK:0:80}..."
echo "═══════════════════════════════════════════"

# ─── Build context ───────────────────────────────────────────────
SYSTEM_PROMPT=$(cat "$SYSTEM_PROMPT_FILE")

# Mandatory context files
MANDATORY_CONTEXT=(
    "$BASE_DIR/docs/context/glossary.md"
    "$BASE_DIR/docs/context/constraints.md"
    "$BASE_DIR/docs/context/decision-matrix.md"
)

# Agent-specific mandatory context
case "$AGENT" in
    sa)
        MANDATORY_CONTEXT+=(
            "$BASE_DIR/docs/context/tech-stack.md"
            "$BASE_DIR/docs/data/data-dictionary.md"
        )
        ;;
    tw)
        MANDATORY_CONTEXT+=(
            "$BASE_DIR/docs/context/tech-stack.md"
        )
        ;;
esac

CONTEXT_BLOCK=""
for ctx_file in "${MANDATORY_CONTEXT[@]}"; do
    if [[ -f "$ctx_file" ]]; then
        CONTEXT_BLOCK+="
--- $(basename "$ctx_file") ---
$(cat "$ctx_file")

"
    else
        echo "WARNING: Mandatory context file not found: $ctx_file"
    fi
done

# Additional context from --context
for ctx_file in "${CONTEXT_FILES[@]}"; do
    if [[ -f "$ctx_file" ]]; then
        CONTEXT_BLOCK+="
--- $(basename "$ctx_file") ---
$(cat "$ctx_file")

"
    else
        echo "WARNING: Context file not found: $ctx_file"
    fi
done

# TW post-deploy mode: add git diff
if [[ "$AGENT" == "tw" && "$MODE" == "post-deploy" ]]; then
    CITA_REPO="/root/cita"
    if [[ -d "$CITA_REPO/.git" ]]; then
        GIT_DIFF=$(cd "$CITA_REPO" && git log -1 --format="Commit: %h%nAuthor: %an%nDate: %ad%nMessage: %s%n" && git diff HEAD~1 HEAD --stat && echo "---" && git diff HEAD~1 HEAD)
        CONTEXT_BLOCK+="
--- git diff (last commit) ---
$GIT_DIFF

"
        echo "  Mode: post-deploy (git diff attached)"
    else
        echo "WARNING: Cita repo not found at $CITA_REPO, skipping git diff"
    fi
fi

# ─── Prepare output ─────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/${AGENT}_${TIMESTAMP}.md"

# ─── Call Claude API ─────────────────────────────────────────────
call_claude() {
    local user_message="$1"
    local response

    # Build JSON payload using jq for proper escaping
    local payload
    payload=$(jq -n \
        --arg model "claude-sonnet-4-6" \
        --arg system "$SYSTEM_PROMPT" \
        --arg content "$user_message" \
        '{
            model: $model,
            max_tokens: 8192,
            system: $system,
            messages: [{
                role: "user",
                content: $content
            }]
        }')

    response=$(curl -s -X POST "https://api.anthropic.com/v1/messages" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d "$payload")

    # Extract text from response
    local text
    text=$(echo "$response" | jq -r '.content[0].text // empty')

    if [[ -z "$text" ]]; then
        local error
        error=$(echo "$response" | jq -r '.error.message // "Unknown error"')
        echo "API Error: $error" >&2
        return 1
    fi

    echo "$text"
}

# ─── Main loop with retry ───────────────────────────────────────
USER_MESSAGE="КОНТЕКСТ:
$CONTEXT_BLOCK

ЗАДАЧА:
$TASK"

ATTEMPT=1
while [[ $ATTEMPT -le $MAX_RETRIES ]]; do
    echo ""
    echo "--- Attempt $ATTEMPT/$MAX_RETRIES ---"

    # Call Claude
    echo "  Calling Claude API..."
    RESULT=$(call_claude "$USER_MESSAGE")

    if [[ $? -ne 0 || -z "$RESULT" ]]; then
        echo "  ERROR: API call failed"
        ATTEMPT=$((ATTEMPT + 1))
        continue
    fi

    # Save result
    echo "$RESULT" > "$OUTPUT_FILE"
    echo "  Saved to: $OUTPUT_FILE"

    # Validate
    echo "  Running validation..."
    VALIDATION_OUTPUT=""
    if VALIDATION_OUTPUT=$("$VALIDATE_SCRIPT" "$OUTPUT_FILE" 2>&1); then
        echo ""
        echo "  Validation PASSED. Creating Paperclip issue..."

        # Create issue in Paperclip (cita.kz company)
        CITA_COMPANY_ID="ed133e66-a694-470e-8e94-4ea412647ce5"
        DB_CMD="docker exec paperclip-db-1 psql -U paperclip -d paperclip -t -A"
        AGENT_UPPER=$(echo "$AGENT" | tr "[:lower:]" "[:upper:]")

        # Get next issue number
        ISSUE_NUM=$($DB_CMD -c "SELECT COALESCE(MAX(issue_number),0)+1 FROM issues WHERE company_id='$CITA_COMPANY_ID';" 2>/dev/null || echo "1")

        # Build title
        ISSUE_TITLE="[$AGENT_UPPER] ${TASK:0:80}"

        # Escape content for SQL
        ARTIFACT_CONTENT=$(cat "$OUTPUT_FILE" | sed "s/'/''/g")
        VALIDATION_LOG=$(echo "$VALIDATION_OUTPUT" | sed "s/'/''/g" | head -30)

        ISSUE_DESC="## Задача
${TASK}

## Артефакт
${ARTIFACT_CONTENT}

## Отчёт валидации
${VALIDATION_LOG}

PASSED (all checks)"

        ESCAPED_DESC=$(echo "$ISSUE_DESC" | sed "s/'/''/g")

        # Find agent ID in Paperclip
        AGENT_ID=$($DB_CMD -c "SELECT id FROM agents WHERE company_id='$CITA_COMPANY_ID' AND name ILIKE '${AGENT}%' LIMIT 1;" 2>/dev/null || echo "")

        ISSUE_ID=$($DB_CMD -c "INSERT INTO issues (id, company_id, title, description, status, priority, issue_number, identifier, created_by_agent_id, created_at, updated_at) VALUES (gen_random_uuid(), '$CITA_COMPANY_ID', '$ISSUE_TITLE', '$ESCAPED_DESC', 'pending_review', 'medium', $ISSUE_NUM, 'CIT-$ISSUE_NUM', $([ -n "$AGENT_ID" ] && echo "'$AGENT_ID'" || echo NULL), now(), now()) RETURNING id;" 2>/dev/null || echo "FAILED")

        if [[ "$ISSUE_ID" != "FAILED" && -n "$ISSUE_ID" ]]; then
            echo ""
            echo "═══════════════════════════════════════════"
            echo "  PASSED - Sent to Paperclip for review"
            echo "  Output: $OUTPUT_FILE"
            echo "  Paperclip: CIT-$ISSUE_NUM (id: $ISSUE_ID)"
            echo "═══════════════════════════════════════════"
        else
            echo ""
            echo "═══════════════════════════════════════════"
            echo "  PASSED - Ready for review"
            echo "  Output: $OUTPUT_FILE"
            echo "  (Paperclip issue creation failed - review manually)"
            echo "═══════════════════════════════════════════"
        fi
        exit 0
    else
        echo "  Validation FAILED"

        if [[ $ATTEMPT -lt $MAX_RETRIES ]]; then
            echo "  Retrying with validation errors as feedback..."
            USER_MESSAGE="КОНТЕКСТ:
$CONTEXT_BLOCK

ЗАДАЧА:
$TASK

ПРЕДЫДУЩАЯ ПОПЫТКА ПРОВАЛИЛА ВАЛИДАЦИЮ. Исправь следующие ошибки:
$VALIDATION_OUTPUT

Вот твой предыдущий ответ (исправь его):
$RESULT"
        fi
    fi

    ATTEMPT=$((ATTEMPT + 1))
done

echo ""
echo "═══════════════════════════════════════════"
echo "  FAILED after $MAX_RETRIES attempts"
echo "  Last output: $OUTPUT_FILE"
echo "  Review manually and fix validation errors"
echo "═══════════════════════════════════════════"
exit 1
