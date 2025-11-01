#!/bin/bash

##
# Docker Build & Test Script
# Tests production Docker images locally before deployment
##

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Docker Production Build & Test${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 1: Clean up existing containers
echo -e "${YELLOW}Step 1: Cleaning up existing containers...${NC}"
docker-compose down --volumes --remove-orphans 2>/dev/null || true
echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# Step 2: Build production images
echo -e "${YELLOW}Step 2: Building production Docker images...${NC}"
echo "  - Backend (Node 22.19.0, production build)"
echo "  - Frontend (Vite production build + Nginx)"
docker-compose build --no-cache
echo -e "${GREEN}✓ Build complete${NC}"
echo ""

# Step 3: Start containers
echo -e "${YELLOW}Step 3: Starting containers...${NC}"
docker-compose up -d
echo -e "${GREEN}✓ Containers started${NC}"
echo ""

# Step 4: Wait for health checks
echo -e "${YELLOW}Step 4: Waiting for health checks...${NC}"
echo "  Waiting 40 seconds for services to stabilize..."
sleep 40

# Check backend health
echo "  Checking backend health..."
BACKEND_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' seip-backend 2>/dev/null || echo "none")
if [ "$BACKEND_HEALTH" = "healthy" ]; then
    echo -e "${GREEN}  ✓ Backend is healthy${NC}"
else
    echo -e "${RED}  ✗ Backend health check failed (status: $BACKEND_HEALTH)${NC}"
    echo "  Showing backend logs:"
    docker logs seip-backend --tail 50
    exit 1
fi

# Check frontend health
echo "  Checking frontend health..."
FRONTEND_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' seip-frontend 2>/dev/null || echo "none")
if [ "$FRONTEND_HEALTH" = "healthy" ]; then
    echo -e "${GREEN}  ✓ Frontend is healthy${NC}"
else
    echo -e "${RED}  ✗ Frontend health check failed (status: $FRONTEND_HEALTH)${NC}"
    echo "  Showing frontend logs:"
    docker logs seip-frontend --tail 50
    exit 1
fi

echo ""

# Step 5: Run smoke tests
echo -e "${YELLOW}Step 5: Running smoke tests...${NC}"

# Test backend API health
echo "  Testing backend API..."
BACKEND_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/api/v1/health || echo "000")
if [ "$BACKEND_RESPONSE" = "200" ]; then
    echo -e "${GREEN}  ✓ Backend API responding (HTTP 200)${NC}"
else
    echo -e "${RED}  ✗ Backend API failed (HTTP $BACKEND_RESPONSE)${NC}"
    exit 1
fi

# Test frontend
echo "  Testing frontend..."
FRONTEND_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80 || echo "000")
if [ "$FRONTEND_RESPONSE" = "200" ]; then
    echo -e "${GREEN}  ✓ Frontend responding (HTTP 200)${NC}"
else
    echo -e "${RED}  ✗ Frontend failed (HTTP $FRONTEND_RESPONSE)${NC}"
    exit 1
fi

# Test database connection
echo "  Testing database connection..."
docker exec seip-backend node -e "
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});
pool.query('SELECT 1')
  .then(() => { console.log('Database connected'); process.exit(0); })
  .catch((err) => { console.error('Database error:', err.message); process.exit(1); });
" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Database connection successful${NC}"
else
    echo -e "${RED}  ✗ Database connection failed${NC}"
    exit 1
fi

# Test Redis connection
echo "  Testing Redis connection..."
docker exec seip-backend node -e "
const redis = require('redis');
const client = redis.createClient({
  url: 'redis://' + process.env.REDIS_HOST + ':6379'
});
client.connect()
  .then(() => client.ping())
  .then(() => { console.log('Redis connected'); process.exit(0); })
  .catch((err) => { console.error('Redis error:', err.message); process.exit(1); })
  .finally(() => client.quit());
" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Redis connection successful${NC}"
else
    echo -e "${RED}  ✗ Redis connection failed${NC}"
    exit 1
fi

echo ""

# Step 6: Display status
echo -e "${YELLOW}Step 6: Container status${NC}"
docker ps --filter "name=seip-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Success message
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ All tests passed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Production containers are running:"
echo "  - Frontend: http://localhost:80"
echo "  - Backend:  http://localhost:3001"
echo ""
echo "View logs:"
echo "  docker logs seip-backend -f"
echo "  docker logs seip-frontend -f"
echo ""
echo "Stop containers:"
echo "  docker-compose down"
echo ""
echo -e "${YELLOW}Ready to deploy!${NC}"
