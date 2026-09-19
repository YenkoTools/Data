#!/usr/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root or with sudo"
    exit 1
fi

SERVICE_USER="aspire-dashboard"
INSTALL_DIR="/opt/aspire-dashboard"

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

cp -v aspire-dashboard.sh "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/aspire-dashboard.sh"

cp -v aspire-dashboard.service /etc/systemd/system/

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable aspire-dashboard.service

echo ""
echo "Installation complete!"
echo ""
echo "To start Aspire Dashboard:"
echo "  sudo systemctl start aspire-dashboard.service"
echo ""
echo "To check status:"
echo "  sudo systemctl status aspire-dashboard.service"
echo ""
echo "To view logs:"
echo "  sudo journalctl -xeu aspire-dashboard.service"
echo ""
