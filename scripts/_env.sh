#!/bin/bash
# Shared env loader for TeamSpeak/SinusBot scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load optional local config (not committed)
if [[ -f "$SCRIPT_DIR/config.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/config.env"
  set +a
elif [[ -f "$SCRIPT_DIR/../.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/../.env"
  set +a
fi

API_URL="${API_URL:-http://localhost:8087}"
BOT_ID="${BOT_ID:-${SINUSBOT_BOT_ID:-}}"
INSTANCE="${INSTANCE:-${SINUSBOT_INSTANCE_ID:-}}"
USERNAME="${USERNAME:-admin}"
PASSWORD="${PASSWORD:-sinusbot}"

CQ_HOST="${CQ_HOST:-${CLIENTQUERY_HOST:-localhost}}"
CQ_PORT="${CQ_PORT:-${CLIENTQUERY_PORT:-25639}}"
if [[ -z "${CQ_KEY:-}" ]]; then
  CQ_KEY="${CLIENTQUERY_KEY:-}"
fi

export API_URL BOT_ID INSTANCE USERNAME PASSWORD CQ_HOST CQ_PORT CQ_KEY

require_bot() {
  if [[ -z "$BOT_ID" || -z "$INSTANCE" ]]; then
    echo "Missing BOT_ID/INSTANCE (set env or scripts/config.env)" >&2
    exit 1
  fi
}

require_cq() {
  if [[ -z "$CQ_KEY" ]]; then
    echo "Missing CLIENTQUERY_KEY (set CQ_KEY/CLIENTQUERY_KEY or scripts/config.env)" >&2
    exit 1
  fi
}
