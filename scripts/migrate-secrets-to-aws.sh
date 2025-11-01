#!/bin/bash

##############################################################################
# Migrate Secrets to AWS Secrets Manager
#
# This script migrates secrets from .env files to AWS Secrets Manager.
# It creates structured JSON secrets for better organization and retrieval.
#
# Prerequisites:
# - AWS CLI installed and configured
# - Appropriate IAM permissions for Secrets Manager
# - .env file exists with current secrets
#
# Usage:
#   ./scripts/migrate-secrets-to-aws.sh [--dry-run] [--region us-east-1]
#
# Options:
#   --dry-run    Show what would be created without actually creating secrets
#   --region     AWS region to create secrets in (default: us-east-1)
#   --profile    AWS CLI profile to use (default: default)
#
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DRY_RUN=false
REGION="us-east-1"
PROFILE="default"
ENV_FILE=".env"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}ERROR: $ENV_FILE not found${NC}"
    exit 1
fi

echo -e "${BLUE}===========================================================${NC}"
echo -e "${BLUE}AWS Secrets Manager Migration Tool${NC}"
echo -e "${BLUE}===========================================================${NC}"
echo ""
echo -e "Region: ${GREEN}${REGION}${NC}"
echo -e "Profile: ${GREEN}${PROFILE}${NC}"
echo -e "Env File: ${GREEN}${ENV_FILE}${NC}"
echo -e "Dry Run: ${GREEN}${DRY_RUN}${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN MODE - No secrets will be created${NC}"
    echo ""
fi

# Function to create or update secret
create_or_update_secret() {
    local secret_name=$1
    local secret_value=$2
    local description=$3

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would create/update: ${GREEN}${secret_name}${NC}"
        echo -e "Description: ${description}"
        echo ""
        return
    fi

    echo -e "Creating/updating secret: ${GREEN}${secret_name}${NC}"

    # Try to create secret
    if aws secretsmanager create-secret \
        --name "${secret_name}" \
        --description "${description}" \
        --secret-string "${secret_value}" \
        --region "${REGION}" \
        --profile "${PROFILE}" \
        2>/dev/null; then
        echo -e "${GREEN}✓ Created secret: ${secret_name}${NC}"
    else
        # If creation fails, try to update
        if aws secretsmanager update-secret \
            --secret-id "${secret_name}" \
            --secret-string "${secret_value}" \
            --region "${REGION}" \
            --profile "${PROFILE}" \
            2>/dev/null; then
            echo -e "${GREEN}✓ Updated secret: ${secret_name}${NC}"
        else
            echo -e "${RED}✗ Failed to create/update secret: ${secret_name}${NC}"
        fi
    fi
    echo ""
}

# Load environment variables
source "$ENV_FILE"

echo -e "${BLUE}Step 1: Migrating Database Credentials${NC}"
echo "----------------------------------------"

DATABASE_CREDENTIALS=$(cat <<EOF
{
  "development": {
    "url": "${DATABASE_URL}",
    "user": "${POSTGRES_USER}",
    "password": "${POSTGRES_PASSWORD}",
    "database": "${POSTGRES_DB}"
  },
  "production": {
    "url": "${DATABASE_URL}",
    "user": "${POSTGRES_USER}",
    "password": "${POSTGRES_PASSWORD}",
    "database": "${POSTGRES_DB}",
    "host": "ai-orchestration-db.cmn4wqs645sa.us-east-1.rds.amazonaws.com"
  }
}
EOF
)

create_or_update_secret \
    "seip-dashboard/database-credentials" \
    "$DATABASE_CREDENTIALS" \
    "Database credentials for development and production environments"

echo -e "${BLUE}Step 2: Migrating AWS Credentials${NC}"
echo "----------------------------------------"

AWS_CREDENTIALS=$(cat <<EOF
{
  "primary": {
    "accessKeyId": "${AWS_ACCESS_KEY_ID}",
    "secretAccessKey": "${AWS_SECRET_ACCESS_KEY}",
    "region": "${AWS_REGION}"
  },
  "backup": {
    "accessKeyId": "${BACKUP_ACCESS_KEY_ID}",
    "secretAccessKey": "${BACKUP_SECRET_ACCESS_KEY}",
    "region": "${AWS_REGION}"
  }
}
EOF
)

create_or_update_secret \
    "seip-dashboard/aws-credentials" \
    "$AWS_CREDENTIALS" \
    "AWS credentials for primary and backup access"

echo -e "${BLUE}Step 3: Migrating Azure Credentials${NC}"
echo "----------------------------------------"

AZURE_CREDENTIALS=$(cat <<EOF
{
  "clientId": "${ARM_CLIENT_ID}",
  "clientSecret": "${ARM_CLIENT_SECRET}",
  "subscriptionId": "${ARM_SUBSCRIPTION_ID}",
  "tenantId": "${ARM_TENANT_ID}",
  "aiSearch": {
    "endpoint": "${AZURE_SEARCH_ENDPOINT}",
    "key": "${AZURE_SEARCH_KEY}"
  }
}
EOF
)

