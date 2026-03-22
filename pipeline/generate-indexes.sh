#!/usr/bin/env bash
# Auto-generate index.md for each artifact subdirectory
set -euo pipefail

DOCS_DIR="${1:-docs/artifacts}"

declare -A TITLES=(
    ["user-stories"]="User Stories от BA Agent"
    ["api-specs"]="API Спецификации от SA Agent"
    ["how-to-guides"]="How-to Guides от TW Agent"
    ["api-reference"]="API Reference от TW Agent"
    ["bug-reports"]="Bug Reports от CS Agent"
    ["test-cases"]="Тест-кейсы от SA Agent"
    ["changelog"]="Changelog от TW Agent"
)

for dir in "$DOCS_DIR"/*/; do
    dirname=$(basename "$dir")
    index="${dir}index.md"
    title="${TITLES[$dirname]:-$dirname}"

    # Find all .md files except index.md
    files=()
    while IFS= read -r f; do
        files+=("$f")
    done < <(find "$dir" -maxdepth 1 -name '*.md' ! -name 'index.md' -printf '%f\n' 2>/dev/null | sort)

    cat > "$index" << EOF
# $title

> Артефакты, прошедшие автовалидацию и одобренные через ревью.

EOF

    if [[ ${#files[@]} -eq 0 ]]; then
        echo '*Пока нет опубликованных артефактов.*' >> "$index"
    else
        echo '| Артефакт | Файл |' >> "$index"
        echo '|----------|------|' >> "$index"
        for f in "${files[@]}"; do
            name="${f%.md}"
            echo "| [$name]($f) | \`$f\` |" >> "$index"
        done
    fi

    echo "  Index: $index (${#files[@]} artifacts)"
done
