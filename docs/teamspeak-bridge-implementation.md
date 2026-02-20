# TeamSpeak Bridge Implementation

This document captures the **implementation details** for the TeamSpeak ↔ OpenClaw bridge. It complements the setup guide in `README.md` and the operator workflows in `SKILL.md`.

> **Goal:** keep the bridge portable and generic. Replace all placeholders with your own values and keep secrets out of version control.
>
> **Status:** The live path is the mention-trigger using `bearface-trigger.js` (renamed copy of `bridge/openclaw-mention-trigger.js`). The log-based Discord relay is **archived/inactive**.

---

## 1) Components

- **TeamSpeak Server** — where users chat and join channels.
- **SinusBot** — connects to TeamSpeak and runs scripts.
- **OpenClaw Gateway** — receives requests and posts replies.
- **Discord Channel** — optional destination for TeamSpeak event relays.

Two bridge paths are documented. **Only A is live; B is archived/inactive.**

### A) Mention-trigger (TeamSpeak → OpenClaw → TeamSpeak) — **LIVE**
Triggered by a prefix (e.g., `@assistant`) in TeamSpeak chat. The SinusBot script calls the OpenClaw `/v1/chat/completions` endpoint and posts the response back into TeamSpeak.
Live deployment uses `bearface-trigger.js` (renamed copy of `bridge/openclaw-mention-trigger.js`).

### B) Event relay (TeamSpeak → OpenClaw → Discord) — **ARCHIVED/INACTIVE**
A SinusBot script logs tagged events (chat, join/leave, moves, DMs). A log listener tails those entries and forwards them to OpenClaw `/v1/messages/send`, which posts into Discord.

---

## 2) Mention-trigger flow (script: `bearface-trigger.js` / `bridge/openclaw-mention-trigger.js`)

**Flow:**
1. User sends a TeamSpeak message containing the trigger prefix.
2. Script POSTs to `POST /v1/chat/completions` with an OpenClaw session key.
3. OpenClaw response is sent back to TeamSpeak.

**Script settings (SinusBot UI):**
- **Trigger prefix**: `@assistant` (case-insensitive)
- **OpenClaw Gateway URL**: `http://<openclaw-host>:<port>`
- **OpenClaw token**: (optional, required if gateway auth is enabled)
- **Session key**: `agent:<agent-name>:discord:channel:<id>`
- **Agent id**: `main` (or another OpenClaw agent)

**Implementation notes:**
- The script prefixes the user message with a TeamSpeak marker, e.g.:
  ```
  [TeamSpeak — <username>]: <message>
  ```
- TeamSpeak has a 1024‑character message limit; the script **truncates** longer responses.
- Messages from the bot itself are ignored to prevent loops.

---

## 3) Event relay flow (log → OpenClaw → Discord) — **ARCHIVED/INACTIVE**

This relay is **not running**. If you re‑enable it, your SinusBot script should write log entries like:
```
[TS-BRIDGE] [TeamSpeak channel] <user>: <message>
[TS-BRIDGE] [TeamSpeak join] <user> joined (in: <channel>)
[TS-BRIDGE] [TeamSpeak move] <user> moved from <A> to <B>
```

A **listener** then tails the log (commonly `/tmp/sinusbot.log`) and forwards tagged lines to:
```
POST /v1/messages/send
```

**Minimum payload fields (example):**
```json
{
  "channel_id": "<discord_channel_id>",
  "message": "[TeamSpeak channel] Alice: hello everyone"
}
```

**Recommended env vars for the listener:**
```bash
GATEWAY_URL=http://<openclaw-host>:<port>
GATEWAY_TOKEN=<openclaw_gateway_token>
DISCORD_CHANNEL_ID=<discord_channel_id>
```

---

## 4) Configuration map (generic)

```bash
# TeamSpeak
TS_SERVER_HOST=<ts_server_host>
TS_SERVER_PORT=<ts_voice_port>
TS_IDENTITY=<ts_identity>
TS_NICKNAME=<bot_nickname>

# SinusBot
SINUSBOT_DIR=/opt/sinusbot
SINUSBOT_USER=<sinusbot_user>
SINUSBOT_PASS=<sinusbot_password>
BOT_ID=<sinusbot_bot_id>
INSTANCE=<sinusbot_instance_id>
API_URL=http://<sinusbot-host>:8087

# ClientQuery (optional; used by move/chat scripts)
CQ_HOST=localhost
CQ_PORT=25639
CQ_KEY=<clientquery_key>

# OpenClaw routing (log relay only)
GATEWAY_URL=http://<openclaw-host>:<port>
GATEWAY_TOKEN=<openclaw_gateway_token>
DISCORD_CHANNEL_ID=<discord_channel_id>

# Mention-trigger routing
OPENCLAW_SESSION_KEY=agent:<agent_name>:discord:channel:<id>
OPENCLAW_AGENT_ID=main
TRIGGER_PREFIX=@assistant
```

> Tip: copy `scripts/config.env.example` → `scripts/config.env` and fill in the required values. This file is ignored by git.

---

## 5) Avoiding duplicate messages (log relay only)

Only relevant if you re‑enable the log relay. If a Discord response is **already** triggered by a TeamSpeak event, do **not** manually re‑send the same content back to TeamSpeak. Reserve `sinusbot-chat.sh` or `sinusbot-play.sh` for **proactive** messages (not event replies).

---

## 6) Operational notes

- **Local vs remote**: `localhost` API URLs only work on the SinusBot host. Use a tunnel or expose ports if you control the bridge remotely.
- **Ghost sessions**: After crashes, TeamSpeak may hold a stale session. Wait briefly before reconnecting.
- **Logs**: `tail -50 /tmp/sinusbot.log` for script init; TS-BRIDGE event lines only appear if the log relay is re‑enabled.
- **ClientQuery**: Use it for moves and message sends if the API is unavailable.

---

## 7) Security + hygiene

- Never commit tokens, passwords, or server hostnames.
- Use placeholders in docs and config examples.
- Keep gateway tokens and SinusBot credentials in environment variables or local `.env` files.

---

## 8) Quick validation checklist

- [ ] SinusBot instance is connected to TeamSpeak.
- [ ] `bearface-trigger.js` (or `openclaw-mention-trigger.js`) is enabled and configured.
- [ ] Sending `@assistant hello` receives a response.
- [ ] Log relay (archived; if re‑enabled) posts tagged TeamSpeak events into Discord.
