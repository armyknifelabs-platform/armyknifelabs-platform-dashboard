#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Setup GitHub Actions IAM Role${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Configuration
AWS_ACCOUNT_ID="241533127046"
GITHUB_ORG="armyknife-tools"
GITHUB_REPO="seip-dashboard"
ROLE_NAME="GitHubActionsECSDeployRole"
POLICY_NAME="GitHubActionsECSDeployPolicy"

echo -e "${YELLOW}Configuration:${NC}"
echo -e "  AWS Account: ${AWS_ACCOUNT_ID}"
echo -e "  GitHub Repo: ${GITHUB_ORG}/${GITHUB_REPO}"
echo -e "  IAM Role:    ${ROLE_NAME}"
echo -e "  IAM Policy:  ${POLICY_NAME}"
echo ""

# Step 1: Create IAM Policy
echo -e "${BLUE}Step 1: Creating IAM Policy...${NC}"

POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRPermissions",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSPermissions",
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:DescribeTasks",
        "ecs:ListTasks",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PassRolePermissions",
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
        "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskRole"
      ]
    }
  ]
}
EOF
)

# Check if policy already exists
POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn" --output text)

if [ -n "$POLICY_ARN" ]; then
    echo -e "${YELLOW}Policy already exists: ${POLICY_ARN}${NC}"
else
    POLICY_ARN=$(aws iam create-policy \
        --policy-name "${POLICY_NAME}" \
        --policy-document "$POLICY_DOC" \
        --description "Allows GitHub Actions to deploy to ECS" \
        --query 'Policy.Arn' \
        --output text)
    echo -e "${GREEN}✓ Created policy: ${POLICY_ARN}${NC}"
fi

# Step 2: Create IAM Role with Trust Policy
echo -e "\n${BLUE}Step 2: Creating IAM Role...${NC}"

TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF
)

# Check if role already exists
if aws iam get-role --role-name "${ROLE_NAME}" &>/dev/null; then
    echo -e "${YELLOW}Role already exists: ${ROLE_NAME}${NC}"
    ROLE_ARN=$(aws iam get-role --role-name "${ROLE_NAME}" --query 'Role.Arn' --output text)
else
    ROLE_ARN=$(aws iam create-role \
        --role-name "${ROLE_NAME}" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --description "GitHub Actions role for ECS deployment" \
        --query 'Role.Arn' \
        --output text)
    echo -e "${GREEN}✓ Created role: ${ROLE_ARN}${NC}"
fi

# Step 3: Attach Policy to Role
echo -e "\n${BLUE}Step 3: Attaching policy to role...${NC}"

aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "${POLICY_ARN}" 2>/dev/null || true

echo -e "${GREEN}✓ Policy attached to role${NC}"

# Step 4: Verify OIDC Provider
echo -e "\n${BLUE}Step 4: Verifying OIDC Provider...${NC}"

OIDC_PROVIDER=$(aws iam list-open-id-connect-providers \
    --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" \
    --output text)

if [ -n "$OIDC_PROVIDER" ]; then
    echo -e "${GREEN}✓ OIDC Provider exists: ${OIDC_PROVIDER}${NC}"
else
    echo -e "${RED}✗ OIDC Provider not found${NC}"
    echo -e "${YELLOW}Creating OIDC Provider...${NC}"

    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

    echo -e "${GREEN}✓ OIDC Provider created${NC}"
fi

# Step 5: Update GitHub Secret
echo -e "\n${BLUE}Step 5: Updating GitHub Secret...${NC}"

echo "${ROLE_ARN}" | gh secret set AWS_ROLE_ARN --repo "${GITHUB_ORG}/${GITHUB_REPO}"

echo -e "${GREEN}✓ GitHub secret AWS_ROLE_ARN updated${NC}"

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo -e "  IAM Role ARN: ${GREEN}${ROLE_ARN}${NC}"
echo -e "  Policy ARN:   ${GREEN}${POLICY_ARN}${NC}"
echo -e "  GitHub Repo:  ${GREEN}${GITHUB_ORG}/${GITHUB_REPO}${NC}"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo -e "  1. Verify GitHub secret: ${GREEN}gh secret list${NC}"
echo -e "  2. Test workflow: ${GREEN}./scripts/deploy.sh${NC}"
echo ""

exit 0
