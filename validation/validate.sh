#!/usr/bin/env bash
set -euo pipefail

# ─── Main Validation Runner ─────────────────────────────────────
# Usage: ./validate.sh <path-to-artifact>
# Returns: exit 0 (PASSED) or exit 1 (FAILED)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <path-to-artifact>"
    exit 1
fi

ARTIFACT="$1"

if [[ ! -f "$ARTIFACT" ]]; then
    echo "ERROR: File not found: $ARTIFACT"
    exit 1
fi

echo "═══════════════════════════════════════════"
echo "  Validating: $(basename "$ARTIFACT")"
echo "═══════════════════════════════════════════"
echo ""

ERRORS=()
WARNINGS=()
CHECKS_PASSED=0
CHECKS_FAILED=0

run_check() {
    local check_name="$1"
    local check_script="$SCRIPT_DIR/$2"

    echo "--- Check: $check_name ---"

    if [[ ! -x "$check_script" ]]; then
        echo "  SKIP: $check_script not found or not executable"
        WARNINGS+=("$check_name: script not found")
        return
    fi

    local output
    if output=$("$check_script" "$ARTIFACT" "$BASE_DIR" 2>&1); then
        echo "  PASSED"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        echo "  FAILED"
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                echo "    - $line"
                ERRORS+=("[$check_name] $line")
            fi
        done <<< "$output"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
    echo ""
}

run_check "Constraints Reference" "constraints-check.sh"
run_check "Completeness" "completeness-check.sh"
run_check "Glossary Terms" "glossary-check.sh"
run_check "Business Rules Consistency" "consistency-check.sh"

echo "═══════════════════════════════════════════"
echo "  Results: $CHECKS_PASSED passed, $CHECKS_FAILED failed"
echo "═══════════════════════════════════════════"

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo ""
    echo "Warnings:"
    for w in "${WARNINGS[@]}"; do
        echo "  ! $w"
    done
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo ""
    echo "Errors:"
    for e in "${ERRORS[@]}"; do
        echo "  x $e"
    done
    echo ""
    echo "RESULT: FAILED"
    exit 1
else
    echo ""
    echo "RESULT: PASSED"
    exit 0
fi
