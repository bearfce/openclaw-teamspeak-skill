# TeamSpeak Bridge Setup (SinusBot + OpenClaw)

This is a **setup/installation** guide for the TeamSpeak ↔ Discord bridge using SinusBot.
**No secrets are included** - use placeholders and your own values.

> For day-to-day bot control commands, see `SKILL.md`.
> For implementation details, see `docs/teamspeak-bridge-implementation.md`.
>
> **Bridge Options:** Choose between two active SinusBot bridge scripts:
> - **Comprehensive Event Bridge** (`bridge/openclaw-event-bridge.js`) - triggers on ALL TeamSpeak events (chat, joins, leaves, moves)
> - **Mention-Only Trigger** (`bridge/openclaw-mention-trigger.js`) - triggers only on @mentions
> 
> See `SKILL.md` for a detailed comparison and setup instructions.

---

## Architecture (high level)

**Option A: Comprehensive Event Bridge (Recommended)**
1. **SinusBot** runs `openclaw-event-bridge.js`
2. ALL TeamSpeak events (chat, joins, leaves, moves) POST to OpenClaw `/v1/chat/completions`
3. Agent responses are sent back to TeamSpeak (configurable per event type)

**Option B: Mention-Only Trigger**
1. **SinusBot** runs `openclaw-mention-trigger.js`
2. Only messages with trigger prefix (e.g., `@assistant`) POST to OpenClaw `/v1/chat/completions`
3. The HTTP response is sent back to the TeamSpeak user/channel

**Archived: Event log → OpenClaw → Discord (INACTIVE)**
1. **SinusBot** runs a script that logs `[TS-BRIDGE] ...` entries
2. A **listener** tails that log and forwards entries to OpenClaw → Discord (`/v1/messages/send`)

---

## Required Ports
- **TeamSpeak voice:** `9987/UDP` (required)
- **SinusBot Web UI + API:** `8087/TCP` (required)
- **TeamSpeak ClientQuery:** `25639/TCP` (local; used by scripts like `sinusbot-move.sh`)
- **TeamSpeak file transfer:** `30033/TCP` (optional)
- **TeamSpeak ServerQuery:** `10011/TCP` (optional)
- **OpenClaw gateway:** `http(s)://<openclaw-host>:<port>` (if listener posts to a remote gateway)

---

## Configuration Placeholders
Use these placeholders in env vars / config files:

```bash
# TeamSpeak
TS_SERVER_HOST=<ts_server_host>
TS_SERVER_PORT=<ts_voice_port>  # usually 9987/UDP
TS_IDENTITY=<ts_identity>
TS_NICKNAME=<bot_nickname>

# SinusBot
SINUSBOT_DIR=/opt/sinusbot
SINUSBOT_USER=<sinusbot_user>
SINUSBOT_PASS=<sinusbot_password>
BOT_ID=<sinusbot_bot_id>
INSTANCE=<sinusbot_instance_id>
API_URL=http://<sinusbot-host>:8087

# ClientQuery (used by move/chat scripts)
CQ_HOST=localhost
CQ_PORT=25639
CQ_KEY=<CLIENTQUERY_KEY>

# Bridge routing
GATEWAY_URL=http://<openclaw-host>:<port>
GATEWAY_TOKEN=<openclaw_gateway_token>
DISCORD_CHANNEL_ID=<discord_channel_id>

# Mention-trigger routing (for bearface-trigger.js / openclaw-mention-trigger.js)
OPENCLAW_SESSION_KEY=agent:<agent_name>:discord:channel:<id>
OPENCLAW_AGENT_ID=main
TRIGGER_PREFIX=@assistant
```

Tip: copy `scripts/config.env.example` → `scripts/config.env` (ignored by git) and fill in BOT_ID, INSTANCE, CLIENTQUERY_KEY.

---

## Docker (SinusBot + TeamSpeak client)
This repo includes a **Dockerfile** that installs SinusBot, the TeamSpeak client, Xvfb, and PulseAudio so you can run the bridge headless.

### Build
```bash
docker build -t openclaw-teamspeak .
```

### Build args (optional)
```bash
# Override Node version or SinusBot download URL
docker build \
  --build-arg NODE_VERSION=20.11.1 \
  --build-arg SINUSBOT_URL=https://www.sinusbot.com/dl/sinusbot.current.tar.bz2 \
  -t openclaw-teamspeak .
```

### Run
```bash
docker run -d --name openclaw-teamspeak \
  --restart unless-stopped \
  -p 8087:8087 \
  -p 25639:25639 \
  -v /path/to/ts-data:/data \
  -e SINUSBOT_ADMIN_PASSWORD=<admin_password> \
  openclaw-teamspeak
```

**What persists in `/data`:**
- `config.ini`, `sinusbot.log`, identities, settings DB
- `scripts/` (custom scripts)

**Seeded scripts:** on first boot, the container copies `openclaw-mention-trigger.js` into `/data/scripts/` if it's missing.

### Docker env vars (optional)
```bash
SINUSBOT_ADMIN_PASSWORD=<admin_password>      # overrides admin password on boot
SINUSBOT_DATA_DIR=/data
SINUSBOT_SCRIPTS_DIR=/data/scripts
SINUSBOT_CONFIG=/data/config.ini
TS3_PATH=/opt/teamspeak-client/ts3client_linux_amd64
```

