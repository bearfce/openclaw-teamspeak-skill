# Fresh Setup Audit — 2026-02-25

Performed a clean-room review: fresh `git clone`, Docker build, container startup, and API validation against the `main` branch at commit `e8a4614`.

---

## ✅ What Works

| Step | Result |
|------|--------|
| `git clone` | Clean, no errors |
| `docker build` (committed Dockerfile) | Succeeds — all upstream URLs (SinusBot tarball, TS3 client 3.5.6, Node 20.11.1) resolve and download |
| Container startup | SinusBot initializes, listens on 8087, PulseAudio + Xvfb start |
| Script seeding | `openclaw-mention-trigger.js` auto-copied to `/data/scripts/` on first boot |
| TS3 plugin | `libsoundbot_plugin.so` installed into the TS client plugins dir |
| `config.ini` generation | Correct: `TS3Path`, `DataDir`, `ListenHost`, `ListenPort`, `LogFile` all set |
| SinusBot API login | Works with `botId` + admin credentials |
| Instance listing | Default instance created, ready to configure a TS server |
| Helper scripts | All present, executable, use shared `_env.sh` loader correctly |
| Message chunking | `sinusbot-chat.sh` handles >1024-char messages via automatic splitting |

---

## 🐛 Issues Found

### 1. Uncommitted Dockerfile change (`libpci3`, `libxslt1.1`)

**Severity:** Low (build succeeds without them; they may be needed at runtime for specific TS client features)

The working copy adds `libpci3 libxslt1.1` to the apt install list, but this was never committed:

```diff
- libsm6 libice6 libfreetype6 libfontconfig1 libxfixes3 libxcb1 libxkbcommon0 libxss1 \
+ libsm6 libice6 libfreetype6 libfontconfig1 libxfixes3 libxcb1 libxkbcommon0 libxss1 libpci3 libxslt1.1 \
```

**Action:** Commit this change or confirm it's unnecessary.

---

### 2. `.data/` directory not in `.gitignore`

**Severity:** Medium — risk of accidentally committing 17 MB of SinusBot runtime data (databases, logs, caches, identities) that may contain secrets.

The `.gitignore` covers `scripts/config.env` and `.env`, but **not** `.data/`. This directory is created when SinusBot runs locally and contains:

- `sinusbot.log` (may leak server IPs, usernames)
- `db/` (SinusBot database — credentials, identities)
- `config.ini` (may contain server addresses)
- `cache/`, `store/`, `scripts/`, `tmp/`

**Action:** Add `.data/` to `.gitignore`.

---

### 3. SinusBot API login requires `botId` (not documented clearly)

**Severity:** Low — the scripts handle this via `config.env`, but the README's placeholder example for `sinusbot-spawn.sh` doesn't emphasize that `BOT_ID` must be obtained from the SinusBot UI or API *after* first boot.

The `/api/v1/botId` endpoint returns the `defaultBotId`, but this isn't mentioned anywhere in the docs. A new user following the README may not realize they need to discover the `BOT_ID` first.

**Recommendation:** Add a "First Boot" note explaining how to get `BOT_ID`:
```bash
curl -s http://localhost:8087/api/v1/botId | jq -r .defaultBotId
```

---

### 4. `--override-password` vs `SINUSBOT_ADMIN_PASSWORD` inconsistency

**Severity:** Low — cosmetic/documentation.

- The entrypoint uses `--override-password=${SINUSBOT_ADMIN_PASSWORD}` (Docker path).
- The `sinusbot-start.sh` script uses `--override-password=sinusbot` (hardcoded fallback).
- The README says `SINUSBOT_ADMIN_PASSWORD=<admin_password>` for Docker, and `--reset-password` for the script.

These all work, but the terms "reset" vs "override" and the hardcoded `sinusbot` in the script could confuse someone.

**Recommendation:** Align terminology. Consider making `sinusbot-start.sh` accept a password arg instead of hardcoding.

---

### 5. `sinusbot-auth.sh` ignores env-sourced `USERNAME`/`PASSWORD`

**Severity:** Low.

`sinusbot-auth.sh` takes positional args `$1` and `$2` for username/password with defaults of `admin`/`sinusbot`, **overriding** anything from `config.env`. The env-based `$USERNAME`/`$PASSWORD` from `_env.sh` are loaded but then shadowed by the positional defaults.

**Recommendation:** Change defaults to use env vars:
```bash
USERNAME="${1:-${USERNAME:-admin}}"
PASSWORD="${2:-${PASSWORD:-sinusbot}}"
```

---

### 6. `chmod` warning on `/tmp/.X11-unix` in Docker

**Severity:** Cosmetic — the `|| true` in the entrypoint suppresses the error correctly:
```
chmod: changing permissions of '/tmp/.X11-unix': Operation not permitted
```

This happens because Docker's default seccomp profile restricts `chmod` on certain tmpfs mounts. It's handled gracefully (non-fatal) but may confuse operators reading logs.

---

### 7. No `.dockerignore` file

**Severity:** Low — currently the build context is small (~11 KB), but if `.data/` grows or users add large files to the repo, build times will increase unnecessarily.

**Recommendation:** Add a `.dockerignore`:
```
.data/
.git/
*.md
scripts/config.env
.env
```

---

## 📋 Dependency Fragility Notes

These aren't current failures, but worth tracking:

| Dependency | URL | Risk |
|-----------|-----|------|
| SinusBot | `sinusbot.com/dl/sinusbot.current.tar.bz2` | Redirects to `dl.sinusbot.com`; may break if DNS changes or project discontinues |
| TS3 Client 3.5.6 | `files.teamspeak-services.com/releases/client/3.5.6/...` | Pinned version; TeamSpeak may delist old clients |
| Node 20.11.1 | `nodejs.org/dist/v20.11.1/...` | LTS but will eventually EOL; not critical since Node is only used by SinusBot |

The README already documents the `SINUSBOT_URL` build arg for mirroring — good.

---

## ✅ Recommended Fixes (in priority order)

1. **Add `.data/` to `.gitignore`** — prevents accidental secret leaks
2. **Commit the Dockerfile `libpci3`/`libxslt1.1` change** — or drop it explicitly
3. **Add a `.dockerignore`** — keep builds lean
4. **Document `BOT_ID` discovery** — one-liner curl in the README
5. **Fix `sinusbot-auth.sh` env handling** — minor but correct
6. **Align password reset terminology** — documentation cleanup
