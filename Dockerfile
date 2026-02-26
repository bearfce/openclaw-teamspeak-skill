FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# TeamSpeak Client version (update as needed)
# Available releases: https://files.teamspeak-services.com/releases/client/
ARG TS3_VERSION=3.5.6

# SinusBot download URL
# Current: https://www.sinusbot.com/dl/sinusbot.current.tar.bz2
# Pin to specific version when available: https://www.sinusbot.com/dl/sinusbot.X.Y.Z.tar.bz2
ARG SINUSBOT_URL=https://www.sinusbot.com/dl/sinusbot.current.tar.bz2

# Node.js version (update to latest LTS periodically)
# Current LTS: https://nodejs.org/
ARG NODE_VERSION=20.11.1

ENV SINUSBOT_DIR=/opt/sinusbot \
    TS3_PATH=/opt/teamspeak-client/ts3client_linux_amd64 \
    DISPLAY=:99

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl bzip2 tar xz-utils jq less \
    libglib2.0-0 libnss3 libx11-6 libxcomposite1 libxcursor1 libxdamage1 \
    libxext6 libxi6 libxrandr2 libxrender1 libxtst6 libasound2 libdbus-1-3 \
    libsm6 libice6 libfreetype6 libfontconfig1 libxfixes3 libxcb1 libxkbcommon0 libxss1 libpci3 libxslt1.1 \
    libqt5core5a libqt5gui5 libqt5widgets5 libqt5network5 libqt5x11extras5 libqt5dbus5 libqt5svg5 libqt5multimedia5 \
    xvfb pulseaudio pulseaudio-utils \
    python3 \
    gosu \
  && rm -rf /var/lib/apt/lists/*

# Install Node.js (non-EOL, from official binaries)
RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -o /tmp/node.tar.xz \
  && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
  && rm -f /tmp/node.tar.xz \
  && ln -sf /usr/local/bin/node /usr/local/bin/nodejs

# Install TeamSpeak 3 client
RUN mkdir -p /opt/teamspeak-client \
  && curl -fsSL "https://files.teamspeak-services.com/releases/client/${TS3_VERSION}/TeamSpeak3-Client-linux_amd64-${TS3_VERSION}.run" -o /tmp/ts3client.run \
  && chmod +x /tmp/ts3client.run \
  && yes | /tmp/ts3client.run --quiet --target /opt/teamspeak-client \
  && rm -f /tmp/ts3client.run

# Install SinusBot
RUN mkdir -p /opt/sinusbot \
  && curl -fsSL "${SINUSBOT_URL}" -o /tmp/sinusbot.tar.bz2 \
  && tar -xjf /tmp/sinusbot.tar.bz2 -C /opt/sinusbot \
  && rm -f /tmp/sinusbot.tar.bz2 \
  && chmod +x /opt/sinusbot/sinusbot

# Prepare runtime user + directories
RUN useradd -m -u 1000 sinusbot \
  && mkdir -p /data /opt/openclaw-scripts /tmp/.X11-unix \
  && chmod 1777 /tmp/.X11-unix \
  && chown -R sinusbot:sinusbot /data /opt/sinusbot /opt/teamspeak-client /opt/openclaw-scripts

COPY bridge/openclaw-mention-trigger.js /opt/openclaw-scripts/openclaw-mention-trigger.js
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8087 25639

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=20s \
  CMD curl -fsS http://127.0.0.1:8087/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]
