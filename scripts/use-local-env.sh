#!/bin/bash
# Switch backend to use local PostgreSQL + Redis
# Usage: ./scripts/use-local-env.sh

set -e

BACKEND_DIR="$(cd "$(dirname "$0")/../packages/backend" && pwd)"
ENV_FILE="$BACKEND_DIR/.env"
BACKUP_FILE="$ENV_FILE.local.backup"

echo "🔄 Switching to local PostgreSQL + Redis..."

if [ -f "$BACKUP_FILE" ]; then
  echo "✅ Restoring .env from backup"
  cp "$BACKUP_FILE" "$ENV_FILE"
  echo "✅ Successfully switched to local configuration!"
else
  echo "⚠️  No backup found at $BACKUP_FILE"
  echo ""
  echo "Creating default local .env..."

  cat > "$ENV_FILE" << 'EOF'
# Local Development Configuration
# PostgreSQL + Redis running in Docker containers

# === DATABASE (Local PostgreSQL) ===
DATABASE_URL=postgresql://seip_user:changeme@localhost:5432/github_metrics

# === REDIS (Local) ===
REDIS_HOST=localhost
REDIS_PORT=6379

# === GITHUB TOKENS ===
GITHUB_TOKEN=your_github_token_here

# === SESSION & SECURITY ===
SESSION_SECRET=local_dev_secret_change_in_production
NODE_ENV=development

# === SERVER CONFIGURATION ===
PORT=3001
HOST=0.0.0.0

# === CORS ===
FRONTEND_URL=http://localhost:5173

# === LOGGING ===
LOG_LEVEL=debug
EOF

  echo "✅ Created default local .env"
  echo ""
  echo "⚠️  Please update GITHUB_TOKEN in .env"
fi

echo ""
echo "📝 Configuration:"
echo "  - Database: Local PostgreSQL (localhost:5432)"
echo "  - Redis: Local Redis (localhost:6379)"
echo ""
echo "🚀 To start local services:"
echo "   docker-compose up -d postgres redis"
echo "   pnpm pm2 start"
