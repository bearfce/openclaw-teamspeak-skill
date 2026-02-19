#!/bin/bash
# Get the bot's own client info from TeamSpeak via ClientQuery
# Usage: ./sinusbot-whoami.sh
#
# Returns the bot's client ID, channel ID, and nickname.
# Useful for verifying connection state and current channel.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_env.sh"

require_cq

RAW=$(
    (echo "auth apikey=$CQ_KEY"; sleep 0.3
     echo "whoami"; sleep 0.3
    ) | timeout 5 nc "$CQ_HOST" "$CQ_PORT" 2>&1
)

if ! echo "$RAW" | grep -q "clid="; then
    echo "Failed. Is the bot connected to TeamSpeak?" >&2
    echo "Raw: $RAW" >&2
    exit 1
fi

decode_cq() {
    local s="$1"
    s="${s//\\s/ }"
    s="${s//\\p/|}"
    s="${s//\\\///}"
    printf '%s' "$s"
}

WHOAMI_LINE=$(echo "$RAW" | grep "clid=")

CLID=$(echo "$WHOAMI_LINE" | grep -oP 'clid=\K[0-9]+')
CID=$(echo "$WHOAMI_LINE" | grep -oP 'cid=\K[0-9]+')

echo "Client ID: $CLID"
echo "Channel:   $CID"
