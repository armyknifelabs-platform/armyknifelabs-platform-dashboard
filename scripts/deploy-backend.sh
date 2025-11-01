#!/bin/bash

# Deploy Backend with Version Tracking
# Usage: ./scripts/deploy-backend.sh v2.10.0-feature-name

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "❌ Error: Version required"
  echo "Usage: ./scripts/deploy-backend.sh v2.10.0-feature-name"
  echo ""
  echo "Version format: vMAJOR.MINOR.PATCH-description"
  echo "Examples:"
  echo "  - v2.10.0-ai-tooltips"
  echo "  - v2.9.3-auth-fix"
  echo "  - v3.0.0-graphql-migration"
  exit 1
fi

echo "🚀 Deploying Backend: ${VERSION}"
echo ""

# Build
echo "📦 Step 1/4: Building Docker image..."
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker build \
  --no-cache \
  -f Dockerfile.backend \
  -t dashboard-backend:latest .

echo ""
echo "✅ Build complete!"
echo ""

# Tag
echo "🏷️  Step 2/4: Tagging image..."
docker tag dashboard-backend:latest \
  241533127046.dkr.ecr.us-east-1.amazonaws.com/seip-backend:${VERSION}

echo "✅ Tagged as: seip-backend:${VERSION}"
echo ""

# Push
echo "⬆️  Step 3/4: Pushing to ECR..."
docker push 241533127046.dkr.ecr.us-east-1.amazonaws.com/seip-backend:${VERSION}

echo ""
echo "✅ Image pushed successfully!"
echo ""

# Instructions
echo "📋 Step 4/4: Update ECS Task Definition"
echo ""
echo "Next steps:"
echo "1. Create task definition with APP_VERSION=${VERSION}"
echo "2. Update the 'image' field to: seip-backend:${VERSION}"
echo "3. Add environment variable: APP_VERSION=${VERSION}"
echo "4. Register task definition"
echo "5. Update ECS service"
echo ""
echo "See docs/deployment/VERSION_DISPLAY_SYSTEM.md for detailed instructions."
echo ""
echo "Quick commands:"
echo "  # Register task definition (edit /tmp/backend-task-def.json first)"
echo "  aws ecs register-task-definition --cli-input-json file:///tmp/backend-task-def.json --region us-east-1"
echo ""
echo "  # Deploy (replace REVISION with output from above)"
echo "  aws ecs update-service --cluster seip-prod --service seip-backend --task-definition seip-backend:REVISION --force-new-deployment --region us-east-1"
echo ""
echo "✅ Backend build complete: ${VERSION}"
