"""
Unit tests for the Flask Web Application.
Tests cover HTML dashboard, JSON healthcheck, system diagnostics, and CRUD tasks.
"""

import pytest
import sys
import os

# Ensure project root and app directory are importable
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

try:
    from app.app import app, TASKS_STORE
except ImportError:
    from app import app, TASKS_STORE


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client

def test_home_page_html(client):
    """Test GET / returns HTML dashboard by default."""
    response = client.get("/")
    assert response.status_code == 200
    html = response.get_data(as_text=True)
    assert "Python Flask Application on AWS EC2" in html
    assert "Bastion Host" in html
    assert "Health: 200 OK" in html

def test_home_page_json(client):
    """Test GET /?format=json returns valid JSON response."""
    response = client.get("/?format=json")
    assert response.status_code == 200
    data = response.get_json()
    assert "message" in data
    assert "version" in data
    assert "hostname" in data

def test_health_check(client):
    """Test GET /health returns 200 and healthy JSON."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "healthy"
    assert "uptime_seconds" in data
    assert data["status_code"] == 200

def test_system_info(client):
    """Test GET /api/info returns diagnostic information."""
    response = client.get("/api/info")
    assert response.status_code == 200
    data = response.get_json()
    assert "app_version" in data
    assert "python_version" in data
    assert "flask_version" in data
    assert "os" in data

def test_get_tasks(client):
    """Test GET /api/tasks returns task list."""
    response = client.get("/api/tasks")
    assert response.status_code == 200
    data = response.get_json()
    assert "tasks" in data
    assert data["count"] >= 3

def test_create_task_success(client):
    """Test POST /api/tasks creates a new task."""
    payload = {"title": "Test Bastion CI/CD Pipeline"}
    response = client.post("/api/tasks", json=payload)
    assert response.status_code == 201
    data = response.get_json()
    assert data["title"] == "Test Bastion CI/CD Pipeline"
    assert data["id"] > 3

def test_create_task_validation_error(client):
    """Test POST /api/tasks with missing title returns 400."""
    response = client.post("/api/tasks", json={})
    assert response.status_code == 400
    data = response.get_json()
    assert "error" in data
