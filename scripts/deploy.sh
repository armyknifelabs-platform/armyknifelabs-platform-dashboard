#!/bin/bash
set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  SEIP Portal - Automated Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check for uncommitted changes
echo -e "${BLUE}Step 1: Checking git status...${NC}"
cd "$PROJECT_DIR"

if [[ -n $(git status -s) ]]; then
    echo -e "${YELLOW}Uncommitted changes detected:${NC}"
    git status -s
    echo ""
else
    echo -e "${YELLOW}No uncommitted changes. Use this script after making changes.${NC}"
    echo -e "${CYAN}Current version: $(git describe --tags --abbrev=0 2>/dev/null || echo 'No tags yet')${NC}"
    echo ""
    read -p "Do you want to continue with current state? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Step 2: Get current version and calculate next version
echo -e "\n${BLUE}Step 2: Calculating next version...${NC}"

# Get the latest tag (e.g., v1.0.5)
CURRENT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")
echo -e "Current version: ${GREEN}${CURRENT_TAG}${NC}"

# Extract version numbers
VERSION_REGEX="v([0-9]+)\.([0-9]+)\.([0-9]+)"
if [[ $CURRENT_TAG =~ $VERSION_REGEX ]]; then
    MAJOR="${BASH_REMATCH[1]}"
    MINOR="${BASH_REMATCH[2]}"
    PATCH="${BASH_REMATCH[3]}"
else
    MAJOR=1
    MINOR=0
    PATCH=0
fi

# Calculate next versions
NEXT_PATCH="v${MAJOR}.${MINOR}.$((PATCH + 1))"
NEXT_MINOR="v${MAJOR}.$((MINOR + 1)).0"
NEXT_MAJOR="v$((MAJOR + 1)).0.0"

echo ""
echo -e "${CYAN}Choose version increment:${NC}"
echo -e "  ${GREEN}1${NC}) Patch (bug fixes):      ${CURRENT_TAG} → ${YELLOW}${NEXT_PATCH}${NC}"
echo -e "  ${GREEN}2${NC}) Minor (new features):   ${CURRENT_TAG} → ${YELLOW}${NEXT_MINOR}${NC}"
echo -e "  ${GREEN}3${NC}) Major (breaking):       ${CURRENT_TAG} → ${YELLOW}${NEXT_MAJOR}${NC}"
echo -e "  ${GREEN}4${NC}) Custom version"
echo ""

read -p "Select option (1-4): " -n 1 -r VERSION_CHOICE
echo ""

case $VERSION_CHOICE in
    1)
        NEW_VERSION=$NEXT_PATCH
        VERSION_TYPE="patch"
        ;;
    2)
        NEW_VERSION=$NEXT_MINOR
        VERSION_TYPE="minor"
        ;;
    3)
        NEW_VERSION=$NEXT_MAJOR
        VERSION_TYPE="major"
        ;;
    4)
        read -p "Enter custom version (e.g., v1.2.3): " NEW_VERSION
        if [[ ! $NEW_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo -e "${RED}Invalid version format. Must be vX.Y.Z${NC}"
            exit 1
        fi
        VERSION_TYPE="custom"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "New version: ${GREEN}${NEW_VERSION}${NC} (${VERSION_TYPE})"
echo ""

# Step 3: Get commit message
echo -e "${BLUE}Step 3: Creating commit...${NC}"
echo ""
echo -e "${CYAN}What changed in this release?${NC}"
read -p "Enter commit message: " COMMIT_MESSAGE

if [[ -z "$COMMIT_MESSAGE" ]]; then
    echo -e "${RED}Commit message cannot be empty${NC}"
    exit 1
fi

# Determine commit type based on version increment
case $VERSION_TYPE in
    patch)
        COMMIT_PREFIX="fix"
        ;;
    minor)
        COMMIT_PREFIX="feat"
        ;;
    major)
        COMMIT_PREFIX="feat!"
        ;;
    custom)
        COMMIT_PREFIX="release"
        ;;
esac

FULL_COMMIT_MESSAGE="${COMMIT_PREFIX}: ${COMMIT_MESSAGE}

Version: ${NEW_VERSION}
"

# Step 4: Run local build and tests
echo -e "\n${BLUE}Step 4: Building and testing locally...${NC}"
echo ""

"${SCRIPT_DIR}/build-and-test.sh" "${NEW_VERSION}"

if [ $? -ne 0 ]; then
    echo -e "${RED}Build or tests failed. Aborting deployment.${NC}"
    exit 1
