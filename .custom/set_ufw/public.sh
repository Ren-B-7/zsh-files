#!/bin/sh

if ! command -v ufw >/dev/null 2>&1; then
    echo "UFW not installed"
    exit 1
fi

# Confirmation prompt before resetting UFW
echo "Resetting and applying Public Environment rules..."
sudo ufw reset

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow essential public services
sudo ufw allow ssh      # Secure Shell (SSH)
sudo ufw allow http     # Web Server (HTTP)
sudo ufw allow https    # Secure Web Server (HTTPS)

# Ensure UFW is enabled
sudo ufw enable
echo "Public Environment firewall rules applied successfully."

