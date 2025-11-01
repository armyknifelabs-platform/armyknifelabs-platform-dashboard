#!/bin/bash
# Fast S3 Bucket Deletion Script
# Uses GNU parallel for faster deletion

echo "🚀 Fast S3 Bucket Cleanup"
echo "========================"
echo ""

# Count buckets
TOTAL=$(aws s3 ls | wc -l | tr -d ' ')
echo "📦 Found $TOTAL buckets to delete"
echo ""

# Final confirmation
read -p "⚠️  Type 'yes' to DELETE ALL $TOTAL buckets: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Cancelled"
  exit 1
fi

echo ""
echo "🗑️  Deleting buckets..."
echo ""

# Export function for parallel execution
delete_bucket() {
  BUCKET=$1
  echo "  Deleting: $BUCKET"

  # Delete all objects first (faster than --force)
  aws s3 rm s3://$BUCKET --recursive --quiet 2>/dev/null || true

  # Delete bucket
  if aws s3 rb s3://$BUCKET 2>/dev/null; then
    echo "    ✅ $BUCKET"
    return 0
  else
    echo "    ❌ $BUCKET (may have versioning enabled)"
    return 1
  fi
}

export -f delete_bucket

# Get all bucket names and delete in parallel (8 at a time)
aws s3 ls | awk '{print $3}' | xargs -P 8 -I {} bash -c 'delete_bucket "$@"' _ {}

echo ""
echo "✅ Deletion complete!"
echo ""
echo "Remaining buckets:"
aws s3 ls | wc -l | xargs echo "  Count:"
