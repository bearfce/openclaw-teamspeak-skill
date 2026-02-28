# Comprehensive Event Bridge Setup Guide

This guide walks through setting up the **comprehensive event bridge** (`openclaw-event-bridge.js`) to trigger your OpenClaw agent on all major TeamSpeak events.

## What You Get

With the comprehensive event bridge, your agent will be notified of:
- ✅ All chat messages (channel, DM, server) — no @mention required
- ✅ User joins
- ✅ User leaves/disconnects
- ✅ Channel moves

The agent can respond contextually to any of these events.

## Prerequisites

1. **SinusBot** installed and running
2. **TeamSpeak server** connection configured in SinusBot
3. **OpenClaw gateway** accessible from the SinusBot host
4. **OpenClaw session key** for the target agent/channel

## Installation Steps

### 1. Copy the Script to SinusBot

```bash
# Find your SinusBot scripts directory (usually one of these):
# /opt/sinusbot/scripts/
# ~/sinusbot/scripts/

cp bridge/openclaw-event-bridge.js /opt/sinusbot/scripts/
```

### 2. Restart SinusBot

```bash
# If using systemd:
sudo systemctl restart sinusbot

# If running in screen:
screen -r sinusbot
# Ctrl+C to stop, then restart:
./sinusbot --override-password=yourpassword
# Ctrl+A, D to detach
```

### 3. Enable and Configure the Script

1. Open SinusBot Web UI: `http://your-server:8087`
2. Go to **Scripts** tab
3. Find **"OpenClaw Event Bridge"** and click **Settings**

### 4. Configure the Bridge

#### Required Settings:

| Setting | Example | Description |
|---------|---------|-------------|
| OpenClaw Gateway URL | `http://localhost:18789` | Your OpenClaw gateway endpoint |
| Session key | `agent:bearface:discord:channel:123...` | Target session for events |
| Agent ID | `main` | OpenClaw agent to trigger |

#### Optional Settings:

| Setting | Default | Description |
|---------|---------|-------------|
| OpenClaw token | _(empty)_ | Gateway auth token if required |
| Debug mode | OFF | Enable verbose logging |
| HTTP timeout | 60000 | Timeout in milliseconds |

#### Event Toggles (all ON by default):

- ☑️ Track channel chat messages
- ☑️ Track private messages (DMs)
- ☑️ Track server-wide messages
- ☑️ Track user joins
- ☑️ Track user leaves/disconnects
- ☑️ Track channel moves

#### Advanced Settings:

| Setting | Default | Description |
|---------|---------|-------------|
| Rate limiting | ON | Prevent spam (5000ms default) |
| Rate limit (ms) | 5000 | Min time between events per user |
| Input validation | ON | Sanitize user input |
| Notification channel ID | _(empty)_ | Optional channel for non-chat events |
| Silent mode | OFF | Send events to agent but no TS replies for non-chat |

### 5. Save and Enable

1. Click **Save**
2. Check the **Enabled** checkbox
3. Click **Save** again

### 6. Verify It's Running

Check SinusBot logs:

```bash
tail -50 /tmp/sinusbot.log | grep "OpenClaw Event Bridge"
```

**Expected output:**
```
[OpenClaw Event Bridge] OpenClaw Event Bridge v1.0.0 initialized
[OpenClaw Event Bridge] Session: agent:bearface:disco...
[OpenClaw Event Bridge] Events tracked:
[OpenClaw Event Bridge]   - Channel chat: ON
[OpenClaw Event Bridge]   - Private messages: ON
[OpenClaw Event Bridge]   - Server messages: ON
[OpenClaw Event Bridge]   - Joins: ON
[OpenClaw Event Bridge]   - Leaves: ON
[OpenClaw Event Bridge]   - Moves: ON
[OpenClaw Event Bridge] Silent mode: OFF
[OpenClaw Event Bridge] Debug: OFF
```

## Testing

### Test 1: Channel Chat
1. Connect to TeamSpeak
2. Send a message in any channel (no @mention needed)
3. Agent should receive the event and respond

### Test 2: User Join
1. Have someone join the server
2. Agent should be notified: `[TeamSpeak join] User joined (in: ChannelName)`
3. If not in silent mode, agent can respond in the notification channel

### Test 3: Channel Move
1. Move to a different channel
2. Agent should be notified: `[TeamSpeak move] User moved from A to B`

### Test 4: Private Message
1. Send a DM to the bot or another user
2. Agent should receive: `[TeamSpeak DM] User: message`

