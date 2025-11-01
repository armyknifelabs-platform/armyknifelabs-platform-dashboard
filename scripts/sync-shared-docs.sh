#!/bin/bash
#
# Verify and sync shared documentation folder
# This script ensures the NFS-mounted shared-docs folder is accessible
# in both local development and CI/CD environments.
#

set -euo pipefail

SHARED_DOCS_PATH="/media/developer/Backup02/docs"
SYMLINK_NAME="shared-docs"

echo "🔍 Verifying shared documentation access..."

# Check if we're in CI environment
if [ "${CI:-false}" = "true" ]; then
  echo "ℹ️  Running in CI environment"

  # In CI, we might need to mount the NFS share or use alternative approach
  # For now, we'll skip the check in CI and document this requirement
  if [ ! -d "$SHARED_DOCS_PATH" ]; then
    echo "⚠️  Shared docs not available in CI - this is expected"
    echo "    CI workflows will document results locally and sync later"
    exit 0
  fi
fi

# Check if NFS mount exists
if [ ! -d "$SHARED_DOCS_PATH" ]; then
  echo "❌ ERROR: Shared documentation folder not found at $SHARED_DOCS_PATH"
  echo "    Please ensure the NFS share is mounted."
  echo ""
  echo "    To mount manually:"
  echo "    sudo mount -t nfs <nfs-server>:/docs $SHARED_DOCS_PATH"
  exit 1
fi

# Check if symbolic link exists
if [ -L "$SYMLINK_NAME" ]; then
  # Verify it points to the correct location
  CURRENT_TARGET=$(readlink -f "$SYMLINK_NAME")
  EXPECTED_TARGET=$(readlink -f "$SHARED_DOCS_PATH")

  if [ "$CURRENT_TARGET" = "$EXPECTED_TARGET" ]; then
    echo "✅ Symbolic link already exists and points to correct location"
  else
    echo "⚠️  Symbolic link points to wrong location: $CURRENT_TARGET"
    echo "    Removing and recreating..."
    rm "$SYMLINK_NAME"
    ln -s "$SHARED_DOCS_PATH" "$SYMLINK_NAME"
    echo "✅ Symbolic link recreated"
  fi
elif [ -e "$SYMLINK_NAME" ]; then
  echo "❌ ERROR: '$SYMLINK_NAME' exists but is not a symbolic link"
  echo "    Please remove it manually and re-run this script"
  exit 1
else
  echo "📁 Creating symbolic link: $SYMLINK_NAME -> $SHARED_DOCS_PATH"
  ln -s "$SHARED_DOCS_PATH" "$SYMLINK_NAME"
  echo "✅ Symbolic link created"
fi

# Verify access to key documentation files
echo ""
echo "🔍 Verifying access to key documentation files..."

REQUIRED_DOCS=(
  "README_SHARED_DOCS.md"
  "PROMOTION_WORKFLOW.md"
  "PRODUCTION_READINESS.md"
)

MISSING_DOCS=()

for doc in "${REQUIRED_DOCS[@]}"; do
  if [ -f "$SYMLINK_NAME/$doc" ]; then
    echo "  ✅ $doc"
  else
    echo "  ❌ $doc (missing)"
    MISSING_DOCS+=("$doc")
  fi
done

if [ ${#MISSING_DOCS[@]} -gt 0 ]; then
  echo ""
  echo "⚠️  Warning: ${#MISSING_DOCS[@]} required documentation file(s) missing"
  echo "    This may indicate an incomplete shared-docs setup"
fi

# Count total documentation files
DOC_COUNT=$(find "$SYMLINK_NAME" -name "*.md" -type f 2>/dev/null | wc -l)
echo ""
echo "📊 Total documentation files available: $DOC_COUNT"

# Calculate total lines of documentation
if command -v wc &> /dev/null; then
  TOTAL_LINES=$(find "$SYMLINK_NAME" -name "*.md" -type f -exec cat {} \; 2>/dev/null | wc -l)
  echo "📝 Total lines of documentation: $TOTAL_LINES"
fi

echo ""
echo "✅ Shared documentation verification complete!"
echo ""
echo "Usage examples:"
echo "  - Read a doc:     cat shared-docs/PROMOTION_WORKFLOW.md"
echo "  - Search docs:    grep -r 'deployment' shared-docs/"
echo "  - List recent:    ls -lt shared-docs/ | head -10"
echo "  - Update doc:     echo 'content' >> shared-docs/DEPLOYMENT_HISTORY.md"
