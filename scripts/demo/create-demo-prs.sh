#!/bin/bash

######################################################################
# Create Demo Pull Requests
######################################################################

set -e

REPO_OWNER="armyknife-tools"
REPO_NAME="github-metrics-demo"
REPO_FULL="${REPO_OWNER}/${REPO_NAME}"

if [ -z "$GH_TOKEN" ]; then
    echo "Error: GH_TOKEN not set"
    exit 1
fi

# PR definitions: branch|title|body_summary
declare -a PRS=(
    "demo/feature/api-v2|Add REST API v2 with improved performance|Implements a new REST API v2 with significant performance improvements, better error handling, and comprehensive OpenAPI documentation. This version addresses scalability concerns and provides backward compatibility with v1."
    "demo/feature/websocket-support|Add real-time WebSocket support for live data streaming|Introduces WebSocket support for real-time bidirectional communication. Enables live dashboards, notifications, and collaborative features. Includes connection pooling and automatic reconnection logic."
    "demo/bugfix/memory-leak|Fix memory leak in event handlers|Resolves critical memory leak caused by not properly removing event listeners during cleanup. This was causing the application to consume increasing amounts of memory over time in production."
    "demo/refactor/database-layer|Modernize database layer with async/await|Refactors the entire database layer to use modern async/await patterns instead of callbacks. Implements connection pooling, query optimization, and better error handling. Performance improvements of 40% observed in benchmarks."
    "demo/feature/monitoring|Add Prometheus metrics and monitoring|Integrates Prometheus for comprehensive application monitoring. Exposes metrics for request duration, error rates, database query performance, and custom business metrics. Includes Grafana dashboard templates."
    "demo/feature/graphql-api|Add GraphQL API endpoint|Implements a GraphQL API alongside the existing REST API, providing clients with flexible data querying capabilities. Includes DataLoader for N+1 query optimization and comprehensive schema documentation."
    "demo/feature/real-time-notifications|Implement real-time push notifications|Adds real-time push notification system using WebSockets. Supports user preferences, notification categories, and delivery tracking. Integrates with existing authentication system."
    "demo/bugfix/race-condition|Fix race condition in concurrent request handling|Resolves race condition that occurred when multiple requests attempted to update the same resource simultaneously. Implements proper locking mechanism and optimistic concurrency control."
)

for pr_data in "${PRS[@]}"; do
    IFS='|' read -r branch_name pr_title pr_summary <<< "$pr_data"

    # Check if PR already exists
    EXISTING_PR=$(/opt/homebrew/bin/gh api "repos/${REPO_FULL}/pulls?head=${REPO_OWNER}:${branch_name}&state=all" --jq '.[0].number' 2>/dev/null || echo "")

    if [ -n "$EXISTING_PR" ] && [ "$EXISTING_PR" != "null" ]; then
        echo "⚠ PR already exists for $branch_name: #$EXISTING_PR"
        continue
    fi

    # Extract feature type
    FEATURE_TYPE=$(echo "$branch_name" | sed 's/demo\///' | cut -d'/' -f1)

    # Select AI tool based on feature type
    case $FEATURE_TYPE in
        "feature")
            AI_TOOL="GitHub Copilot"
            AI_EMAIL="noreply@github.com"
            ;;
        "bugfix")
            AI_TOOL="Claude"
            AI_EMAIL="noreply@anthropic.com"
            ;;
        "refactor")
            AI_TOOL="Cursor"
            AI_EMAIL="noreply@cursor.sh"
            ;;
        *)
            AI_TOOL="Aider"
            AI_EMAIL="git@aider.chat"
            ;;
    esac

    # Create comprehensive PR body
    PR_BODY="## Summary
$pr_summary

## Changes
- Implements core functionality for ${branch_name##*/}
- Adds comprehensive error handling and logging
- Includes unit and integration tests (95%+ coverage)
- Updates documentation and API references
- Adds performance benchmarks

## AI-Assisted Development
This PR was developed using **${AI_TOOL}** for pair programming, which significantly accelerated development:
- ✅ Code generation and scaffolding
- ✅ Test case generation
- ✅ Documentation writing
- ✅ Code review and optimization suggestions

## Test Plan
- [x] Unit tests pass (npm run test)
- [x] Integration tests pass
- [x] Manual testing completed
- [x] Performance benchmarks run
- [x] Security scan passed
- [x] Code review completed

## Performance Impact
- Load time: No regression
- Memory usage: +2MB (within acceptable limits)
- API response time: Improved by 15ms average

## Breaking Changes
None - fully backward compatible

## Co-authored-by
Co-authored-by: ${AI_TOOL} <${AI_EMAIL}>

---
🤖 **Demo Data** - Part of demonstration dataset for client presentations"

    # Create PR
    PR_JSON=$(echo "{}" | jq -c \
        --arg title "$pr_title" \
        --arg body "$PR_BODY" \
        --arg head "$branch_name" \
        --arg base "main" \
        '{title: $title, body: $body, head: $head, base: $base}')

    PR_NUM=$(echo "$PR_JSON" | /opt/homebrew/bin/gh api --method POST "repos/${REPO_FULL}/pulls" --input - --jq '.number' 2>/dev/null || echo "")

    if [ -n "$PR_NUM" ] && [ "$PR_NUM" != "null" ]; then
        echo "✓ Created PR #${PR_NUM}: $pr_title"

        # Add demo label
        /opt/homebrew/bin/gh api --method POST "repos/${REPO_FULL}/issues/${PR_NUM}/labels" \
            --input - <<< '{"labels":["demo:ai-assisted"]}' > /dev/null 2>&1

        # Randomly decide to merge some PRs (50% chance)
        if [ $((RANDOM % 2)) -eq 0 ]; then
            sleep 1  # Brief delay
            # Try to merge
            MERGE_RESULT=$(/opt/homebrew/bin/gh api --method PUT "repos/${REPO_FULL}/pulls/${PR_NUM}/merge" \
                -f merge_method="squash" \
                --jq '.merged' 2>/dev/null || echo "false")

            if [ "$MERGE_RESULT" = "true" ]; then
                echo "  → Merged PR #${PR_NUM}"
            fi
        fi
    else
        echo "✗ Failed to create PR for $branch_name"
    fi

    sleep 1  # Rate limiting protection
done

echo ""
echo "Demo PRs created successfully!"
