# TeamSpeak Bridge Setup (SinusBot + OpenClaw)

This is a **setup/installation** guide for the TeamSpeak ↔ Discord bridge using SinusBot.  
**No secrets are included** — use placeholders and your own values.

> For day‑to‑day bot control commands, see `SKILL.md`.
> For implementation details, see `docs/teamspeak-bridge-implementation.md`.

---

## Architecture (high level)
Two common receive paths are supported:

**A) @-mention trigger → OpenClaw → reply in TeamSpeak**
1. **SinusBot** runs `openclaw-mention-trigger.js`.
2. On a trigger prefix (e.g., `@assistant`), the script POSTs to OpenClaw `/v1/chat/completions`.
3. The HTTP response is sent back to the TeamSpeak user/channel.

**B) Event log → OpenClaw → Discord**
1. **SinusBot** runs a script that logs `[TS-BRIDGE] ...` entries (commonly `/tmp/sinusbot.log`).
2. A **listener** tails that log and forwards entries to OpenClaw → Discord (`/v1/messages/send`).

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

# Mention-trigger routing (for openclaw-mention-trigger.js)
OPENCLAW_SESSION_KEY=agent:<agent_name>:discord:channel:<id>
OPENCLAW_AGENT_ID=main
TRIGGER_PREFIX=@assistant
```

Tip: copy `scripts/config.env.example` → `scripts/config.env` (ignored by git) and fill in BOT_ID, INSTANCE, CLIENTQUERY_KEY.

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

---

## 3) Add/Enable the Bridge Script

### Option A: @-mention trigger (OpenClaw direct)
1. Copy `bridge/openclaw-mention-trigger.js` into the SinusBot **scripts** directory.
2. Enable it in the SinusBot UI.
3. Configure the script settings in the UI:
   - **Trigger prefix** (e.g., `@assistant`)
   - **OpenClaw Gateway URL** (e.g., `http://localhost:18789`)
   - **OpenClaw token** (if required)
   - **Session key** (`x-openclaw-session-key`, for shared context)
   - **Agent id** (default `main`)
4. When a user types the trigger prefix, the script calls `/v1/chat/completions` and replies in TeamSpeak.

### Option B: Log-based event bridge (to Discord)
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
Skip this step if you only use **Option A (mention trigger)**.

Run a log‑tail listener that forwards `[TS-BRIDGE]` entries to Discord.

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
- **Option B:** `tail -50 /tmp/sinusbot.log | grep TS-BRIDGE`
- Send a TeamSpeak message → confirm it appears in Discord with a `[TeamSpeak ...]` prefix.

---

## Notes / Gotchas
- **Avoid duplicates:** If a Discord response is already triggered by a TeamSpeak event, don’t manually re‑send the same reply back to TS.
- **Ghost sessions:** If SinusBot reconnects too quickly after a crash, TS may reject the new connection. Wait ~30s and retry.
- **Local vs remote:** `localhost` API URLs only work on the SinusBot host. Use a tunnel or expose ports for remote control.
