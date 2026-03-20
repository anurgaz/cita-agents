#!/usr/bin/env bash
set -euo pipefail

# ─── Validate and Review ────────────────────────────────────────
# Usage: ./validate-and-review.sh <path-to-artifact>
# Runs validation and provides a summary for human review.

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATE_SCRIPT="$BASE_DIR/validation/validate.sh"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <path-to-artifact>"
    exit 1
fi

ARTIFACT="$1"

if [[ ! -f "$ARTIFACT" ]]; then
    echo "ERROR: File not found: $ARTIFACT"
    exit 1
fi

echo ""
echo "Artifact: $ARTIFACT"
echo "Size: $(wc -l < "$ARTIFACT") lines, $(wc -c < "$ARTIFACT" | tr -d ' ') bytes"
echo "Modified: $(stat -c '%y' "$ARTIFACT" 2>/dev/null || stat -f '%Sm' "$ARTIFACT" 2>/dev/null || echo 'unknown')"
echo ""

# Run validation
if "$VALIDATE_SCRIPT" "$ARTIFACT"; then
    echo ""
    echo "-----------------------------------------------"
    echo "  Status: PASSED - Ready for human review"
    echo "-----------------------------------------------"
    echo ""
    echo "Next steps:"
    echo "  1. Review the artifact content"
    echo "  2. Check business logic correctness (automated checks can't verify this)"
    echo "  3. Approve or request changes"
else
    echo ""
    echo "-----------------------------------------------"
    echo "  Status: FAILED - Fix errors before review"
    echo "-----------------------------------------------"
    echo ""
    echo "Next steps:"
    echo "  1. Fix the errors listed above"
    echo "  2. Re-run: $0 $ARTIFACT"
fi