fi

# Step 5: Update task definitions with new version
echo -e "\n${BLUE}Step 5: Updating task definitions...${NC}"

# Update backend task definition
BACKEND_TASK_DEF="${PROJECT_DIR}/aws/task-definition-backend.json"
if [ -f "$BACKEND_TASK_DEF" ]; then
    # Use jq to update the image tag
    TMP_FILE=$(mktemp)
    jq --arg version "$NEW_VERSION" \
        '.containerDefinitions[0].image = "241533127046.dkr.ecr.us-east-1.amazonaws.com/seip-backend:" + $version' \
        "$BACKEND_TASK_DEF" > "$TMP_FILE"
    mv "$TMP_FILE" "$BACKEND_TASK_DEF"
    echo -e "${GREEN}✓ Updated backend task definition${NC}"
else
    echo -e "${YELLOW}⚠ Backend task definition not found${NC}"
fi

# Update frontend task definition
FRONTEND_TASK_DEF="${PROJECT_DIR}/aws/task-definition-frontend.json"
if [ -f "$FRONTEND_TASK_DEF" ]; then
    TMP_FILE=$(mktemp)
    jq --arg version "$NEW_VERSION" \
        '.containerDefinitions[0].image = "241533127046.dkr.ecr.us-east-1.amazonaws.com/seip-frontend:" + $version' \
        "$FRONTEND_TASK_DEF" > "$TMP_FILE"
    mv "$TMP_FILE" "$FRONTEND_TASK_DEF"
    echo -e "${GREEN}✓ Updated frontend task definition${NC}"
else
    echo -e "${YELLOW}⚠ Frontend task definition not found${NC}"
fi

# Step 6: Git operations
echo -e "\n${BLUE}Step 6: Committing and tagging...${NC}"

# Stage all changes
git add -A

# Check if there are changes to commit
if git diff --cached --quiet; then
    echo -e "${YELLOW}No changes to commit${NC}"
else
    # Commit
    git commit -m "$FULL_COMMIT_MESSAGE"
    echo -e "${GREEN}✓ Changes committed${NC}"
fi

# Create tag
git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION: $COMMIT_MESSAGE"
echo -e "${GREEN}✓ Tag created: ${NEW_VERSION}${NC}"

# Step 7: Confirmation before push
echo -e "\n${BLUE}Step 7: Ready to deploy${NC}"
echo ""
echo -e "${CYAN}Summary:${NC}"
echo -e "  Version:  ${GREEN}${NEW_VERSION}${NC}"
echo -e "  Message:  ${COMMIT_MESSAGE}"
echo -e "  Branch:   $(git branch --show-current)"
echo -e "  Remote:   $(git remote get-url origin 2>/dev/null || echo 'No remote')"
echo ""
echo -e "${YELLOW}This will:${NC}"
echo -e "  1. Push commits to GitHub"
echo -e "  2. Push tag ${NEW_VERSION} to GitHub"
echo -e "  3. Trigger GitHub Actions workflow"
echo -e "  4. Build Docker images (linux/amd64)"
echo -e "  5. Push images to ECR"
echo -e "  6. Deploy to ECS cluster ${GREEN}seip-prod${NC}"
echo -e "  7. Update services: ${GREEN}seip-backend${NC} and ${GREEN}seip-frontend${NC}"
echo ""

read -p "Continue with deployment? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled.${NC}"
    echo -e "${CYAN}To undo the local commit and tag:${NC}"
    echo -e "  git reset HEAD~1"
    echo -e "  git tag -d ${NEW_VERSION}"
    exit 0
fi

# Step 8: Push to GitHub
echo -e "\n${BLUE}Step 8: Pushing to GitHub...${NC}"

# Push commits
git push origin $(git branch --show-current)
echo -e "${GREEN}✓ Commits pushed${NC}"

# Push tag
git push origin "$NEW_VERSION"
echo -e "${GREEN}✓ Tag pushed${NC}"

# Success!
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ Deployment Initiated!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Version ${GREEN}${NEW_VERSION}${NC} has been pushed to GitHub."
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "  1. Monitor GitHub Actions: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/actions"
echo -e "  2. Watch ECS deployment progress in AWS Console"
echo -e "  3. Verify deployment: ${GREEN}https://seip.armyknifelabs.com${NC}"
echo ""
echo -e "${YELLOW}Estimated deployment time: 5-10 minutes${NC}"
echo ""

exit 0
