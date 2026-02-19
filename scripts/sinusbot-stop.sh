#!/bin/bash
# Stop audio playback or disconnect from TeamSpeak
# Usage: ./sinusbot-stop.sh [--disconnect]
#
# Without flags: stops current audio playback
# With --disconnect: kills the instance (disconnects from TS entirely)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_env.sh"

require_bot

# Authenticate
TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\",\"botId\":\"$BOT_ID\"}" \
    "$API_URL/api/v1/bot/login" | jq -r '.token // empty')

if [[ -z "$TOKEN" ]]; then
    echo "Authentication failed" >&2
    exit 1
fi

if [[ "$1" == "--disconnect" ]]; then
    curl -s -X POST -H "Authorization: Bearer $TOKEN" \
        "$API_URL/api/v1/bot/i/$INSTANCE/kill" > /dev/null
    echo "Disconnected from TeamSpeak"
else
    curl -s -X POST -H "Authorization: Bearer $TOKEN" \
        "$API_URL/api/v1/bot/i/$INSTANCE/stop" > /dev/null
    echo "Playback stopped"
fi
