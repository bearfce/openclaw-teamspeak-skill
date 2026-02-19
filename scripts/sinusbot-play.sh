#!/bin/bash
# Upload and play audio file through SinusBot
# Usage: ./sinusbot-play.sh <audio_file> [channel_id]

AUDIO_FILE="$1"
CHANNEL_ID="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_env.sh"

require_bot
require_cq

if [[ -z "$AUDIO_FILE" ]]; then
    echo "Usage: $0 <audio_file> [channel_id]" >&2
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

# Ensure bot is spawned (connected to TS)
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
    "$API_URL/api/v1/bot/i/$INSTANCE/spawn" > /dev/null
sleep 2

# Move to channel if specified
if [[ -n "$CHANNEL_ID" ]]; then
    (echo "auth apikey=$CQ_KEY"; sleep 0.3; echo "clientmove cid=$CHANNEL_ID clid=0"; sleep 0.3) \
        | timeout 3 nc "$CQ_HOST" "$CQ_PORT" > /dev/null 2>&1
    sleep 1
fi

# Upload file
UPLOAD_RESP=$(curl -s -X POST -H "Authorization: Bearer $TOKEN" \
    -F "file=@$AUDIO_FILE" \
    "$API_URL/api/v1/bot/upload")

UUID=$(echo "$UPLOAD_RESP" | jq -r '.uuid // empty')

if [[ -z "$UUID" ]]; then
    echo "Upload failed: $UPLOAD_RESP" >&2
    exit 1
fi

# Play
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
    "$API_URL/api/v1/bot/i/$INSTANCE/play/byId/$UUID" > /dev/null

echo "Playing: $AUDIO_FILE (UUID: $UUID)"
