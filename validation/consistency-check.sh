#!/usr/bin/env bash
set -euo pipefail

# Check for conflicts between artifact and business rules
# Exit 0 = passed, Exit 1 = failed (errors on stdout)

ARTIFACT="$1"
BASE_DIR="$2"
RULES_DIR="$BASE_DIR/docs/business-rules"

if [[ ! -d "$RULES_DIR" ]]; then
    echo "Business rules directory not found: $RULES_DIR"
    exit 1
fi

ERRORS=()
CONTENT=$(cat "$ARTIFACT")

# Extract all referenced business rule IDs from the artifact
REFERENCED_RULES=$(grep -oE '(BR|SR|NR|CR)-[0-9]{3}' "$ARTIFACT" 2>/dev/null | sort -u || true)

if [[ -z "$REFERENCED_RULES" ]]; then
    # No rules referenced - not necessarily an error for all artifact types
    # Only flag for user stories and API specs
    if echo "$CONTENT" | grep -qiE '(US-[0-9]+|API-[0-9]+)'; then
        ERRORS+=("No business rules referenced (BR-NNN, SR-NNN, NR-NNN, CR-NNN)")
    fi
fi

# Verify each referenced rule exists in the business-rules docs
while IFS= read -r rule_id; do
    [[ -z "$rule_id" ]] && continue

    FOUND=false
    for rules_file in "$RULES_DIR"/*.md; do
        [[ ! -f "$rules_file" ]] && continue
        if grep -q "$rule_id" "$rules_file"; then
            FOUND=true
            break
        fi
    done

    if [[ "$FOUND" == "false" ]]; then
        ERRORS+=("Referenced rule $rule_id not found in any business-rules file")
    fi
done <<< "$REFERENCED_RULES"

# Check for contradictions: if artifact mentions a status flow, verify against booking-rules
if echo "$CONTENT" | grep -qiE 'status.*pending.*confirmed'; then
    BOOKING_RULES="$RULES_DIR/booking-rules.md"
    if [[ -f "$BOOKING_RULES" ]]; then
        # Verify the status flow matches
        if echo "$CONTENT" | grep -qiE 'pending.*->.*completed' && ! echo "$CONTENT" | grep -qiE 'pending.*->.*confirmed.*->.*completed'; then
            ERRORS+=("Status flow conflict: pending cannot go directly to completed (must go through confirmed, see BR-002)")
        fi
    fi
fi

# Check for schedule rule consistency
if echo "$CONTENT" | grep -qiE '(business.schedule|master.schedule|расписание)'; then
    SCHEDULE_RULES="$RULES_DIR/scheduling-rules.md"
    if [[ -f "$SCHEDULE_RULES" ]]; then
        # If artifact mentions schedule without mentioning two-level priority
        if echo "$CONTENT" | grep -qiE 'schedule' && ! echo "$CONTENT" | grep -qiE '(master.*>.*business|приоритет|fallback|override|SR-001)'; then
            # Only warn for API specs and user stories
            if echo "$CONTENT" | grep -qiE '(US-[0-9]+|API-[0-9]+)'; then
                ERRORS+=("Schedule logic mentioned but two-level priority (master > business, SR-001) not referenced")
            fi
        fi
    fi
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    for e in "${ERRORS[@]}"; do
        echo "$e"
    done
    exit 1
fi

exit 0
