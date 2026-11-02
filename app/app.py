"""
Sample Flask Web Application for EC2 CI/CD Deployment via Bastion Host.
Provides an interactive web dashboard alongside RESTful API endpoints.
"""

import os
import socket
import platform
import time
from datetime import datetime
from flask import Flask, jsonify, request, render_template
import flask

app = Flask(__name__)
START_TIME = time.time()
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
APP_ENV = os.getenv("APP_ENV", "production")

# In-memory storage for demo items/tasks
TASKS_STORE = [
    {"id": 1, "title": "Configure AWS VPC and Subnets", "status": "completed"},
    {"id": 2, "title": "Setup Bastion Host & Security Groups", "status": "completed"},
    {"id": 3, "title": "Deploy Flask via GitHub Actions ProxyJump", "status": "active"},
]

@app.route("/", methods=["GET"])
def home():
    """Root route: returns HTML dashboard for browser or JSON for API clients."""
    uptime_seconds = int(time.time() - START_TIME)
    hostname = socket.gethostname()
    os_info = f"{platform.system()} {platform.release()}"
    timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")

    # If client prefers JSON or query param ?format=json
    if request.args.get("format") == "json" or request.headers.get("Accept") == "application/json":
        return jsonify({
            "message": "Welcome to Sample Flask Application on AWS EC2!",
            "version": APP_VERSION,
            "environment": APP_ENV,
            "hostname": hostname,
            "os": os_info,
            "uptime_seconds": uptime_seconds,
            "timestamp": timestamp,
            "endpoints": {
                "health": "/health",
                "info": "/api/info",
                "tasks": "/api/tasks"
            }
        }), 200

    return render_template(
        "index.html",
        hostname=hostname,
        environment=APP_ENV,
        version=APP_VERSION,
        os_info=os_info,
        uptime=uptime_seconds,
        timestamp=timestamp,
        py_version=platform.python_version(),
        flask_version=flask.__version__
    )

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
    """Detailed system telemetry and runtime information."""
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
        "flask_version": flask.__version__,
        "uptime_seconds": int(time.time() - START_TIME)
    }), 200

@app.route("/api/tasks", methods=["GET"])
def get_tasks():
    """List all sample tasks."""
    return jsonify({
        "count": len(TASKS_STORE),
        "tasks": TASKS_STORE
    }), 200

@app.route("/api/tasks", methods=["POST"])
def create_task():
    """Create a new task."""
    data = request.get_json(silent=True) or {}
    title = data.get("title")
    if not title:
        return jsonify({"error": "Field 'title' is required"}), 400

    new_task = {
        "id": len(TASKS_STORE) + 1,
        "title": title,
        "status": data.get("status", "pending")
    }
    TASKS_STORE.append(new_task)
    return jsonify(new_task), 201

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
