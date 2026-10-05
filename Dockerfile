FROM ghcr.io/linuxserver/baseimage-selkies:debiantrixie

# Beeper Desktop version to install, e.g. 4.3.160. Empty installs the latest stable release.
ARG BEEPER_VERSION=""
ARG TARGETARCH

LABEL maintainer="zachatrocity"

# title
ENV TITLE=Beeper

RUN \
  echo "**** add icon ****" && \
  curl -o \
    /usr/share/selkies/www/icon.png \
    https://avatars.githubusercontent.com/u/74791520?s=200&v=4 && \
  echo "**** install packages ****" && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    chromium \
    chromium-l10n \
    git \
    libgtk-3-bin \
    libatk1.0 \
    libatk-bridge2.0 \
    libnss3 \
    python3-xdg && \
  cd /tmp && \
  echo "**** install beeper ****" && \
  case "${TARGETARCH:-amd64}" in \
    amd64) API_ARCH=x64; FILE_ARCH=x86_64 ;; \
    arm64) API_ARCH=arm64; FILE_ARCH=arm64 ;; \
    *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
  esac && \
  if [ -n "${BEEPER_VERSION}" ]; then \
    BEEPER_URL="https://beeper-desktop.download.beeper.com/builds/Beeper-${BEEPER_VERSION}-${FILE_ARCH}.AppImage"; \
  else \
    BEEPER_URL=$(curl -fsS -o /dev/null -w '%{redirect_url}' \
      "https://api.beeper.com/desktop/download/linux/${API_ARCH}/stable/com.automattic.beeper.desktop"); \
  fi && \
  case "${BEEPER_URL}" in \
    https://beeper-desktop.download.beeper.com/builds/Beeper-*.AppImage) ;; \
    *) echo "could not resolve a Beeper download URL: '${BEEPER_URL}'" >&2; exit 1 ;; \
  esac && \
  echo "**** downloading ${BEEPER_URL} ****" && \
  curl -fL -o /tmp/beeper.app "${BEEPER_URL}" && \
  chmod +x /tmp/beeper.app && \
  ./beeper.app --appimage-extract && \
  mv squashfs-root /opt/beeper && \
  cp \
    /opt/beeper/beepertexts.png \
    /usr/share/icons/hicolor/512x512/apps/beeper.png && \
  echo "**** cleanup ****" && \
  apt-get autoclean && \
  rm -rf \
    /config/.cache \
    /config/.launchpadlib \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*

# add local files
COPY /root /

# ports and volumes
EXPOSE 3000
VOLUME /config
