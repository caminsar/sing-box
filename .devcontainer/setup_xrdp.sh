#!/usr/bin/env bash

set -Eeuo pipefail


MODE="${1:-configure}"

XRDP_USER="${USER:-vscode}"
XRDP_HOME="$(getent passwd "${XRDP_USER}" | cut -d: -f6)"


print_header() {
    echo
    echo "========================================"
    echo "$1"
    echo "========================================"
}


get_user_info() {

    if [[ -z "${XRDP_HOME}" ]]; then
        echo "Cannot determine home directory for user: ${XRDP_USER}"
        exit 1
    fi

    echo "XRDP user: ${XRDP_USER}"
    echo "XRDP home: ${XRDP_HOME}"
}


configure_xfce() {

    print_header "Configuring XFCE session"

    cat > "${XRDP_HOME}/.xsession" <<'EOF'
#!/bin/sh

unset DBUS_SESSION_BUS_ADDRESS
unset SESSION_MANAGER
unset XDG_RUNTIME_DIR

export XDG_SESSION_DESKTOP=xfce
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=xfce

exec dbus-launch --exit-with-session startxfce4
EOF

    chmod 700 "${XRDP_HOME}/.xsession"

    if [[ "$(stat -c '%U' "${XRDP_HOME}/.xsession")" != "${XRDP_USER}" ]]; then
        sudo chown \
            "${XRDP_USER}:${XRDP_USER}" \
            "${XRDP_HOME}/.xsession"
    fi
}


configure_startwm() {

    print_header "Configuring XRDP window manager"

    if [[ -f /etc/xrdp/startwm.sh ]] \
        && [[ ! -f /etc/xrdp/startwm.sh.original ]]; then

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
unset SESSION_MANAGER
unset XDG_RUNTIME_DIR

export XDG_SESSION_DESKTOP=xfce
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=xfce

if [ -x "$HOME/.xsession" ]; then
    exec "$HOME/.xsession"
fi

exec dbus-launch --exit-with-session startxfce4
EOF

    sudo chmod 755 /etc/xrdp/startwm.sh
}


configure_certificate_permissions() {

    print_header "Configuring XRDP certificate permissions"

    sudo usermod -aG ssl-cert xrdp
}


configure_session_socket_group() {

    print_header "Checking XRDP session socket configuration"

    if [[ ! -f /etc/xrdp/sesman.ini ]]; then
        echo "/etc/xrdp/sesman.ini not found"
        return 0
    fi


    #
    # XRDP 0.10 uses local UNIX sockets.
    #
    # Older XRDP versions may not contain SessionSockdirGroup at all.
    # Only modify the configuration when this option exists.
    #

    if grep -q 'SessionSockdirGroup' /etc/xrdp/sesman.ini; then

        XRDP_RUNTIME_GROUP="$(
            awk -F= '
                /^[[:space:]]*runtime_group[[:space:]]*=/ {
                    gsub(/[[:space:]]/, "", $2)
                    print $2
                    exit
                }
            ' /etc/xrdp/xrdp.ini 2>/dev/null || true
        )"


        if [[ -z "${XRDP_RUNTIME_GROUP}" ]]; then
            XRDP_RUNTIME_GROUP="xrdp"
        fi


        echo "XRDP runtime group: ${XRDP_RUNTIME_GROUP}"


        if grep -qE \
            '^[[:space:]]*SessionSockdirGroup[[:space:]]*=' \
            /etc/xrdp/sesman.ini; then

            sudo sed -i \
                "s|^[[:space:]]*SessionSockdirGroup[[:space:]]*=.*|SessionSockdirGroup=${XRDP_RUNTIME_GROUP}|" \
                /etc/xrdp/sesman.ini

        else

            sudo sed -i \
                "/^\[Security\]/a SessionSockdirGroup=${XRDP_RUNTIME_GROUP}" \
                /etc/xrdp/sesman.ini
        fi


        grep \
            'SessionSockdirGroup' \
            /etc/xrdp/sesman.ini \
            || true

    else

        echo "SessionSockdirGroup is not used by this XRDP version"
    fi
}


configure_x11_socket() {

    print_header "Configuring X11 socket directory"

    sudo mkdir -p /tmp/.X11-unix

    sudo chown \
        root:root \
        /tmp/.X11-unix

    sudo chmod \
        1777 \
        /tmp/.X11-unix

    ls -ld /tmp/.X11-unix
}


configure_edge_launcher() {

    print_header "Configuring Microsoft Edge for Codespaces"

    if [[ ! -x /usr/bin/microsoft-edge-stable ]]; then
        echo "Microsoft Edge is not installed"
        return 0
    fi


    sudo tee /usr/local/bin/edge-codespaces > /dev/null <<'EOF'
#!/usr/bin/env bash

exec /usr/bin/microsoft-edge-stable \
    --no-sandbox \
    --disable-dev-shm-usage \
    "$@"
EOF

    sudo chmod \
        755 \
        /usr/local/bin/edge-codespaces


    mkdir -p \
        "${XRDP_HOME}/.local/share/applications"


    if [[ -f /usr/share/applications/microsoft-edge.desktop ]]; then

        cp \
            /usr/share/applications/microsoft-edge.desktop \
            "${XRDP_HOME}/.local/share/applications/microsoft-edge.desktop"


        sed -i \
            's|/usr/bin/microsoft-edge-stable|/usr/local/bin/edge-codespaces|g' \
            "${XRDP_HOME}/.local/share/applications/microsoft-edge.desktop"
    fi
}


