#!/usr/bin/env bash
# ==============================================================================
# Script: deploy.sh
# Purpose: Deploys or updates the Python application in /opt/python-app,
#          updates the venv dependencies, restarts systemd service, and performs
#          health check verification.
# ==============================================================================
set -euo pipefail

APP_DIR="/opt/python-app"
HEALTH_CHECK_URL="http://127.0.0.1:5000/health"
MAX_HEALTH_RETRIES=15
RETRY_INTERVAL_SECONDS=2

echo "=========================================================="
echo " Starting Application Deployment to $APP_DIR"
echo "=========================================================="

# 1. Ensure directory exists
sudo mkdir -p "$APP_DIR"
cd "$APP_DIR"

# 2. Setup / update Python virtual environment
echo "==> [1/5] Ensuring Python virtual environment..."
if [ ! -d "$APP_DIR/venv" ]; then
    sudo python3 -m venv "$APP_DIR/venv"
fi

# Ensure pip is up to date
sudo "$APP_DIR/venv/bin/pip" install --upgrade pip setuptools wheel

# 3. Install/Update application dependencies
if [ -f "$APP_DIR/requirements.txt" ]; then
    echo "==> [2/5] Installing dependencies from requirements.txt..."
    sudo "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"
elif [ -f "$APP_DIR/app/requirements.txt" ]; then
    echo "==> [2/5] Installing dependencies from app/requirements.txt..."
    sudo "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/app/requirements.txt"
else
    echo "WARNING: requirements.txt not found in $APP_DIR"
fi


# 4. Fix permissions
echo "==> [3/5] Setting ownership to appuser..."
sudo chown -R appuser:appuser "$APP_DIR"

# 5. Restart application service
echo "==> [4/5] Restarting systemd service: python-app.service..."
sudo systemctl daemon-reload
sudo systemctl restart python-app.service

# 6. Verify health check
echo "==> [5/5] Verifying service health check at $HEALTH_CHECK_URL..."
ATTEMPT=1
SUCCESS=0

while [ $ATTEMPT -le $MAX_HEALTH_RETRIES ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_URL" || true)
    if [ "$HTTP_CODE" -eq 200 ]; then
        echo "--> SUCCESS: Health check returned HTTP 200 on attempt $ATTEMPT!"
        SUCCESS=1
        break
    else
        echo "--> Attempt $ATTEMPT/$MAX_HEALTH_RETRIES: Received HTTP status '$HTTP_CODE'. Retrying in ${RETRY_INTERVAL_SECONDS}s..."
        sleep $RETRY_INTERVAL_SECONDS
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

if [ $SUCCESS -ne 1 ]; then
    echo "ERROR: Health check failed after $MAX_HEALTH_RETRIES attempts!"
    echo "--> Systemd service logs:"
    sudo journalctl -u python-app.service -n 50 --no-pager
    exit 1
fi

echo "=========================================================="
echo " Deployment Successfully Finished!"
echo "=========================================================="
