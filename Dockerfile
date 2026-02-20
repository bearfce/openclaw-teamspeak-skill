FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TS3_VERSION=3.5.6

ENV SINUSBOT_DIR=/opt/sinusbot \
    TS3_PATH=/opt/teamspeak-client/ts3client_linux_amd64 \
    DISPLAY=:99

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl bzip2 tar xz-utils jq \
    libglib2.0-0 libnss3 libx11-6 libxcomposite1 libxcursor1 libxdamage1 \
    libxext6 libxi6 libxrandr2 libxrender1 libxtst6 libasound2 libdbus-1-3 \
    libsm6 libice6 libfreetype6 libfontconfig1 libxfixes3 libxcb1 libxkbcommon0 \
    libqt5core5a libqt5gui5 libqt5widgets5 libqt5network5 libqt5x11extras5 libqt5dbus5 libqt5svg5 libqt5multimedia5 \
    xvfb pulseaudio pulseaudio-utils \
    python3 python3-pip \
    nodejs npm \
    gosu \
  && rm -rf /var/lib/apt/lists/*

# Install TeamSpeak 3 client
RUN mkdir -p /opt/teamspeak-client \
  && curl -fsSL "https://files.teamspeak-services.com/releases/client/${TS3_VERSION}/TeamSpeak3-Client-linux_amd64-${TS3_VERSION}.run" -o /tmp/ts3client.run \
  && chmod +x /tmp/ts3client.run \
  && yes | /tmp/ts3client.run --quiet --target /opt/teamspeak-client \
  && rm -f /tmp/ts3client.run

# Install SinusBot
RUN mkdir -p /opt/sinusbot \
  && curl -fsSL https://www.sinusbot.com/dl/sinusbot.current.tar.bz2 \
    | tar -xj --strip-components=1 -C /opt/sinusbot \
  && chmod +x /opt/sinusbot/sinusbot

# Prepare runtime user + directories
RUN useradd -m -u 1000 sinusbot \
  && mkdir -p /data /opt/openclaw-scripts \
  && chown -R sinusbot:sinusbot /data /opt/sinusbot /opt/teamspeak-client /opt/openclaw-scripts

COPY bridge/openclaw-mention-trigger.js /opt/openclaw-scripts/openclaw-mention-trigger.js
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8087 25639

ENTRYPOINT ["/entrypoint.sh"]
