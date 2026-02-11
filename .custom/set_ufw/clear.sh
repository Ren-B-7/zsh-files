#!/bin/sh

if ! command -v ufw >/dev/null 2>&1; then
    echo "UFW not installed"
    exit 1
fi

# Find and remove only UFW backup rule files
echo "Removing UFW backup rule files..."
sudo find /etc/ufw/ -type f -name "*.rules.*" -exec rm -f {} \; -print

echo "Backup rule files have been cleared."

