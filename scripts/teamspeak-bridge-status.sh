#!/bin/bash
# Check TeamSpeak bridge + OpenClaw integration status
# Usage: ./teamspeak-bridge-status.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_env.sh" 2>/dev/null || true

LOG_FILE="${TS_BRIDGE_LOG:-${SINUSBOT_LOG:-/tmp/sinusbot.log}}"
BRIDGE_SCRIPT="${TS_BRIDGE_SCRIPT:-/home/claw/ts3audiobot/scripts/bearface-trigger.js}"
OPENCLAW_URL="${OPENCLAW_URL:-}"

parse_port() {
  local url="$1"
  local port
  port=$(echo "$url" | sed -nE 's#^https?://[^:/]+:([0-9]+).*#\1#p')
  if [[ -z "$port" ]]; then
    if [[ "$url" == https://* ]]; then
      port=443
    else
      port=80
    fi
  fi
  echo "$port"
}

extract_js_value() {
  local key="$1"
  local file="$2"
  grep -m1 "$key" "$file" 2>/dev/null | sed -nE "s/.*${key}[[:space:]]*:[[:space:]]*['\"]([^'\"]+)['\"].*/\1/p"
}

if [[ -z "$OPENCLAW_URL" && -f "$BRIDGE_SCRIPT" ]]; then
  OPENCLAW_URL=$(extract_js_value "openclawUrl" "$BRIDGE_SCRIPT")
fi

if [[ -z "$OPENCLAW_URL" ]]; then
  OPENCLAW_URL="http://127.0.0.1:18789"
fi

API_PORT=8087
if [[ -n "$API_URL" ]]; then
  API_PORT=$(parse_port "$API_URL")
fi

echo "========================================="
echo "TeamSpeak Bridge + Integration Status"
echo "========================================="

# 1) SinusBot process
if pgrep -f sinusbot > /dev/null; then
  SINUS_PID=$(pgrep -f sinusbot | head -1)
  echo "SinusBot: ✓ Running (PID: $SINUS_PID)"
else
  echo "SinusBot: ✗ Not running"
fi

# 2) API port
if command -v ss >/dev/null 2>&1; then
  if ss -tlnp 2>/dev/null | grep -q ":$API_PORT"; then
    echo "API Port $API_PORT: ✓ Listening"
  else
    echo "API Port $API_PORT: ✗ Not listening"
  fi
else
  echo "API Port $API_PORT: ⚠ ss not available for port check"
fi

# 3) Instance status (if configured)
if [[ -n "$BOT_ID" && -n "$INSTANCE" ]]; then
  TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\",\"botId\":\"$BOT_ID\"}" \
    "$API_URL/api/v1/bot/login" | jq -r '.token // empty')

  if [[ -n "$TOKEN" ]]; then
    STATUS=$(curl -s -H "Authorization: Bearer $TOKEN" \
      "$API_URL/api/v1/bot/i/$INSTANCE/status")
    if command -v jq >/dev/null 2>&1; then
      RUNNING=$(echo "$STATUS" | jq -r '.running // empty')
      PLAYING=$(echo "$STATUS" | jq -r '.playing // empty')
      CHANNEL=$(echo "$STATUS" | jq -r '.connStatus.channelId // empty')
      NICK=$(echo "$STATUS" | jq -r '.connStatus.clientNick // empty')
      echo "Instance: ✓ running=$RUNNING playing=$PLAYING channel=$CHANNEL nick=$NICK"
    else
      echo "Instance: ✓ status received (jq not available to parse)"
    fi
  else
    echo "Instance: ⚠ Auth failed (check USERNAME/PASSWORD/BOT_ID)"
  fi
else
  echo "Instance: ⚠ BOT_ID/INSTANCE not set"
fi

# 4) Bridge script + logs
if [[ -f "$BRIDGE_SCRIPT" ]]; then
  echo "Bridge script: ✓ Found"

  BRIDGE_OPENCLAW=$(extract_js_value "openclawUrl" "$BRIDGE_SCRIPT")
  BRIDGE_SESSION=$(extract_js_value "sessionKey" "$BRIDGE_SCRIPT")

  if [[ -n "$BRIDGE_OPENCLAW" ]]; then
    echo "Bridge config: ✓ OpenClaw URL configured"
  else
    echo "Bridge config: ⚠ OpenClaw URL not found in script"
  fi

  if [[ -n "$BRIDGE_SESSION" ]]; then
    echo "Bridge config: ✓ sessionKey configured"
  else
    echo "Bridge config: ⚠ sessionKey not found in script"
  fi
else
  echo "Bridge script: ✗ Not found ($BRIDGE_SCRIPT)"
fi

if [[ -f "$LOG_FILE" ]]; then
  LINES=$(wc -l < "$LOG_FILE" | tr -d ' ')
  echo "Log: ✓ $LOG_FILE ($LINES lines)"

  BF_COUNT=$(grep -c "Bearface Bridge" "$LOG_FILE" 2>/dev/null || true)
  TS_COUNT=$(grep -c "\[TS-BRIDGE\]\|\[DISCORD-BRIDGE\]" "$LOG_FILE" 2>/dev/null || true)

  if [[ "$BF_COUNT" -gt 0 ]]; then
    echo "Bridge logs: ✓ Bearface Bridge entries: $BF_COUNT"
    LAST_BF=$(grep "Bearface Bridge" "$LOG_FILE" | tail -n 1)
    echo "Last bridge log: $LAST_BF"
  else
    echo "Bridge logs: ⚠ No Bearface Bridge entries found"
  fi

  if [[ "$TS_COUNT" -gt 0 ]]; then
    echo "Event logs: ✓ TS/Discord bridge entries: $TS_COUNT"
  else
    echo "Event logs: (optional) none found"
  fi
else
  if command -v journalctl >/dev/null 2>&1 && systemctl --user status sinusbot.service >/dev/null 2>&1; then
    JOURNAL=$(journalctl --user -u sinusbot.service -n 200 --no-pager 2>/dev/null)
    if [[ -n "$JOURNAL" ]]; then
      echo "Log: ✓ journalctl (sinusbot.service, last 200 lines)"

      BF_COUNT=$(echo "$JOURNAL" | grep -c "Bearface Bridge" 2>/dev/null || true)
      TS_COUNT=$(echo "$JOURNAL" | grep -c "\[TS-BRIDGE\]\|\[DISCORD-BRIDGE\]" 2>/dev/null || true)

      if [[ "$BF_COUNT" -gt 0 ]]; then
        echo "Bridge logs: ✓ Bearface Bridge entries: $BF_COUNT"
        LAST_BF=$(echo "$JOURNAL" | grep "Bearface Bridge" | tail -n 1)
        echo "Last bridge log: $LAST_BF"
      else
        echo "Bridge logs: ⚠ No Bearface Bridge entries found"
      fi

      if [[ "$TS_COUNT" -gt 0 ]]; then
        echo "Event logs: ✓ TS/Discord bridge entries: $TS_COUNT"
      else
        echo "Event logs: (optional) none found"
      fi
    else
      echo "Log: ⚠ journalctl empty (sinusbot.service)"
    fi
  else
    echo "Log: ⚠ Not found ($LOG_FILE) and no sinusbot.service logs"
  fi
fi

# 5) OpenClaw gateway reachability
if [[ -n "$OPENCLAW_URL" ]]; then
  OC_PORT=$(parse_port "$OPENCLAW_URL")
  if command -v ss >/dev/null 2>&1; then
    if ss -tlnp 2>/dev/null | grep -q ":$OC_PORT"; then
      echo "OpenClaw port $OC_PORT: ✓ Listening"
    else
      echo "OpenClaw port $OC_PORT: ✗ Not listening"
    fi
  fi

  if command -v curl >/dev/null 2>&1; then
    CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$OPENCLAW_URL/v1/models")
    if [[ "$CODE" == "200" ]]; then
      echo "OpenClaw HTTP: ✓ /v1/models reachable"
    elif [[ "$CODE" == "401" ]]; then
      echo "OpenClaw HTTP: ✓ reachable (auth required)"
    else
      echo "OpenClaw HTTP: ⚠ status=$CODE"
    fi
  else
    echo "OpenClaw HTTP: ⚠ curl not available"
  fi
fi

# 6) Legacy listeners (if any)
LEGACY_PIDS=$(pgrep -af "bridge-listener|log-listener|listener-daemon|bridge-monitor|monitor-bridge|process-ts-bridge-queue" 2>/dev/null || true)
if [[ -n "$LEGACY_PIDS" ]]; then
  echo "Legacy listeners: ⚠ running"
  echo "$LEGACY_PIDS"
else
  echo "Legacy listeners: ✓ none detected"
fi

echo "========================================="
