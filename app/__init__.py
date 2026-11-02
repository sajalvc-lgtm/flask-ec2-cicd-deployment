cat << 'EOF' > app/__init__.py
from .app import app, TASKS_STORE
__all__ = ["app", "TASKS_STORE"]
EOF