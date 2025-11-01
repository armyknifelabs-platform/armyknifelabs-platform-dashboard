#!/bin/bash

# GitHub Metrics API Testing Script

BASE_URL="http://localhost:3001/api/v1/github"

echo "=== Testing GitHub Metrics API ==="
echo ""

# Test 1: Get available scopes
echo "1. Testing GET /scopes"
curl -s "${BASE_URL}/scopes" | jq '.' || echo "Failed"
echo ""
echo "---"
echo ""

# Test 2: Get user repositories
echo "2. Testing GET /repositories?scope=user&owner=armyknife-tools"
curl -s "${BASE_URL}/repositories?scope=user&owner=armyknife-tools&timeRange=7d" | jq '.data.overview' || echo "Failed"
echo ""
echo "---"
echo ""

# Test 3: Get DORA metrics
echo "3. Testing GET /dora?scope=user&owner=armyknife-tools&timeRange=7d"
curl -s "${BASE_URL}/dora?scope=user&owner=armyknife-tools&timeRange=7d" | jq '.data' || echo "Failed"
echo ""
echo "---"
echo ""

# Test 4: Get pull requests
echo "4. Testing GET /pull-requests?scope=user&owner=armyknife-tools&timeRange=30d"
curl -s "${BASE_URL}/pull-requests?scope=user&owner=armyknife-tools&timeRange=30d" | jq '.data.overview' || echo "Failed"
echo ""
echo "---"
echo ""

# Test 5: Get CI/CD metrics
echo "5. Testing GET /cicd?scope=user&owner=armyknife-tools&timeRange=30d"
curl -s "${BASE_URL}/cicd?scope=user&owner=armyknife-tools&timeRange=30d" | jq '.data.workflowMetrics' || echo "Failed"
echo ""
echo "---"
echo ""

# Test 6: Get issues
echo "6. Testing GET /issues?scope=user&owner=armyknife-tools&timeRange=30d"
curl -s "${BASE_URL}/issues?scope=user&owner=armyknife-tools&timeRange=30d" | jq '.data' || echo "Failed"
echo ""
echo "---"
echo ""

# Test 7: Get complete metrics
echo "7. Testing GET /metrics?scope=user&owner=armyknife-tools&timeRange=7d"
curl -s "${BASE_URL}/metrics?scope=user&owner=armyknife-tools&timeRange=7d" | jq '.data.dora.doraLevel' || echo "Failed"
echo ""
echo "---"
echo ""

# Test 8: Get rate limit
echo "8. Testing GET /rate-limit"
curl -s "${BASE_URL}/rate-limit" | jq '.data' || echo "Failed"
echo ""
echo "---"
echo ""

# Test 9: Get cache stats
echo "9. Testing GET /cache-stats"
curl -s "${BASE_URL}/cache-stats" | jq '.data' || echo "Failed"
echo ""
echo "---"
echo ""

# Test 10: Org repos (if available)
echo "10. Testing GET /repositories?scope=org&owner=armyknifelabs-platform"
curl -s "${BASE_URL}/repositories?scope=org&owner=armyknifelabs-platform&timeRange=7d" | jq '.data.overview.totalRepos' || echo "Failed (might be private repos)"
echo ""

echo ""
echo "=== Testing Complete ==="
