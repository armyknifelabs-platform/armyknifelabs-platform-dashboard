#!/bin/bash
# Load secrets from AWS Secrets Manager
# Usage: source ./scripts/load-aws-secrets.sh [environment]
#   environment: production or development (default: production)

set -e

ENVIRONMENT="${1:-production}"
AWS_REGION="us-east-1"

echo "🔐 Loading secrets from AWS Secrets Manager..."
echo "📍 Environment: $ENVIRONMENT"
echo "🌍 Region: $AWS_REGION"
echo ""

# Function to get secret value
get_secret() {
  local secret_name=$1
  aws secretsmanager get-secret-value \
    --secret-id "$secret_name" \
    --region "$AWS_REGION" \
    --query 'SecretString' \
    --output text 2>/dev/null || echo "{}"
}

# Load GitHub OAuth credentials based on environment
if [ "$ENVIRONMENT" = "production" ]; then
  echo "🏢 Loading production OAuth credentials..."
  OAUTH_SECRET=$(get_secret "seip/github-oauth-production")
  export GITHUB_CALLBACK_URL="https://seip.armyknifeplatform.com/api/v1/auth/github/callback"
  export FRONTEND_URL="https://seip.armyknifeplatform.com"
else
  echo "💻 Loading development OAuth credentials..."
  OAUTH_SECRET=$(get_secret "seip/github-oauth-development")
  export GITHUB_CALLBACK_URL="https://localhost/api/v1/auth/github/callback"
  export FRONTEND_URL="https://localhost"
fi

export GITHUB_CLIENT_ID=$(echo "$OAUTH_SECRET" | jq -r '.client_id // empty')
export GITHUB_CLIENT_SECRET=$(echo "$OAUTH_SECRET" | jq -r '.client_secret // empty')

# Load database credentials
echo "🗄️  Loading database credentials..."
DB_SECRET=$(get_secret "seip/database/rds")
DB_HOST=$(echo "$DB_SECRET" | jq -r '.host // "ai-orchestration-db.cmn4wqs645sa.us-east-1.rds.amazonaws.com"')
DB_PORT=$(echo "$DB_SECRET" | jq -r '.port // "5432"')
DB_NAME=$(echo "$DB_SECRET" | jq -r '.database // "ai_orchestration"')
DB_USER=$(echo "$DB_SECRET" | jq -r '.username // "postgres"')
DB_PASS=$(echo "$DB_SECRET" | jq -r '.password // empty')

export DATABASE_URL="postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=no-verify"
export AWS_DATABASE_URL="$DATABASE_URL"

# Load encryption keys
echo "🔑 Loading encryption keys..."
ENCRYPTION_SECRET=$(get_secret "seip/encryption/keys")
export SESSION_SECRET=$(echo "$ENCRYPTION_SECRET" | jq -r '.session_secret // empty')
export ENCRYPTION_KEY=$(echo "$ENCRYPTION_SECRET" | jq -r '.encryption_key // empty')

# Load GitHub API tokens
echo "🔧 Loading GitHub API tokens..."
TOKEN_SECRET=$(get_secret "seip/github/tokens")
export GITHUB_TOKEN=$(echo "$TOKEN_SECRET" | jq -r '.primary // empty')
export GH_TOKEN_1="$GITHUB_TOKEN"
export GH_TOKEN_2="$GITHUB_TOKEN"
export GH_TOKEN_ENTERPRISE="$GITHUB_TOKEN"

# ElastiCache configuration
if [ "$ENVIRONMENT" = "production" ]; then
  export REDIS_HOST="seip-redis.rbzg8e.0001.use1.cache.amazonaws.com"
  export REDIS_PORT="6379"
else
  export REDIS_HOST="localhost"
  export REDIS_PORT="6379"
fi

# Other configuration
export NODE_ENV="production"
export PORT="3001"
export HOST="0.0.0.0"
export LOG_LEVEL="info"

echo ""
echo "✅ Secrets loaded successfully!"
echo ""
echo "📋 Configuration Summary:"
echo "  Environment:     $ENVIRONMENT"
echo "  OAuth Client ID: ${GITHUB_CLIENT_ID:0:20}..."
echo "  Database:        ${DB_HOST}:${DB_PORT}/${DB_NAME}"
echo "  Redis:           ${REDIS_HOST}:${REDIS_PORT}"
echo "  Frontend URL:    $FRONTEND_URL"
echo "  Callback URL:    $GITHUB_CALLBACK_URL"
echo ""

# Optionally write to .env file for Docker
if [ "$2" = "--write-env" ]; then
  ENV_FILE=".env.${ENVIRONMENT}"
  echo "📝 Writing to ${ENV_FILE}..."

  cat > "$ENV_FILE" <<EOF
# AWS Secrets Manager - Auto-generated on $(date)
# Environment: $ENVIRONMENT

# GitHub OAuth
GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID}
GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET}
GITHUB_CALLBACK_URL=${GITHUB_CALLBACK_URL}

# Database
DATABASE_URL=${DATABASE_URL}
AWS_DATABASE_URL=${AWS_DATABASE_URL}

# Redis
REDIS_HOST=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT}

# Encryption
SESSION_SECRET=${SESSION_SECRET}
ENCRYPTION_KEY=${ENCRYPTION_KEY}

# GitHub Tokens
GITHUB_TOKEN=${GITHUB_TOKEN}
GH_TOKEN_1=${GH_TOKEN_1}
GH_TOKEN_2=${GH_TOKEN_2}
GH_TOKEN_ENTERPRISE=${GH_TOKEN_ENTERPRISE}

# Frontend
FRONTEND_URL=${FRONTEND_URL}

# Server
NODE_ENV=${NODE_ENV}
PORT=${PORT}
HOST=${HOST}
LOG_LEVEL=${LOG_LEVEL}
EOF

  echo "✅ Environment file written to ${ENV_FILE}"
  echo "⚠️  WARNING: This file contains secrets. Do NOT commit to git!"
fi
