FROM mcr.microsoft.com/devcontainers/base:ubuntu24.04

USER root

# ============================================================
# Install XFCE, XRDP and basic utilities
# ============================================================

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        xfce4 \
        xfce4-goodies \
        xfce4-terminal \
        xrdp \
        xorgxrdp \
        dbus-x11 \
        dbus-user-session \
        x11-xserver-utils \
        fonts-noto-cjk \
        curl \
        ca-certificates \
        gnupg \
        procps \
        iproute2 \
        psmisc \
    && usermod -aG ssl-cert xrdp \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# Microsoft Edge repository
# ============================================================

RUN install -d -m 0755 /usr/share/keyrings \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor --batch --yes \
        -o /usr/share/keyrings/microsoft-edge.gpg \
    && printf '%s\n' \
        'Types: deb' \
        'URIs: https://packages.microsoft.com/repos/edge' \
        'Suites: stable' \
        'Components: main' \
        'Architectures: amd64' \
        'Signed-By: /usr/share/keyrings/microsoft-edge.gpg' \
        > /etc/apt/sources.list.d/microsoft-edge.sources


# ============================================================
# Google Chrome repository
# ============================================================

RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
        | gpg --dearmor --batch --yes \
        -o /usr/share/keyrings/google-chrome.gpg \
    && printf '%s\n' \
        'Types: deb' \
        'URIs: https://dl.google.com/linux/chrome/deb/' \
        'Suites: stable' \
        'Components: main' \
        'Architectures: amd64' \
        'Signed-By: /usr/share/keyrings/google-chrome.gpg' \
        > /etc/apt/sources.list.d/google-chrome.sources


# ============================================================
# Install browsers
# ============================================================

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        microsoft-edge-stable \
        google-chrome-stable \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# Ensure X11 socket directory exists with correct permissions
# ============================================================

RUN mkdir -p /tmp/.X11-unix \
    && chown root:root /tmp/.X11-unix \
    && chmod 1777 /tmp/.X11-unix


# ============================================================
# Verify important binaries during image build
# ============================================================

RUN command -v xrdp \
    && command -v xrdp-sesman \
    && command -v startxfce4 \
    && command -v microsoft-edge-stable \
    && command -v google-chrome-stable
