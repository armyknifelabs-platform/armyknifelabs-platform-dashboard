#!/bin/bash
# Stop AWS development environment (tunnel + backend)

set -e

TUNNEL_PID_FILE="/tmp/ssm-tunnel.pid"
BACKEND_PID_FILE="/tmp/backend-aws.pid"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🛑 Stopping AWS Development Environment${NC}"
echo ""

# Stop backend
if [ -f "$BACKEND_PID_FILE" ]; then
    BACKEND_PID=$(cat "$BACKEND_PID_FILE")
    if ps -p $BACKEND_PID &> /dev/null; then
        echo "  🛑 Stopping backend (PID: $BACKEND_PID)..."
        kill $BACKEND_PID 2>/dev/null || true
        sleep 2
        if ps -p $BACKEND_PID &> /dev/null; then
            kill -9 $BACKEND_PID 2>/dev/null || true
        fi
        echo -e "  ${GREEN}✅ Backend stopped${NC}"
    else
        echo "  ℹ️  Backend not running"
    fi
    rm -f "$BACKEND_PID_FILE"
else
    # Try to find and kill pnpm dev process
    if pgrep -f "pnpm dev" > /dev/null; then
        echo "  🛑 Stopping backend processes..."
        pkill -f "pnpm dev" || true
        echo -e "  ${GREEN}✅ Backend stopped${NC}"
    else
        echo "  ℹ️  Backend not running"
    fi
fi

# Stop SSM tunnel
if [ -f "$TUNNEL_PID_FILE" ]; then
    TUNNEL_PID=$(cat "$TUNNEL_PID_FILE")
    if ps -p $TUNNEL_PID &> /dev/null; then
        echo "  🛑 Stopping SSM tunnel (PID: $TUNNEL_PID)..."
        kill $TUNNEL_PID 2>/dev/null || true
        sleep 2
        if ps -p $TUNNEL_PID &> /dev/null; then
            kill -9 $TUNNEL_PID 2>/dev/null || true
        fi
        echo -e "  ${GREEN}✅ SSM tunnel stopped${NC}"
    else
        echo "  ℹ️  SSM tunnel not running"
    fi
    rm -f "$TUNNEL_PID_FILE"
else
    # Try to find and kill SSM session
    if pgrep -f "aws ssm start-session" > /dev/null; then
        echo "  🛑 Stopping SSM tunnel..."
        pkill -f "aws ssm start-session" || true
        echo -e "  ${GREEN}✅ SSM tunnel stopped${NC}"
    else
        echo "  ℹ️  SSM tunnel not running"
    fi
fi

# Clean up log files (optional)
if [ "$1" == "--clean-logs" ]; then
    echo ""
    echo "  🗑️  Cleaning log files..."
    rm -f /tmp/ssm-tunnel.log
    rm -f /tmp/backend-aws.log
    echo -e "  ${GREEN}✅ Logs cleaned${NC}"
fi

echo ""
echo -e "${GREEN}✅ AWS Development Environment Stopped${NC}"
echo ""
