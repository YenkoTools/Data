#!/usr/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root or with sudo"
    exit 1
fi

SERVICE_USER="gitea"
INSTALL_DIR="/opt/gitea"
NETWORK_NAME="gitea-network"
CONTAINERS="gitea-runner gitea gitea-db"

# The service user's home is the install directory, so data lives inside it
DATA_PATHS="$INSTALL_DIR/.local/share/gitea-data $INSTALL_DIR/.local/share/gitea-db-data $INSTALL_DIR/.local/share/gitea-runner-data"

REMOVE_USER=false
PURGE_DATA=false

for arg in "$@"; do
    case "$arg" in
        --remove-user) REMOVE_USER=true ;;
        --purge-data) PURGE_DATA=true ;;
        *) echo "Unknown option: $arg"; echo "Usage: $0 [--remove-user] [--purge-data]"; exit 1 ;;
    esac
done

echo "Stopping and disabling gitea.service..."
systemctl stop gitea.service 2>/dev/null || true
systemctl disable gitea.service 2>/dev/null || true

# Containers may still exist if the service was already stopped/disabled
echo "Removing gitea containers (if present)..."
for container in $CONTAINERS; do
    docker rm -f "$container" 2>/dev/null || true
done

echo "Removing docker network '$NETWORK_NAME' (if present)..."
docker network rm "$NETWORK_NAME" 2>/dev/null || true

echo "Removing systemd unit file..."
rm -f /etc/systemd/system/gitea.service

systemctl daemon-reload
systemctl reset-failed gitea.service 2>/dev/null || true

echo "Removing management script '$INSTALL_DIR/gitea.sh'..."
rm -f "$INSTALL_DIR/gitea.sh"

if [ "$PURGE_DATA" = false ]; then
    for path in $DATA_PATHS; do
        if [ -d "$path" ]; then
            read -r -p "Delete data directories under '$INSTALL_DIR/.local/share' (repositories, database, runner)? [y/N] " REPLY
            case "$REPLY" in
                [yY]|[yY][eE][sS]) PURGE_DATA=true ;;
            esac
            break
        fi
    done
fi

if [ "$PURGE_DATA" = true ]; then
    for path in $DATA_PATHS; do
        if [ -d "$path" ]; then
            echo "Purging data directory '$path'..."
            rm -rf "$path"
        fi
    done
else
    echo "Leaving data directories under '$INSTALL_DIR/.local/share' in place."
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

# Only remove the install directory once it holds nothing worth keeping
if [ "$PURGE_DATA" = true ]; then
    echo "Removing install directory '$INSTALL_DIR'..."
    rm -rf "$INSTALL_DIR"
fi

echo ""
echo "Uninstallation complete!"
