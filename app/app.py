"""
Sample Python Web Application for EC2 CI/CD Deployment
Built with Flask and designed for production deployment with Gunicorn & Systemd.
"""

import os
import socket
import platform
import time
from datetime import datetime
from flask import Flask, jsonify, request

app = Flask(__name__)
START_TIME = time.time()
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
APP_ENV = os.getenv("APP_ENV", "production")

# In-memory store for demo items
ITEMS_STORE = [
    {"id": 1, "name": "EC2 Deployment Pipeline", "status": "active"},
    {"id": 2, "name": "GitHub Actions Automation", "status": "active"},
]

@app.route("/", methods=["GET"])
def home():
    """Root landing route."""
    return jsonify({
        "message": "Welcome to Sample Python Application deployed on AWS EC2!",
        "version": APP_VERSION,
        "environment": APP_ENV,
        "hostname": socket.gethostname(),
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "documentation": {
            "health": "/health",
            "info": "/api/info",
            "items": "/api/items"
        }
    }), 200

@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint used by ALB/NLB and CI/CD post-deployment validation."""
    uptime_seconds = int(time.time() - START_TIME)
    return jsonify({
        "status": "healthy",
        "uptime_seconds": uptime_seconds,
        "version": APP_VERSION,
        "hostname": socket.gethostname(),
        "status_code": 200
    }), 200

@app.route("/api/info", methods=["GET"])
def system_info():
    """Detailed system diagnostic information."""
    try:
        ip_addr = socket.gethostbyname(socket.gethostname())
    except Exception:
        ip_addr = "127.0.0.1"

    return jsonify({
        "app_version": APP_VERSION,
        "environment": APP_ENV,
        "hostname": socket.gethostname(),
        "ip_address": ip_addr,
        "os": platform.system(),
        "os_release": platform.release(),
        "python_version": platform.python_version(),
        "uptime_seconds": int(time.time() - START_TIME)
    }), 200

@app.route("/api/items", methods=["GET"])
def get_items():
    """Fetch all sample items."""
    return jsonify({
        "count": len(ITEMS_STORE),
        "items": ITEMS_STORE
    }), 200

@app.route("/api/items", methods=["POST"])
def create_item():
    """Create a new item in memory."""
    data = request.get_json(silent=True) or {}
    name = data.get("name")
    if not name:
        return jsonify({"error": "Field 'name' is required"}), 400

    new_id = len(ITEMS_STORE) + 1
    new_item = {
        "id": new_id,
        "name": name,
        "status": data.get("status", "pending")
    }
    ITEMS_STORE.append(new_item)
    return jsonify(new_item), 201

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
