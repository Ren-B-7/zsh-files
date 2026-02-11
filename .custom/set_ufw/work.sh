#!/bin/sh

if ! command -v ufw >/dev/null 2>&1; then
    echo "UFW not installed"
    exit 1
fi

# Confirmation prompt before resetting UFW
echo "Resetting and applying Work Environment rules..."
sudo ufw reset

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow necessary work-related ports
sudo ufw allow 22/tcp    # SSH access
sudo ufw allow 80/tcp    # Web server (HTTP)
sudo ufw allow 443/tcp   # Secure Web server (HTTPS)
sudo ufw allow 8080/tcp  # Custom dev server
sudo ufw allow 3306/tcp  # MySQL database
sudo ufw allow 5432/tcp  # PostgreSQL database
sudo ufw allow 5900/tcp  # VNC server (remote work access)
sudo ufw allow 5000/tcp  # Flask dev server
sudo ufw allow 8000/tcp  # Custom dev server

# Ensure UFW is enabled
sudo ufw enable
echo "Work Environment firewall rules applied successfully."

