---
name: teamspeak
description: Control TeamSpeak via SinusBot - connect, play audio, TTS, move channels. Use for voice playback, announcements, joining TS channels, or bot management.
---

# TeamSpeak Control via SinusBot

A SinusBot-controlled client connects to TeamSpeak through SinusBot (Web UI + API).

Implementation notes: see `docs/teamspeak-bridge-implementation.md`.

## Quick Reference

| Item | Value |
|------|-------|
| TS Server | configured in the TS client / SinusBot profile |
| Web UI | `$API_URL` (default `http://localhost:8087`) |
| Bot ID | `$BOT_ID` |
| Instance ID | `$INSTANCE` |
| ClientQuery | `$CQ_HOST:$CQ_PORT` (default `localhost:25639`) |
| ClientQuery Key | `$CLIENTQUERY_KEY` |

### Configuration (secrets)

Create `scripts/config.env` (ignored by git) or `./.env` and set:

```
BOT_ID=...
INSTANCE=...
CLIENTQUERY_KEY=...
```

Optional overrides:

```
API_URL=http://localhost:8087
CQ_HOST=localhost
CQ_PORT=25639
USERNAME=admin
PASSWORD=sinusbot
```

See `scripts/config.env.example` for a template.

### Channels

Use `sinusbot-channels.sh` for a live list. Channel IDs/names are server-specific.

## Scripts

Helper scripts in `skills/teamspeak/scripts/`. All use sensible defaults and env var overrides.

### Bot Lifecycle
- `sinusbot-start.sh [--reset-password]` — Start SinusBot process in screen
- `sinusbot-spawn.sh` — Connect bot to TeamSpeak (authenticate + spawn instance)
- `sinusbot-stop.sh [--disconnect]` — Stop audio playback, or `--disconnect` to leave TS entirely
- `sinusbot-status.sh` — Check process/port/instance health

### TeamSpeak Actions
- `sinusbot-move.sh <channel_id>` — Move bot to a channel (via ClientQuery)
- `sinusbot-chat.sh <message> [mode] [target_id]` — Send a message (mode: 1=DM, 2=channel, 3=server). **Automatically chunks messages longer than 1024 chars.**
- `sinusbot-play.sh <file> [channel_id]` — Upload and play audio file (optionally move first)

### Information
- `sinusbot-channels.sh` — List all TeamSpeak channels (CID + name)
- `sinusbot-clients.sh` — List connected users (CLID, CID, nickname)
- `sinusbot-whoami.sh` — Show bot's own client ID and current channel
- `sinusbot-auth.sh [user] [pass]` — Get raw API token (for manual API calls)

## Message Chunking

TeamSpeak has a 1024-character limit per message. The `sinusbot-chat.sh` script automatically handles this by splitting longer messages into multiple sends.

**Example:**
```bash
# This 2000-char message is automatically split into 2 messages
./sinusbot-chat.sh "$(printf 'a%.0s' {1..2000})"
# Output: "Sending channel message in 2 parts..."
```

## Common Workflows

All workflows use the scripts above. Run from the `scripts/` directory.

### Cold Start (SinusBot not running)

```bash
./sinusbot-start.sh --reset-password   # Start process
./sinusbot-spawn.sh                     # Connect to TS
```

### Join a Channel and Talk

```bash
./sinusbot-move.sh <channel_id>         # Move to a channel
./sinusbot-chat.sh "Hello everyone"     # Send channel message
```

### Play Audio in a Channel

```bash
./sinusbot-play.sh /path/to/audio.mp3 <channel_id>   # Move to a channel and play
```

### Full TTS to TeamSpeak

1. Generate TTS via OpenClaw `tts` tool → returns `MEDIA:/tmp/tts-xxx/voice-xxx.mp3`
2. `./sinusbot-spawn.sh` (ensure connected)
3. `./sinusbot-move.sh <channel_id>`
4. `./sinusbot-play.sh /tmp/tts-xxx/voice-xxx.mp3`

### DM a Specific User

```bash
./sinusbot-clients.sh                        # Find their CLID
./sinusbot-chat.sh "Hey there" 1 <clid>      # Send private message
```

### Check Who's Online

```bash
./sinusbot-clients.sh                   # All connected users
./sinusbot-channels.sh                  # All channels
./sinusbot-whoami.sh                    # Bot's own state
```

## Check Status