**Notes:**
- The SinusBot download endpoint may redirect to `dl.sinusbot.com`. If your DNS can't resolve it, mirror the tarball somewhere reachable and set `SINUSBOT_URL` at build time.
- The container connects **out** to your TeamSpeak server; you typically don't need to publish `9987/UDP` unless you run a TS server locally.
- TeamSpeak and SinusBot license terms apply. Building the image implies acceptance.
- Enable `openclaw-mention-trigger.js` in the SinusBot UI after the first boot.

---

## 1) Install SinusBot (headless)
1. Download and extract SinusBot into `$SINUSBOT_DIR`.
2. Install the TeamSpeak 3 client binary and set `TS3Path` in `config.ini`:
   - `TS3Path = "/path/to/ts3client_linux_amd64"`
3. Ensure **Xvfb** is available for headless operation (`DISPLAY=:99`).

---

## 2) Configure SinusBot (Web UI)
1. Open `http://<sinusbot-host>:8087`.
2. Set admin credentials (**store safely**).
3. Create a **Bot** and **Instance**:
   - Server: `<TS_SERVER_HOST>:<TS_SERVER_PORT>`
   - Nickname: `<TS_NICKNAME>`
   - Identity: `<TS_IDENTITY>`
4. Record **BOT_ID** and **INSTANCE** from the UI.
   - **Tip (Docker / headless):** On first boot, SinusBot auto-creates a default bot. Discover the `BOT_ID` via the API:
     ```bash
     curl -s http://localhost:8087/api/v1/botId | jq -r .defaultBotId
     ```
   - The instance ID is returned after authenticating - see `sinusbot-auth.sh` or the instance list endpoint.

---

## 3) Add/Enable the Bridge Script

### Option A: @-mention trigger (OpenClaw direct)
1. Copy `bridge/openclaw-mention-trigger.js` into the SinusBot **scripts** directory. Rename to `bearface-trigger.js` if you want to match the live deployment name.
2. Enable it in the SinusBot UI.
3. Configure the script settings in the UI:
   - **Trigger prefix** (e.g., `@assistant`)
   - **OpenClaw Gateway URL** (e.g., `http://localhost:18789`)
   - **OpenClaw token** (if required)
   - **Session key** (`x-openclaw-session-key`, for shared context)
   - **Agent id** (default `main`)
4. When a user types the trigger prefix, the script calls `/v1/chat/completions` and replies in TeamSpeak.

### Option B: Log-based event bridge (to Discord) - **ARCHIVED/INACTIVE**
1. Copy your bridge script (e.g., `teamspeak-bridge.js`) into the SinusBot **scripts** directory.
2. Enable it in the SinusBot UI.
3. Ensure it emits log lines like:
   ```
   [TS-BRIDGE] [TeamSpeak channel] User: message text
   ```
   (Tag is configurable; just make the listener match.)
4. If the script posts directly to OpenClaw, configure:
   - `GATEWAY_URL`, `GATEWAY_TOKEN`, `DISCORD_CHANNEL_ID`

> If you only use Option A, you do **not** need the log listener in step 6.

---

## 4) Start SinusBot
Use the helper script in this repo:

```bash
cd ./scripts
export SINUSBOT_DIR=/opt/sinusbot
./sinusbot-start.sh --reset-password   # optional
```

---

## 5) Spawn (Connect) the Bot Instance
```bash
cd ./scripts
export API_URL=http://<sinusbot-host>:8087
export BOT_ID=<BOT_ID>
export INSTANCE=<instance_id>
export USERNAME=<sinusbot_user>
export PASSWORD=<sinusbot_password>
./sinusbot-spawn.sh
```

---

## 6) Start the Bridge Listener (log → OpenClaw)
**Archived/inactive.** Skip this step unless you explicitly re-enable **Option B**.

Run a log-tail listener that forwards `[TS-BRIDGE]` entries to Discord.

Example (custom or from archive scripts):

```bash
export GATEWAY_URL=http://<openclaw-host>:<port>
export GATEWAY_TOKEN=<openclaw_gateway_token>
export DISCORD_CHANNEL_ID=<discord_channel_id>
python3 /path/to/bridge-listener.py
```

> Start the listener **before** SinusBot so early events are captured.

---

## 7) Verify
- **Option A:** Send a TeamSpeak message with the trigger prefix (e.g., `@assistant hello`) → confirm the bot replies in TeamSpeak.
- **Option B (if re-enabled):** `tail -50 /tmp/sinusbot.log | grep TS-BRIDGE`
- Send a TeamSpeak message → confirm it appears in Discord with a `[TeamSpeak ...]` prefix.

---

## Message Handling

### Character Limits
TeamSpeak has a **1024-character limit per message**. The mention-trigger script handles this automatically:
- **Long responses are chunked** into multiple messages (1024 chars each)
- Small delays between chunks prevent rate limiting
- The script logs how many parts were sent

Example: A 2500-character response is split into 3 messages.

### Rate Limiting
To prevent spam:
- **Rate limiting is enabled by default** (2 seconds between mentions per user)
- Configure `rateLimitMs` in the SinusBot plugin settings
- Users receive a message if they trigger too quickly

### Input Validation
- Control characters are stripped from user messages
- Messages are limited to 4096 characters
- Empty messages (after sanitization) are rejected

---

## Notes / Gotchas
- **Avoid duplicates:** If a Discord response is already triggered by a TeamSpeak event, don't manually re‑send the same reply back to TS.
- **Ghost sessions:** If SinusBot reconnects too quickly after a crash, TS may reject the new connection. Wait ~30s and retry.
- **Local vs remote:** `localhost` API URLs only work on the SinusBot host. Use a tunnel or expose ports for remote control.
- **Security:** Store API tokens securely; never send passwords or sensitive data via TeamSpeak.
