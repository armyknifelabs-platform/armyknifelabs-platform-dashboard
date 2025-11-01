#!/bin/bash
# Stop SSM tunnel to AWS RDS PostgreSQL

TUNNEL_PID_FILE="/tmp/rds-tunnel.pid"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🛑 Stopping RDS PostgreSQL Tunnel${NC}"
echo ""

if [ -f "$TUNNEL_PID_FILE" ]; then
    PID=$(cat "$TUNNEL_PID_FILE")

    if ps -p "$PID" > /dev/null 2>&1; then
        echo "  Killing tunnel process (PID: $PID)..."
        kill "$PID" 2>/dev/null || kill -9 "$PID" 2>/dev/null

        # Wait a moment for process to die
        sleep 2

        if ps -p "$PID" > /dev/null 2>&1; then
            echo -e "${RED}  ❌ Failed to stop tunnel${NC}"
            exit 1
        else
            echo -e "${GREEN}  ✅ Tunnel stopped${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠️  Tunnel not running (stale PID file)${NC}"
    fi

    rm -f "$TUNNEL_PID_FILE"
else
    echo -e "${YELLOW}  ⚠️  No tunnel PID file found${NC}"

    # Check if any process is using port 5432
    if lsof -Pi :5432 -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo ""
        echo "Process using port 5432:"
        lsof -Pi :5432 -sTCP:LISTEN
        echo ""
        echo "Kill it with: lsof -ti:5432 | xargs kill -9"
    fi
fi

echo ""
