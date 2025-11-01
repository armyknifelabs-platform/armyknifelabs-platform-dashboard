#!/bin/bash
# Delete versioned S3 buckets script

echo "🗑️  Deleting remaining versioned buckets"
echo "========================================"
echo ""

# List of buckets to delete
BUCKETS=(
  "acme-corp-prod-backups"
  "acme-corp-prod-data"
  "acme-corp-prod-logs"
  "ai-orchestration-terraform-state-241533127046"
  "armyknife-roaming-profiles-test"
)

for BUCKET in "${BUCKETS[@]}"; do
  echo "Processing: $BUCKET"

  # 1. Suspend versioning
  aws s3api put-bucket-versioning --bucket $BUCKET --versioning-configuration Status=Suspended 2>/dev/null || echo "  ⚠️  Versioning not enabled"

  # 2. Delete all object versions
  aws s3api delete-objects --bucket $BUCKET \
    --delete "$(aws s3api list-object-versions --bucket $BUCKET \
    --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --max-items 1000)" 2>/dev/null || echo "  No versions"

  # 3. Delete all delete markers
  aws s3api delete-objects --bucket $BUCKET \
    --delete "$(aws s3api list-object-versions --bucket $BUCKET \
    --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --max-items 1000)" 2>/dev/null || echo "  No delete markers"

  # 4. Delete bucket
  if aws s3 rb s3://$BUCKET 2>/dev/null; then
    echo "  ✅ Deleted: $BUCKET"
  else
    echo "  ❌ Failed: $BUCKET"
  fi
  echo ""
done

echo "✅ Complete! Remaining buckets:"
aws s3 ls | wc -l | xargs echo "  Count:"
