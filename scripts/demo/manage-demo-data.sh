#!/bin/bash

#######################################################################
# Demo Data Management Script for armyknife-tools/github-metrics-demo
#######################################################################
#
# Purpose: Populate GitHub repo with realistic demo data for client demos
# and provide easy cleanup when transitioning to production use.
#
# Usage:
#   ./manage-demo-data.sh populate    # Add demo data
#   ./manage-demo-data.sh cleanup     # Remove all demo data
#   ./manage-demo-data.sh status      # Show current demo data
#
#######################################################################

set -e  # Exit on error

# Configuration
REPO_OWNER="armyknife-tools"
REPO_NAME="github-metrics-demo"
REPO_FULL="${REPO_OWNER}/${REPO_NAME}"
DEMO_TAG_PREFIX="demo-"
DEMO_BRANCH_PREFIX="demo/"
DEMO_LABEL_PREFIX="demo:"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if GH_TOKEN is set
if [ -z "$GH_TOKEN" ]; then
    echo -e "${RED}Error: GH_TOKEN environment variable not set${NC}"
    echo "Please set your GitHub token:"
    echo "  export GH_TOKEN=ghp_..."
    exit 1
fi

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

gh_api() {
    /opt/homebrew/bin/gh api "$@" 2>/dev/null || echo "[]"
}

#######################################################################
# STATUS: Show current demo data
#######################################################################
show_status() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Demo Data Status for ${REPO_FULL}"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Count issues
    TOTAL_ISSUES=$(gh_api "repos/${REPO_FULL}/issues?state=all&per_page=100" --jq 'length')
    OPEN_ISSUES=$(gh_api "repos/${REPO_FULL}/issues?state=open&per_page=100" --jq 'length')
    CLOSED_ISSUES=$((TOTAL_ISSUES - OPEN_ISSUES))

    # Count PRs
    TOTAL_PRS=$(gh_api "repos/${REPO_FULL}/pulls?state=all&per_page=100" --jq 'length')
    OPEN_PRS=$(gh_api "repos/${REPO_FULL}/pulls?state=open&per_page=100" --jq 'length')
    MERGED_PRS=$(gh_api "repos/${REPO_FULL}/pulls?state=closed&per_page=100" --jq '[.[] | select(.merged_at != null)] | length')

    # Count branches
    ALL_BRANCHES=$(gh_api "repos/${REPO_FULL}/branches?per_page=100" --jq 'length')
    DEMO_BRANCHES=$(gh_api "repos/${REPO_FULL}/branches?per_page=100" --jq "[.[] | select(.name | startswith(\"${DEMO_BRANCH_PREFIX}\"))] | length")

    # Count commits (last 100)
    COMMIT_COUNT=$(gh_api "repos/${REPO_FULL}/commits?per_page=100" --jq 'length')

    # Count labels
    DEMO_LABELS=$(gh_api "repos/${REPO_FULL}/labels?per_page=100" --jq "[.[] | select(.name | startswith(\"${DEMO_LABEL_PREFIX}\"))] | length")

    echo "📊 Issues:"
    echo "   Total: ${TOTAL_ISSUES} (Open: ${OPEN_ISSUES}, Closed: ${CLOSED_ISSUES})"
    echo ""
    echo "🔀 Pull Requests:"
    echo "   Total: ${TOTAL_PRS} (Open: ${OPEN_PRS}, Merged: ${MERGED_PRS})"
    echo ""
    echo "🌿 Branches:"
    echo "   Total: ${ALL_BRANCHES} (Demo branches: ${DEMO_BRANCHES})"
    echo ""
    echo "📝 Commits (last 100):"
    echo "   Count: ${COMMIT_COUNT}"
    echo ""
    echo "🏷️  Demo Labels:"
    echo "   Count: ${DEMO_LABELS}"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

#######################################################################
# POPULATE: Add realistic demo data
#######################################################################
populate_demo_data() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Populating Demo Data for ${REPO_FULL}"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    log_info "Step 1: Creating demo labels..."
    create_demo_labels

    log_info "Step 2: Creating demo issues..."
    create_demo_issues

    log_info "Step 3: Creating demo branches and commits..."
    create_demo_branches

    log_info "Step 4: Creating demo pull requests..."
    create_demo_prs

    log_info "Step 5: Adding comments and reviews..."
    add_collaboration_data

    echo ""
    log_success "Demo data population complete!"
    echo ""
    show_status
}

