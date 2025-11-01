#!/bin/bash
#
# Environment Alignment Checker
# Verifies that main, guest, and Docker builds are synchronized
#
set -e

echo "=== Environment Alignment Check ==="
echo "Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ALIGNED=true

# 1. Check Git Branches
echo "📌 Checking Git Branches..."
MAIN_COMMIT=$(git rev-parse main 2>/dev/null || echo "ERROR")
GUEST_COMMIT=$(git rev-parse guest 2>/dev/null || echo "ERROR")

if [ "$MAIN_COMMIT" = "$GUEST_COMMIT" ]; then
    echo -e "${GREEN}✓${NC} main and guest are aligned at: ${MAIN_COMMIT:0:7}"
else
    echo -e "${RED}✗${NC} main and guest are NOT aligned"
    echo "  main:  $MAIN_COMMIT"
    echo "  guest: $GUEST_COMMIT"
    ALIGNED=false
fi
echo ""

# 2. Check Latest Git Tags
echo "📌 Checking Latest Git Tags..."
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "NO_TAGS")
TAG_COMMIT=$(git rev-list -n 1 "$LATEST_TAG" 2>/dev/null || echo "ERROR")

echo "Latest tag: $LATEST_TAG"
if [ "$TAG_COMMIT" = "$MAIN_COMMIT" ]; then
    echo -e "${GREEN}✓${NC} Tag $LATEST_TAG points to main/guest"
else
    echo -e "${YELLOW}⚠${NC} Tag $LATEST_TAG does not point to current main/guest"
    echo "  Tag commit: $TAG_COMMIT"
    echo "  Main commit: $MAIN_COMMIT"
fi
echo ""

# 3. Check Docker Images in ECR
echo "📌 Checking Docker Images..."
AWS_REGION=${AWS_REGION:-us-east-1}

# Get latest tags
BACKEND_TAGS=$(aws ecr describe-images \
    --repository-name seip-backend \
    --region "$AWS_REGION" \
    --query 'imageDetails[*].imageTags[]' \
    --output text 2>/dev/null | grep -E "^(v[0-9]|guest-|main-)" | head -5)

FRONTEND_TAGS=$(aws ecr describe-images \
    --repository-name seip-frontend \
    --region "$AWS_REGION" \
    --query 'imageDetails[*].imageTags[]' \
    --output text 2>/dev/null | grep -E "^(v[0-9]|guest-|main-)" | head -5)

echo "Backend tags (latest 5):"
echo "$BACKEND_TAGS" | head -5

echo ""
echo "Frontend tags (latest 5):"
echo "$FRONTEND_TAGS" | head -5

# Check if aligned tag exists
if echo "$BACKEND_TAGS" | grep -q "v1.0.0-aligned" && \
   echo "$FRONTEND_TAGS" | grep -q "v1.0.0-aligned"; then
    echo -e "${GREEN}✓${NC} Docker images have v1.0.0-aligned tag"
else
    echo -e "${YELLOW}⚠${NC} v1.0.0-aligned tag not found in Docker images"
fi
echo ""

# 4. Check Deployment Status
echo "📌 Checking ECS Deployments..."
CLUSTER=${ECS_CLUSTER:-seip-prod}

# Check guest backend
GUEST_BACKEND_STATUS=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services seip-backend-guest \
    --region "$AWS_REGION" \
    --query 'services[0].deployments[0].{status:status,running:runningCount,desired:desiredCount}' \
    --output json 2>/dev/null)

GUEST_FRONTEND_STATUS=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services seip-frontend-guest \
    --region "$AWS_REGION" \
    --query 'services[0].deployments[0].{status:status,running:runningCount,desired:desiredCount}' \
    --output json 2>/dev/null)

echo "Guest Backend:  $(echo "$GUEST_BACKEND_STATUS" | jq -r '"\(.status) - \(.running)/\(.desired)"')"
echo "Guest Frontend: $(echo "$GUEST_FRONTEND_STATUS" | jq -r '"\(.status) - \(.running)/\(.desired)"')"

if echo "$GUEST_BACKEND_STATUS" | jq -e '.running == .desired and .status == "PRIMARY"' > /dev/null && \
   echo "$GUEST_FRONTEND_STATUS" | jq -e '.running == .desired and .status == "PRIMARY"' > /dev/null; then
    echo -e "${GREEN}✓${NC} Guest environment is healthy"
else
    echo -e "${RED}✗${NC} Guest environment has deployment issues"
    ALIGNED=false
fi
echo ""

# 5. Check RAG System Health
echo "📌 Checking RAG System..."
GUEST_URL=${GUEST_URL:-https://guest.dashboard.armyknifelabs.com}

RAG_HEALTH=$(curl -sf "$GUEST_URL/api/v1/rag/health" 2>/dev/null || echo '{"success":false}')

if echo "$RAG_HEALTH" | jq -e '.success == true' > /dev/null; then
    EMBEDDINGS=$(echo "$RAG_HEALTH" | jq -r '.data.vectorStore.totalEmbeddings // 0')
    TOKENS=$(echo "$RAG_HEALTH" | jq -r '.data.github.tokens // 0')
    echo -e "${GREEN}✓${NC} RAG system healthy"
    echo "  Embeddings: $EMBEDDINGS"
    echo "  GitHub tokens: $TOKENS"
else
    echo -e "${RED}✗${NC} RAG system unhealthy or unreachable"
    ALIGNED=false
fi
echo ""

# Final Summary
echo "=== Alignment Summary ==="
if [ "$ALIGNED" = true ]; then
    echo -e "${GREEN}✓ ALL SYSTEMS ALIGNED${NC}"
    exit 0
else
    echo -e "${RED}✗ ALIGNMENT ISSUES DETECTED${NC}"
    echo ""
    echo "Run: ./scripts/realign-environments.sh to fix"
    exit 1
fi
