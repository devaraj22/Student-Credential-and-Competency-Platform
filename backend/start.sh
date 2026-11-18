#!/usr/bin/env sh
set -e

echo "Applying Alembic database migrations..."
alembic upgrade head

PORT="${PORT:-8000}"
echo "Starting Uvicorn server on 0.0.0.0:${PORT}..."
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT}"
