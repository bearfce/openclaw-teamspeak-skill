#!/bin/bash
# Connect (spawn) the bot instance to TeamSpeak
# Usage: ./sinusbot-spawn.sh
#
# Authenticates and spawns the instance. Waits for connection and verifies.
# Requires SinusBot to be running on port 8087.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_env.sh"

require_bot

# Check SinusBot is up
if ! ss -tlnp 2>/dev/null | grep -q ':8087'; then
    echo "SinusBot not running on port 8087. Start it first." >&2
    exit 1
fi

# Authenticate
TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\",\"botId\":\"$BOT_ID\"}" \
    "$API_URL/api/v1/bot/login" | jq -r '.token // empty')

if [[ -z "$TOKEN" ]]; then
    echo "Authentication failed" >&2
    exit 1
fi

# Check if already running
RUNNING=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "$API_URL/api/v1/bot/i/$INSTANCE/status" | jq -r '.running // false')

if [[ "$RUNNING" == "true" ]]; then
    echo "Already connected to TeamSpeak"
    exit 0
fi

# Spawn
SPAWN_RESP=$(curl -s -X POST -H "Authorization: Bearer $TOKEN" \
    "$API_URL/api/v1/bot/i/$INSTANCE/spawn")

if ! echo "$SPAWN_RESP" | jq -e '.success' > /dev/null 2>&1; then
    echo "Spawn failed: $SPAWN_RESP" >&2
    exit 1
fi

# Wait for connection
echo "Connecting to TeamSpeak..."
for i in {1..10}; do
    sleep 1
    RUNNING=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "$API_URL/api/v1/bot/i/$INSTANCE/status" | jq -r '.running // false')
    if [[ "$RUNNING" == "true" ]]; then
        CHANNEL=$(curl -s -H "Authorization: Bearer $TOKEN" \
            "$API_URL/api/v1/bot/i/$INSTANCE/status" | jq -r '.connStatus.channelId // "unknown"')
        echo "Connected to TeamSpeak (channel: $CHANNEL)"
        exit 0
    fi
done

echo "Spawn sent but connection not confirmed after 10s. Check logs." >&2
exit 1
