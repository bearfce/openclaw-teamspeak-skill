#!/bin/bash
# Authenticate with SinusBot API and output token
# Usage: ./sinusbot-auth.sh [username] [password]
# Outputs: TOKEN=<token> and INSTANCE=<instance_id>

USERNAME="${1:-${USERNAME:-admin}}"
PASSWORD="${2:-${PASSWORD:-sinusbot}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_env.sh"

require_bot

RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\",\"botId\":\"$BOT_ID\"}" \
    "$API_URL/api/v1/bot/login")

TOKEN=$(echo "$RESPONSE" | jq -r '.token // empty')

if [[ -z "$TOKEN" ]]; then
    echo "Authentication failed: $RESPONSE" >&2
    exit 1
fi

echo "TOKEN=$TOKEN"
echo "INSTANCE=$INSTANCE"
