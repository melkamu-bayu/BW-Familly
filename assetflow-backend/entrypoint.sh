#!/bin/sh
# Runs on every container start (Render free tier has no Shell/one-off-job
# access, so this is how migrations and seeding happen instead of a manual
# `alembic upgrade head` / `python -m app.seed` in a shell).
#
# Safe to run on every boot:
#   - `alembic upgrade head` is a no-op if the schema is already current.
#   - `app.seed` checks for existing rows before creating anything, so it
#     never duplicates data on a restart/redeploy.
set -e

echo "== Running database migrations =="
alembic upgrade head

echo "== Seeding initial data (idempotent) =="
python -m app.seed

echo "== Starting server =="
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