#######################################################################
# Create Demo Labels
#######################################################################
create_demo_labels() {
    # Label definitions: name|color|description
    local LABEL_DEFS=(
        "demo:high-priority|e11d21|High priority demo item"
        "demo:ai-assisted|7057ff|Code created with AI assistance"
        "demo:experiment|fbca04|Experimental feature or POC"
        "demo:security|d73a4a|Security-related demo"
        "demo:performance|0e8a16|Performance improvement demo"
        "demo:refactor|5319e7|Code refactoring demo"
    )

    for label_def in "${LABEL_DEFS[@]}"; do
        IFS='|' read -r label color description <<< "$label_def"

        # Check if label exists
        EXISTS=$(gh_api "repos/${REPO_FULL}/labels/${label}" --jq '.name' 2>/dev/null || echo "")

        if [ -z "$EXISTS" ]; then
            gh_api --method POST "repos/${REPO_FULL}/labels" \
                -f name="$label" \
                -f color="$color" \
                -f description="$description" > /dev/null
            log_success "Created label: $label"
        else
            log_warning "Label already exists: $label"
        fi
    done
}

#######################################################################
# Create Demo Issues
#######################################################################
create_demo_issues() {
    # Array of realistic issues
    declare -a ISSUES=(
        "Add authentication middleware|bug,demo:high-priority|The API needs JWT authentication middleware to secure endpoints. Currently, all routes are publicly accessible."
        "Implement rate limiting|enhancement,demo:ai-assisted|Add rate limiting to prevent API abuse. Should support configurable limits per endpoint."
        "Database connection pooling|demo:performance|Optimize database connections with pooling to handle concurrent requests efficiently."
        "Add comprehensive API documentation|documentation,demo:experiment|Create OpenAPI/Swagger documentation for all API endpoints with examples."
        "Memory leak in WebSocket handler|bug,demo:high-priority|WebSocket connections are not being properly closed, causing memory leaks over time."
        "Implement caching layer|demo:performance,demo:ai-assisted|Add Redis caching for frequently accessed data to reduce database load."
        "Refactor error handling|demo:refactor|Consolidate error handling into middleware for consistent error responses across all endpoints."
        "Add input validation|demo:security,demo:ai-assisted|Implement Zod schema validation for all API inputs to prevent injection attacks."
        "Create metrics dashboard|enhancement,demo:experiment|Build a real-time metrics dashboard showing API performance and usage statistics."
        "Optimize query performance|demo:performance|Several database queries are slow. Need to add indexes and optimize complex joins."
    )

    local issue_count=0
    for issue_data in "${ISSUES[@]}"; do
        IFS='|' read -r title labels body <<< "$issue_data"

        # Create issue using jq to properly format labels array
        LABELS_ARRAY=$(echo "$labels" | jq -R 'split(",")' 2>/dev/null)

        ISSUE_NUM=$(echo "{}" | jq -c \
            --arg title "$title" \
            --arg body "$body" \
            --argjson labels "$LABELS_ARRAY" \
            '{title: $title, body: $body, labels: $labels}' | \
            gh_api --method POST "repos/${REPO_FULL}/issues" --input - --jq '.number' 2>/dev/null || echo "")

        if [ -n "$ISSUE_NUM" ] && [ "$ISSUE_NUM" != "null" ]; then
            log_success "Created issue #${ISSUE_NUM}: $title"
        else
            log_warning "Failed to create issue: $title"
            continue
        fi

        # Close some issues randomly to show activity
        if [ $((RANDOM % 3)) -eq 0 ]; then
            gh_api --method PATCH "repos/${REPO_FULL}/issues/${ISSUE_NUM}" \
                -f state="closed" > /dev/null
            log_info "  → Closed issue #${ISSUE_NUM}"
        fi

        issue_count=$((issue_count + 1))
    done

    log_success "Created $issue_count demo issues"
}

