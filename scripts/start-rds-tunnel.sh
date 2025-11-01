#!/bin/bash
# Start SSM tunnel to AWS RDS PostgreSQL
# This creates a tunnel from localhost:5432 to RDS through an EC2 bastion

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TUNNEL_PID_FILE="/tmp/rds-tunnel.pid"
TUNNEL_LOG_FILE="/tmp/rds-tunnel.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting RDS PostgreSQL Tunnel${NC}"
echo ""

# Configuration
EC2_INSTANCE_ID="i-095c2af65a008ec32"  # Same bastion as ElastiCache
RDS_ENDPOINT="ai-orchestration-db.cmn4wqs645sa.us-east-1.rds.amazonaws.com"
RDS_PORT="5432"
LOCAL_PORT="15432"  # Use non-standard port to avoid conflicts
AWS_REGION="us-east-1"

echo "Configuration:"
echo "  EC2 Instance:      $EC2_INSTANCE_ID"
echo "  RDS Endpoint:      $RDS_ENDPOINT"
echo "  Remote Port:       $RDS_PORT"
echo "  Local Port:        $LOCAL_PORT"
echo "  AWS Region:        $AWS_REGION"
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
else
    echo "  ✅ AWS CLI configured"
fi

# Step 2: Check if tunnel is already running
echo ""
echo -e "${BLUE}Step 2: Checking for existing tunnel...${NC}"

if [ -f "$TUNNEL_PID_FILE" ]; then
    OLD_PID=$(cat "$TUNNEL_PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo -e "${YELLOW}  ⚠️  Tunnel already running (PID: $OLD_PID)${NC}"
        echo "  Stop it with: kill $OLD_PID"
        exit 1
    else
        echo "  🧹 Removing stale PID file"
        rm -f "$TUNNEL_PID_FILE"
    fi
fi

# Check if port is already in use
if lsof -Pi :$LOCAL_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${RED}  ❌ Port $LOCAL_PORT is already in use${NC}"
    echo ""
    echo "Process using the port:"
    lsof -Pi :$LOCAL_PORT -sTCP:LISTEN
    echo ""
    echo "Kill it with: lsof -ti:$LOCAL_PORT | xargs kill -9"
    exit 1
else
    echo "  ✅ Port $LOCAL_PORT is available"
fi

# Step 3: Check if EC2 instance is registered with SSM
echo ""
echo -e "${BLUE}Step 3: Checking if EC2 instance is registered with SSM...${NC}"

SSM_STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$EC2_INSTANCE_ID" \
    --region "$AWS_REGION" \
    --query 'InstanceInformationList[0].PingStatus' \
    --output text 2>/dev/null || echo "NotFound")

if [ "$SSM_STATUS" != "Online" ]; then
    echo -e "${RED}  ❌ EC2 instance is not registered with SSM or not online${NC}"
    echo "  Status: $SSM_STATUS"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check if EC2 instance is running"
    echo "  2. Verify SSM agent is installed and running on the EC2 instance"
    echo "  3. Ensure the instance has the AmazonSSMManagedInstanceCore IAM role"
    exit 1
else
    echo "  ✅ EC2 instance is registered with SSM (Status: $SSM_STATUS)"
fi

# Step 4: Start the tunnel
echo ""
echo -e "${BLUE}Step 4: Starting port forwarding session...${NC}"
echo ""
echo "Once connected, you can access RDS at: localhost:$LOCAL_PORT"
echo ""
echo "Example connection:"
echo "  psql -h localhost -U postgres -d ai_orchestration"
echo ""
echo "Press Ctrl+C to stop the tunnel"
echo ""

# Start the tunnel in the background and save PID
aws ssm start-session \
    --target "$EC2_INSTANCE_ID" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$RDS_ENDPOINT\"],\"portNumber\":[\"$RDS_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
    --region "$AWS_REGION" \
    > "$TUNNEL_LOG_FILE" 2>&1 &

TUNNEL_PID=$!
echo "$TUNNEL_PID" > "$TUNNEL_PID_FILE"

echo -e "${GREEN}✅ Tunnel started (PID: $TUNNEL_PID)${NC}"
echo ""
echo "Logs: tail -f $TUNNEL_LOG_FILE"
echo "Stop: kill $TUNNEL_PID"
echo ""

# Wait for the tunnel process
wait "$TUNNEL_PID"
