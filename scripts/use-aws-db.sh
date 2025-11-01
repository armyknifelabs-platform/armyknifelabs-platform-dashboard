#!/bin/bash

# Script to configure backend to use AWS RDS + ElastiCache
# Usage: ./use-aws-db.sh

set -e

echo "🔧 Configuring backend to use AWS RDS + ElastiCache..."

# Copy .env.aws to .env
cd packages/backend
cp .env.aws .env

echo "✅ Backend configured to use AWS infrastructure"
echo ""
echo "AWS Endpoints:"
echo "  RDS: ai-orchestration-db.cmn4wqs645sa.us-east-1.rds.amazonaws.com:5432"
echo "  ElastiCache: seip-redis.rbzg8e.0001.use1.cache.amazonaws.com:6379"
echo ""
echo "To start the backend with AWS configuration:"
echo "  cd packages/backend && pnpm dev"
echo ""
echo "To switch back to local Docker:"
echo "  cd packages/backend && cp .env.local .env"
