#!/usr/bin/env bash
set -euo pipefail

# Diagram Format & Syntax Validation
# Rules:
#   Flowchart, ER diagram -> must be Mermaid
#   Sequence diagram, C4  -> must be PlantUML
# Validates syntax via Claude Haiku API.
# Usage: ./diagram-check.sh <artifact.md> <base_dir>

ARTIFACT="${1:-}"
BASE_DIR="${2:-}"

if [[ -z "$ARTIFACT" || ! -f "$ARTIFACT" ]]; then
    exit 0
fi

ERRORS=()

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Extract blocks with Python
python3 - "$ARTIFACT" "$TMPDIR" << 'PYEOF'
import sys, re, os

filepath = sys.argv[1]
outdir = sys.argv[2]

with open(filepath) as f:
    content = f.read()

idx = 0
for lang in ['mermaid', 'plantuml']:
    for m in re.finditer(r'```' + lang + r'\s*\n(.*?)```', content, re.DOTALL):
        code = m.group(1).strip()
        with open(os.path.join(outdir, f"block_{idx}.{lang}"), 'w') as out:
            out.write(code)
        idx += 1

print(idx)
PYEOF

# Check format rules per block
for block_file in "$TMPDIR"/block_*.mermaid; do
    [[ -f "$block_file" ]] || continue
    CODE=$(cat "$block_file")
    if echo "$CODE" | grep -qi "sequenceDiagram"; then
        ERRORS+=("Sequence diagram in Mermaid detected. Use PlantUML for sequence diagrams.")
    fi
    if echo "$CODE" | grep -qi "C4Context\|C4Container\|C4Component\|C4Deployment"; then
        ERRORS+=("C4 diagram in Mermaid detected. Use PlantUML for C4 diagrams.")
    fi
done

for block_file in "$TMPDIR"/block_*.plantuml; do
    [[ -f "$block_file" ]] || continue
    CODE=$(cat "$block_file")
    if echo "$CODE" | grep -qi "digraph\|^graph {"; then
        ERRORS+=("Flowchart in PlantUML detected. Use Mermaid for flowcharts.")
    fi
    if echo "$CODE" | grep -qi "^entity "; then
        ERRORS+=("ER diagram in PlantUML detected. Use Mermaid for ER diagrams.")
    fi
done

# Validate syntax via Claude Haiku if API key available
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    for block_file in "$TMPDIR"/block_*.*; do
        [[ -f "$block_file" ]] || continue
        LANG="${block_file##*.}"
        CODE=$(cat "$block_file")

        RESPONSE=$(curl -s -X POST "https://api.anthropic.com/v1/messages" \
            -H "Content-Type: application/json" \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -d "$(jq -n --arg prompt "Check this $LANG diagram ONLY for syntax errors that would prevent rendering. Ignore semantic issues, naming conventions, or design suggestions. Reply ONLY 'VALID' if it will render without errors, or 'INVALID: reason' if there is a real syntax error.

\`\`\`$LANG
$CODE
\`\`\`" '{
                model: "claude-haiku-4-5-20251001",
                max_tokens: 256,
                messages: [{role: "user", content: $prompt}]
            }')" 2>/dev/null)

        REPLY=$(echo "$RESPONSE" | jq -r '.content[0].text // "SKIP"' 2>/dev/null)

        if echo "$REPLY" | grep -qi "INVALID"; then
            REASON=$(echo "$REPLY" | head -1)
            ERRORS+=("$LANG syntax error: $REASON")
        fi
    done
fi

# Output
if [[ ${#ERRORS[@]} -gt 0 ]]; then
    for e in "${ERRORS[@]}"; do
        echo "$e"
    done
    exit 1
fi

exit 0
