#!/usr/bin/env bash
set -euo pipefail

# Check that artifact uses correct terminology from glossary.md
# Exit 0 = passed, Exit 1 = failed (warnings on stdout)

ARTIFACT="$1"
BASE_DIR="$2"
GLOSSARY="$BASE_DIR/docs/context/glossary.md"

if [[ ! -f "$GLOSSARY" ]]; then
    echo "Glossary file not found: $GLOSSARY"
    exit 1
fi

ERRORS=()
CONTENT=$(cat "$ARTIFACT")

# Define forbidden terms and their correct alternatives
# Format: "wrong_term|correct_term"
TERM_PAIRS=(
    "бронь|запись (booking)"
    "заказ|запись (booking)"
    "специалист|мастер (master)"
    "работник|мастер (master)"
    "сотрудник|мастер (master)"
    "пользователь|клиент (client) или владелец (owner)"
    "заказчик|клиент (client)"
    "хозяин|владелец (owner)"
    "бизнесмен|владелец (owner)"
)

for pair in "${TERM_PAIRS[@]}"; do
    WRONG="${pair%%|*}"
    CORRECT="${pair##*|}"

    # Case-insensitive search, skip if in code blocks or quotes
    COUNT=$(echo "$CONTENT" | grep -ciw "$WRONG" || true)
    if [[ "$COUNT" -gt 0 ]]; then
        # Check if it's inside a template/example block (between ```)
        IN_CODE=$(echo "$CONTENT" | awk '/^```/{f=!f} f{print}' | grep -ciw "$WRONG" || true)
        REAL_COUNT=$((COUNT - IN_CODE))
        if [[ "$REAL_COUNT" -gt 0 ]]; then
            ERRORS+=("Term '$WRONG' used $REAL_COUNT time(s). Use: $CORRECT (see glossary.md)")
        fi
    fi
done

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    for e in "${ERRORS[@]}"; do
        echo "$e"
    done
    exit 1
fi

exit 0
