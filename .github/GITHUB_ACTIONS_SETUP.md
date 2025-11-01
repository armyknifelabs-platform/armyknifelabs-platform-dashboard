# GitHub Actions Setup Guide

This guide explains how to configure GitHub repository secrets and use the CI/CD workflows.

## Repository Secrets Configuration

You need to configure the following secrets in your GitHub repository:

### Required Secrets

1. **AWS_ACCESS_KEY_ID** - AWS access key for ECR and ECS deployments
2. **AWS_SECRET_ACCESS_KEY** - AWS secret access key

### How to Add Secrets

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with the following values:

```bash
# AWS Credentials (for CI/CD deployments)
AWS_ACCESS_KEY_ID=<your-aws-access-key-id>
AWS_SECRET_ACCESS_KEY=<your-aws-secret-access-key>
```

### Getting AWS Credentials

If you need to create a new IAM user for GitHub Actions:

```bash
# Create IAM user for GitHub Actions
aws iam create-user --user-name github-actions-seip

# Attach required policies
aws iam attach-user-policy \
  --user-name github-actions-seip \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

aws iam attach-user-policy \
  --user-name github-actions-seip \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess

# Create access key
aws iam create-access-key --user-name github-actions-seip
```

## Workflows Overview

### 1. CI Workflow (`.github/workflows/ci.yml`)

**Triggers:**
- Pull requests to `main` or `develop`
- Pushes to `main` or `develop`

**What it does:**
- ✅ Lints and type-checks code
- ✅ Builds backend and frontend
- ✅ Runs tests (when implemented)
- ✅ Security scanning (npm audit + secrets detection)
- ✅ Docker build test (verifies linux/amd64 platform)

**Jobs:**
1. `lint` - ESLint and TypeScript type checking
2. `build-backend` - Compiles backend TypeScript
3. `build-frontend` - Builds frontend with Vite
4. `test` - Runs test suite (skipped if not implemented)
5. `security` - npm audit + secret scanning
6. `docker-build` - Tests Docker builds for both services
7. `ci-success` - Final check that all jobs passed

### 2. CD Workflow (`.github/workflows/deploy.yml`)

**Triggers:**
- Git tags matching `v*.*.*` (e.g., `v2.10.0`)
- Manual dispatch via GitHub UI

**What it does:**
- ✅ Builds Docker images with correct platform (linux/amd64)
- ✅ Pushes to Amazon ECR
- ✅ Deploys to AWS ECS Fargate
- ✅ Waits for deployment to stabilize
- ✅ Health check verification

**Manual Deployment:**
1. Go to **Actions** → **CD - Deploy to AWS ECS**
2. Click **Run workflow**
3. Select environment (production/staging)
4. Select service (backend/frontend/both)
5. Click **Run workflow**

**Tag-based Deployment:**
```bash
# Create and push a tag to trigger deployment
git tag v2.11.0
git push origin v2.11.0
```

### 3. Database Migration Workflow (`.github/workflows/database-migration.yml`)

**Triggers:**
- Manual dispatch only (for safety)

**What it does:**
- ✅ Runs database migrations
- ✅ Reverts last migration
- ✅ Shows pending migrations

**How to use:**
1. Go to **Actions** → **Database Migration**
2. Click **Run workflow**
3. Select action:
   - `run` - Apply pending migrations
   - `revert` - Rollback last migration
   - `show` - List pending migrations
4. Select environment (production/staging/test)
5. Click **Run workflow**

## Workflow Files

```
.github/workflows/
├── ci.yml                  # Continuous Integration
├── deploy.yml              # Continuous Deployment
└── database-migration.yml  # Database migrations
```

## Environment Variables

The workflows use these environment variables:

```yaml
AWS_REGION: us-east-1
ECR_REGISTRY: 241533127046.dkr.ecr.us-east-1.amazonaws.com
ECS_CLUSTER: seip-prod
BACKEND_SERVICE: seip-backend
FRONTEND_SERVICE: seip-frontend
NODE_VERSION: '20'
```

## Deployment Process

### Automated (via git tag):

```bash
# 1. Make your changes
git add .
git commit -m "feat: add new feature"

# 2. Create a tag
git tag v2.11.0

# 3. Push code and tag
git push origin main
git push origin v2.11.0

# 4. GitHub Actions will automatically:
#    - Run CI checks
#    - Build Docker images (linux/amd64)
#    - Push to ECR
#    - Deploy to ECS
#    - Verify health
```

### Manual Deployment:

1. Go to GitHub repository
2. Click **Actions** tab
3. Select **CD - Deploy to AWS ECS**
4. Click **Run workflow**
5. Choose environment and service
6. Click **Run workflow**
7. Monitor progress in Actions tab

## Monitoring Deployments

### View logs:

```bash
# Backend logs
aws logs tail /ecs/seip-backend --follow --region us-east-1

# Frontend logs
aws logs tail /ecs/seip-frontend --follow --region us-east-1
```

### Check deployment status:

```bash
# ECS services
aws ecs describe-services \
  --cluster seip-prod \
  --services seip-backend seip-frontend \
  --region us-east-1

# Running tasks
aws ecs list-tasks --cluster seip-prod --region us-east-1
```

## Rollback Procedure

If a deployment fails:

### Option 1: Revert via git tag

```bash
# Deploy previous version
git tag v2.10.1  # Previous working version
git push origin v2.10.1
```

### Option 2: Manual ECS rollback

```bash
# Scale to 0
aws ecs update-service \
  --cluster seip-prod \
  --service seip-backend \
  --desired-count 0 \
  --region us-east-1

# Use previous task definition
aws ecs update-service \
  --cluster seip-prod \
  --service seip-backend \
  --task-definition seip-backend:52 \
  --desired-count 1 \
  --force-new-deployment \
  --region us-east-1
```

## Security Best Practices

1. **Never commit secrets** - Use GitHub Secrets and AWS Secrets Manager
2. **Use IAM roles with minimal permissions** - Follow principle of least privilege
3. **Rotate AWS access keys regularly** - Set expiration policies
4. **Enable branch protection** - Require PR reviews before merging to main
5. **Use deployment gates** - Manual approval for production deployments (optional)

## Troubleshooting

### CI fails with "secrets detected"

Check for exposed secrets:
```bash
git ls-files | xargs grep -E "(ghp_|sk-ant-|AKIA)"
```

### Docker build fails with "platform mismatch"

Ensure workflow uses `linux/amd64`:
```yaml
platforms: linux/amd64
```

### Deployment stuck in "pending"

Check ECS events:
```bash
aws ecs describe-services \
  --cluster seip-prod \
  --services seip-backend \
  --region us-east-1 \
  --query 'services[0].events[0:5]'
```

### Health check fails

Check application logs:
```bash
aws logs tail /ecs/seip-backend --since 10m --region us-east-1
```

## Next Steps

After configuring secrets:

1. ✅ Test CI workflow by creating a pull request
2. ✅ Test deployment workflow with manual dispatch
3. ✅ Create first release tag (e.g., `v2.11.0`)
4. ✅ Monitor deployment in GitHub Actions
5. ✅ Verify production at https://seip.armyknifelabs.com

## Support

For issues with GitHub Actions:
- Check workflow logs in **Actions** tab
- Review AWS CloudWatch logs
- Verify IAM permissions
- Ensure secrets are configured correctly
