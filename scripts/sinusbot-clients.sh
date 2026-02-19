#!/bin/bash
# List connected TeamSpeak clients via ClientQuery
# Usage: ./sinusbot-clients.sh
#
# Outputs client ID, channel ID, and nickname for each connected user.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_env.sh"

require_cq

RAW=$(
    (echo "auth apikey=$CQ_KEY"; sleep 0.3
     echo "clientlist"; sleep 0.3
    ) | timeout 5 nc "$CQ_HOST" "$CQ_PORT" 2>&1
)

if ! echo "$RAW" | grep -q "clid="; then
    echo "Failed to list clients. Is the bot connected to TeamSpeak?" >&2
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

echo "CLID  CID  Client Name"
echo "----  ---  -----------"

CLIENT_LINE=$(echo "$RAW" | grep "clid=")

IFS='|' read -ra ENTRIES <<< "$CLIENT_LINE"
for entry in "${ENTRIES[@]}"; do
    CLID=$(echo "$entry" | grep -oP 'clid=\K[0-9]+')
    CID=$(echo "$entry" | grep -oP 'cid=\K[0-9]+')
    NAME_RAW=$(echo "$entry" | grep -oP 'client_nickname=\K[^\s]+' | head -1)
    if [[ -n "$CLID" && -n "$NAME_RAW" ]]; then
        NAME=$(decode_cq "$NAME_RAW")
        printf "%-5s %-4s %s\n" "$CLID" "$CID" "$NAME"
    fi
done
