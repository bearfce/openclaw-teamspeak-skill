#!/usr/bin/env bash
set -euo pipefail

SINUSBOT_DIR="${SINUSBOT_DIR:-/opt/sinusbot}"
DATA_DIR="${SINUSBOT_DATA_DIR:-/data}"
SCRIPTS_DIR="${SINUSBOT_SCRIPTS_DIR:-${DATA_DIR}/scripts}"
CONFIG_PATH="${SINUSBOT_CONFIG:-${DATA_DIR}/config.ini}"
TS3_PATH="${TS3_PATH:-/opt/teamspeak-client/ts3client_linux_amd64}"

if [ "$(id -u)" = "0" ]; then
  mkdir -p "${DATA_DIR}" "${SCRIPTS_DIR}" /tmp/xdg /tmp/.X11-unix
  chmod 1777 /tmp/.X11-unix || true
  chown -R sinusbot:sinusbot "${DATA_DIR}" /tmp/xdg
  exec gosu sinusbot "$0" "$@"
fi

export DISPLAY="${DISPLAY:-:99}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg}"
export PULSE_SERVER="${PULSE_SERVER:-unix:${XDG_RUNTIME_DIR}/pulse/native}"

mkdir -p "${DATA_DIR}" "${SCRIPTS_DIR}" "${XDG_RUNTIME_DIR}" /tmp/.X11-unix
chmod 700 "${XDG_RUNTIME_DIR}"
chmod 1777 /tmp/.X11-unix || true

# Initialize config if needed
if [ ! -f "${CONFIG_PATH}" ]; then
  cp "${SINUSBOT_DIR}/config.ini.dist" "${CONFIG_PATH}"
fi

set_ini() {
  local key="$1" value="$2"
  if grep -qE "^${key}[[:space:]]*=" "${CONFIG_PATH}"; then
    sed -i -E "s|^${key}[[:space:]]*=.*|${key} = ${value}|" "${CONFIG_PATH}"
  else
    echo "${key} = ${value}" >> "${CONFIG_PATH}"
  fi
}

set_ini "TS3Path" "\"${TS3_PATH}\""
set_ini "DataDir" "\"${DATA_DIR}\""
set_ini "ListenHost" "\"0.0.0.0\""
set_ini "ListenPort" "8087"
set_ini "LogFile" "\"${DATA_DIR}/sinusbot.log\""

ln -sf "${CONFIG_PATH}" "${SINUSBOT_DIR}/config.ini"

# Persist scripts via /data/scripts (seed defaults on first run)
if [ -z "$(ls -A "${SCRIPTS_DIR}" 2>/dev/null)" ]; then
  mkdir -p "${SCRIPTS_DIR}"
  cp -r "${SINUSBOT_DIR}/scripts/." "${SCRIPTS_DIR}/" 2>/dev/null || true
fi
rm -rf "${SINUSBOT_DIR}/scripts"
ln -sf "${SCRIPTS_DIR}" "${SINUSBOT_DIR}/scripts"

# Seed default OpenClaw script if missing
if [ ! -f "${SCRIPTS_DIR}/openclaw-mention-trigger.js" ]; then
  cp /opt/openclaw-scripts/openclaw-mention-trigger.js "${SCRIPTS_DIR}/"
fi

# Ensure TeamSpeak plugin is installed (prevents library download errors)
TS3_DIR="$(dirname "${TS3_PATH}")"
if [ -n "${TS3_DIR}" ]; then
  mkdir -p "${TS3_DIR}/plugins"
  if [ ! -f "${TS3_DIR}/plugins/libsoundbot_plugin.so" ]; then
    cp -f "${SINUSBOT_DIR}/plugin/libsoundbot_plugin.so" "${TS3_DIR}/plugins/"
  fi
fi

# Start PulseAudio + Xvfb (headless TS client needs both)
pulseaudio --daemonize=yes --exit-idle-time=-1 --disallow-exit || true
if ! pgrep -x Xvfb >/dev/null 2>&1; then
  Xvfb "${DISPLAY}" -screen 0 1024x768x24 -ac &
fi

cd "${SINUSBOT_DIR}"

SINUSBOT_ARGS=()
if [ -n "${SINUSBOT_ADMIN_PASSWORD:-}" ]; then
  SINUSBOT_ARGS+=("--override-password=${SINUSBOT_ADMIN_PASSWORD}")
fi

exec "${SINUSBOT_DIR}/sinusbot" "${SINUSBOT_ARGS[@]}"
