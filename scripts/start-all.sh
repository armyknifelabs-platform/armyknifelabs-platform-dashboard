#!/bin/bash

# AI Performance Dashboard - Start All Services
# This script starts PostgreSQL, Redis, Backend, and Frontend

set -e

echo "🚀 Starting AI Performance Dashboard..."
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check if a service is running on a port
check_port() {
  local port=$1
  lsof -i :"$port" -t >/dev/null 2>&1
}

# Function to wait for a service to be ready
wait_for_service() {
  local service=$1
  local port=$2
  local max_wait=30
  local wait_count=0

  echo -n "Waiting for $service to be ready..."
  while ! check_port "$port" && [ $wait_count -lt $max_wait ]; do
    sleep 1
    wait_count=$((wait_count + 1))
    echo -n "."
  done

  if [ $wait_count -ge $max_wait ]; then
    echo -e " ${RED}✗ Failed${NC}"
    return 1
  else
    echo -e " ${GREEN}✓ Ready${NC}"
    return 0
  fi
}

# 1. Start PostgreSQL
echo -e "${YELLOW}[1/4]${NC} Starting PostgreSQL..."
if check_port 5432; then
  echo -e "  ${GREEN}✓ PostgreSQL already running${NC}"
else
  brew services start postgresql@14 >/dev/null 2>&1 || brew services start postgresql >/dev/null 2>&1
  if wait_for_service "PostgreSQL" 5432; then
    echo -e "  ${GREEN}✓ PostgreSQL started${NC}"
  else
    echo -e "  ${RED}✗ Failed to start PostgreSQL${NC}"
    exit 1
  fi
fi
echo ""

# 2. Start Redis
echo -e "${YELLOW}[2/4]${NC} Starting Redis..."
if check_port 6379; then
  echo -e "  ${GREEN}✓ Redis already running${NC}"
else
  brew services start redis >/dev/null 2>&1
  if wait_for_service "Redis" 6379; then
    echo -e "  ${GREEN}✓ Redis started${NC}"
  else
    echo -e "  ${RED}✗ Failed to start Redis${NC}"
    exit 1
  fi
fi
echo ""

# 3. Start Backend
echo -e "${YELLOW}[3/4]${NC} Starting Backend API..."
if check_port 3001; then
  echo -e "  ${YELLOW}⚠ Port 3001 already in use, killing existing process...${NC}"
  lsof -i :3001 -t | xargs kill -9 2>/dev/null || true
  sleep 2
fi

cd "$(dirname "$0")/../packages/backend"
echo "  Starting backend server..."
pnpm dev > ../../logs/backend.log 2>&1 &
BACKEND_PID=$!
echo $BACKEND_PID > ../../logs/backend.pid

if wait_for_service "Backend" 3001; then
  echo -e "  ${GREEN}✓ Backend started (PID: $BACKEND_PID)${NC}"
  echo -e "  ${GREEN}→ Logs: logs/backend.log${NC}"
else
  echo -e "  ${RED}✗ Failed to start Backend${NC}"
  exit 1
fi
echo ""

# 4. Start Frontend
echo -e "${YELLOW}[4/4]${NC} Starting Frontend..."
if check_port 5173; then
  echo -e "  ${YELLOW}⚠ Port 5173 already in use, killing existing process...${NC}"
  lsof -i :5173 -t | xargs kill -9 2>/dev/null || true
  sleep 2
fi

cd "$(dirname "$0")/../packages/frontend"
echo "  Starting frontend server..."
pnpm dev > ../../logs/frontend.log 2>&1 &
FRONTEND_PID=$!
echo $FRONTEND_PID > ../../logs/frontend.pid

if wait_for_service "Frontend" 5173; then
  echo -e "  ${GREEN}✓ Frontend started (PID: $FRONTEND_PID)${NC}"
  echo -e "  ${GREEN}→ Logs: logs/frontend.log${NC}"
else
  echo -e "  ${RED}✗ Failed to start Frontend${NC}"
  exit 1
fi
echo ""

# Summary
echo -e "${GREEN}✨ All services started successfully!${NC}"
echo ""
echo "📊 Service URLs:"
echo "  • Frontend:  http://localhost:5173"
echo "  • Backend:   http://localhost:3001"
echo "  • Health:    http://localhost:3001/api/v1/health"
echo ""
echo "📁 Log Files:"
echo "  • Backend:   logs/backend.log"
echo "  • Frontend:  logs/frontend.log"
echo ""
echo "🛑 To stop all services, run: pnpm stop-all"
echo ""
