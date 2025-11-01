#!/bin/bash

######################################################################
# Add PR Comments and Reviews for Collaboration Simulation
######################################################################

set -e

REPO_OWNER="armyknife-tools"
REPO_NAME="github-metrics-demo"
REPO_FULL="${REPO_OWNER}/${REPO_NAME}"

if [ -z "$GH_TOKEN" ]; then
    echo "Error: GH_TOKEN not set"
    exit 1
fi

# Get all open PRs
OPEN_PRS=$(/opt/homebrew/bin/gh api "repos/${REPO_FULL}/pulls?state=open" --jq '.[].number')

# Comment templates
declare -a REVIEW_COMMENTS=(
    "LGTM! 🚀 The implementation looks solid. Really impressed with how AI helped us scaffold this quickly. The test coverage is excellent."
    "Great work! The error handling is comprehensive and the performance improvements are significant. AI-assisted development really shows in the code quality."
    "Approved! This follows our coding standards perfectly. The AI-generated documentation is particularly well-written."
    "Looks good to me! The refactoring makes the code much more maintainable. Nice use of modern patterns."
    "Excellent implementation! The integration tests cover all the edge cases. Ready to merge once CI passes."
    "Solid PR! The performance benchmarks show significant improvements. This will really help with our scaling issues."
)

declare -a REVIEW_QUESTIONS=(
    "Quick question: Have we considered the impact on backward compatibility? Otherwise looks great!"
    "This looks fantastic! One thought - should we add rate limiting to this endpoint as well?"
    "Great work! Could you add a note about the migration strategy in the PR description?"
    "Love the comprehensive error handling! Should we also add metrics for these error cases?"
)

declare -a APPROVAL_COMMENTS=(
    "Approved! ✅ Ready for production deployment."
    "LGTM! Merging after CI passes."
    "Looks perfect! Great job on this feature."
    "Approved! This is exactly what we needed."
)

echo "Adding collaboration comments to open PRs..."
echo ""

pr_count=0
while IFS= read -r pr_num; do
    [ -z "$pr_num" ] && continue

    echo "PR #${pr_num}:"

    # Get PR details
    PR_TITLE=$(/opt/homebrew/bin/gh api "repos/${REPO_FULL}/pulls/${pr_num}" --jq '.title')

    # Add 2-3 comments per PR
    num_comments=$((2 + RANDOM % 2))

    for ((i=0; i<num_comments; i++)); do
        if [ $i -eq 0 ]; then
            # First comment is usually a review
            COMMENT="${REVIEW_COMMENTS[$((RANDOM % ${#REVIEW_COMMENTS[@]}))]}"
        elif [ $i -eq 1 ] && [ $((RANDOM % 2)) -eq 0 ]; then
            # Sometimes add a question
            COMMENT="${REVIEW_QUESTIONS[$((RANDOM % ${#REVIEW_QUESTIONS[@]}))]}"
        else
            # Final comment is approval
            COMMENT="${APPROVAL_COMMENTS[$((RANDOM % ${#APPROVAL_COMMENTS[@]}))]}"
        fi

        # Add comment
        /opt/homebrew/bin/gh api --method POST "repos/${REPO_FULL}/issues/${pr_num}/comments" \
            --input - <<< "{\"body\": \"$COMMENT\"}" > /dev/null 2>&1

        echo "  ✓ Added comment: ${COMMENT:0:50}..."

        sleep 0.5  # Rate limiting
    done

    # Add PR review (approved) for some PRs
    if [ $((RANDOM % 2)) -eq 0 ]; then
        REVIEW_BODY="Code review complete. This PR demonstrates excellent use of AI pair programming. The code quality is high and tests are comprehensive."

        /opt/homebrew/bin/gh api --method POST "repos/${REPO_FULL}/pulls/${pr_num}/reviews" \
            --input - <<< "{\"event\": \"APPROVE\", \"body\": \"$REVIEW_BODY\"}" > /dev/null 2>&1 || true

        echo "  ✓ Added approval review"
    fi

    echo ""
    pr_count=$((pr_count + 1))
done <<< "$OPEN_PRS"

echo "Added collaboration data to $pr_count open PRs!"