#######################################################################
# Create Demo Branches with Commits
#######################################################################
create_demo_branches() {
    # Clone repo to temp directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    log_info "Cloning repository to ${TEMP_DIR}..."
    git clone "https://github.com/${REPO_FULL}.git" . > /dev/null 2>&1

    # Configure git
    git config user.name "Demo Bot"
    git config user.email "demo@armyknife-tools.com"

    # Create feature branches with commits
    declare -a BRANCHES=(
        "demo/feature/api-v2:feat: add API v2 endpoints:Implement new REST API v2 with improved performance and better error handling.|GitHub Copilot <noreply@github.com>"
        "demo/feature/websocket-support:feat: add WebSocket support:Add real-time WebSocket support for live data streaming.|Cursor <noreply@cursor.sh>"
        "demo/bugfix/memory-leak:fix: resolve memory leak in event handlers:Fixed memory leak caused by not removing event listeners in cleanup.|Claude <noreply@anthropic.com>"
        "demo/refactor/database-layer:refactor: modernize database layer:Refactor database layer to use async/await and connection pooling.|GitHub Copilot <noreply@github.com>"
        "demo/feature/monitoring:feat: add Prometheus metrics:Integrate Prometheus for application monitoring and alerting.|Aider <git@aider.chat>"
    )

    for branch_data in "${BRANCHES[@]}"; do
        IFS=':' read -r branch_name commit_title commit_body coauthor <<< "$branch_data"

        # Create and checkout branch
        git checkout -b "$branch_name" origin/main > /dev/null 2>&1

        # Create a meaningful file change
        FILE_NAME="src/$(echo "$branch_name" | sed 's/demo\/feature\///;s/demo\/bugfix\///;s/demo\/refactor\///' | tr '/' '_').js"
        cat > "$FILE_NAME" << EOF
// ${commit_title}
// Generated for demo purposes

export class DemoFeature {
  constructor() {
    this.initialized = false;
    this.config = {};
  }

  async initialize(config) {
    this.config = config;
    this.initialized = true;
    console.log('Demo feature initialized');
  }

  async execute() {
    if (!this.initialized) {
      throw new Error('Feature not initialized');
    }
    // Demo implementation
    return { success: true, timestamp: new Date().toISOString() };
  }
}

export default DemoFeature;
EOF

        git add "$FILE_NAME"

        # Create commit with co-author
        COMMIT_MSG="${commit_title}

${commit_body}

Co-authored-by: ${coauthor}"

        git commit --no-verify -m "$COMMIT_MSG" > /dev/null 2>&1

        # Push branch
        git push origin "$branch_name" > /dev/null 2>&1

        log_success "Created branch: $branch_name"
    done

    # Cleanup
    cd /tmp
    rm -rf "$TEMP_DIR"
}

#######################################################################
# Create Demo Pull Requests
#######################################################################
create_demo_prs() {
    # Get list of demo branches
    DEMO_BRANCH_LIST=$(gh_api "repos/${REPO_FULL}/branches?per_page=100" \
        --jq "[.[] | select(.name | startswith(\"${DEMO_BRANCH_PREFIX}\")) | .name] | .[]")

    while IFS= read -r branch_name; do
        [ -z "$branch_name" ] && continue

        # Extract feature name for PR title
        FEATURE_NAME=$(echo "$branch_name" | sed "s/${DEMO_BRANCH_PREFIX}//")
        PR_TITLE="[DEMO] $(echo "$FEATURE_NAME" | tr '/' ' ' | sed 's/\b\(.\)/\u\1/g')"

        # Create PR body
        PR_BODY="## Summary
This is a demo pull request showcasing team collaboration and AI-assisted development.

## Changes
- Implements ${FEATURE_NAME}
- Includes comprehensive error handling
- Adds unit tests for new functionality
- Updates documentation

## Test Plan
- ✅ Unit tests pass
- ✅ Integration tests pass
- ✅ Manual testing completed
- ✅ Code review by team

## AI Assistance
This PR was developed with AI pair programming tools to demonstrate modern development velocity.

---
🤖 Part of demo data - will be removed when transitioning to production."

        # Check if PR already exists
        EXISTING_PR=$(gh_api "repos/${REPO_FULL}/pulls?head=${REPO_OWNER}:${branch_name}" --jq '.[0].number' 2>/dev/null || echo "")

        if [ -z "$EXISTING_PR" ]; then
            PR_NUM=$(gh_api --method POST "repos/${REPO_FULL}/pulls" \
                -f title="$PR_TITLE" \
                -f body="$PR_BODY" \
                -f head="$branch_name" \
                -f base="main" \
                --jq '.number')

            log_success "Created PR #${PR_NUM}: $PR_TITLE"

            # Add labels
            gh_api --method POST "repos/${REPO_FULL}/issues/${PR_NUM}/labels" \
                -f labels='["demo:ai-assisted"]' > /dev/null

            # Randomly merge some PRs
            if [ $((RANDOM % 2)) -eq 0 ]; then
                sleep 2  # Avoid rate limiting
                gh_api --method PUT "repos/${REPO_FULL}/pulls/${PR_NUM}/merge" \
                    -f merge_method="squash" > /dev/null 2>&1 || log_warning "  → Could not merge PR #${PR_NUM}"
                log_info "  → Merged PR #${PR_NUM}"
            fi
        else
            log_warning "PR already exists for branch: $branch_name"
        fi

    done <<< "$DEMO_BRANCH_LIST"
}

#######################################################################
# Add Collaboration Data (Comments, Reviews)
#######################################################################
add_collaboration_data() {
    # Get all open demo PRs
    OPEN_PRS=$(gh_api "repos/${REPO_FULL}/pulls?state=open" --jq '.[].number')

    while IFS= read -r pr_num; do
        [ -z "$pr_num" ] && continue

        # Add review comments
        REVIEW_COMMENTS=(
            "LGTM! The error handling looks solid. Nice work using AI to generate the test cases."
            "Great implementation! The performance improvements are impressive. AI really helped optimize this."
            "Code quality is excellent. The AI-generated documentation is clear and comprehensive."
            "Approved! This follows our coding standards perfectly."
        )

        # Pick a random comment
        COMMENT="${REVIEW_COMMENTS[$((RANDOM % ${#REVIEW_COMMENTS[@]}))]}"

        gh_api --method POST "repos/${REPO_FULL}/issues/${pr_num}/comments" \
            -f body="$COMMENT" > /dev/null 2>&1 || log_warning "Could not add comment to PR #${pr_num}"

        log_success "Added review comment to PR #${pr_num}"

    done <<< "$OPEN_PRS"
}

