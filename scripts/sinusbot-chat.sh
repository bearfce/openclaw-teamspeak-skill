#!/bin/bash
# Send a text message in TeamSpeak via ClientQuery
# Long messages are automatically chunked into multiple sends.
# Usage: ./sinusbot-chat.sh <message> [targetmode] [target_id]
#
# Target modes:
#   1 = Private message (target_id = client ID)
#   2 = Channel message (target_id = channel ID, default: current channel)
#   3 = Server message (target_id ignored)
#
# Default: sends to current channel (mode 2, target 0)
# Character limit: 1024 chars per message (chunked automatically)
#
# Examples:
#   ./sinusbot-chat.sh "Hello everyone"              # current channel
#   ./sinusbot-chat.sh "Hey there" 1 42              # DM to client 42
#   ./sinusbot-chat.sh "Server announcement" 3       # server-wide

MESSAGE="$1"
TARGET_MODE="${2:-2}"
TARGET_ID="${3:-0}"
MAX_CHUNK_SIZE="${TS_MAX_MSG_LEN:-1024}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_env.sh"

require_cq

if [[ -z "$MESSAGE" ]]; then
    echo "Usage: $0 <message> [targetmode: 1=private|2=channel|3=server] [target_id]" >&2
    exit 1
fi

# URL-encode the message for ClientQuery (spaces → \s, pipes → \p, etc.)
encode_cq() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s// /\\s}"
    s="${s////\\/}"
    s="${s//|/\\p}"
    printf '%s' "$s"
}

# Split message into chunks of MAX_CHUNK_SIZE characters
chunk_message() {
    local msg="$1"
    local chunk_size="$2"
    local pos=0
    
    while (( pos < ${#msg} )); do
        echo "${msg:$pos:$chunk_size}"
        (( pos += chunk_size ))
    done
}

# Main logic: chunk and send all parts in a single ClientQuery session
MSG_LEN=${#MESSAGE}
CHUNK_COUNT=$(( (MSG_LEN + MAX_CHUNK_SIZE - 1) / MAX_CHUNK_SIZE ))

if (( CHUNK_COUNT > 1 )); then
    case "$TARGET_MODE" in
        1) echo "Sending private message in $CHUNK_COUNT parts to client $TARGET_ID..." ;;
        2) echo "Sending channel message in $CHUNK_COUNT parts..." ;;
        3) echo "Sending server message in $CHUNK_COUNT parts..." ;;
    esac
fi

# Build all commands into a single batch
COMMANDS="auth apikey=$CQ_KEY"
COMMANDS+=$'\n'

SUCCESS_COUNT=0
FAIL_COUNT=0
while IFS= read -r chunk; do
    encoded=$(encode_cq "$chunk")
    COMMANDS+="sendtextmessage targetmode=$TARGET_MODE target=$TARGET_ID msg=$encoded"
    COMMANDS+=$'\n'
    (( SUCCESS_COUNT++ ))
done < <(chunk_message "$MESSAGE" "$MAX_CHUNK_SIZE")

# Send all commands in one session
RESULT=$(
    (echo -e "$COMMANDS"; sleep 0.5) | timeout 5 nc "$CQ_HOST" "$CQ_PORT" 2>&1
)

# Check if all sends succeeded (look for multiple "error id=0" responses)
ERROR_COUNT=$(echo "$RESULT" | grep -c "error id=0" || true)
if (( ERROR_COUNT < SUCCESS_COUNT )); then
    FAIL_COUNT=$((SUCCESS_COUNT - ERROR_COUNT))
    echo "Send completed with errors: $ERROR_COUNT sent, $FAIL_COUNT failed" >&2
    exit 1
else
    case "$TARGET_MODE" in
        1) echo "Sent private message ($CHUNK_COUNT part(s)) to client $TARGET_ID" ;;
        2) echo "Sent channel message ($CHUNK_COUNT part(s))" ;;
        3) echo "Sent server message ($CHUNK_COUNT part(s))" ;;
    esac
fi
