#!/usr/bin/env bash
set -euo pipefail

# ─── Diagram Validation via Claude API ───────────────────────────
# Checks mermaid/plantuml diagrams in a .md file for syntax errors.
# Usage: ./diagram-check.sh [--fix] <artifact.md>
# Requires: ANTHROPIC_API_KEY, jq, curl

FIX_MODE=false
if [[ "${1:-}" == "--fix" ]]; then
    FIX_MODE=true
    shift
fi

ARTIFACT="${1:-}"
if [[ -z "$ARTIFACT" || ! -f "$ARTIFACT" ]]; then
    echo "Usage: $0 [--fix] <artifact.md>"
    exit 1
fi

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "ANTHROPIC_API_KEY not set, skipping diagram check"
    exit 0
fi

ERRORS=0
FIXED=0
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Extract diagram blocks: ```mermaid...``` and ```plantuml...``` and @startuml...@enduml
python3 - "$ARTIFACT" "$TMPDIR" << 'PYEOF'
import sys, re

filepath = sys.argv[1]
outdir = sys.argv[2]

with open(filepath) as f:
    content = f.read()

# Match fenced code blocks: ```mermaid or ```plantuml
fenced = re.finditer(r'```(mermaid|plantuml)\s*\n(.*?)```', content, re.DOTALL)
idx = 0
for m in fenced:
    lang = m.group(1)
    code = m.group(2).strip()
    with open(f"{outdir}/block_{idx}.{lang}", 'w') as out:
        out.write(code)
    # Store position for replacement
    with open(f"{outdir}/block_{idx}.pos", 'w') as out:
        out.write(f"{m.start()}:{m.end()}")
    idx += 1

# Match @startuml...@enduml blocks (not inside fenced blocks)
puml = re.finditer(r'(@startuml.*?@enduml)', content, re.DOTALL)
for m in puml:
    code = m.group(1).strip()
    # Skip if inside a fenced block
    before = content[:m.start()]
    open_fences = before.count('```')
    if open_fences % 2 == 0:  # Not inside a fence
        with open(f"{outdir}/block_{idx}.plantuml", 'w') as out:
            out.write(code)
        with open(f"{outdir}/block_{idx}.pos", 'w') as out:
            out.write(f"{m.start()}:{m.end()}")
        idx += 1

print(idx)
PYEOF

BLOCK_COUNT=$(python3 - "$ARTIFACT" "$TMPDIR" << 'PYEOF'
import sys, re, os

filepath = sys.argv[1]
outdir = sys.argv[2]

with open(filepath) as f:
    content = f.read()

fenced = list(re.finditer(r'```(mermaid|plantuml)\s*\n(.*?)```', content, re.DOTALL))
idx = 0
for m in fenced:
    lang = m.group(1)
    code = m.group(2).strip()
    with open(f"{outdir}/block_{idx}.{lang}", 'w') as out:
        out.write(code)
    with open(f"{outdir}/block_{idx}.pos", 'w') as out:
        out.write(f"{m.start()}:{m.end()}")
    idx += 1

print(idx)
PYEOF
)

if [[ "$BLOCK_COUNT" -eq 0 ]]; then
    # No diagrams found — pass
    exit 0
fi

echo "  Found $BLOCK_COUNT diagram block(s) in $(basename "$ARTIFACT")"

# Validate each block via Claude API
for block_file in "$TMPDIR"/block_*.mermaid "$TMPDIR"/block_*.plantuml; do
    [[ -f "$block_file" ]] || continue

    LANG="${block_file##*.}"
    BLOCK_NAME=$(basename "$block_file")
    BLOCK_IDX="${BLOCK_NAME%%.*}"
    CODE=$(cat "$block_file")

    echo -n "  Checking $LANG block... "

    PROMPT="Check this $LANG diagram for syntax errors. Reply STRICTLY in this format:
STATUS: VALID
or
STATUS: INVALID
ERRORS:
- error description
FIXED:
\`\`\`$LANG
corrected code here
\`\`\`

Diagram to check:
\`\`\`$LANG
$CODE
\`\`\`"

    RESPONSE=$(curl -s -X POST "https://api.anthropic.com/v1/messages" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d "$(jq -n --arg prompt "$PROMPT" '{
            model: "claude-haiku-4-5-20251001",
            max_tokens: 2048,
            messages: [{role: "user", content: $prompt}]
        }')" 2>/dev/null)

    REPLY=$(echo "$RESPONSE" | jq -r '.content[0].text // "ERROR"')

    if echo "$REPLY" | grep -q "STATUS: VALID"; then
        echo "VALID"
    elif echo "$REPLY" | grep -q "STATUS: INVALID"; then
        echo "INVALID"
        ERRORS=$((ERRORS + 1))

        # Show errors
        echo "$REPLY" | sed -n '/^ERRORS:/,/^FIXED:/p' | head -10 | sed 's/^/    /'

        if [[ "$FIX_MODE" == "true" ]]; then
            # Extract fixed code
            FIXED_CODE=$(echo "$REPLY" | sed -n "/^\`\`\`$LANG/,/^\`\`\`/p" | sed '1d;$d')
            if [[ -n "$FIXED_CODE" ]]; then
                echo "$FIXED_CODE" > "$block_file.fixed"
                FIXED=$((FIXED + 1))
                echo "    -> Fixed version saved"
            fi
        fi
    else
        echo "SKIP (API error)"
    fi
done

# Apply fixes if --fix mode and fixes exist
if [[ "$FIX_MODE" == "true" && "$FIXED" -gt 0 ]]; then
    echo "  Applying $FIXED fix(es) to $(basename "$ARTIFACT")..."

    python3 - "$ARTIFACT" "$TMPDIR" << 'PYEOF'
import sys, re, os

filepath = sys.argv[1]
tmpdir = sys.argv[2]

with open(filepath) as f:
    content = f.read()

# Collect all fixes
fixes = []
for fname in sorted(os.listdir(tmpdir)):
    if fname.endswith('.fixed'):
        base = fname.replace('.fixed', '')
        idx = base.split('.')[0]  # block_0
        lang = base.split('.')[1]  # mermaid or plantuml
        pos_file = os.path.join(tmpdir, f"{idx}.pos")
        if os.path.exists(pos_file):
            with open(pos_file) as f2:
                start, end = map(int, f2.read().strip().split(':'))
            with open(os.path.join(tmpdir, fname)) as f2:
                fixed_code = f2.read().strip()
            fixes.append((start, end, lang, fixed_code))

# Apply in reverse order to preserve positions
fixes.sort(key=lambda x: x[0], reverse=True)
for start, end, lang, fixed_code in fixes:
    original = content[start:end]
    if original.startswith('```'):
        replacement = f"```{lang}\n{fixed_code}\n```"
    else:
        replacement = fixed_code
    content = content[:start] + replacement + content[end:]

with open(filepath, 'w') as f:
    f.write(content)

print(f"Applied {len(fixes)} fix(es)")
PYEOF
fi

if [[ "$ERRORS" -gt 0 && "$FIX_MODE" != "true" ]]; then
    echo "$ERRORS diagram(s) have syntax errors"
    exit 1
fi

exit 0
