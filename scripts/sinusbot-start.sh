#!/bin/bash
# Start SinusBot with screen (survives shell exits)
# Usage: ./sinusbot-start.sh [--reset-password]

SINUSBOT_DIR="${SINUSBOT_DIR:-$HOME/ts3audiobot}"
LOG_FILE="/tmp/sinusbot.log"

# Ensure Xvfb is running (required for TS3 client)
if ! pgrep -x Xvfb > /dev/null; then
    echo "Starting Xvfb..."
    Xvfb :99 -screen 0 1024x768x24 &
    sleep 2
fi

# Kill existing instances
screen -S sinusbot -X quit 2>/dev/null
pkill -f sinusbot 2>/dev/null
sleep 2

# Build command
CMD="cd $SINUSBOT_DIR && DISPLAY=:99 ./sinusbot"
if [[ "$1" == "--reset-password" ]]; then
    CMD="$CMD --override-password=sinusbot"
    echo "Password will be reset to: sinusbot"
fi
CMD="$CMD 2>&1 | tee $LOG_FILE"

# Start with screen
screen -dmS sinusbot bash -c "$CMD"
echo "Started SinusBot in screen session 'sinusbot'"

# Wait for port
echo "Waiting for port 8087..."
for i in {1..15}; do
    if ss -tlnp 2>/dev/null | grep -q ':8087'; then
        echo "✓ SinusBot ready on port 8087"
        exit 0
    fi
    sleep 1
done

echo "✗ Timeout waiting for port 8087. Check: tail -50 $LOG_FILE"
exit 1
