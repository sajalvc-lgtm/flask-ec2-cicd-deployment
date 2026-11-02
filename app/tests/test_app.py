"""
Unit tests for the Sample Python Application.
Tests cover root endpoint, health check, system diagnostics, and CRUD actions.
"""

import pytest
import sys
import os

# Add parent directory to path so app can be imported
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app import app, ITEMS_STORE

@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client

def test_root_endpoint(client):
    """Test GET / returns 200 and welcoming message."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.get_json()
    assert "message" in data
    assert "version" in data
    assert "hostname" in data

def test_health_check(client):
    """Test GET /health returns 200 and healthy status."""
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
    assert "os" in data

def test_get_items(client):
    """Test GET /api/items returns list of items."""
    response = client.get("/api/items")
    assert response.status_code == 200
    data = response.get_json()
    assert "items" in data
    assert data["count"] >= 2

def test_create_item_success(client):
    """Test POST /api/items creates new item successfully."""
    payload = {"name": "Test EC2 Pipeline", "status": "active"}
    response = client.post("/api/items", json=payload)
    assert response.status_code == 201
    data = response.get_json()
    assert data["name"] == "Test EC2 Pipeline"
    assert data["id"] > 2

def test_create_item_validation_error(client):
    """Test POST /api/items with missing name returns 400."""
    response = client.post("/api/items", json={})
    assert response.status_code == 400
    data = response.get_json()
    assert "error" in data
