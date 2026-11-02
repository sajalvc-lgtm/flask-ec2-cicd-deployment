#!/usr/bin/env bash
# ==============================================================================
# Script: install_prereqs.sh
# Purpose: Prepares an AWS EC2 instance (Ubuntu or Amazon Linux 2023) for hosting
#          the Python application under Systemd with Gunicorn.
# ==============================================================================
set -euo pipefail

echo "==> [1/5] Detecting Linux Distribution..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Unknown OS, defaulting to generic debian/rhel check"
    OS="unknown"
fi

echo "==> Detected OS: $OS"

echo "==> [2/5] Checking Python 3..."
if command -v python3 >/dev/null 2>&1; then
    echo "Python 3 is already installed ($(python3 --version)), skipping package manager update."
else
    echo "Python 3 not found, attempting installation via package manager..."
    if [[ "$OS" == "amzn" || "$OS" == "rhel" || "$OS" == "fedora" || "$OS" == "centos" ]]; then
        sudo dnf install -y python3 python3-pip || true
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        sudo apt-get update -y && sudo apt-get install -y python3 python3-pip python3-venv || true
    fi
fi


echo "==> [3/5] Creating dedicated system application user and group..."
if ! id -u appuser >/dev/null 2>&1; then
    sudo useradd -r -s /bin/false appuser
    echo "User 'appuser' created."
else
    echo "User 'appuser' already exists."
fi

echo "==> [4/5] Setting up target deployment directory /opt/python-app..."
sudo mkdir -p /opt/python-app
sudo chown -R appuser:appuser /opt/python-app
sudo chmod -R 775 /opt/python-app

# Create log files with proper permissions
sudo touch /var/log/python-app-access.log /var/log/python-app-error.log
sudo chown appuser:appuser /var/log/python-app-access.log /var/log/python-app-error.log

echo "==> [5/5] Installing and enabling Systemd unit..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/python-app.service" ]; then
    sudo cp "$SCRIPT_DIR/python-app.service" /etc/systemd/system/python-app.service
    sudo systemctl daemon-reload
    sudo systemctl enable python-app.service
    echo "Systemd unit installed and enabled."
fi

echo "==> EC2 prerequisite setup complete!"
