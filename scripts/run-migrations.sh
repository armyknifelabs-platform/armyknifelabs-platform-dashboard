#!/bin/bash
set -e

echo "[Migrations] Starting database migrations..."

# Wait for PostgreSQL to be ready
until PGPASSWORD=$POSTGRES_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c '\q' 2>/dev/null; do
  echo "[Migrations] Waiting for PostgreSQL to be ready..."
  sleep 2
done

echo "[Migrations] PostgreSQL is ready. Running migrations..."

# Run all migration files in order
for migration in /app/packages/backend/src/db/migrations/*.sql; do
  echo "[Migrations] Running $(basename $migration)..."
  PGPASSWORD=$POSTGRES_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$migration" 2>&1 | grep -v "ERROR.*already exists" || true
done

echo "[Migrations] Database migrations complete!"
