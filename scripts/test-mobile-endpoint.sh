cat > /tmp/test-mobile-oauth-endpoint.sh << 'EOF'
#!/bin/bash

echo "=== Testing Mobile OAuth Endpoint Detection ==="
echo ""
echo "This script tests if the backend has mobile OAuth detection deployed."
echo ""

BACKEND_URL="https://seip.armyknifelabs.com"

echo "1. Testing OAuth callback endpoint with mobile User-Agent header..."
echo ""

# Test with mobile User-Agent
response=$(curl -s -L -w "\n%{http_code}\n%{redirect_url}" \
  -H "User-Agent: SEIP-Mobile/1.0" \
  -H "X-Mobile-App: true" \
  "${BACKEND_URL}/api/v1/auth/github/callback?code=test_code_12345" 2>&1)

echo "Response:"
echo "$response"
echo ""

# Check if redirect contains seip:// deep link
if echo "$response" | grep -q "seip://"; then
    echo "✅ SUCCESS: Mobile OAuth detection is working!"
    echo "   Backend is redirecting to deep link: seip://oauth-callback"
else
    echo "❌ FAILED: Mobile OAuth detection NOT deployed"
    echo "   Backend is still redirecting to website"
fi

echo ""
echo "2. Alternative test - Check backend logs endpoint..."
echo ""

# Simple health check
curl -s "${BACKEND_URL}/api/v1/health" || echo "Health endpoint not available"

echo ""
echo "=== Instructions for Backend Lead ==="
echo ""
echo "To verify mobile OAuth is deployed, check if oauth.routes.ts contains:"
echo "  - Lines 174-187: Mobile app detection code"
echo "  - Check for: userAgent.includes('SEIP-Mobile')"
echo "  - Check for: seip://oauth-callback redirect"
echo ""
echo "Or test manually with:"
echo "  curl -H 'User-Agent: SEIP-Mobile/1.0' \\"
echo "       'https://seip.armyknifelabs.com/api/v1/auth/github'"
echo ""
echo "Expected: Should redirect to GitHub OAuth with mobile detection"
EOF

chmod +x /tmp/test-mobile-oauth-endpoint.sh
/tmp/test-mobile-oauth-endpoint.sh