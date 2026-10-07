FROM mcr.microsoft.com/devcontainers/base:ubuntu

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        xfce4 \
        xfce4-goodies \
        xrdp \
        xorgxrdp \
        dbus-x11 \
        dbus-user-session \
        x11-xserver-utils \
        fonts-noto-cjk \
    && usermod -aG ssl-cert xrdp \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV DEBIAN_FRONTEND=

CMD ["sleep", "infinity"]
