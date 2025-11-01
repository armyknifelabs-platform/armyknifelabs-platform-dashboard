#!/bin/bash
# Delete All S3 Test Buckets Script
# WARNING: This will delete ALL buckets and their contents

set -e

echo "⚠️  S3 Bucket Cleanup - DELETE ALL BUCKETS"
echo "=========================================="
echo ""
echo "This will DELETE all 93 S3 buckets and their contents."
echo ""

# Prompt for confirmation
read -p "Are you ABSOLUTELY SURE you want to delete ALL buckets? (type 'DELETE ALL' to confirm): " CONFIRM

if [ "$CONFIRM" != "DELETE ALL" ]; then
  echo "❌ Aborted. No buckets were deleted."
  exit 1
fi

echo ""
echo "🗑️  Starting bucket deletion..."
echo ""

DELETED=0
FAILED=0

# Get all buckets
aws s3 ls | awk '{print $3}' | while read BUCKET; do
  echo "  Deleting: $BUCKET"

  # Try to empty and delete bucket
  if aws s3 rb s3://$BUCKET --force 2>/dev/null; then
    echo "    ✅ Deleted: $BUCKET"
    DELETED=$((DELETED + 1))
  else
    echo "    ❌ Failed: $BUCKET"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "================================"
echo "✅ Cleanup Complete"
echo "================================"
echo "  Deleted: $DELETED buckets"
echo "  Failed: $FAILED buckets"
echo ""
echo "Remaining buckets:"
aws s3 ls
