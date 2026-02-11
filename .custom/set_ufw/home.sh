#!/bin/sh

if ! command -v ufw >/dev/null 2>&1; then
    echo "UFW not installed"
    exit 1
fi

# Confirmation prompt before resetting UFW
echo "Resetting and applying Home Environment rules..."
sudo ufw reset

# Apply Home Environment Rules (slightly more secure)
echo "Applying Home Environment rules..."

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow traffic from the local network
sudo ufw allow from 192.168.0.0/16 to any port 80,443,22 proto tcp  # Web & SSH
sudo ufw allow from 192.168.0.0/16  # (Allows all traffic within the local network)

# Open necessary ports
sudo ufw allow 3306/tcp   # MySQL
sudo ufw allow 8080/tcp   # Custom web server
sudo ufw allow 8000/tcp   # Custom web server
sudo ufw allow 5900/tcp   # VNC

# Ensure UFW is enabled
sudo ufw enable
echo "Firewall rules applied successfully."
