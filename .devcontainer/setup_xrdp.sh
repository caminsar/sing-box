#!/usr/bin/env bash

set -Eeuo pipefail

echo
echo "========================================"
echo "Configuring XRDP desktop"
echo "========================================"

XRDP_USER="${USER:-vscode}"
XRDP_HOME="$(getent passwd "${XRDP_USER}" | cut -d: -f6)"

if [[ -z "${XRDP_HOME}" ]]; then
    echo "Cannot determine home directory for user: ${XRDP_USER}"
    exit 1
fi

echo "XRDP user: ${XRDP_USER}"
echo "XRDP home: ${XRDP_HOME}"


echo
echo "========================================"
echo "Configuring XFCE session"
echo "========================================"

cat > "${XRDP_HOME}/.xsession" <<'EOF'
#!/bin/sh

unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

exec dbus-launch --exit-with-session startxfce4
EOF

chmod 700 "${XRDP_HOME}/.xsession"


echo
echo "========================================"
echo "Configuring XRDP window manager"
echo "========================================"

if [[ -f /etc/xrdp/startwm.sh ]] && \
   [[ ! -f /etc/xrdp/startwm.sh.original ]]; then

    sudo cp \
        /etc/xrdp/startwm.sh \
        /etc/xrdp/startwm.sh.original
fi


sudo tee /etc/xrdp/startwm.sh > /dev/null <<'EOF'
#!/bin/sh

if [ -r /etc/profile ]; then
    . /etc/profile
fi

if [ -r "$HOME/.profile" ]; then
    . "$HOME/.profile"
fi

unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

if [ -x "$HOME/.xsession" ]; then
    exec "$HOME/.xsession"
fi

exec dbus-launch --exit-with-session startxfce4
EOF

sudo chmod 755 /etc/xrdp/startwm.sh


echo
echo "========================================"
echo "Configuring XRDP certificate permissions"
echo "========================================"

sudo usermod -aG ssl-cert xrdp


echo
echo "========================================"
echo "Starting XRDP"
echo "========================================"

sudo service xrdp restart


echo
echo "========================================"
echo "Checking XRDP processes"
echo "========================================"

ps aux | grep '[x]rdp' || true


echo
echo "========================================"
echo "Checking TCP port 3389"
echo "========================================"

sudo ss -lntp | grep ':3389' || true

echo
echo "Configuring Microsoft Edge for Codespaces"

sudo tee /usr/local/bin/edge-codespaces > /dev/null <<'EOF'
#!/usr/bin/env bash

exec /usr/bin/microsoft-edge-stable \
    --no-sandbox \
    --disable-dev-shm-usage \
    "$@"
EOF

sudo chmod +x /usr/local/bin/edge-codespaces

mkdir -p "${HOME}/.local/share/applications"

if [ -f /usr/share/applications/microsoft-edge.desktop ]; then

    cp /usr/share/applications/microsoft-edge.desktop \
       "${HOME}/.local/share/applications/microsoft-edge.desktop"

    sed -i \
        's|/usr/bin/microsoft-edge-stable|/usr/local/bin/edge-codespaces|g' \
        "${HOME}/.local/share/applications/microsoft-edge.desktop"
fi

echo
echo "========================================"
echo "XRDP configuration completed"
echo "========================================"

echo
echo "XRDP login user:"
echo
echo "    ${XRDP_USER}"
echo
echo "Set the login password with:"
echo
echo "    sudo passwd ${XRDP_USER}"
echo
