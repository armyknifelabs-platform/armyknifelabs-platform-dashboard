#!/bin/bash
# Switch backend to use AWS RDS + ElastiCache
# Usage: ./scripts/use-aws-env.sh

set -e

BACKEND_DIR="$(cd "$(dirname "$0")/../packages/backend" && pwd)"
ENV_FILE="$BACKEND_DIR/.env"
AWS_ENV_FILE="$BACKEND_DIR/.env.aws"

echo "🔄 Switching to AWS RDS + ElastiCache..."

if [ ! -f "$AWS_ENV_FILE" ]; then
  echo "❌ Error: $AWS_ENV_FILE not found"
  echo "Please create .env.aws with AWS credentials first"
  exit 1
fi

# Backup current .env
if [ -f "$ENV_FILE" ]; then
  echo "📦 Backing up current .env to .env.local.backup"
  cp "$ENV_FILE" "$ENV_FILE.local.backup"
fi

# Copy .env.aws to .env
echo "✅ Copying .env.aws to .env"
cp "$AWS_ENV_FILE" "$ENV_FILE"

echo ""
echo "✅ Successfully switched to AWS configuration!"
echo ""
echo "📝 Configuration:"
echo "  - Database: AWS RDS (ai-orchestration-db)"
echo "  - Redis: AWS ElastiCache (seip-redis)"
echo ""
echo "⚠️  Note: AWS RDS/ElastiCache are in PRIVATE subnets"
echo "   - Local connections will TIMEOUT"
echo "   - Use this config for ECS Fargate deployment only"
echo "   - For local dev, run: ./scripts/use-local-env.sh"
echo ""
echo "🚀 To test with ECS:"
echo "   1. Build and push Docker images"
echo "   2. Deploy to ECS Fargate"
echo "   3. Access via ECS tasks (inside VPC)"
