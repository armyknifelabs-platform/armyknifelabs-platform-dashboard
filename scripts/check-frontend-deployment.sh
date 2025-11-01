#!/bin/bash

echo "=== Frontend Deployment Checker ==="
echo ""

FRONTEND_URL="https://seip.armyknifelabs.com"

echo "Current deployment status:"
echo ""

# 1. Check if frontend is accessible
echo "1. Checking frontend accessibility..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL/")
if [ "$STATUS" = "200" ]; then
    echo "   ✅ Frontend is accessible (HTTP $STATUS)"
else
    echo "   ❌ Frontend returned HTTP $STATUS"
fi
echo ""

# 2. Check last modified date
echo "2. Checking deployment timestamp..."
LAST_MODIFIED=$(curl -sI "$FRONTEND_URL/" | grep -i "last-modified:" | cut -d' ' -f2-)
echo "   Last Modified: $LAST_MODIFIED"
echo ""

# 3. Check current bundle hash
echo "3. Checking bundle version..."
BUNDLE=$(curl -s "$FRONTEND_URL/" | grep -o "index-[^.]*\.js" | head -1)
echo "   Current Bundle: $BUNDLE"
echo ""

# 4. Check backend health
echo "4. Checking backend health..."
BACKEND_STATUS=$(curl -s "$FRONTEND_URL/api/v1/health" | jq -r '.data.status' 2>/dev/null)
if [ "$BACKEND_STATUS" = "healthy" ]; then
    echo "   ✅ Backend is healthy"
else
    echo "   ⚠️  Backend status: $BACKEND_STATUS"
fi
echo ""

# 5. Check backend uptime
UPTIME=$(curl -s "$FRONTEND_URL/api/v1/health" | jq -r '.data.uptime' 2>/dev/null)
if [ ! -z "$UPTIME" ]; then
    UPTIME_MIN=$((UPTIME / 60))
    echo "   Backend uptime: ${UPTIME}s (~${UPTIME_MIN} minutes)"
fi
echo ""

echo "=== Deployment Check Complete ==="
echo ""
echo "To monitor for changes, run this script again in a few minutes."
echo ""
echo "Expected changes after deployment:"
echo "  - Last Modified date will be newer"
echo "  - Bundle hash (index-XXXXX.js) will be different"
echo "  - Frontend should show updated content"
