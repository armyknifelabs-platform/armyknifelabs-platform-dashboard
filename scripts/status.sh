#!/bin/bash

# AI Performance Dashboard - Service Status
# This script checks the status of all services

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if a service is running on a port
check_port() {
  local port=$1
  lsof -i :"$port" -t >/dev/null 2>&1
}

# Function to get PID for a port
get_pid() {
  local port=$1
  lsof -i :"$port" -t 2>/dev/null | head -n 1
}

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  AI Performance Dashboard - Service Status${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check PostgreSQL
echo -n "PostgreSQL (5432):  "
if check_port 5432; then
  PID=$(get_pid 5432)
  echo -e "${GREEN}● Running${NC} (PID: $PID)"
else
  echo -e "${RED}○ Stopped${NC}"
fi

# Check Redis
echo -n "Redis (6379):       "
if check_port 6379; then
  PID=$(get_pid 6379)
  echo -e "${GREEN}● Running${NC} (PID: $PID)"
else
  echo -e "${RED}○ Stopped${NC}"
fi

# Check Backend
echo -n "Backend (3001):     "
if check_port 3001; then
  PID=$(get_pid 3001)
  echo -e "${GREEN}● Running${NC} (PID: $PID)"

  # Test health endpoint
  HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/api/v1/health 2>/dev/null)
  if [ "$HEALTH_STATUS" == "200" ]; then
    echo -e "  ${GREEN}→ Health check: OK${NC}"
  else
    echo -e "  ${YELLOW}→ Health check: Failed (HTTP $HEALTH_STATUS)${NC}"
  fi
else
  echo -e "${RED}○ Stopped${NC}"
fi

# Check Frontend
echo -n "Frontend (5173):    "
if check_port 5173; then
  PID=$(get_pid 5173)
  echo -e "${GREEN}● Running${NC} (PID: $PID)"
else
  echo -e "${RED}○ Stopped${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Service URLs (only show if services are running)
if check_port 5173 || check_port 3001; then
  echo ""
  echo "📊 Service URLs:"
  if check_port 5173; then
    echo "  • Frontend:  http://localhost:5173"
  fi
  if check_port 3001; then
    echo "  • Backend:   http://localhost:3001"
    echo "  • Health:    http://localhost:3001/api/v1/health"
  fi
fi

# Show logs if they exist
if [ -f "logs/backend.log" ] || [ -f "logs/frontend.log" ]; then
  echo ""
  echo "📁 Log Files:"
  if [ -f "logs/backend.log" ]; then
    LOG_SIZE=$(du -h logs/backend.log | cut -f1)
    echo "  • Backend:   logs/backend.log ($LOG_SIZE)"
  fi
  if [ -f "logs/frontend.log" ]; then
    LOG_SIZE=$(du -h logs/frontend.log | cut -f1)
    echo "  • Frontend:  logs/frontend.log ($LOG_SIZE)"
  fi
fi

echo ""
