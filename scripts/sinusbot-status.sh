#!/bin/bash
# Check SinusBot and bot instance status
# Usage: ./sinusbot-status.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_env.sh"

require_bot

echo "=== SinusBot Status ==="

# Process check
if pgrep -f sinusbot > /dev/null; then
    echo "Process: ✓ Running"
else
    echo "Process: ✗ Not running"
fi

# Port check
if ss -tlnp 2>/dev/null | grep -q ':8087'; then
    echo "Port 8087: ✓ Listening"
else
    echo "Port 8087: ✗ Not listening"
    exit 1
fi

# Xvfb check
if pgrep -x Xvfb > /dev/null; then
    echo "Xvfb: ✓ Running"
else
    echo "Xvfb: ✗ Not running (TS3 client may fail)"
fi

# Screen session
if screen -ls | grep -q sinusbot; then
    echo "Screen: ✓ Session exists"
else
    echo "Screen: ⚠ No session (process may die on shell exit)"
fi

# Instance status (authenticate for detailed info)
TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\",\"botId\":\"$BOT_ID\"}" \
    "$API_URL/api/v1/bot/login" | jq -r '.token // empty')

if [[ -n "$TOKEN" ]]; then
    echo ""
    echo "=== Instance Status ==="
    STATUS=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "$API_URL/api/v1/bot/i/$INSTANCE/status")
    echo "$STATUS" | jq '{running: .running, playing: .playing, channel: .connStatus.channelId, nick: .connStatus.clientNick}'
else
    echo ""
    echo "⚠ Could not authenticate — skipping instance details"
fi
