#!/bin/bash
set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKEND_IMAGE="seip-backend"
FRONTEND_IMAGE="seip-frontend"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
PLATFORM="linux/amd64"  # ECS Fargate platform
TEST_NETWORK="seip-test-network"

# Parse version from command line or use "test"
VERSION="${1:-test}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  SEIP Portal - Build & Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Version: ${GREEN}${VERSION}${NC}"
echo -e "Platform: ${GREEN}${PLATFORM}${NC}"
echo ""

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up test containers and network...${NC}"
    docker rm -f seip-backend-test 2>/dev/null || true
    docker rm -f seip-frontend-test 2>/dev/null || true
    docker network rm ${TEST_NETWORK} 2>/dev/null || true
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Step 1: Build Backend
echo -e "${BLUE}Step 1: Building backend image...${NC}"
docker buildx build \
    --platform ${PLATFORM} \
    --file Dockerfile.backend \
    --tag ${BACKEND_IMAGE}:${VERSION} \
    --tag ${ECR_REGISTRY}/${BACKEND_IMAGE}:${VERSION} \
    --no-cache \
    --load \
    .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Backend build successful${NC}\n"
else
    echo -e "${RED}✗ Backend build failed${NC}"
    exit 1
fi

# Step 2: Build Frontend (with production nginx config)
echo -e "${BLUE}Step 2: Building frontend image...${NC}"
docker buildx build \
    --platform ${PLATFORM} \
    --file Dockerfile.frontend \
    --build-arg NGINX_CONFIG=nginx.production.conf \
    --tag ${FRONTEND_IMAGE}:${VERSION} \
    --tag ${ECR_REGISTRY}/${FRONTEND_IMAGE}:${VERSION} \
    --no-cache \
    --load \
    .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Frontend build successful${NC}\n"
else
    echo -e "${RED}✗ Frontend build failed${NC}"
    exit 1
fi

# Step 3: Smoke Tests
echo -e "${BLUE}Step 3: Running smoke tests...${NC}"

# Create test network
docker network create ${TEST_NETWORK} 2>/dev/null || true

# Test Backend
echo -e "${YELLOW}Testing backend health endpoint...${NC}"
docker run -d \
    --name seip-backend-test \
    --network ${TEST_NETWORK} \
    -e NODE_ENV=test \
    -e PORT=3001 \
    -e REDIS_HOST=localhost \
    -e REDIS_PORT=6379 \
    -p 3002:3001 \
    ${BACKEND_IMAGE}:${VERSION}

# Wait for backend to start
echo -n "Waiting for backend to be ready"
BACKEND_READY=false
for i in {1..30}; do
    echo -n "."
    if docker exec seip-backend-test wget --quiet --tries=1 --spider http://localhost:3001/health 2>/dev/null; then
        BACKEND_READY=true
        break
    fi
    sleep 1
done
echo ""

if [ "$BACKEND_READY" = true ]; then
    echo -e "${GREEN}✓ Backend health check passed${NC}"
else
    echo -e "${RED}✗ Backend health check failed${NC}"
    echo -e "${YELLOW}Backend logs:${NC}"
    docker logs seip-backend-test --tail 50
    exit 1
fi

# Test Frontend
echo -e "${YELLOW}Testing frontend...${NC}"
docker run -d \
    --name seip-frontend-test \
    --network ${TEST_NETWORK} \
    -e VITE_API_URL=http://seip-backend-test:3001/api/v1 \
    -p 8081:80 \
    ${FRONTEND_IMAGE}:${VERSION}

# Wait for frontend to start
echo -n "Waiting for frontend to be ready"
FRONTEND_READY=false
for i in {1..30}; do
    echo -n "."
    if docker exec seip-frontend-test wget --quiet --tries=1 --spider http://localhost:80/ 2>/dev/null; then
        FRONTEND_READY=true
        break
    fi
    sleep 1
done
echo ""

if [ "$FRONTEND_READY" = true ]; then
    echo -e "${GREEN}✓ Frontend health check passed${NC}"
else
    echo -e "${RED}✗ Frontend health check failed${NC}"
    echo -e "${YELLOW}Frontend logs:${NC}"
    docker logs seip-frontend-test --tail 50
    exit 1
fi

# Verify environment injection
echo -e "${YELLOW}Verifying environment injection...${NC}"
docker logs seip-frontend-test 2>&1 | grep -q "Env Injection"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Environment injection working${NC}"
else
    echo -e "${RED}✗ Environment injection check failed${NC}"
    exit 1
fi

# Step 4: Image Verification
echo -e "\n${BLUE}Step 4: Verifying images...${NC}"

# Check image sizes
BACKEND_SIZE=$(docker images ${BACKEND_IMAGE}:${VERSION} --format "{{.Size}}")
FRONTEND_SIZE=$(docker images ${FRONTEND_IMAGE}:${VERSION} --format "{{.Size}}")

echo -e "Backend image:  ${GREEN}${BACKEND_IMAGE}:${VERSION}${NC} (${BACKEND_SIZE})"
echo -e "Frontend image: ${GREEN}${FRONTEND_IMAGE}:${VERSION}${NC} (${FRONTEND_SIZE})"

# Check platform
BACKEND_PLATFORM=$(docker image inspect ${BACKEND_IMAGE}:${VERSION} --format '{{.Architecture}}')
FRONTEND_PLATFORM=$(docker image inspect ${FRONTEND_IMAGE}:${VERSION} --format '{{.Architecture}}')

if [ "$BACKEND_PLATFORM" = "amd64" ] && [ "$FRONTEND_PLATFORM" = "amd64" ]; then
    echo -e "${GREEN}✓ Correct platform (amd64) for both images${NC}"
else
    echo -e "${RED}✗ Platform mismatch: Backend=${BACKEND_PLATFORM}, Frontend=${FRONTEND_PLATFORM}${NC}"
    exit 1
fi

# Success Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ All Tests Passed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Backend:  ${BACKEND_IMAGE}:${VERSION}"
echo -e "Frontend: ${FRONTEND_IMAGE}:${VERSION}"
echo -e ""
echo -e "Images are ready to push to ECR:"
echo -e "  ${ECR_REGISTRY}/${BACKEND_IMAGE}:${VERSION}"
echo -e "  ${ECR_REGISTRY}/${FRONTEND_IMAGE}:${VERSION}"
echo ""

exit 0
