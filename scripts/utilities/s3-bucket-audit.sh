#!/bin/bash
# S3 Bucket Audit Script
# Analyzes all buckets and categorizes them for cleanup

echo "🔍 S3 Bucket Audit Report"
echo "=========================="
echo ""

# Count total buckets
TOTAL=$(aws s3 ls | wc -l)
echo "📦 Total Buckets: $TOTAL"
echo ""

# Categorize buckets
echo "📊 Bucket Categories:"
echo ""

# Test buckets
TEST_COUNT=$(aws s3 ls | grep -i "test" | wc -l)
echo "  🧪 Test Buckets: $TEST_COUNT"
aws s3 ls | grep -i "test" | awk '{print "     - " $3}'
echo ""

# Armyknife buckets
ARMYKNIFE_COUNT=$(aws s3 ls | grep -i "armyknife" | wc -l)
echo "  🔪 Armyknife Buckets: $ARMYKNIFE_COUNT"
echo ""

# ACME Corp buckets
ACME_COUNT=$(aws s3 ls | grep -i "acme" | wc -l)
echo "  🏢 ACME Corp Buckets: $ACME_COUNT"
echo ""

# AI Orchestration buckets
AI_COUNT=$(aws s3 ls | grep -i "ai-orchestration" | wc -l)
echo "  🤖 AI Orchestration Buckets: $AI_COUNT"
echo ""

# VSCode buckets
VSCODE_COUNT=$(aws s3 ls | grep -i "vscode" | wc -l)
echo "  📝 VSCode Buckets: $VSCODE_COUNT"
echo ""

# SSO buckets
SSO_COUNT=$(aws s3 ls | grep -i "sso" | wc -l)
echo "  🔐 SSO Buckets: $SSO_COUNT"
echo ""

echo "================================"
echo "💾 Bucket Size Analysis (top 10)"
echo "================================"
echo ""

# Get sizes for all buckets (this may take a while)
aws s3 ls | awk '{print $3}' | while read bucket; do
  SIZE=$(aws s3 ls s3://$bucket --recursive --summarize 2>/dev/null | grep "Total Size" | awk '{print $3}')
  if [ -n "$SIZE" ]; then
    echo "$SIZE $bucket"
  fi
done | sort -rn | head -10 | awk '{
  size = $1
  bucket = $2
  if (size > 1073741824) {
    printf "  %.2f GB - %s\n", size/1073741824, bucket
  } else if (size > 1048576) {
    printf "  %.2f MB - %s\n", size/1048576, bucket
  } else if (size > 1024) {
    printf "  %.2f KB - %s\n", size/1024, bucket
  } else {
    printf "  %d bytes - %s\n", size, bucket
  }
}'

echo ""
echo "================================"
echo "🗑️  Recommended Actions"
echo "================================"
echo ""
echo "1. Delete test buckets: $TEST_COUNT buckets"
echo "2. Consolidate armyknife buckets: $ARMYKNIFE_COUNT buckets"
echo "3. Archive ACME Corp buckets: $ACME_COUNT buckets"
echo "4. Review SSO buckets: $SSO_COUNT buckets"
echo ""
echo "💡 Run with --delete-tests to remove all test buckets"
