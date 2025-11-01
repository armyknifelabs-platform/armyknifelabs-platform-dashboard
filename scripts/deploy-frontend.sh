#!/bin/bash

# Deploy Frontend with Version Tracking
# Usage: ./scripts/deploy-frontend.sh v2.9.0-feature-name

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "❌ Error: Version required"
  echo "Usage: ./scripts/deploy-frontend.sh v2.9.0-feature-name"
  echo ""
  echo "Version format: vMAJOR.MINOR.PATCH-description"
  echo "Examples:"
  echo "  - v2.9.0-ui-redesign"
  echo "  - v2.8.1-nav-fix"
  echo "  - v3.0.0-react-19"
  exit 1
fi

echo "🚀 Deploying Frontend: ${VERSION}"
echo ""

# Build with version
echo "📦 Step 1/4: Building Docker image with version..."
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker build \
  --no-cache \
  --build-arg APP_VERSION=${VERSION} \
  --build-arg NGINX_CONFIG=nginx.production.conf \
  -f Dockerfile.frontend \
  -t dashboard-frontend:latest .

echo ""
echo "✅ Build complete with version: ${VERSION}"
echo ""

# Tag
echo "🏷️  Step 2/4: Tagging image..."
docker tag dashboard-frontend:latest \
  241533127046.dkr.ecr.us-east-1.amazonaws.com/seip-frontend:${VERSION}

echo "✅ Tagged as: seip-frontend:${VERSION}"
echo ""

# Push
echo "⬆️  Step 3/4: Pushing to ECR..."
docker push 241533127046.dkr.ecr.us-east-1.amazonaws.com/seip-frontend:${VERSION}

echo ""
echo "✅ Image pushed successfully!"
echo ""

# Instructions
echo "📋 Step 4/4: Update ECS Task Definition"
echo ""
echo "Next steps:"
echo "1. Create task definition with image: seip-frontend:${VERSION}"
echo "2. Register task definition"
echo "3. Update ECS service"
echo ""
echo "See docs/deployment/VERSION_DISPLAY_SYSTEM.md for detailed instructions."
echo ""
echo "Quick commands:"
echo "  # Register task definition (edit /tmp/frontend-task-def.json first)"
echo "  aws ecs register-task-definition --cli-input-json file:///tmp/frontend-task-def.json --region us-east-1"
echo ""
echo "  # Deploy (replace REVISION with output from above)"
echo "  aws ecs update-service --cluster seip-prod --service seip-frontend --task-definition seip-frontend:REVISION --force-new-deployment --region us-east-1"
echo ""
echo "  # Verify in browser (hard refresh required)"
echo "  open https://seip.armyknifelabs.com"
echo ""
echo "✅ Frontend build complete: ${VERSION}"
echo ""
echo "💡 Version will be visible in GlobalStatusBar (bottom of page) after deployment"
