#!/bin/bash
# List TeamSpeak channels via ClientQuery
# Usage: ./sinusbot-channels.sh
#
# Outputs channel ID and name for each channel on the server.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_env.sh"

require_cq

RAW=$(
    (echo "auth apikey=$CQ_KEY"; sleep 0.3
     echo "channellist"; sleep 0.3
    ) | timeout 5 nc "$CQ_HOST" "$CQ_PORT" 2>&1
)

# Check for error
if ! echo "$RAW" | grep -q "cid="; then
    echo "Failed to list channels. Is the bot connected to TeamSpeak?" >&2
    echo "Raw: $RAW" >&2
    exit 1
fi

# Parse the channellist line — fields separated by | , key=value pairs
# Decode ClientQuery escapes: \s → space, \p → pipe, \/ → /
decode_cq() {
    local s="$1"
    s="${s//\\s/ }"
    s="${s//\\p/|}"
    s="${s//\\\///}"
    printf '%s' "$s"
}

echo "CID  Channel Name"
echo "---  ------------"

# The channellist response is on one line, entries separated by |
CHANNEL_LINE=$(echo "$RAW" | grep "cid=")

IFS='|' read -ra ENTRIES <<< "$CHANNEL_LINE"
for entry in "${ENTRIES[@]}"; do
    CID=$(echo "$entry" | grep -oP 'cid=\K[0-9]+')
    NAME_RAW=$(echo "$entry" | grep -oP 'channel_name=\K[^\s]+' | head -1)
    if [[ -n "$CID" && -n "$NAME_RAW" ]]; then
        NAME=$(decode_cq "$NAME_RAW")
        printf "%-4s %s\n" "$CID" "$NAME"
    fi
done
