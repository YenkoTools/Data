#!/usr/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root or with sudo"
    exit 1
fi

SERVICE_USER="qdrant"
INSTALL_DIR="/opt/qdrant"
DATA_PATH="/home/$SERVICE_USER/.local/share/qdrant-data"

REMOVE_USER=false
PURGE_DATA=false

for arg in "$@"; do
    case "$arg" in
        --remove-user) REMOVE_USER=true ;;
        --purge-data) PURGE_DATA=true ;;
        *) echo "Unknown option: $arg"; echo "Usage: $0 [--remove-user] [--purge-data]"; exit 1 ;;
    esac
done

echo "Stopping and disabling qdrant.service..."
systemctl stop qdrant.service 2>/dev/null || true
systemctl disable qdrant.service 2>/dev/null || true

# Container may still exist if the service was already stopped/disabled
echo "Removing qdrant container (if present)..."
docker rm -f qdrant 2>/dev/null || true

echo "Removing systemd unit file..."
rm -f /etc/systemd/system/qdrant.service

systemctl daemon-reload
systemctl reset-failed qdrant.service 2>/dev/null || true

echo "Removing install directory '$INSTALL_DIR'..."
rm -rf "$INSTALL_DIR"

if [ "$PURGE_DATA" = false ] && [ -d "$DATA_PATH" ]; then
    read -r -p "Delete data directory '$DATA_PATH'? [y/N] " REPLY
    case "$REPLY" in
        [yY]|[yY][eE][sS]) PURGE_DATA=true ;;
    esac
fi

if [ "$PURGE_DATA" = true ]; then
    echo "Purging data directory '$DATA_PATH'..."
    rm -rf "$DATA_PATH"
else
    echo "Leaving data directory '$DATA_PATH' in place."
fi

if [ "$REMOVE_USER" = true ]; then
    if id "$SERVICE_USER" &>/dev/null; then
        echo "Removing user '$SERVICE_USER'..."
        loginctl disable-linger "$SERVICE_USER" 2>/dev/null || true
        userdel "$SERVICE_USER" 2>/dev/null || echo "Warning: failed to remove user '$SERVICE_USER'"
    fi
else
    echo "Leaving user '$SERVICE_USER' in place (use --remove-user to remove it)."
fi

echo ""
echo "Uninstallation complete!"
