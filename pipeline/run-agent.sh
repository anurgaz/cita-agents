#!/usr/bin/env bash
set -euo pipefail

# ─── Agent Pipeline Runner ──────────────────────────────────────
# Usage: ./run-agent.sh --agent ba --task "Create user story for..." [--context file1.md file2.md] [--mode post-deploy]

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$BASE_DIR/output"
VALIDATE_SCRIPT="$BASE_DIR/validation/validate.sh"
MAX_RETRIES=3

# Paperclip DB
CITA_COMPANY_ID="ed133e66-a694-470e-8e94-4ea412647ce5"
DB_CMD="docker exec paperclip-db-1 psql -U paperclip -d paperclip -t -A"

# ─── Parse arguments ────────────────────────────────────────────
AGENT=""
TASK=""
CONTEXT_FILES=()
MODE=""
FEEDBACK=""

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
        --feedback)
            FEEDBACK="$2"
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

echo ""
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

# ─── Detect artifact type → target directory ────────────────────
detect_target_dir() {
    local file="$1"
    local content
    content=$(cat "$file")

    if echo "$content" | grep -qi "User Story\|US-[0-9]"; then
        echo "docs/artifacts/user-stories"
    elif echo "$content" | grep -qi "API Spec\|API спецификац\|endpoint.*method\|OpenAPI"; then
        echo "docs/artifacts/api-specs"
    elif echo "$content" | grep -qi "Test Case\|TC-[0-9]\|тест-кейс"; then
        echo "docs/artifacts/test-cases"
    elif echo "$content" | grep -qi "How-to\|How to\|Как подключить\|Как настроить\|Пошаговая"; then
        echo "docs/artifacts/how-to-guides"
    elif echo "$content" | grep -qi "API Reference\|эндпоинт.*описание"; then
        echo "docs/artifacts/api-reference"
    elif echo "$content" | grep -qi "Changelog\|CHANGELOG\|изменения.*версия"; then
        echo "docs/artifacts/changelog"
    elif echo "$content" | grep -qi "BUG\|Bug Report\|баг\|дефект"; then
        echo "docs/artifacts/bug-reports"
    else
        # Default by agent
        case "$AGENT" in
            ba) echo "docs/artifacts/user-stories" ;;
            sa) echo "docs/artifacts/api-specs" ;;
            tw) echo "docs/artifacts/how-to-guides" ;;
            cs) echo "docs/artifacts/bug-reports" ;;
            *)  echo "docs/artifacts" ;;
        esac
    fi
}

# ─── Generate filename from task ────────────────────────────────
make_filename() {
    local task="$1"
    local issue_num="${2:-0}"
    local slug
    slug=$(echo "$task" | \
        LC_ALL=C sed 's/[^a-zA-Z0-9 ]//g' | \
        tr '[:upper:]' '[:lower:]' | \
        tr ' ' '-' | \
        sed 's/--*/-/g; s/^-//; s/-$//' | \
        cut -c1-50)
    if [[ -z "$slug" ]]; then
        slug="artifact"
    fi
    echo "CIT-${issue_num}-${slug}"
}

