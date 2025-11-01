#!/bin/bash
# Deploy Dashboard Frontend to AWS ECS
# Version: v2.18.0-dashboard-integration
# Domain: dashboard.armyknifelabs.com

set -e  # Exit on error

# Configuration
VERSION="v2.18.0-dashboard-integration"
REGION="us-east-1"
# Get AWS account ID dynamically
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="dashboard-frontend"
IMAGE_TAG="$VERSION"
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO"

# Infrastructure
VPC_ID="vpc-056f04c0582933d14"
PRIVATE_SUBNET_1="subnet-0cd198aa66be909d1"  # us-east-1a
PRIVATE_SUBNET_2="subnet-037c04a1c2ebf8628"  # us-east-1b
PUBLIC_SUBNET_1="subnet-011f9abcd75f3e21a"   # us-east-1a
PUBLIC_SUBNET_2="subnet-07506579b21f4c22c"   # us-east-1b
ALB_ARN="arn:aws:elasticloadbalancing:us-east-1:${AWS_ACCOUNT_ID}:loadbalancer/app/ai-orchestration-alb/cfaab8b3ea3c622c"
CERTIFICATE_ARN="arn:aws:acm:us-east-1:${AWS_ACCOUNT_ID}:certificate/2981b3b1-a9a1-4561-9276-813d62c0fd95"
ECS_CLUSTER="seip-prod"
HOSTED_ZONE_ID="Z00997282G6IUTMY40WE0"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Dashboard Deployment to AWS ECS${NC}"
echo -e "${BLUE}Version: $VERSION${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Step 1: Push Docker image to ECR
echo -e "${GREEN}[1/8] Pushing Docker image to ECR...${NC}"

# Check if image exists locally
if ! docker images | grep -q "dashboard-frontend.*$VERSION"; then
    echo -e "${RED}Error: Docker image not found locally. Please build first:${NC}"
    echo "DOCKER_DEFAULT_PLATFORM=linux/amd64 docker build -f Dockerfile.frontend -t dashboard-frontend:$VERSION --build-arg APP_VERSION=$VERSION --build-arg NGINX_CONFIG=nginx.production.conf ."
    exit 1
fi

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

# Tag and push
echo "Tagging image..."
docker tag dashboard-frontend:$VERSION $ECR_URI:$IMAGE_TAG
docker tag dashboard-frontend:$VERSION $ECR_URI:latest

echo "Pushing to ECR..."
docker push $ECR_URI:$IMAGE_TAG
docker push $ECR_URI:latest

echo -e "${GREEN}✓ Image pushed to ECR${NC}"
echo ""

# Step 2: Create Target Group
echo -e "${GREEN}[2/8] Creating Target Group...${NC}"

TG_ARN=$(aws elbv2 create-target-group \
    --name dashboard-frontend-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path / \
    --health-check-protocol HTTP \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 10 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --region $REGION \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || \
    aws elbv2 describe-target-groups \
        --names dashboard-frontend-tg \
        --region $REGION \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text)

echo "Target Group ARN: $TG_ARN"
echo -e "${GREEN}✓ Target Group created/found${NC}"
echo ""

# Step 3: Add HTTPS Listener Rule
echo -e "${GREEN}[3/8] Adding HTTPS Listener Rule...${NC}"

HTTPS_LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn $ALB_ARN \
    --region $REGION \
    --query 'Listeners[?Port==`443`].ListenerArn' \
    --output text)

echo "HTTPS Listener ARN: $HTTPS_LISTENER_ARN"

# Add rule with priority 10
aws elbv2 create-rule \
    --listener-arn $HTTPS_LISTENER_ARN \
    --priority 10 \
    --conditions Field=host-header,Values=dashboard.armyknifelabs.com \
    --actions Type=forward,TargetGroupArn=$TG_ARN \
    --region $REGION \
    --output text 2>/dev/null || echo "Rule may already exist"

echo -e "${GREEN}✓ HTTPS Listener Rule created${NC}"
echo ""

# Step 4: Add HTTP Listener Rule (redirect to HTTPS)
echo -e "${GREEN}[4/8] Adding HTTP Listener Rule (redirect)...${NC}"

HTTP_LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn $ALB_ARN \
    --region $REGION \
    --query 'Listeners[?Port==`80`].ListenerArn' \
    --output text)

echo "HTTP Listener ARN: $HTTP_LISTENER_ARN"

# Add redirect rule
aws elbv2 create-rule \
    --listener-arn $HTTP_LISTENER_ARN \
    --priority 10 \
    --conditions Field=host-header,Values=dashboard.armyknifelabs.com \
    --actions Type=redirect,RedirectConfig="{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}" \
    --region $REGION \
    --output text 2>/dev/null || echo "Rule may already exist"

