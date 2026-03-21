#!/usr/bin/env bash
set -euo pipefail

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

echo "======================================="
echo "  Validating: $(basename "$ARTIFACT")"
echo "======================================="
echo ""

ERRORS=()
WARNINGS=()
CHECKS_PASSED=0
CHECKS_FAILED=0

run_check() {
    local check_name="$1"
    local check_script="$2"

    # Try SCRIPT_DIR first, then SCRIPT_DIR/rules/
    local script_path=""
    if [[ -x "$SCRIPT_DIR/$check_script" ]]; then
        script_path="$SCRIPT_DIR/$check_script"
    elif [[ -x "$SCRIPT_DIR/rules/$check_script" ]]; then
        script_path="$SCRIPT_DIR/rules/$check_script"
    else
        echo "--- Check: $check_name ---"
        echo "  SKIP: $check_script not found"
        WARNINGS+=("$check_name: script not found")
        echo ""
        return
    fi

    echo "--- Check: $check_name ---"

    local output
    if output=$("$script_path" "$ARTIFACT" "$BASE_DIR" 2>&1); then
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
run_check "Diagram Syntax" "diagram-check.sh"

echo "======================================="
echo "  Results: $CHECKS_PASSED passed, $CHECKS_FAILED failed"
echo "======================================="

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
