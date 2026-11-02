"""
WSGI Entrypoint for Gunicorn server.
Imports and exposes the Flask application instance.
"""

import sys
import os

# Add app directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "app")))

from app import app

if __name__ == "__main__":
    app.run()