# ─── Render PlantUML blocks to SVG ──────────────────────────────
render_plantuml_svgs() {
    local artifact="$1"
    local issue_num="$2"
    local images_dir="$BASE_DIR/docs/artifacts/.images"
    mkdir -p "$images_dir"

    # Extract plantuml blocks and render each to SVG
    local idx=0
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf $tmpdir" RETURN

    python3 - "$artifact" "$tmpdir" << 'PYEOF'
import sys, re, os
filepath = sys.argv[1]
outdir = sys.argv[2]
with open(filepath) as f:
    content = f.read()
blocks = list(re.finditer(r'```plantuml\s*\n(.*?)```', content, re.DOTALL))
for i, m in enumerate(blocks):
    code = m.group(1).strip()
    with open(os.path.join(outdir, f"block_{i}.puml"), 'w') as out:
        out.write(code)
print(len(blocks))
PYEOF

    local block_count
    block_count=$(python3 -c "
import re, sys
with open(sys.argv[1]) as f:
    content = f.read()
print(len(re.findall(r'\`\`\`plantuml\s*\n.*?\`\`\`', content, re.DOTALL)))
" "$artifact")

    if [[ "$block_count" -eq 0 ]]; then
        return
    fi

    echo "  Rendering $block_count PlantUML diagram(s) to SVG..."

    local rendered=0
    for puml_file in "$tmpdir"/block_*.puml; do
        [[ -f "$puml_file" ]] || continue
        local i
        i=$(basename "$puml_file" .puml | sed 's/block_//')
        local svg_name="CIT-${issue_num}-diagram-${i}.svg"
        local svg_path="$images_dir/$svg_name"

        # Render with plantuml
        plantuml -tsvg "$puml_file" -o "$tmpdir" 2>/dev/null
        local rendered_svg="$tmpdir/block_${i}.svg"

        if [[ -f "$rendered_svg" ]]; then
            cp "$rendered_svg" "$svg_path"
            rendered=$((rendered + 1))
        fi
    done

    if [[ "$rendered" -eq 0 ]]; then
        return
    fi

    # Insert ![image] references after each ```plantuml...``` block
    python3 - "$artifact" "$images_dir" "$issue_num" << 'PYEOF'
import sys, re, os

filepath = sys.argv[1]
images_dir = sys.argv[2]
issue_num = sys.argv[3]

with open(filepath) as f:
    content = f.read()

blocks = list(re.finditer(r'```plantuml\s*\n.*?```', content, re.DOTALL))

# Process in reverse to preserve positions
for i in range(len(blocks) - 1, -1, -1):
    m = blocks[i]
    end = m.end()
    svg_name = f"CIT-{issue_num}-diagram-{i}.svg"
    svg_path = os.path.join(images_dir, svg_name)
    if os.path.exists(svg_path):
        # Compute relative path from artifact to .images
        img_ref = f"\n\n![Diagram {i}](../.images/{svg_name})\n"
        content = content[:end] + img_ref + content[end:]

with open(filepath, 'w') as f:
    f.write(content)

print(f"Inserted {len(blocks)} image reference(s)")
PYEOF

    echo "  Rendered $rendered SVG(s) into docs/artifacts/.images/"
}

# ─── Main loop with retry ───────────────────────────────────────
FEEDBACK_BLOCK=""
if [[ -n "$FEEDBACK" ]]; then
    FEEDBACK_BLOCK="

ФИДБЭК ОТ РЕВЬЮВЕРА (учти при генерации):
${FEEDBACK}

Исправь артефакт с учётом этого фидбэка. Не меняй то что не просили менять."
fi

USER_MESSAGE="КОНТЕКСТ:
$CONTEXT_BLOCK

ЗАДАЧА:
$TASK
$FEEDBACK_BLOCK"

ATTEMPT=1
while [[ $ATTEMPT -le $MAX_RETRIES ]]; do
    echo ""
    echo "--- Attempt $ATTEMPT/$MAX_RETRIES ---"

    echo "  Calling Claude API..."
    RESULT=$(call_claude "$USER_MESSAGE")

    if [[ $? -ne 0 || -z "$RESULT" ]]; then
        echo "  ERROR: API call failed"
        ATTEMPT=$((ATTEMPT + 1))
        continue
    fi

    echo "$RESULT" > "$OUTPUT_FILE"
    echo "  Saved to: $OUTPUT_FILE"

    echo "  Running validation..."
    VALIDATION_OUTPUT=""
    if VALIDATION_OUTPUT=$("$VALIDATE_SCRIPT" "$OUTPUT_FILE" 2>&1); then
        echo ""
        echo "  Validation PASSED. Creating PR..."

        AGENT_UPPER=$(echo "$AGENT" | tr "[:lower:]" "[:upper:]")

        # ─── Get next issue number from Paperclip ────────────
        if [[ -n "${PAPERCLIP_ISSUE_NUMBER:-}" ]]; then
            ISSUE_NUM="$PAPERCLIP_ISSUE_NUMBER"
        else
            ISSUE_NUM=$($DB_CMD -c "SELECT COALESCE(MAX(issue_number),0)+1 FROM issues WHERE company_id='$CITA_COMPANY_ID';" 2>/dev/null || echo "1")
        fi

        # ─── Detect target directory ─────────────────────────
        TARGET_DIR=$(detect_target_dir "$OUTPUT_FILE")
        FILENAME=$(make_filename "$TASK" "$ISSUE_NUM").md
        TARGET_PATH="${TARGET_DIR}/${FILENAME}"

        # ─── Create branch and PR ────────────────────────────
        BRANCH="review/CIT-${ISSUE_NUM}"

        cd "$BASE_DIR"
        git checkout main >/dev/null 2>&1
        git pull origin main >/dev/null 2>&1
        git branch -D "$BRANCH" 2>/dev/null || true
        git push origin --delete "$BRANCH" 2>/dev/null || true
        git checkout -b "$BRANCH" >/dev/null 2>&1

        mkdir -p "$BASE_DIR/$TARGET_DIR"
        cp "$OUTPUT_FILE" "$BASE_DIR/$TARGET_PATH"

        # Render PlantUML diagrams to SVG
        render_plantuml_svgs "$BASE_DIR/$TARGET_PATH" "$ISSUE_NUM"

        git add "$TARGET_PATH"
        git add "docs/artifacts/.images/" 2>/dev/null || true
        git commit -m "artifact(CIT-${ISSUE_NUM}): [${AGENT_UPPER}] ${TASK:0:60}" >/dev/null 2>&1
        git push origin "$BRANCH" >/dev/null 2>&1

        # Create PR via gh CLI
        PR_BODY="## Артефакт от ${AGENT_UPPER} Agent

**Тикет:** CIT-${ISSUE_NUM}
**Статус валидации:** PASSED (5/5)
**Файл:** \`${TARGET_PATH}\`

### Задача
${TASK}

### Отчёт валидации
\`\`\`
${VALIDATION_OUTPUT}
\`\`\`

---
**Для ревью:** откройте файл \`${TARGET_PATH}\` в разделе Files changed.
**Approve** → merge в main → автодеплой в GitHub Pages.
**Request changes** → агент переделает с учётом комментариев."

        PR_URL=$(gh pr create \
            --base main \
            --head "$BRANCH" \
            --title "CIT-${ISSUE_NUM}: [${AGENT_UPPER}] ${TASK:0:80}" \
            --body "$PR_BODY" \
            2>/dev/null) || PR_URL="FAILED"

        # Add labels to PR
        if [[ "$PR_URL" != "FAILED" && "$PR_URL" == http* ]]; then
            PR_NUM=$(echo "$PR_URL" | grep -oP '[0-9]+$')
            gh api "repos/anurgaz/cita-agents/issues/${PR_NUM}/labels" \
                -X POST -f "labels[]=artifact" -f "labels[]=${AGENT}" >/dev/null 2>&1 || true
        fi

        git checkout main >/dev/null 2>&1

        # ─── Create Paperclip issue with PR link ─────────────
        ISSUE_TITLE="[${AGENT_UPPER}] ${TASK:0:80}"
        ESCAPED_TITLE=$(echo "$ISSUE_TITLE" | sed "s/'/''/g")

        ISSUE_DESC="## CIT-${ISSUE_NUM}: [${AGENT_UPPER}] ${TASK:0:80}

**Статус:** pending_review
**Pull Request:** ${PR_URL}
**Валидация:** PASSED (5/5)
**Файл:** ${TARGET_PATH}

Ревью артефакта в GitHub PR: ${PR_URL}"
        ESCAPED_DESC=$(echo "$ISSUE_DESC" | sed "s/'/''/g")

        AGENT_ID=$($DB_CMD -c "SELECT id FROM agents WHERE company_id='$CITA_COMPANY_ID' AND name ILIKE '${AGENT}%' LIMIT 1;" 2>/dev/null || echo "")

        ISSUE_ID=$($DB_CMD -c "INSERT INTO issues (id, company_id, title, description, status, priority, issue_number, identifier, created_by_agent_id, created_at, updated_at) VALUES (gen_random_uuid(), '$CITA_COMPANY_ID', '$ESCAPED_TITLE', '$ESCAPED_DESC', 'pending_review', 'medium', $ISSUE_NUM, 'CIT-$ISSUE_NUM', $([ -n "$AGENT_ID" ] && echo "'$AGENT_ID'" || echo NULL), now(), now()) RETURNING id;" 2>/dev/null || echo "FAILED")

        echo ""
        echo "═══════════════════════════════════════════"
        if [[ "$PR_URL" != "FAILED" && "$PR_URL" == http* ]]; then
            echo "  PASSED - Pull Request created"
            echo "  PR: $PR_URL"
            echo "  Paperclip: CIT-$ISSUE_NUM"
            echo "  File: $TARGET_PATH"
            echo "  Review the artifact in GitHub PR"
        else
            echo "  PASSED - Branch pushed (PR creation failed)"
            echo "  Branch: $BRANCH"
            echo "  Paperclip: CIT-$ISSUE_NUM"
            echo "  Create PR manually: gh pr create --base main --head $BRANCH"
        fi
        echo "═══════════════════════════════════════════"
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
