#!/bin/bash
# Start development environment with AWS RDS + ElastiCache
# This script manages both the SSM tunnel and the backend service

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TUNNEL_PID_FILE="/tmp/ssm-tunnel.pid"
BACKEND_PID_FILE="/tmp/backend-aws.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting AWS Development Environment${NC}"
echo ""

# Step 1: Check prerequisites
echo -e "${BLUE}Step 1: Checking prerequisites...${NC}"

# Check if session-manager-plugin is installed
if ! command -v session-manager-plugin &> /dev/null; then
    if [ -f "$HOME/bin/session-manager-plugin" ]; then
        export PATH="$HOME/bin:$PATH"
        echo "  ✅ Session Manager plugin found in ~/bin"
    else
        echo -e "${RED}  ❌ Session Manager plugin not found${NC}"
        echo ""
        echo "Install it with:"
        echo "  cd /tmp"
        echo "  curl -L 'https://session-manager-downloads.s3.amazonaws.com/plugin/latest/mac_arm64/sessionmanager-bundle.zip' -o sessionmanager-bundle.zip"
        echo "  unzip sessionmanager-bundle.zip"
        echo "  mkdir -p ~/bin"
        echo "  cp sessionmanager-bundle/bin/session-manager-plugin ~/bin/"
        echo "  chmod +x ~/bin/session-manager-plugin"
        exit 1
    fi
else
    echo "  ✅ Session Manager plugin installed"
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}  ❌ AWS CLI not configured${NC}"
    echo "  Run: aws configure"
    exit 1
fi
echo "  ✅ AWS CLI configured"

# Step 2: Stop conflicting services
echo ""
echo -e "${BLUE}Step 2: Stopping conflicting services...${NC}"

# Stop Homebrew Redis if running
if brew services list | grep redis | grep started &> /dev/null; then
    echo "  🛑 Stopping Homebrew Redis..."
    brew services stop redis &> /dev/null || true
    echo "  ✅ Homebrew Redis stopped"
else
    echo "  ✅ Homebrew Redis not running"
fi

# Stop Docker Redis if running
if docker ps | grep seip-redis &> /dev/null; then
    echo "  🛑 Stopping Docker Redis..."
    docker stop seip-redis &> /dev/null || true
    echo "  ✅ Docker Redis stopped"
else
    echo "  ✅ Docker Redis not running"
fi

# Stop local Redis processes
if lsof -i :6379 &> /dev/null; then
    echo "  ⚠️  Port 6379 still in use, attempting to free..."
    pkill -f redis-server 2>/dev/null || true
    sleep 2
fi

# Verify port is free
if lsof -i :6379 &> /dev/null; then
    echo -e "${RED}  ❌ Port 6379 is still in use. Cannot start tunnel.${NC}"
    echo "  Processes using port 6379:"
    lsof -i :6379
    exit 1
fi
echo "  ✅ Port 6379 is free"

# Step 3: Start SSM tunnel
echo ""
echo -e "${BLUE}Step 3: Starting SSM tunnel to ElastiCache...${NC}"

# Kill existing tunnel if running
if [ -f "$TUNNEL_PID_FILE" ]; then
    OLD_PID=$(cat "$TUNNEL_PID_FILE")
    if ps -p $OLD_PID &> /dev/null; then
        echo "  🛑 Stopping existing tunnel (PID: $OLD_PID)..."
        kill $OLD_PID 2>/dev/null || true
        sleep 2
    fi
    rm -f "$TUNNEL_PID_FILE"
fi

# Start tunnel in background
echo "  🔐 Starting SSM port forwarding..."
export PATH="$HOME/bin:$PATH"
cd "$PROJECT_ROOT"
nohup ./scripts/ssm-elasticache-tunnel.sh > /tmp/ssm-tunnel.log 2>&1 &
TUNNEL_PID=$!
echo $TUNNEL_PID > "$TUNNEL_PID_FILE"

# Wait for tunnel to establish
echo "  ⏳ Waiting for tunnel to establish (10 seconds)..."
sleep 10

# Check if tunnel is running
if ! ps -p $TUNNEL_PID &> /dev/null; then
    echo -e "${RED}  ❌ Tunnel failed to start${NC}"
    echo "  Check logs: tail -f /tmp/ssm-tunnel.log"
    exit 1
