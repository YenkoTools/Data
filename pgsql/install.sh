#!/usr/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root or with sudo"
    exit 1
fi

SERVICE_USER="pgsql"
INSTALL_DIR="/opt/pgsql"

if id "$SERVICE_USER" &>/dev/null; then
    echo "User '$SERVICE_USER' already exists, continuing..."
else
    useradd -m -d "$INSTALL_DIR" -s /bin/bash "$SERVICE_USER"
    echo "User '$SERVICE_USER' created"
fi

# Add user to docker group for container access
usermod -aG docker "$SERVICE_USER"
echo "User '$SERVICE_USER' added to docker group"

loginctl enable-linger "$SERVICE_USER"

mkdir -p "$INSTALL_DIR"

cp -v pgsql.sh "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/pgsql.sh"

cp -v pgsql.service /etc/systemd/system/

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable pgsql.service

echo ""
echo "Installation complete!"
echo ""
echo "To start PostgreSQL:"
echo "  sudo systemctl start pgsql.service"
echo ""
echo "To check status:"
echo "  sudo systemctl status pgsql.service"
echo ""
echo "To view logs:"
echo "  sudo journalctl -xeu pgsql.service"
echo ""