echo -e "${GREEN}✓ HTTP Listener Rule created${NC}"
echo ""

# Step 5: Get Security Group (reuse from existing service)
echo -e "${GREEN}[5/8] Getting Security Group...${NC}"

SECURITY_GROUP=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=*frontend*" \
    --region $REGION \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || \
    aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --region $REGION \
        --query 'SecurityGroups[0].GroupId' \
        --output text)

echo "Security Group: $SECURITY_GROUP"
echo -e "${GREEN}✓ Security Group found${NC}"
echo ""

# Step 6: Register ECS Task Definition
echo -e "${GREEN}[6/8] Registering ECS Task Definition...${NC}"

cat > /tmp/dashboard-task-def.json <<EOF
{
  "family": "dashboard-frontend",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::$AWS_ACCOUNT_ID:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "dashboard-frontend",
      "image": "$ECR_URI:$IMAGE_TAG",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "VITE_API_BASE_URL",
          "value": ""
        },
        {
          "name": "VITE_API_URL",
          "value": "/api/v1"
        },
        {
          "name": "VITE_USE_MOCK_DATA",
          "value": "false"
        },
        {
          "name": "VITE_APP_VERSION",
          "value": "$VERSION"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/dashboard-frontend",
          "awslogs-region": "$REGION",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:80/ || exit 1"],
        "interval": 30,
        "timeout": 10,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

# Create CloudWatch log group if it doesn't exist
aws logs create-log-group --log-group-name /ecs/dashboard-frontend --region $REGION 2>/dev/null || true
aws logs put-retention-policy --log-group-name /ecs/dashboard-frontend --retention-in-days 7 --region $REGION 2>/dev/null || true

# Register task definition
TASK_DEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json file:///tmp/dashboard-task-def.json \
    --region $REGION \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "Task Definition ARN: $TASK_DEF_ARN"
echo -e "${GREEN}✓ Task Definition registered${NC}"
echo ""

# Step 7: Create ECS Service
echo -e "${GREEN}[7/8] Creating ECS Service...${NC}"

aws ecs create-service \
    --cluster $ECS_CLUSTER \
    --service-name dashboard-frontend \
    --task-definition dashboard-frontend \
    --desired-count 2 \
    --launch-type FARGATE \
    --platform-version LATEST \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
    --load-balancers "targetGroupArn=$TG_ARN,containerName=dashboard-frontend,containerPort=80" \
    --health-check-grace-period-seconds 60 \
    --deployment-configuration "minimumHealthyPercent=100,maximumPercent=200" \
    --region $REGION \
    --output text 2>/dev/null || echo "Service may already exist"

echo -e "${GREEN}✓ ECS Service created${NC}"
echo ""

# Wait for service to stabilize
echo "Waiting for service to become healthy (this may take 2-3 minutes)..."
aws ecs wait services-stable --cluster $ECS_CLUSTER --services dashboard-frontend --region $REGION

echo -e "${GREEN}✓ Service is stable${NC}"
echo ""

# Step 8: Create Route53 A Record
echo -e "${GREEN}[8/8] Creating Route53 A Record...${NC}"

ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --region $REGION \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

ALB_ZONE_ID=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --region $REGION \
    --query 'LoadBalancers[0].CanonicalHostedZoneId' \
    --output text)

cat > /tmp/route53-change.json <<EOF
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "dashboard.armyknifelabs.com",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "$ALB_ZONE_ID",
        "DNSName": "$ALB_DNS",
        "EvaluateTargetHealth": true
      }
    }
  }]
}
EOF

aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch file:///tmp/route53-change.json \
    --query 'ChangeInfo.Status' \
    --output text

echo -e "${GREEN}✓ Route53 A record created${NC}"
echo ""

# Cleanup
rm -f /tmp/dashboard-task-def.json /tmp/route53-change.json

echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}✓ Deployment Complete!${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "${YELLOW}Dashboard URL:${NC} https://dashboard.armyknifelabs.com"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Wait 2-3 minutes for DNS propagation"
echo "2. Test: curl https://dashboard.armyknifelabs.com/"
echo "3. Visit: https://dashboard.armyknifelabs.com/dashboard/overview"
echo "4. Monitor CloudWatch logs: /ecs/dashboard-frontend"
echo ""
echo -e "${BLUE}Monitoring Commands:${NC}"
echo "aws ecs describe-services --cluster $ECS_CLUSTER --services dashboard-frontend --region $REGION"
echo "aws logs tail /ecs/dashboard-frontend --follow --region $REGION"
echo ""
