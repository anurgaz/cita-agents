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

# Preprocess: strip code blocks, lines with quoted terms (guillemets),
# and lines that mention forbidden terms only in negation/meta context
CLEANED=$(cat "$ARTIFACT" | \
    awk '/^```/{f=!f; next} !f{print}' | \
    grep -v '«' | \
    grep -vi 'запрещённ\|запрещен\|заменён\|заменен\|не использовать\|не используйте\|вместо .* использу')

# Define forbidden terms and their correct alternatives
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

    COUNT=$(echo "$CLEANED" | grep -ciw "$WRONG" || true)
    if [[ "$COUNT" -gt 0 ]]; then
        ERRORS+=("Term '$WRONG' used $COUNT time(s). Use: $CORRECT (see glossary.md)")
    fi
done

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    for e in "${ERRORS[@]}"; do
        echo "$e"
    done
    exit 1
fi

exit 0