configure_chrome_launcher() {

    print_header "Configuring Google Chrome for Codespaces"

    if [[ ! -x /usr/bin/google-chrome-stable ]]; then
        echo "Google Chrome is not installed"
        return 0
    fi


    sudo tee /usr/local/bin/chrome-codespaces > /dev/null <<'EOF'
#!/usr/bin/env bash

exec /usr/bin/google-chrome-stable \
    --no-sandbox \
    --disable-dev-shm-usage \
    "$@"
EOF

    sudo chmod \
        755 \
        /usr/local/bin/chrome-codespaces


    mkdir -p \
        "${XRDP_HOME}/.local/share/applications"


    if [[ -f /usr/share/applications/google-chrome.desktop ]]; then

        cp \
            /usr/share/applications/google-chrome.desktop \
            "${XRDP_HOME}/.local/share/applications/google-chrome.desktop"


        sed -i \
            's|/usr/bin/google-chrome-stable|/usr/local/bin/chrome-codespaces|g' \
            "${XRDP_HOME}/.local/share/applications/google-chrome.desktop"
    fi
}


stop_old_xrdp() {

    print_header "Stopping old XRDP processes"

    sudo service xrdp stop \
        >/dev/null 2>&1 \
        || true


    sudo pkill -x xrdp \
        >/dev/null 2>&1 \
        || true


    sudo pkill -x xrdp-sesman \
        >/dev/null 2>&1 \
        || true


    sudo rm -f \
        /run/xrdp/xrdp.pid \
        /run/xrdp/xrdp-sesman.pid \
        /var/run/xrdp/xrdp.pid \
        /var/run/xrdp/xrdp-sesman.pid


    sleep 1
}


start_xrdp() {

    print_header "Starting XRDP"

    configure_x11_socket

    stop_old_xrdp


    sudo mkdir -p /run/xrdp


    XRDP_START_LOG="/tmp/xrdp-service-start.log"

    : > "${XRDP_START_LOG}"


    if ! sudo service xrdp start \
        > "${XRDP_START_LOG}" 2>&1; then

        echo
        echo "XRDP init script returned a nonzero status."
        echo "Checking the actual processes and listening port."
        echo

        cat "${XRDP_START_LOG}" || true
    fi


    sleep 2


    print_header "XRDP processes"

    ps -eo user,group,pid,cmd \
        | grep -E '[x]rdp|[s]esman' \
        || true


    print_header "XRDP port"

    if sudo ss -lntp \
        | grep -q ':3389'; then

        sudo ss -lntp \
            | grep ':3389' \
            || true

        echo
        echo "XRDP is listening on TCP port 3389."

    else

        echo
        echo "WARNING: XRDP is not listening on TCP port 3389."
        echo


        if [[ -f /var/log/xrdp.log ]]; then

            echo
            echo "Last lines from /var/log/xrdp.log:"
            echo

            sudo tail -n 40 \
                /var/log/xrdp.log \
                || true
        fi


        if [[ -f /var/log/xrdp-sesman.log ]]; then

            echo
            echo "Last lines from /var/log/xrdp-sesman.log:"
            echo

            sudo tail -n 40 \
                /var/log/xrdp-sesman.log \
                || true
        fi
    fi


    #
    # Never make postStartCommand fail only because the service
    # init script returns an unusual status inside a container.
    #

    return 0
}


show_versions() {

    print_header "Installed versions"

    xrdp --version \
        2>/dev/null \
        | head -n 3 \
        || true


    if command -v microsoft-edge-stable >/dev/null 2>&1; then

        microsoft-edge-stable \
            --version \
            || true
    fi


    if command -v google-chrome-stable >/dev/null 2>&1; then

        google-chrome-stable \
            --version \
            || true
    fi
}


configure_all() {

    print_header "Configuring XRDP desktop"

    get_user_info

    configure_xfce

    configure_startwm

    configure_certificate_permissions

    configure_session_socket_group

    configure_x11_socket

    configure_edge_launcher

    configure_chrome_launcher

    show_versions

    start_xrdp


    print_header "XRDP configuration completed"

    echo
    echo "XRDP login user:"
    echo
    echo "    ${XRDP_USER}"
    echo
    echo "Set the XRDP login password with:"
    echo
    echo "    sudo passwd ${XRDP_USER}"
    echo
}


case "${MODE}" in

    configure)

        configure_all
        ;;

    start)

        start_xrdp
        ;;

    *)

        echo "Usage:"
        echo
        echo "    bash .devcontainer/setup_xrdp.sh configure"
        echo
        echo "or"
        echo
        echo "    bash .devcontainer/setup_xrdp.sh start"
        echo

        exit 1
        ;;
esac
