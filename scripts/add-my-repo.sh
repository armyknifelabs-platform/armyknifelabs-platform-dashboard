#!/bin/bash

echo "=== Adding enterprise-seip-dashboard to tracked repos ==="
echo ""

BACKEND_URL="https://seip.armyknifelabs.com"

# Add the repo to tracking
response=$(curl -s -X POST "${BACKEND_URL}/api/v1/github/tracked-repos" \
  -H "Content-Type: application/json" \
  -d '{
    "owner": "armyknife-tools",
    "repo": "enterprise-seip-dashboard",
    "priority": "high"
  }')

echo "Response:"
echo "$response" | jq '.' 2>/dev/null || echo "$response"
echo ""

if echo "$response" | grep -q '"success": *true'; then
    echo "✅ SUCCESS: Repository added to tracking!"
    echo ""
    echo "The backend will now:"
    echo "  1. Clone and analyze the repository"
    echo "  2. Calculate metrics for all contributors"
    echo "  3. Cache file-level metrics"
    echo "  4. Make metrics available via /vscode API"
    echo ""
    echo "This may take a few minutes. Check status with:"
    echo "  curl -s '${BACKEND_URL}/api/v1/github/tracked-repos' | jq '.'"
else
    echo "❌ FAILED: Could not add repository to tracking"
    echo ""
    echo "Possible reasons:"
    echo "  - Endpoint requires authentication"
    echo "  - Repository already exists"
    echo "  - Backend error"
fi
