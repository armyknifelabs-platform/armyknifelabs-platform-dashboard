#!/bin/bash

######################################################################
# Create Demo Branches via GitHub API
######################################################################

set -e

REPO_OWNER="armyknife-tools"
REPO_NAME="github-metrics-demo"
REPO_FULL="${REPO_OWNER}/${REPO_NAME}"

if [ -z "$GH_TOKEN" ]; then
    echo "Error: GH_TOKEN not set"
    exit 1
fi

# Get the main branch SHA
MAIN_SHA=$(/opt/homebrew/bin/gh api "repos/${REPO_FULL}/git/refs/heads/main" --jq '.object.sha')
echo "Main branch SHA: $MAIN_SHA"

# Create demo branches
declare -a BRANCHES=(
    "demo/feature/api-v2"
    "demo/feature/websocket-support"
    "demo/bugfix/memory-leak"
    "demo/refactor/database-layer"
    "demo/feature/monitoring"
    "demo/feature/graphql-api"
    "demo/feature/real-time-notifications"
    "demo/bugfix/race-condition"
)

for branch_name in "${BRANCHES[@]}"; do
    # Check if branch exists
    EXISTS=$(/opt/homebrew/bin/gh api "repos/${REPO_FULL}/git/refs/heads/${branch_name}" --jq '.ref' 2>/dev/null || echo "")

    if [ -z "$EXISTS" ]; then
        # Create branch from main
        /opt/homebrew/bin/gh api --method POST "repos/${REPO_FULL}/git/refs" \
            -f ref="refs/heads/${branch_name}" \
            -f sha="$MAIN_SHA" > /dev/null
        echo "✓ Created branch: $branch_name"
    else
        echo "⚠ Branch already exists: $branch_name"
    fi
done

echo ""
echo "Demo branches created successfully!"
