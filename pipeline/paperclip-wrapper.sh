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

# Find the issue assigned to this agent (status=in_progress, assignee=this agent)
ISSUES_JSON=$(curl -sf "${API_URL}/api/companies/${COMPANY_ID}/issues?assigneeAgentId=${AGENT_ID}&status=in_progress" \
  -H "Authorization: Bearer ${API_KEY}" || echo '[]')

# Parse first issue
ISSUE_ID=$(echo "$ISSUES_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data if isinstance(data, list) else data.get('items', data.get('data', []))
if items:
    print(items[0]['id'])
" 2>/dev/null || echo "")

for fallback_status in todo backlog; do
  if [[ -z "$ISSUE_ID" ]]; then
    echo "Checking ${fallback_status}..."
    ISSUES_JSON=$(curl -sf "${API_URL}/api/companies/${COMPANY_ID}/issues?assigneeAgentId=${AGENT_ID}&status=${fallback_status}" \
      -H "Authorization: Bearer ${API_KEY}" || echo '[]')
    ISSUE_ID=$(echo "$ISSUES_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data if isinstance(data, list) else data.get('items', data.get('data', []))
if items:
    print(items[0]['id'])
" 2>/dev/null || echo "")
  fi
done

if [[ -z "$ISSUE_ID" ]]; then
  echo "No issues found for agent. Nothing to do."
  exit 0
fi

# Get issue details
ISSUE_JSON=$(curl -sf "${API_URL}/api/issues/${ISSUE_ID}" \
  -H "Authorization: Bearer ${API_KEY}")

ISSUE_TITLE=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])")
ISSUE_DESC=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('description',''))")
ISSUE_NUMBER=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['issueNumber'])")
ISSUE_IDENTIFIER=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['identifier'])")

echo "Issue: $ISSUE_IDENTIFIER - $ISSUE_TITLE"

# Strip agent prefix from title: "[BA] actual task" -> "actual task"
TASK=$(echo "$ISSUE_TITLE" | sed 's/^\[[A-Z]*\] //')

# Update status to in_progress
curl -sf -X PATCH "${API_URL}/api/issues/${ISSUE_ID}" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"status":"in_progress"}' > /dev/null 2>&1 || true

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
  # Update Paperclip status to done (PR created, awaiting review)
  curl -sf -X PATCH "${API_URL}/api/issues/${ISSUE_ID}" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"status":"done"}' > /dev/null 2>&1 || true
  echo "Agent completed successfully. PR created."
else
  echo "Agent failed with exit code $EXIT_CODE"
fi

exit $EXIT_CODE
