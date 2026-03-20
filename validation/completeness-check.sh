#!/usr/bin/env bash
set -euo pipefail

ARTIFACT="$1"
BASE_DIR="$2"

ERRORS=()

check_field() {
    local field="$1"
    if ! grep -qi "$field" "$ARTIFACT"; then
        ERRORS+=("Missing required section: $field")
    fi
}

# Detect artifact type by grepping file directly
if grep -qiE "^# US-[0-9]+" "$ARTIFACT"; then
    for f in "User Story" "Acceptance Criteria" "Business Rules" "Out of Scope" "Meta" "Given" "When" "Then"; do
        check_field "$f"
    done
    AC_COUNT=$(grep -cE "^### AC-" "$ARTIFACT" || true)
    if [[ "$AC_COUNT" -lt 3 ]]; then
        ERRORS+=("User Story must have at least 3 Acceptance Criteria (found: $AC_COUNT)")
    fi

elif grep -qiE "^# API-[0-9]+" "$ARTIFACT"; then
    for f in "Endpoint" "Method" "Path" "Auth" "Response" "Error Responses" "Business Logic"; do
        check_field "$f"
    done

elif grep -qiE "^# TC-[0-9]+" "$ARTIFACT"; then
    for f in "Preconditions" "Steps" "Expected Result" "Meta"; do
        check_field "$f"
    done

elif grep -qiE "(^# Как |Пошаговая инструкция|Что понадобится)" "$ARTIFACT"; then
    for f in "Что понадобится" "Пошаговая инструкция" "Результат" "Частые вопросы"; do
        check_field "$f"
    done
    STEP_COUNT=$(grep -cE "^### Шаг [0-9]+" "$ARTIFACT" || true)
    if [[ "$STEP_COUNT" -lt 3 ]]; then
        ERRORS+=("How-to Guide must have at least 3 steps (found: $STEP_COUNT)")
    fi

elif grep -qiE "^## BUG-[0-9]+" "$ARTIFACT"; then
    for f in "Severity" "Environment" "Steps to Reproduce" "Expected Behavior" "Actual Behavior"; do
        check_field "$f"
    done

elif grep -qiE "^# SEQ-[0-9]+" "$ARTIFACT"; then
    for f in "@startuml" "@enduml" "participant"; do
        check_field "$f"
    done

else
    LINE_COUNT=$(wc -l < "$ARTIFACT" | tr -d " ")
    if [[ "$LINE_COUNT" -lt 5 ]]; then
        ERRORS+=("Artifact appears too short ($LINE_COUNT lines)")
    fi
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    for e in "${ERRORS[@]}"; do
        echo "$e"
    done
    exit 1
fi
exit 0
