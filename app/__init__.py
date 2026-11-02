# Sample Python Application Package
"""
Flask Application Package.
Exposes the main Flask application instance and in-memory store.
"""

from .app import app, TASKS_STORE

__all__ = ["app", "TASKS_STORE"]