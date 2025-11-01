#!/bin/bash
#
# Version Synchronization Script
# Synchronizes version tags across all three component repositories
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
VERSION_FILE="VERSION.json"
ORG_NAME="${GITHUB_ORG:-armyknifelabs-platform}"

# Function to print colored output
print_info() {
  echo -e "${GREEN}ℹ️  $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
}

# Function to check if jq is installed
check_dependencies() {
  if ! command -v jq &> /dev/null; then
    print_error "jq is required but not installed"
    echo "Install with: sudo apt-get install jq (Ubuntu) or brew install jq (macOS)"
    exit 1
  fi

  if ! command -v git &> /dev/null; then
    print_error "git is required but not installed"
    exit 1
  fi
}

# Function to validate VERSION.json
validate_version_file() {
  if [ ! -f "$VERSION_FILE" ]; then
    print_error "VERSION.json not found in current directory"
    exit 1
  fi

  # Validate JSON syntax
  if ! jq empty "$VERSION_FILE" 2>/dev/null; then
    print_error "VERSION.json is not valid JSON"
    exit 1
  fi

  print_info "VERSION.json validated successfully"
}

# Function to extract component information
extract_component_info() {
  local component=$1

  COMMIT=$(jq -r ".components.$component.commit" "$VERSION_FILE")
  REPO=$(jq -r ".components.$component.repository" "$VERSION_FILE")

  if [ "$COMMIT" = "null" ] || [ -z "$COMMIT" ]; then
    print_error "Missing commit for component: $component"
    exit 1
  fi

  if [ "$REPO" = "null" ] || [ -z "$REPO" ]; then
    print_error "Missing repository for component: $component"
    exit 1
  fi

  echo "$COMMIT|$REPO"
}

# Function to create git tag in a repository
create_tag_in_repo() {
  local component=$1
  local version=$2
  local commit=$3
  local repo=$4

  print_info "Tagging $component ($repo) at commit $commit with $version"

  # Clone repository (shallow clone for speed)
  local tmp_dir=$(mktemp -d)

  if ! git clone --quiet --depth 50 "https://github.com/$ORG_NAME/$repo.git" "$tmp_dir"; then
    print_error "Failed to clone $repo"
    rm -rf "$tmp_dir"
    return 1
  fi

  cd "$tmp_dir"

  # Fetch the specific commit if not in shallow clone
  if ! git cat-file -e "$commit" 2>/dev/null; then
    print_warning "Commit $commit not found in shallow clone, fetching..."
    git fetch --depth 100
  fi

  # Verify commit exists
  if ! git cat-file -e "$commit" 2>/dev/null; then
    print_error "Commit $commit does not exist in $repo"
    cd - > /dev/null
    rm -rf "$tmp_dir"
    return 1
  fi

  # Create annotated tag
  local description=$(jq -r ".description" "../$VERSION_FILE")
  git tag -a "$version" "$commit" -m "Release $version: $description" || {
    print_warning "Tag $version may already exist in $repo"
  }

  # Push tag (requires authentication)
  if [ "${DRY_RUN:-false}" = "false" ]; then
    if git push origin "$version" 2>/dev/null; then
      print_info "✅ Tagged $repo with $version"
    else
      print_warning "Could not push tag to $repo (may already exist)"
    fi
  else
    print_info "DRY RUN: Would push tag $version to $repo"
  fi

  cd - > /dev/null
  rm -rf "$tmp_dir"
}

# Function to update VERSION.json metadata
update_version_metadata() {
  local version=$1
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  jq --arg timestamp "$timestamp" \
     --arg version "$version" \
     '.deployment.lastDeployedAt = $timestamp | .metadata.buildNumber = null' \
     "$VERSION_FILE" > "${VERSION_FILE}.tmp"

  mv "${VERSION_FILE}.tmp" "$VERSION_FILE"

  print_info "Updated VERSION.json metadata"
}

# Main script
main() {
  print_info "Starting version synchronization..."

  # Check dependencies
  check_dependencies

  # Validate VERSION.json
  validate_version_file

  # Extract version
  VERSION=$(jq -r '.release' "$VERSION_FILE")

  if [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then
    print_error "Missing or invalid release version in VERSION.json"
    exit 1
  fi

  print_info "Synchronizing version: $VERSION"

  # Extract component information
  COMPONENTS=("database" "backend" "frontend")

  for component in "${COMPONENTS[@]}"; do
    print_info "Processing component: $component"

    INFO=$(extract_component_info "$component")
    COMMIT=$(echo "$INFO" | cut -d'|' -f1)
    REPO=$(echo "$INFO" | cut -d'|' -f2)

    create_tag_in_repo "$component" "$VERSION" "$COMMIT" "$REPO"
  done

  # Update metadata
  if [ "${DRY_RUN:-false}" = "false" ]; then
    update_version_metadata "$VERSION"
  fi

  print_info "✅ Version synchronization complete!"

  # Log to shared docs if available
  if [ -f "shared-docs/DEPLOYMENT_HISTORY.md" ]; then
    echo "" >> shared-docs/DEPLOYMENT_HISTORY.md
    echo "---" >> shared-docs/DEPLOYMENT_HISTORY.md
    echo "**Version Sync: $VERSION**" >> shared-docs/DEPLOYMENT_HISTORY.md
    echo "- Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> shared-docs/DEPLOYMENT_HISTORY.md
    echo "- Components: database, backend, frontend" >> shared-docs/DEPLOYMENT_HISTORY.md
    echo "- Status: Synchronized" >> shared-docs/DEPLOYMENT_HISTORY.md
    echo "---" >> shared-docs/DEPLOYMENT_HISTORY.md

    print_info "Logged to shared-docs/DEPLOYMENT_HISTORY.md"
  fi
}

# Usage information
usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Synchronizes version tags across all component repositories based on VERSION.json

Options:
  --dry-run       Show what would be done without making changes
  --help          Show this help message

Environment Variables:
  GITHUB_ORG      GitHub organization name (default: armyknifelabs-platform)
  DRY_RUN         Set to 'true' for dry-run mode

Example:
  $0
  $0 --dry-run
  GITHUB_ORG=myorg $0

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      export DRY_RUN=true
      print_warning "DRY RUN MODE - No changes will be made"
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      print_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Run main function
main