fi

# Check if port is listening
if ! lsof -i :6379 &> /dev/null; then
    echo -e "${YELLOW}  ⚠️  Tunnel started but port 6379 not listening yet${NC}"
    echo "  Waiting 5 more seconds..."
    sleep 5
fi

if grep -q "Port 6379 opened" /tmp/ssm-tunnel.log; then
    echo -e "  ${GREEN}✅ SSM tunnel active (PID: $TUNNEL_PID)${NC}"
else
    echo -e "${YELLOW}  ⚠️  Tunnel may still be connecting...${NC}"
    echo "  Monitor: tail -f /tmp/ssm-tunnel.log"
fi

# Step 4: Configure backend for AWS
echo ""
echo -e "${BLUE}Step 4: Configuring backend for AWS...${NC}"

cd "$PROJECT_ROOT/packages/backend"

# Switch to AWS configuration
if [ -f ".env.aws" ]; then
    if [ -f ".env" ]; then
        echo "  📦 Backing up current .env"
        cp .env .env.local.backup
    fi
    cp .env.aws .env
    echo "  ✅ Using AWS configuration"
else
    echo -e "${RED}  ❌ .env.aws not found${NC}"
    exit 1
fi

# Step 5: Start backend
echo ""
echo -e "${BLUE}Step 5: Starting backend...${NC}"

# Kill existing backend if running
if [ -f "$BACKEND_PID_FILE" ]; then
    OLD_PID=$(cat "$BACKEND_PID_FILE")
    if ps -p $OLD_PID &> /dev/null; then
        echo "  🛑 Stopping existing backend (PID: $OLD_PID)..."
        kill $OLD_PID 2>/dev/null || true
        sleep 2
    fi
    rm -f "$BACKEND_PID_FILE"
fi

# Stop Docker backend if running
if docker ps | grep seip-backend &> /dev/null; then
    echo "  🛑 Stopping Docker backend..."
    docker stop seip-backend &> /dev/null || true
fi

# Start backend
echo "  🚀 Starting backend with AWS infrastructure..."
export PATH="$HOME/bin:$PATH"
nohup pnpm dev > /tmp/backend-aws.log 2>&1 &
BACKEND_PID=$!
echo $BACKEND_PID > "$BACKEND_PID_FILE"

# Wait for backend to start
echo "  ⏳ Waiting for backend to start (15 seconds)..."
sleep 15

# Check if backend is running
if ! ps -p $BACKEND_PID &> /dev/null; then
    echo -e "${RED}  ❌ Backend failed to start${NC}"
    echo "  Check logs: tail -f /tmp/backend-aws.log"
    # Stop tunnel since backend failed
    kill $TUNNEL_PID 2>/dev/null || true
    exit 1
fi

# Check if backend is healthy
if curl -s http://localhost:3001/health > /dev/null 2>&1; then
    echo -e "  ${GREEN}✅ Backend running (PID: $BACKEND_PID)${NC}"
else
    echo -e "${YELLOW}  ⚠️  Backend started but health check failed${NC}"
    echo "  Monitor: tail -f /tmp/backend-aws.log"
fi

# Step 6: Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ AWS Development Environment Running!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Services:${NC}"
echo "  🔐 SSM Tunnel:    PID $TUNNEL_PID (localhost:6379 → ElastiCache)"
echo "  🚀 Backend:       PID $BACKEND_PID (http://localhost:3001)"
echo ""
echo -e "${BLUE}Infrastructure:${NC}"
echo "  📊 Database:      AWS RDS (ai-orchestration-db)"
echo "  🗄️  Cache:         AWS ElastiCache (seip-redis) via tunnel"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "  Status:           pnpm aws:dev:status"
echo "  Backend logs:     tail -f /tmp/backend-aws.log"
echo "  Tunnel logs:      tail -f /tmp/ssm-tunnel.log"
echo "  Stop all:         pnpm aws:dev:stop"
echo "  Restart:          pnpm aws:dev:restart"
echo ""
echo -e "${BLUE}Endpoints:${NC}"
echo "  Backend API:      http://localhost:3001"
echo "  Health Check:     http://localhost:3001/health"
echo ""
echo -e "${YELLOW}Note:${NC} Keep this terminal session active or run in background"
echo ""