create_or_update_secret \
    "seip-dashboard/azure-credentials" \
    "$AZURE_CREDENTIALS" \
    "Azure credentials including AI Search service"

echo -e "${BLUE}Step 4: Migrating Google Cloud Credentials${NC}"
echo "----------------------------------------"

GOOGLE_CREDENTIALS=$(cat <<EOF
{
  "credentialsPath": "${GOOGLE_APPLICATION_CREDENTIALS}",
  "serviceAccountKey": ""
}
EOF
)

create_or_update_secret \
    "seip-dashboard/google-credentials" \
    "$GOOGLE_CREDENTIALS" \
    "Google Cloud credentials and service account path"

echo -e "${BLUE}Step 5: Migrating GitHub Tokens${NC}"
echo "----------------------------------------"

GITHUB_TOKENS=$(cat <<EOF
{
  "primary": "${GITHUB_TOKEN}",
  "seip_token_01": "${SEIP_TOKEN_01}",
  "token_1": "${GH_TOKEN_1}",
  "token_2": "${GH_TOKEN_2}",
  "enterprise": "${GH_TOKEN}"
}
EOF
)

create_or_update_secret \
    "seip-dashboard/github-tokens" \
    "$GITHUB_TOKENS" \
    "GitHub personal access tokens for API access"

echo -e "${BLUE}Step 6: Migrating GitHub OAuth Credentials${NC}"
echo "----------------------------------------"

GITHUB_OAUTH=$(cat <<EOF
{
  "clientId": "${GITHUB_OAUTH_CLIENT_ID}",
  "clientSecret": "${GITHUB_OAUTH_CLIENT_SECRET}",
  "callbackUrl": "${GITHUB_CALLBACK_URL}"
}
EOF
)

create_or_update_secret \
    "seip-dashboard/github-oauth" \
    "$GITHUB_OAUTH" \
    "GitHub OAuth application credentials"

echo -e "${BLUE}Step 7: Migrating Application Secrets${NC}"
echo "----------------------------------------"

APPLICATION_SECRETS=$(cat <<EOF
{
  "encryptionKey": "${ENCRYPTION_KEY}",
  "sessionSecret": "${SESSION_SECRET}",
  "apiKeySecret": "${API_KEY_SECRET}",
  "jwtSecret": "${JWT_SECRET}"
}
EOF
)

create_or_update_secret \
    "seip-dashboard/application-secrets" \
    "$APPLICATION_SECRETS" \
    "Application encryption and session secrets"

echo -e "${BLUE}Step 8: Creating AI Provider Keys Placeholder${NC}"
echo "----------------------------------------"

AI_PROVIDER_KEYS=$(cat <<EOF
{
  "anthropic": "",
  "openai": "",
  "awsBedrock": {
    "region": "us-east-1",
    "modelId": "anthropic.claude-3-5-haiku-20250110-v1:0"
  },
  "googleVertex": {
    "projectId": "",
    "location": "us-central1",
    "modelId": "claude-3-5-haiku@20250110"
  },
  "azureAI": {
    "endpoint": "",
    "deploymentName": "claude-3-5-haiku"
  }
}
EOF
)

create_or_update_secret \
    "seip-dashboard/ai-provider-keys" \
    "$AI_PROVIDER_KEYS" \
    "AI provider API keys and configuration"

echo ""
echo -e "${GREEN}===========================================================${NC}"
echo -e "${GREEN}Migration Complete!${NC}"
echo -e "${GREEN}===========================================================${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}This was a DRY RUN. No secrets were actually created.${NC}"
    echo -e "${YELLOW}Run without --dry-run to create secrets.${NC}"
else
    echo -e "${GREEN}All secrets have been migrated to AWS Secrets Manager.${NC}"
    echo ""
    echo -e "${YELLOW}NEXT STEPS:${NC}"
    echo "1. Verify secrets in AWS Console or CLI:"
    echo "   aws secretsmanager list-secrets --region ${REGION}"
    echo ""
    echo "2. Test SecretManager service in development"
    echo ""
    echo "3. Update IAM policies for ECS tasks:"
    echo "   - Allow secretsmanager:GetSecretValue"
    echo "   - Resource: arn:aws:secretsmanager:${REGION}:*:secret:seip-dashboard/*"
    echo ""
    echo "4. Deploy updated application code"
    echo ""
    echo "5. ROTATE ALL SECRETS after confirming everything works"
    echo ""
    echo -e "${RED}WARNING: Current secrets are still in .env file!${NC}"
    echo -e "${RED}After confirming migration works, remove secrets from .env${NC}"
fi

echo ""
