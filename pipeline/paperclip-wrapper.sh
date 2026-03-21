#!/bin/bash
# Paperclip process adapter wrapper for cita-agents
# Called by Paperclip heartbeat with env: PAPERCLIP_AGENT_ID, PAPERCLIP_COMPANY_ID, PAPERCLIP_API_URL, PAPERCLIP_API_KEY
# Also receives CITA_AGENT_TYPE (ba|sa|tw|cs) from adapter_config env

set -euo pipefail

AGENT_TYPE="${CITA_AGENT_TYPE:?CITA_AGENT_TYPE not set}"
API_URL="${PAPERCLIP_API_URL:?PAPERCLIP_API_URL not set}"
API_KEY="${PAPERCLIP_API_KEY:?PAPERCLIP_API_KEY not set}"
COMPANY_ID="${PAPERCLIP_COMPANY_ID:?PAPERCLIP_COMPANY_ID not set}"
AGENT_ID="${PAPERCLIP_AGENT_ID:?PAPERCLIP_AGENT_ID not set}"

echo "=== cita-agents wrapper ==="
echo "Agent type: $AGENT_TYPE"
echo "Agent ID: $AGENT_ID"
echo "API URL: $API_URL"

# Helper: extract first issue ID from JSON array
extract_id() {
  node -e "
    const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
    const items = Array.isArray(d) ? d : (d.items || d.data || []);
    if (items.length) process.stdout.write(items[0].id);
  " 2>/dev/null
}

# Find assigned issue: in_progress > todo > backlog
ISSUE_ID=""
for status in in_progress todo backlog; do
  if [[ -z "$ISSUE_ID" ]]; then
    RESP=$(curl -sf "${API_URL}/api/companies/${COMPANY_ID}/issues?assigneeAgentId=${AGENT_ID}&status=${status}" \
      -H "Authorization: Bearer ${API_KEY}" 2>/dev/null || echo '[]')
    ISSUE_ID=$(echo "$RESP" | extract_id || echo "")
    if [[ -n "$ISSUE_ID" ]]; then
      echo "Found issue (${status}): $ISSUE_ID"
    fi
  fi
done

if [[ -z "$ISSUE_ID" ]]; then
  echo "No issues assigned to this agent. Nothing to do."
  exit 0
fi

# Get issue details
ISSUE_JSON=$(curl -sf "${API_URL}/api/issues/${ISSUE_ID}" \
  -H "Authorization: Bearer ${API_KEY}")

eval "$(echo "$ISSUE_JSON" | node -e "
  const d = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  console.log('ISSUE_TITLE=' + JSON.stringify(d.title));
  console.log('ISSUE_NUMBER=' + d.issueNumber);
  console.log('ISSUE_IDENTIFIER=' + d.identifier);
")"

echo "Issue: $ISSUE_IDENTIFIER - $ISSUE_TITLE"

# Strip agent prefix from title: "[BA] actual task" -> "actual task"
TASK=$(echo "$ISSUE_TITLE" | sed 's/^\[[A-Z]*\] //')

# Update status to in_progress via API
curl -sf -X PATCH "${API_URL}/api/issues/${ISSUE_ID}" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"status":"in_progress"}' > /dev/null 2>&1 || true

# Export issue number for run-agent.sh
export PAPERCLIP_ISSUE_NUMBER="$ISSUE_NUMBER"

# Load Anthropic API key
export ANTHROPIC_API_KEY=$(cat /root/.anthropic_key)

# Run the agent
echo "Running: ./pipeline/run-agent.sh --agent $AGENT_TYPE --task \"$TASK\""
cd /root/cita-agents

./pipeline/run-agent.sh \
  --agent "$AGENT_TYPE" \
  --task "$TASK"

EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
  curl -sf -X PATCH "${API_URL}/api/issues/${ISSUE_ID}" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"status":"done"}' > /dev/null 2>&1 || true
  echo "Agent completed successfully. PR created."
else
  echo "Agent failed with exit code $EXIT_CODE"
fi

exit $EXIT_CODE