#######################################################################
# CLEANUP: Remove all demo data
#######################################################################
cleanup_demo_data() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Cleaning Up Demo Data from ${REPO_FULL}"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    log_warning "This will remove ALL demo data including:"
    log_warning "  • Demo branches"
    log_warning "  • Demo issues (open and closed)"
    log_warning "  • Demo pull requests"
    log_warning "  • Demo labels"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi

    log_info "Step 1: Closing and deleting demo PRs..."
    cleanup_demo_prs

    log_info "Step 2: Deleting demo branches..."
    cleanup_demo_branches

    log_info "Step 3: Closing demo issues..."
    cleanup_demo_issues

    log_info "Step 4: Deleting demo labels..."
    cleanup_demo_labels

    echo ""
    log_success "Demo data cleanup complete!"
    echo ""
    show_status
}

cleanup_demo_prs() {
    # Get all PRs with demo label
    DEMO_PRS=$(gh_api "repos/${REPO_FULL}/pulls?state=all&per_page=100" \
        --jq "[.[] | select(.title | startswith(\"[DEMO]\")) | .number] | .[]")

    local count=0
    while IFS= read -r pr_num; do
        [ -z "$pr_num" ] && continue

        # Close PR
        gh_api --method PATCH "repos/${REPO_FULL}/pulls/${pr_num}" \
            -f state="closed" > /dev/null 2>&1

        log_success "Closed demo PR #${pr_num}"
        count=$((count + 1))
    done <<< "$DEMO_PRS"

    log_success "Closed $count demo PRs"
}

cleanup_demo_branches() {
    # Get all demo branches
    DEMO_BRANCHES=$(gh_api "repos/${REPO_FULL}/branches?per_page=100" \
        --jq "[.[] | select(.name | startswith(\"${DEMO_BRANCH_PREFIX}\")) | .name] | .[]")

    local count=0
    while IFS= read -r branch_name; do
        [ -z "$branch_name" ] && continue

        # Delete remote branch
        gh_api --method DELETE "repos/${REPO_FULL}/git/refs/heads/${branch_name}" > /dev/null 2>&1

        log_success "Deleted branch: $branch_name"
        count=$((count + 1))
    done <<< "$DEMO_BRANCHES"

    log_success "Deleted $count demo branches"
}

cleanup_demo_issues() {
    # Get all issues with demo labels
    DEMO_ISSUES=$(gh_api "repos/${REPO_FULL}/issues?state=all&per_page=100" \
        --jq "[.[] | select(.labels | any(.name | startswith(\"demo:\"))) | .number] | .[]")

    local count=0
    while IFS= read -r issue_num; do
        [ -z "$issue_num" ] && continue

        # Close issue
        gh_api --method PATCH "repos/${REPO_FULL}/issues/${issue_num}" \
            -f state="closed" \
            -f labels='[]' > /dev/null 2>&1

        log_success "Closed demo issue #${issue_num}"
        count=$((count + 1))
    done <<< "$DEMO_ISSUES"

    log_success "Closed $count demo issues"
}

cleanup_demo_labels() {
    # Get all demo labels
    DEMO_LABELS=$(gh_api "repos/${REPO_FULL}/labels?per_page=100" \
        --jq "[.[] | select(.name | startswith(\"${DEMO_LABEL_PREFIX}\")) | .name] | .[]")

    local count=0
    while IFS= read -r label_name; do
        [ -z "$label_name" ] && continue

        # Delete label
        gh_api --method DELETE "repos/${REPO_FULL}/labels/${label_name}" > /dev/null 2>&1

        log_success "Deleted label: $label_name"
        count=$((count + 1))
    done <<< "$DEMO_LABELS"

    log_success "Deleted $count demo labels"
}

#######################################################################
# Main Script
#######################################################################
main() {
    case "${1:-}" in
        populate)
            populate_demo_data
            ;;
        cleanup)
            cleanup_demo_data
            ;;
        status)
            show_status
            ;;
        *)
            echo "Usage: $0 {populate|cleanup|status}"
            echo ""
            echo "Commands:"
            echo "  populate    Add realistic demo data to the repository"
            echo "  cleanup     Remove all demo data from the repository"
            echo "  status      Show current demo data statistics"
            echo ""
            exit 1
            ;;
    esac
}

main "$@"
