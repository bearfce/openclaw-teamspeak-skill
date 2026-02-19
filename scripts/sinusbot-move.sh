#!/bin/bash
# Move bot to a TeamSpeak channel via ClientQuery
# Usage: ./sinusbot-move.sh <channel_id>
#
# Known channels:
#   1 = Spawn Room
#   5 = STONKS 🚀🚀
#
# Uses ClientQuery (more reliable than the HTTP API move endpoint).

CHANNEL_ID="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_env.sh"

require_cq

if [[ -z "$CHANNEL_ID" ]]; then
    echo "Usage: $0 <channel_id>" >&2
    echo "Known channels: 1=Spawn Room, 5=STONKS" >&2
    exit 1
fi

RESULT=$(
    (echo "auth apikey=$CQ_KEY"; sleep 0.3
     echo "clientmove cid=$CHANNEL_ID clid=0"; sleep 0.3
    ) | timeout 5 nc "$CQ_HOST" "$CQ_PORT" 2>&1
)

if echo "$RESULT" | grep -q "error id=0"; then
    echo "Moved to channel $CHANNEL_ID"
else
    echo "Move failed: $RESULT" >&2
    exit 1
fi
