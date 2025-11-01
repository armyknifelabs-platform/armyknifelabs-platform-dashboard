#!/bin/bash

# AI Performance Dashboard - Stop All Services
# This script gracefully stops Backend, Frontend, and optionally PostgreSQL and Redis

set -e

echo "🛑 Stopping AI Performance Dashboard..."
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

# Function to gracefully kill a process
kill_process() {
  local pid=$1
  local name=$2

  if kill -0 "$pid" 2>/dev/null; then
    echo "  Sending SIGTERM to $name (PID: $pid)..."
    kill -TERM "$pid" 2>/dev/null || true

    # Wait up to 10 seconds for graceful shutdown
    local wait_count=0
    while kill -0 "$pid" 2>/dev/null && [ $wait_count -lt 10 ]; do
      sleep 1
      wait_count=$((wait_count + 1))
    done

    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
      echo "  Sending SIGKILL to $name (PID: $pid)..."
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
}

# 1. Stop Frontend
echo -e "${YELLOW}[1/4]${NC} Stopping Frontend..."
if [ -f "logs/frontend.pid" ]; then
  FRONTEND_PID=$(cat logs/frontend.pid)
  kill_process "$FRONTEND_PID" "Frontend"
  rm -f logs/frontend.pid
  echo -e "  ${GREEN}✓ Frontend stopped${NC}"
elif check_port 5173; then
  echo "  Killing process on port 5173..."
  lsof -i :5173 -t | xargs kill -9 2>/dev/null || true
  echo -e "  ${GREEN}✓ Frontend stopped${NC}"
else
  echo -e "  ${GREEN}✓ Frontend not running${NC}"
fi
echo ""

# 2. Stop Backend
echo -e "${YELLOW}[2/4]${NC} Stopping Backend..."
if [ -f "logs/backend.pid" ]; then
  BACKEND_PID=$(cat logs/backend.pid)
  kill_process "$BACKEND_PID" "Backend"
  rm -f logs/backend.pid
  echo -e "  ${GREEN}✓ Backend stopped${NC}"
elif check_port 3001; then
  echo "  Killing process on port 3001..."
  lsof -i :3001 -t | xargs kill -9 2>/dev/null || true
  echo -e "  ${GREEN}✓ Backend stopped${NC}"
else
  echo -e "  ${GREEN}✓ Backend not running${NC}"
fi
echo ""

# 3. Ask about Redis
echo -e "${YELLOW}[3/4]${NC} Redis..."
if check_port 6379; then
  read -p "  Stop Redis? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    brew services stop redis >/dev/null 2>&1
    echo -e "  ${GREEN}✓ Redis stopped${NC}"
  else
    echo -e "  ${YELLOW}⊘ Redis left running${NC}"
  fi
else
  echo -e "  ${GREEN}✓ Redis not running${NC}"
fi
echo ""

# 4. Ask about PostgreSQL
echo -e "${YELLOW}[4/4]${NC} PostgreSQL..."
if check_port 5432; then
  read -p "  Stop PostgreSQL? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    brew services stop postgresql@14 >/dev/null 2>&1 || brew services stop postgresql >/dev/null 2>&1
    echo -e "  ${GREEN}✓ PostgreSQL stopped${NC}"
  else
    echo -e "  ${YELLOW}⊘ PostgreSQL left running${NC}"
  fi
else
  echo -e "  ${GREEN}✓ PostgreSQL not running${NC}"
fi
echo ""

# Summary
echo -e "${GREEN}✨ Services stopped successfully!${NC}"
echo ""