## Troubleshooting

### No events are triggering

**Check:**
- Script is enabled in SinusBot UI
- SinusBot is connected to TeamSpeak (`./sinusbot-whoami.sh`)
- Gateway URL is correct and reachable
- Session key is valid

**Fix:**
```bash
# Restart SinusBot
sudo systemctl restart sinusbot

# Check bot connection
./scripts/sinusbot-whoami.sh

# Check logs
tail -50 /tmp/sinusbot.log
```

### Events trigger but no responses in TeamSpeak

**Check:**
- Silent mode is OFF (unless you want it on)
- Agent is actually generating responses
- Rate limiting isn't blocking (check logs)

**Debug:**
- Enable **Debug mode** in script settings
- Watch logs: `tail -f /tmp/sinusbot.log | grep "OpenClaw Event Bridge"`

### Too many API calls / high volume

**Solutions:**

1. **Disable some event types** — Turn off joins/leaves/moves, keep only chat
2. **Switch to mention-only** — Use `openclaw-mention-trigger.js` instead
3. **Increase rate limit** — Raise the rate limit ms to reduce frequency
4. **Enable silent mode for non-chat** — Events go to agent, but no TS replies

### Rate limiting kicking in too often

**Adjust the rate limit:**
- Default: 5000ms (5 seconds between events per user)
- Lower it for more responsive (but higher volume)
- Raise it for less spam (but slower response)

## Event Formats

The agent receives events in these formats:

```
[TeamSpeak channel] Username (in ChannelName): message text
[TeamSpeak DM] Username: message text
[TeamSpeak server] Username: message text
[TeamSpeak join] Username joined (in: ChannelName)
[TeamSpeak leave] Username disconnected (reason)
[TeamSpeak move] Username moved from ChannelA to ChannelB
```

## Switching Between Bridges

### To switch from Mention-Only to Comprehensive:

1. **Disable** the old script (openclaw-mention-trigger.js)
2. **Enable** openclaw-event-bridge.js
3. Configure settings (see above)

### To switch from Comprehensive to Mention-Only:

1. **Disable** openclaw-event-bridge.js
2. **Enable** openclaw-mention-trigger.js
3. Set trigger prefix (e.g., `@assistant`)

Both scripts can coexist but **only enable one at a time** to avoid duplicate messages.

## Performance Considerations

### API Call Volume

With comprehensive event bridge:
- **High traffic server**: Could generate hundreds of API calls per hour
- **Low traffic server**: Typically 10-50 calls per hour

**Recommendation:** Start with all events enabled, monitor volume, then adjust.

### Rate Limiting

Default 5-second rate limit per user prevents:
- Spam from single users
- Accidental loops
- API quota exhaustion

Adjust based on your needs and API limits.

## Silent Mode

**Use case:** You want the agent to be aware of all events but only reply to chat messages.

**How it works:**
- All events (chat, joins, leaves, moves) are sent to the agent
- Agent responses for **chat** events are posted to TeamSpeak
- Agent responses for **non-chat** events (joins, leaves, moves) are NOT posted

**When to use:**
- Build context awareness without cluttering channels with join/leave replies
- Reduce noise while maintaining full event tracking
- Agent uses events for internal state but doesn't need to respond publicly

**Enable:** Set **Silent mode** to ON in script settings.

## Notification Channel

**Use case:** All join/leave/move responses go to a specific channel (like a status channel).

**How to configure:**
1. Find your channel ID: `./scripts/sinusbot-channels.sh`
2. Set **Notification channel ID** in script settings
3. Join/leave/move responses will be posted there instead of the event channel

**Leave empty:** Responses go to the channel where the event occurred.

## Best Practices

1. **Start with all events enabled** — See what the agent does naturally
2. **Monitor API usage** — Check your gateway logs for volume
3. **Tune rate limiting** — Adjust based on server activity
4. **Use silent mode** — If you want awareness without noise
5. **Set notification channel** — For centralized status updates
6. **Enable debug mode temporarily** — When troubleshooting
7. **Disable unused event types** — If joins/leaves aren't useful, turn them off

## Security Notes

- **Input validation** is ON by default (removes control characters, limits length)
- **Rate limiting** is ON by default (prevents abuse)
- **Bot's own events are ignored** (prevents loops)
- Never commit your session key or gateway token to git

## Next Steps

- Check `SKILL.md` for bot control commands
- See `teamspeak-bridge-implementation.md` for implementation details
- Use `scripts/teamspeak-bridge-status.sh` to monitor bridge health
