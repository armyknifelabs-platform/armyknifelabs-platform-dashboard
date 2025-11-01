#!/bin/bash
# SSM Port Forwarding to AWS ElastiCache
# This script sets up a secure tunnel to ElastiCache via AWS Systems Manager

set -e

# Add ~/bin to PATH for session-manager-plugin
export PATH="$HOME/bin:$PATH"

# Configuration
EC2_INSTANCE_ID="i-095c2af65a008ec32"
ELASTICACHE_ENDPOINT="seip-redis.rbzg8e.0001.use1.cache.amazonaws.com"
REDIS_PORT="6379"
LOCAL_PORT="6379"
AWS_REGION="us-east-1"

echo "🔐 Setting up SSM port forwarding to ElastiCache..."
echo ""
echo "Configuration:"
echo "  EC2 Instance:      $EC2_INSTANCE_ID"
echo "  ElastiCache:       $ELASTICACHE_ENDPOINT"
echo "  Remote Port:       $REDIS_PORT"
echo "  Local Port:        $LOCAL_PORT"
echo "  AWS Region:        $AWS_REGION"
echo ""

# Check if Session Manager plugin is installed
if ! command -v session-manager-plugin &> /dev/null; then
    echo "❌ Error: AWS Session Manager plugin is not installed"
    echo ""
    echo "Install it from:"
    echo "  https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
    echo ""
    echo "macOS: brew install --cask session-manager-plugin"
    echo "Linux: Download from AWS documentation"
    exit 1
fi

# Check if instance is registered with SSM
echo "🔍 Checking if EC2 instance is registered with SSM..."
SSM_STATUS=$(aws ssm describe-instance-information \
    --region $AWS_REGION \
    --filters "Key=InstanceIds,Values=$EC2_INSTANCE_ID" \
    --query 'InstanceInformationList[0].PingStatus' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SSM_STATUS" != "Online" ]; then
    echo "❌ Error: EC2 instance is not registered with SSM or is offline"
    echo "   Status: $SSM_STATUS"
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Verify EC2 instance is running"
    echo "  2. Ensure IAM role 'SEIP-SSM-EC2-Role' is attached"
    echo "  3. Check SSM agent is installed and running on the instance"
    echo "  4. Wait 5-10 minutes after attaching IAM role"
    echo ""
    echo "To install SSM agent on EC2:"
    echo "  Amazon Linux 2:"
    echo "    sudo yum install -y amazon-ssm-agent"
    echo "    sudo systemctl enable amazon-ssm-agent"
    echo "    sudo systemctl start amazon-ssm-agent"
    echo ""
    echo "  Ubuntu:"
    echo "    sudo snap install amazon-ssm-agent --classic"
    echo "    sudo snap start amazon-ssm-agent"
    exit 1
fi

echo "✅ EC2 instance is registered with SSM (Status: $SSM_STATUS)"
echo ""
echo "🚀 Starting port forwarding session..."
echo ""
echo "Once connected, you can access ElastiCache at: localhost:$LOCAL_PORT"
echo ""
echo "Press Ctrl+C to stop the tunnel"
echo ""

# Start SSM port forwarding session
aws ssm start-session \
    --target $EC2_INSTANCE_ID \
    --region $AWS_REGION \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{
        \"host\":[\"$ELASTICACHE_ENDPOINT\"],
        \"portNumber\":[\"$REDIS_PORT\"],
        \"localPortNumber\":[\"$LOCAL_PORT\"]
    }"

echo ""
echo "✅ Tunnel closed"
