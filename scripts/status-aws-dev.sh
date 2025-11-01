#!/bin/bash
# Check status of AWS development environment

TUNNEL_PID_FILE="/tmp/ssm-tunnel.pid"
BACKEND_PID_FILE="/tmp/backend-aws.pid"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📊 AWS Development Environment Status${NC}"
echo ""

# Check SSM Tunnel
echo -e "${BLUE}SSM Tunnel:${NC}"
if [ -f "$TUNNEL_PID_FILE" ]; then
    TUNNEL_PID=$(cat "$TUNNEL_PID_FILE")
    if ps -p $TUNNEL_PID &> /dev/null; then
        echo -e "  ${GREEN}✅ Running${NC} (PID: $TUNNEL_PID)"
        if lsof -i :6379 | grep -q LISTEN; then
            echo "  ${GREEN}✅ Port 6379 listening${NC}"
        else
            echo -e "  ${YELLOW}⚠️  Port 6379 not listening${NC}"
        fi

        # Check tunnel log for session ID
        if [ -f "/tmp/ssm-tunnel.log" ]; then
            SESSION_ID=$(grep "Starting session with SessionId:" /tmp/ssm-tunnel.log | tail -1 | awk '{print $NF}')
            if [ -n "$SESSION_ID" ]; then
                echo "  📡 Session: $SESSION_ID"
            fi
        fi
    else
        echo -e "  ${RED}❌ Not running${NC} (stale PID file)"
    fi
else
    if pgrep -f "aws ssm start-session" > /dev/null; then
        TUNNEL_PID=$(pgrep -f "aws ssm start-session" | head -1)
        echo -e "  ${YELLOW}⚠️  Running${NC} (PID: $TUNNEL_PID, no PID file)"
    else
        echo -e "  ${RED}❌ Not running${NC}"
    fi
fi

echo ""

# Check Backend
echo -e "${BLUE}Backend:${NC}"
if [ -f "$BACKEND_PID_FILE" ]; then
    BACKEND_PID=$(cat "$BACKEND_PID_FILE")
    if ps -p $BACKEND_PID &> /dev/null; then
        echo -e "  ${GREEN}✅ Running${NC} (PID: $BACKEND_PID)"

        # Check health endpoint
        if curl -s http://localhost:3001/health > /dev/null 2>&1; then
            HEALTH=$(curl -s http://localhost:3001/health | jq -r '.status' 2>/dev/null || echo "unknown")
            echo -e "  ${GREEN}✅ Health: $HEALTH${NC}"
        else
            echo -e "  ${RED}❌ Health check failed${NC}"
        fi
    else
        echo -e "  ${RED}❌ Not running${NC} (stale PID file)"
    fi
else
    if pgrep -f "pnpm dev" > /dev/null; then
        BACKEND_PID=$(pgrep -f "pnpm dev" | head -1)
        echo -e "  ${YELLOW}⚠️  Running${NC} (PID: $BACKEND_PID, no PID file)"
    else
        echo -e "  ${RED}❌ Not running${NC}"
    fi
fi

echo ""

# Check port usage
echo -e "${BLUE}Port Usage:${NC}"
if lsof -i :6379 &> /dev/null; then
    PORT_6379=$(lsof -i :6379 | grep LISTEN | awk '{print $1}' | head -1)
    echo "  Port 6379: $PORT_6379"
else
    echo -e "  Port 6379: ${RED}Not in use${NC}"
fi

if lsof -i :3001 &> /dev/null; then
    PORT_3001=$(lsof -i :3001 | grep LISTEN | awk '{print $1}' | head -1)
    echo "  Port 3001: $PORT_3001"
else
    echo -e "  Port 3001: ${RED}Not in use${NC}"
fi

echo ""

# Check log files
echo -e "${BLUE}Log Files:${NC}"
if [ -f "/tmp/ssm-tunnel.log" ]; then
    TUNNEL_LOG_SIZE=$(du -h /tmp/ssm-tunnel.log | awk '{print $1}')
    echo "  Tunnel log:  $TUNNEL_LOG_SIZE (/tmp/ssm-tunnel.log)"
else
    echo "  Tunnel log:  Not found"
fi

if [ -f "/tmp/backend-aws.log" ]; then
    BACKEND_LOG_SIZE=$(du -h /tmp/backend-aws.log | awk '{print $1}')
    echo "  Backend log: $BACKEND_LOG_SIZE (/tmp/backend-aws.log)"
else
    echo "  Backend log: Not found"
fi

echo ""

# Test connections
echo -e "${BLUE}Connection Tests:${NC}"

# Test ElastiCache via tunnel
if nc -z localhost 6379 2>/dev/null; then
    echo -e "  ${GREEN}✅ ElastiCache (via tunnel): Reachable${NC}"
else
    echo -e "  ${RED}❌ ElastiCache (via tunnel): Not reachable${NC}"
fi

# Test backend API
if curl -s http://localhost:3001/health > /dev/null 2>&1; then
    echo -e "  ${GREEN}✅ Backend API: Responding${NC}"
else
    echo -e "  ${RED}❌ Backend API: Not responding${NC}"
fi

echo ""

# Quick actions
echo -e "${BLUE}Quick Actions:${NC}"
echo "  View tunnel logs:  tail -f /tmp/ssm-tunnel.log"
echo "  View backend logs: tail -f /tmp/backend-aws.log"
echo "  Stop all:          pnpm aws:dev:stop"
echo "  Restart:           pnpm aws:dev:restart"
echo ""
