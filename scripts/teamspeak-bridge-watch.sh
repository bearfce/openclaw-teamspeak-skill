#!/bin/bash
# Run TeamSpeak bridge status and invoke Bearface on any error/warning.
# Usage: ./teamspeak-bridge-watch.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_env.sh" 2>/dev/null || true
STATUS_SCRIPT="$SCRIPT_DIR/teamspeak-bridge-status.sh"

LOG_FILE="${TS_BRIDGE_WATCH_LOG:-/home/claw/.openclaw/logs/teamspeak-bridge-watch.log}"
DISCORD_CHANNEL_ID="${DISCORD_CHANNEL_ID:-1468441876326776852}"
SESSION_TARGET="${ALERT_SESSION_TARGET:-discord:channel:${DISCORD_CHANNEL_ID}}"

# Ensure node + openclaw are on PATH for cron
export PATH="/home/claw/.nvm/versions/node/v24.13.0/bin:$PATH"
OPENCLAW_BIN="${OPENCLAW_BIN:-/home/claw/.nvm/versions/node/v24.13.0/bin/openclaw}"
if command -v openclaw >/dev/null 2>&1; then
  OPENCLAW_BIN="$(command -v openclaw)"
fi

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $*" >> "$LOG_FILE"
}

if [[ ! -x "$STATUS_SCRIPT" ]]; then
  log "ERROR: status script not found or not executable: $STATUS_SCRIPT"
  exit 1
fi

OUTPUT="$($STATUS_SCRIPT 2>&1)"
EXIT_CODE=$?

FAIL=0
if [[ $EXIT_CODE -ne 0 ]]; then
  FAIL=1
fi
if echo "$OUTPUT" | grep -qE "[✗⚠]"; then
  FAIL=1
fi

if [[ $FAIL -eq 0 ]]; then
  log "OK: bridge status healthy"
  exit 0
fi

# Prepare alert message
MAX=1500
if [[ ${#OUTPUT} -gt $MAX ]]; then
  OUTPUT="${OUTPUT:0:$MAX}... (truncated)"
fi

ALERT="[TS Bridge] status check failed on $(date '+%Y-%m-%d %H:%M:%S %Z')\n\n$OUTPUT"

if [[ ! -x "$OPENCLAW_BIN" ]]; then
  log "ERROR: openclaw CLI not found at $OPENCLAW_BIN"
  log "OUTPUT: $OUTPUT"
  exit 2
fi

OPENCLAW_OUTPUT=$(
  "$OPENCLAW_BIN" agent \
    --to "$SESSION_TARGET" \
    --message "$ALERT" \
    --deliver \
    --reply-channel discord \
    --reply-to "$DISCORD_CHANNEL_ID" \
    --timeout 30 2>&1
)
OPENCLAW_CODE=$?

if [[ $OPENCLAW_CODE -eq 0 ]]; then
  log "ALERT: invoked Bearface (openclaw agent)"
else
  log "ALERT: failed to invoke Bearface (openclaw agent exit $OPENCLAW_CODE)"
  log "OPENCLAW: $OPENCLAW_OUTPUT"
  log "OUTPUT: $OUTPUT"
fi

exit 0