```bash
./sinusbot-status.sh          # Process, port, Xvfb, screen, instance
./sinusbot-whoami.sh          # Bot's CLID and current channel
tail -50 /tmp/sinusbot.log    # Recent logs
screen -r sinusbot            # Attach live console (Ctrl+A, D to detach)
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Port 8087 not listening | Restart with screen method |
| "Invalid username or password" | Start with `--override-password=sinusbot` |
| Bot disconnects immediately | Identity collision - wait 30s or kill ghost connections |
| ClientQuery refused | Instance not spawned - call spawn endpoint first |
| Process dies on shell exit | Not using screen - restart with screen method |

## API Endpoints

Base: `http://localhost:8087/api/v1`

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/bot/login` | POST | Get auth token |
| `/bot/i/{id}/spawn` | POST | Connect to TS |
| `/bot/i/{id}/kill` | POST | Disconnect from TS |
| `/bot/i/{id}/status` | GET | Instance status |
| `/bot/i/{id}/move` | POST | Move to channel (body: `{"channelId":"X"}`) |
| `/bot/upload` | POST | Upload audio (multipart) |
| `/bot/i/{id}/play/byId/{uuid}` | POST | Play uploaded audio |
| `/bot/i/{id}/stop` | POST | Stop playback |

## TeamSpeak Bridge Options

You have **two bridge scripts** to choose from. Pick the one that fits your use case:

### Option A: Comprehensive Event Bridge (Recommended)
**Script:** `bridge/openclaw-event-bridge.js`

Triggers the agent on **ALL major TeamSpeak events**:
- All chat messages (channel, DM, server) — no trigger prefix needed
- User joins
- User leaves/disconnects  
- Channel moves

**When to use:**
- You want the agent to be aware of all TeamSpeak activity
- You want contextual responses to joins, leaves, and moves
- You want the agent to participate naturally in all conversations

**Configuration (SinusBot UI):**
- OpenClaw Gateway URL
- Session key
- Agent ID
- Enable/disable individual event types (chat, joins, leaves, moves)
- Optional: notification channel ID for non-chat events
- Optional: silent mode (send events to agent but no TeamSpeak replies for non-chat)
- Rate limiting and input validation

**Event formats sent to agent:**
- `[TeamSpeak channel] User (in ChannelName): message`
- `[TeamSpeak DM] User: message`
- `[TeamSpeak server] User: message`
- `[TeamSpeak join] User joined (in: ChannelName)`
- `[TeamSpeak leave] User disconnected (reason)`
- `[TeamSpeak move] User moved from ChannelA to ChannelB`

### Option B: Mention-Only Trigger
**Script:** `bridge/openclaw-mention-trigger.js`

Triggers the agent **only** when mentioned with a specific prefix (e.g., `@assistant`).

**When to use:**
- You want the agent to respond only when explicitly called
- You want to reduce noise/API calls
- You prefer explicit invocation over ambient awareness

**Configuration (SinusBot UI):**
- Trigger prefix (e.g., `@assistant`)
- OpenClaw Gateway URL
- Session key
- Agent ID
- Rate limiting and input validation

### Choosing Between Them

| Feature | Event Bridge | Mention-Only |
|---------|-------------|--------------|
| All chat messages | ✓ | Only @mentions |
| User joins/leaves | ✓ | ✗ |
| Channel moves | ✓ | ✗ |
| API calls | High | Low |
| Context awareness | Full | Limited |
| Explicit control | Less | More |

**Recommendation:** Start with the **Event Bridge** for full awareness, then switch to Mention-Only if you need to reduce API calls or prefer explicit control.

### Archived/Inactive: Log-based Discord relay (TeamSpeak → OpenClaw → Discord)
This relay is **not running**. The details below are kept only for reference if you choose to re-enable it.

#### How It Works (archived)

1. Any TeamSpeak event occurs (user sends message, moves channel, joins, leaves)
2. A SinusBot script detects the event and formats it
3. Event is sent to OpenClaw gateway via `/v1/messages/send` API
4. OpenClaw posts the message to the configured Discord channel (`DISCORD_CHANNEL_ID`)
5. The agent sees the event in Discord mixed with other Discord activity and can respond

#### Event-triggered behavior (archived)

- When the agent is triggered by a TeamSpeak event (e.g., a user message, join, move, or DM), the event is routed into the Discord channel. If your bridge already forwards agent responses back to TeamSpeak, don’t manually re-send the same reply (prevents duplicates).
- Default behavior: if an agent response originates from handling a TeamSpeak event, do not call `sinusbot-chat.sh` to re-post the same content to TeamSpeak. Use `sinusbot-chat.sh` only for proactive messages initiated by the agent (not replies to an event) or when you intend to send additional/different content.

#### Events Tracked (archived)

| Event | Format | Example |
|-------|--------|---------|
| Channel message | `[TeamSpeak channel] User: text` | `[TeamSpeak channel] Alice: hello everyone` |
| DM | `[TeamSpeak DM] User: text` | `[TeamSpeak DM] Bob: need help?` |
| Server message | `[TeamSpeak server] User: text` | `[TeamSpeak server] Carol: attention everyone` |
| Channel move | `[TeamSpeak move] User moved from A to B` | `[TeamSpeak move] Dave moved from Lobby to Gaming` |
| User join | `[TeamSpeak join] User joined (in: Channel)` | `[TeamSpeak join] Eve joined (in: Lobby)` |
| User leave | `[TeamSpeak leave] User disconnected (reason)` | `[TeamSpeak leave] Frank disconnected (left)` |

#### Start/Restart SinusBot (archived relay)

```bash
# Kill existing instance (if needed)
pkill -f sinusbot

# Start SinusBot
./sinusbot-start.sh --reset-password   # Full restart
./sinusbot-spawn.sh                     # Connect to TS
```

#### Verification (archived relay)

Check SinusBot logs for initialization:

```bash
tail -20 /tmp/sinusbot.log | grep "TS-BRIDGE"
```

Expected output:
```
[TS-BRIDGE] initialized
[TS-BRIDGE] routing: ENABLED
```

#### Testing (archived relay)

1. Connect to your TeamSpeak server
2. Send a message in any channel or DM → Should appear in Discord with `[TeamSpeak...]` prefix
3. Move to a different channel → Should see `[TeamSpeak move]` event in Discord
4. Have someone join/leave → Should see `[TeamSpeak join]`/`[TeamSpeak leave]` in Discord
