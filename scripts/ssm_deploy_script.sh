#!/usr/bin/env bash
# ==============================================================================
# Script: ssm_deploy_script.sh
# Purpose: Entrypoint script executed remotely by AWS Systems Manager (SSM)
#          Run Command (AWS-RunShellScript) to pull/deploy the latest code.
# ==============================================================================
set -euo pipefail

GIT_REPO_URL="${1:-}"
GIT_BRANCH="${2:-main}"
APP_DIR="/opt/python-app"

echo "=========================================================="
echo " AWS SSM Remote Deployment Initiated"
echo " Host: $(hostname -f 2>/dev/null || hostname)"
echo " Date: $(date -u)"
echo " Target Dir: $APP_DIR"
echo "=========================================================="

# 1. Check prerequisites (Python 3, venv, git)
if ! command -v python3 >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
    echo "--> Installing prerequisites via package manager..."
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y python3 python3-pip git curl jq
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update -y && apt-get install -y python3 python3-pip python3-venv git curl jq
    fi
fi

# 2. Ensure application user
if ! id -u appuser >/dev/null 2>&1; then
    useradd -r -s /bin/false appuser
fi

# 3. Pull or clone latest code
mkdir -p "$APP_DIR"
if [ -n "$GIT_REPO_URL" ]; then
    if [ -d "$APP_DIR/.git" ]; then
        echo "--> Pulling latest changes from branch $GIT_BRANCH..."
        cd "$APP_DIR"
        git fetch origin
        git checkout "$GIT_BRANCH"
        git pull origin "$GIT_BRANCH"
    else
        echo "--> Cloning repository from $GIT_REPO_URL..."
        git clone -b "$GIT_BRANCH" "$GIT_REPO_URL" "$APP_DIR"
    fi
fi

# 4. Copy systemd service if provided in repo
if [ -f "$APP_DIR/scripts/python-app.service" ]; then
    cp "$APP_DIR/scripts/python-app.service" /etc/systemd/system/python-app.service
    systemctl daemon-reload
    systemctl enable python-app.service
fi

# 5. Run standard deployment script
if [ -f "$APP_DIR/scripts/deploy.sh" ]; then
    chmod +x "$APP_DIR/scripts/deploy.sh"
    "$APP_DIR/scripts/deploy.sh"
else
    echo "--> Running inline virtualenv setup and restart..."
    cd "$APP_DIR"
    python3 -m venv "$APP_DIR/venv"
    "$APP_DIR/venv/bin/pip" install --upgrade pip
    if [ -f "$APP_DIR/requirements.txt" ]; then
        "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"
    elif [ -f "$APP_DIR/app/requirements.txt" ]; then
        "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/app/requirements.txt"
    fi
    chown -R appuser:appuser "$APP_DIR"
    systemctl restart python-app.service || true
fi

echo "=========================================================="
echo " AWS SSM Deployment Successful!"
echo "=========================================================="
