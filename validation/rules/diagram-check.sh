#!/usr/bin/env bash
set -euo pipefail

# ─── Diagram Validation ─────────────────────────────────────────
# 1. Flags PlantUML as ERROR (GitHub doesn't render it)
# 2. Validates Mermaid syntax via Claude API
# Usage: ./diagram-check.sh <artifact.md> <base_dir>

ARTIFACT="${1:-}"
BASE_DIR="${2:-}"

if [[ -z "$ARTIFACT" || ! -f "$ARTIFACT" ]]; then
    exit 0
fi

ERRORS=()

# ─── Check 1: Flag PlantUML usage ───────────────────────────────
PUML_COUNT=$(grep -c "@startuml\|plantuml" "$ARTIFACT" 2>/dev/null || true)
if [[ "$PUML_COUNT" -gt 0 ]]; then
    ERRORS+=("PlantUML detected ($PUML_COUNT occurrences). Use Mermaid instead — GitHub and Pages don't render PlantUML.")
fi

# ─── Check 2: Validate Mermaid blocks via Claude API ────────────
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    TMPDIR=$(mktemp -d)
    trap "rm -rf $TMPDIR" EXIT

    # Extract mermaid blocks
    python3 - "$ARTIFACT" "$TMPDIR" << 'PYEOF'
import sys, re

filepath = sys.argv[1]
outdir = sys.argv[2]

with open(filepath) as f:
    content = f.read()

blocks = list(re.finditer(r'```mermaid\s*\n(.*?)```', content, re.DOTALL))
for idx, m in enumerate(blocks):
    code = m.group(1).strip()
    with open(f"{outdir}/block_{idx}.mermaid", 'w') as out:
        out.write(code)

print(len(blocks))
PYEOF

    BLOCK_COUNT=$(python3 -c "
import re, sys
with open(sys.argv[1]) as f:
    content = f.read()
blocks = re.findall(r'\`\`\`mermaid\s*\n.*?\`\`\`', content, re.DOTALL)
print(len(blocks))
" "$ARTIFACT")

    if [[ "$BLOCK_COUNT" -gt 0 ]]; then
        for block_file in "$TMPDIR"/block_*.mermaid; do
            [[ -f "$block_file" ]] || continue
            CODE=$(cat "$block_file")

            RESPONSE=$(curl -s -X POST "https://api.anthropic.com/v1/messages" \
                -H "Content-Type: application/json" \
                -H "x-api-key: $ANTHROPIC_API_KEY" \
                -H "anthropic-version: 2023-06-01" \
                -d "$(jq -n --arg prompt "Check this Mermaid diagram for syntax errors. Reply ONLY 'VALID' or 'INVALID: reason'.

\`\`\`mermaid
$CODE
\`\`\`" '{
                    model: "claude-haiku-4-5-20251001",
                    max_tokens: 256,
                    messages: [{role: "user", content: $prompt}]
                }')" 2>/dev/null)

            REPLY=$(echo "$RESPONSE" | jq -r '.content[0].text // "SKIP"' 2>/dev/null)

            if echo "$REPLY" | grep -qi "INVALID"; then
                REASON=$(echo "$REPLY" | head -1)
                ERRORS+=("Mermaid syntax error: $REASON")
            fi
        done
    fi
fi

# ─── Output ─────────────────────────────────────────────────────
if [[ ${#ERRORS[@]} -gt 0 ]]; then
    for e in "${ERRORS[@]}"; do
        echo "$e"
    done
    exit 1
fi

exit 0
