#!/bin/bash
set -e

# Deploy SEIP (Software Engineering Intelligence Platform) to AWS ECS Fargate
# Domain: seip.armyknifeplatform.com

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-YOUR_ACCOUNT_ID}"
CLUSTER_NAME="seip-cluster"
DOMAIN_NAME="seip.armyknifeplatform.com"

# Service names
BACKEND_SERVICE="seip-backend"
FRONTEND_SERVICE="seip-frontend"
WORKER_SERVICE="seip-worker"

# Task definition families
BACKEND_TASK="seip-backend"
FRONTEND_TASK="seip-frontend"
WORKER_TASK="seip-worker"

# ECR repository names
BACKEND_ECR="seip/backend"
FRONTEND_ECR="seip/frontend"
WORKER_ECR="seip/worker"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Deploying SEIP to AWS ECS Fargate${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Region:  ${GREEN}$AWS_REGION${NC}"
echo -e "Cluster: ${GREEN}$CLUSTER_NAME${NC}"
echo -e "Domain:  ${GREEN}$DOMAIN_NAME${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not installed. Please install it first.${NC}"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured. Run 'aws configure' first.${NC}"
    exit 1
fi

# Get actual AWS account ID
ACTUAL_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ "$AWS_ACCOUNT_ID" == "YOUR_ACCOUNT_ID" ]; then
    AWS_ACCOUNT_ID=$ACTUAL_ACCOUNT_ID
fi

echo -e "${GREEN}✅ AWS credentials configured (Account: $AWS_ACCOUNT_ID)${NC}"
echo ""

# Step 1: Create ECR repositories if they don't exist
echo -e "${BLUE}📦 Step 1: Creating ECR repositories...${NC}"
for repo in "$BACKEND_ECR" "$FRONTEND_ECR" "$WORKER_ECR"; do
    aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" &>/dev/null || \
    aws ecr create-repository \
        --repository-name "$repo" \
        --region "$AWS_REGION" \
        --image-scanning-configuration scanOnPush=true \
        --query 'repository.repositoryUri' \
        --output text
    echo -e "${GREEN}  ✓ $repo${NC}"
done
echo ""

# Step 2: Log in to ECR
echo -e "${BLUE}🔐 Step 2: Logging in to ECR...${NC}"
aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
echo -e "${GREEN}✅ Logged in to ECR${NC}"
echo ""

# Step 3: Build and push Docker images
echo -e "${BLUE}🏗️  Step 3: Building and pushing Docker images...${NC}"

# Backend
echo -e "${YELLOW}Building backend...${NC}"
BACKEND_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$BACKEND_ECR:latest"
docker build -t "$BACKEND_IMAGE" -f Dockerfile.backend .
docker push "$BACKEND_IMAGE"
echo -e "${GREEN}  ✓ Backend pushed to ECR${NC}"

# Worker
echo -e "${YELLOW}Building worker...${NC}"
WORKER_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$WORKER_ECR:latest"
docker build -t "$WORKER_IMAGE" -f Dockerfile.worker .
docker push "$WORKER_IMAGE"
echo -e "${GREEN}  ✓ Worker pushed to ECR${NC}"

# Frontend
echo -e "${YELLOW}Building frontend...${NC}"
FRONTEND_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$FRONTEND_ECR:latest"
docker build -t "$FRONTEND_IMAGE" -f Dockerfile.frontend .
docker push "$FRONTEND_IMAGE"
echo -e "${GREEN}  ✓ Frontend pushed to ECR${NC}"
echo ""

# Step 4: Create ECS cluster
echo -e "${BLUE}🏭 Step 4: Creating ECS cluster...${NC}"
aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" &>/dev/null || \
aws ecs create-cluster \
    --cluster-name "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --capacity-providers FARGATE FARGATE_SPOT \
    --default-capacity-provider-strategy \
        capacityProvider=FARGATE,weight=1 \
        capacityProvider=FARGATE_SPOT,weight=4
echo -e "${GREEN}✅ Cluster created/verified${NC}"
echo ""

# Step 5: Create CloudWatch log groups
echo -e "${BLUE}📊 Step 5: Creating CloudWatch log groups...${NC}"
for service in backend frontend worker; do
    aws logs create-log-group \
        --log-group-name "/ecs/seip-$service" \
        --region "$AWS_REGION" 2>/dev/null || echo -e "${YELLOW}  Log group /ecs/seip-$service already exists${NC}"
done
echo -e "${GREEN}✅ Log groups ready${NC}"
echo ""

# Step 6: Setup networking
echo -e "${BLUE}🌐 Step 6: Setting up VPC and networking...${NC}"
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region "$AWS_REGION")
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text --region "$AWS_REGION" | tr '\t' ',')
echo -e "${GREEN}  VPC ID: $VPC_ID${NC}"
echo -e "${GREEN}  Subnets: $SUBNET_IDS${NC}"

# Create security group
SG_NAME="seip-security-group"
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null)

if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$SG_NAME" \
        --description "Security group for SEIP" \
        --vpc-id "$VPC_ID" \
        --output text \
        --region "$AWS_REGION")

    # Add ingress rules
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "$AWS_REGION"
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0 --region "$AWS_REGION"
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 3001 --cidr 0.0.0.0/0 --region "$AWS_REGION"
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 5432 --source-group "$SG_ID" --region "$AWS_REGION"
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 6379 --source-group "$SG_ID" --region "$AWS_REGION"

    echo -e "${GREEN}✅ Security group created: $SG_ID${NC}"
else
    echo -e "${GREEN}✅ Security group exists: $SG_ID${NC}"
fi
echo ""

# Step 7: Deploy script completion message
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Pre-deployment complete!${NC}"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo -e "  1. Run: ${BLUE}./scripts/create-ecs-task-definitions.sh${NC}"
echo -e "  2. Run: ${BLUE}./scripts/create-ecs-services.sh${NC}"
echo -e "  3. Setup Route53 DNS: ${BLUE}seip.armyknifeplatform.com${NC}"
echo -e "  4. Configure ALB with SSL certificate"
echo ""
echo -e "${YELLOW}📋 Configuration saved:${NC}"
echo -e "  VPC ID:          $VPC_ID"
echo -e "  Security Group:  $SG_ID"
echo -e "  Subnets:         $SUBNET_IDS"
echo -e "  Backend Image:   $BACKEND_IMAGE"
echo -e "  Frontend Image:  $FRONTEND_IMAGE"
echo -e "  Worker Image:    $WORKER_IMAGE"
