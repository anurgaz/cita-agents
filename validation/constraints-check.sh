#!/usr/bin/env bash
set -euo pipefail

# Check that artifact references relevant constraints (C-NNN pattern)
# Exit 0 = passed, Exit 1 = failed (errors on stdout)

ARTIFACT="$1"
BASE_DIR="$2"
CONSTRAINTS_FILE="$BASE_DIR/docs/context/constraints.md"

ERRORS=()

# Detect artifact type
CONTENT=$(cat "$ARTIFACT")

# Check if artifact references any constraints or business rules
HAS_CONSTRAINT_REF=$(grep -cE '(C-[0-9]{3}|BR-[0-9]{3}|SR-[0-9]{3}|NR-[0-9]{3}|CR-[0-9]{3})' "$ARTIFACT" || true)

# Determine if constraints are expected based on artifact type
if echo "$CONTENT" | grep -qiE '(User Story|Acceptance Criteria|API Spec|API-[0-9]{3}|US-[0-9]{3})'; then
    # User stories and API specs MUST reference rules
    if [[ "$HAS_CONSTRAINT_REF" -eq 0 ]]; then
        ERRORS+=("Artifact does not reference any constraints or business rules (C-NNN, BR-NNN, SR-NNN, NR-NNN, CR-NNN)")
    fi
fi

# If constraints file exists, verify referenced constraints actually exist
if [[ -f "$CONSTRAINTS_FILE" ]]; then
    while IFS= read -r ref; do
        if ! grep -q "$ref" "$CONSTRAINTS_FILE"; then
            # Check business rules files too
            FOUND=false
            for rules_file in "$BASE_DIR"/docs/business-rules/*.md; do
                if [[ -f "$rules_file" ]] && grep -q "$ref" "$rules_file"; then
                    FOUND=true
                    break
                fi
            done
            if [[ "$FOUND" == "false" ]]; then
                ERRORS+=("Referenced rule $ref not found in constraints or business-rules docs")
            fi
        fi
    done < <(grep -oE '(C-[0-9]{3})' "$ARTIFACT" 2>/dev/null || true)
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    for e in "${ERRORS[@]}"; do
        echo "$e"
    done
    exit 1
fi

exit 0
