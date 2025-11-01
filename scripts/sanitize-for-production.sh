#!/bin/bash
set -e

echo "🧹 Production Sanitization Script"
echo "=================================="
echo ""
echo "This script will:"
echo "1. Remove all Claude/Claude Code references"
echo "2. Sanitize documentation (replace real tokens with placeholders)"
echo "3. Organize files into proper directories"
echo "4. Set up pre-commit hooks"
echo "5. Prepare for clean initial commit"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Navigate to project root
cd "$(dirname "$0")/.."

echo ""
echo "📝 Step 1: Remove Claude/Claude Code references"
echo "================================================"

# List of files to sanitize
FILES_TO_SANITIZE=(
    "docs/GH_ARCHIVE_VISIBILITY_CHECK.md"
    "docs/AWS_DEVELOPMENT_WORKFLOW.md"
    "docs/AWS_ELASTICACHE_SSM_TUNNEL_COMPLETE_GUIDE.md"
    "docs/AWS_INTEGRATION_SETUP.md"
    "docs/architecture/GITHUB_METRICS_COMPLETE.md"
    "docs/sessions/SESSION_HANDOFF_OCT18_EVENING.md"
    "docs/AWS_RDS_PUBLIC_ACCESS_FIX.md"
    "docs/implementation/PERSISTENT_NOTIFICATION_HEADER.md"
    "docs/implementation/UX_IMPROVEMENTS_TIMEOUT_HANDLING.md"
    "docs/implementation/SECURITY_IMPLEMENTATION_COMPLETE.md"
    "docs/packages/backend/IMPLEMENTATION_SUMMARY.md"
    "docs/PRODUCTION_READINESS_ANALYSIS.md"
    "docs/SSM_ELASTICACHE_TUNNEL_SETUP.md"
    "docs/phases/PHASE_3_SPRINT_1_BACKEND_COMPLETE.md"
    "docs/phases/PHASE_2_COMPLETE.md"
    "docs/phases/PHASE_3_SPRINT_1_COMPLETE.md"
    "docs/phases/PHASE_3_PLAN.md"
    "docs/reports/TEST_RESULTS.md"
    "packages/backend/IMPLEMENTATION_SUMMARY.md"
    "CLAUDE.md"
)

for file in "${FILES_TO_SANITIZE[@]}"; do
    if [ -f "$file" ]; then
        echo "  Sanitizing: $file"

        # Remove Claude Code references
        sed -i '' 's/Claude Code/AI Assistant/g' "$file"
        sed -i '' 's/claude-code/ai-assistant/g' "$file"

        # Remove specific attribution lines
        sed -i '' '/\*\*Author\*\*:.*Claude/d' "$file"
        sed -i '' '/\*\*Developer\*\*:.*Claude/d' "$file"
        sed -i '' '/\*\*Implemented By\*\*:.*Claude/d' "$file"
        sed -i '' '/\*\*Built By\*\*:.*Claude/d' "$file"
        sed -i '' '/\*\*Analyst\*\*:.*Claude/d' "$file"
        sed -i '' '/\*\*Tester\*\*:.*Claude/d' "$file"
        sed -i '' '/\*\*Team\*\*:.*Claude/d' "$file"
        sed -i '' '/\*\*Contact\*\*:.*Claude/d' "$file"
        sed -i '' '/\*By:.*Claude/d' "$file"

        # Remove "Generated with Claude Code" footers
        sed -i '' '/🤖 Generated with.*Claude/d' "$file"
        sed -i '' '/Generated with.*Claude/d' "$file"

        # Keep "Claude 3.5 Sonnet" references (it's the AI model name, legitimate)
        # No changes needed for "Claude 3.5 Sonnet" or "Anthropic Claude"
    fi
done

echo "  ✅ Claude references removed"
echo ""

echo "🔐 Step 2: Sanitize secrets in documentation"
echo "============================================="

# Replace the exposed GitHub token with placeholder
EXPOSED_TOKEN="<REDACTED_GITHUB_TOKEN>"
PLACEHOLDER="<YOUR_GITHUB_TOKEN>"

for file in docs/**/*.md; do
    if [ -f "$file" ] && grep -q "$EXPOSED_TOKEN" "$file" 2>/dev/null; then
        echo "  Sanitizing token in: $file"
        sed -i '' "s/$EXPOSED_TOKEN/$PLACEHOLDER/g" "$file"
    fi
done

echo "  ✅ Secrets sanitized"
echo ""

echo "📁 Step 3: Organize files into proper directories"
echo "=================================================="

# Create directories if they don't exist
mkdir -p scripts
mkdir -p data
mkdir -p docs/archive

# Move standalone scripts to scripts/
echo "  Moving scripts..."
find . -maxdepth 1 -name "*.sh" ! -name "setup.sh" -exec mv {} scripts/ \; 2>/dev/null || true

# Move JSON data files to data/ (excluding package.json, tsconfig.json, etc.)
echo "  Moving data files..."
find . -maxdepth 1 -name "*-data.json" -exec mv {} data/ \; 2>/dev/null || true
find . -maxdepth 1 -name "*_data.json" -exec mv {} data/ \; 2>/dev/null || true

# Archive old/redundant docs
echo "  Archiving redundant docs..."
if [ -f "docs/DEPLOYMENT_PROGRESS.md" ]; then
    mv docs/DEPLOYMENT_PROGRESS.md docs/archive/ 2>/dev/null || true
fi

echo "  ✅ Files organized"
echo ""

echo "🔒 Step 4: Set up pre-commit hooks"
echo "==================================="

# Check if pre-commit is installed
if ! command -v pre-commit &> /dev/null; then
    echo "  Installing pre-commit..."
    pip3 install pre-commit detect-secrets || pip install pre-commit detect-secrets
fi

# Create pre-commit configuration
cat > .pre-commit-config.yaml <<'YAML'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
        args: ['--maxkb=1000']
      - id: check-merge-conflict
      - id: detect-private-key

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
        exclude: |
          (?x)^(
              pnpm-lock.yaml|
              package-lock.json|
              .*\.lock|
              \.git/.*
          )$
YAML

# Initialize secrets baseline
echo "  Initializing secrets baseline..."
detect-secrets scan --exclude-files 'pnpm-lock.yaml|package-lock.json|node_modules/.*|\.git/.*' > .secrets.baseline

# Install hooks
echo "  Installing pre-commit hooks..."
pre-commit install

echo "  ✅ Pre-commit hooks installed"
echo ""

echo "✅ Step 5: Verify clean state"
echo "=============================="

# Check for remaining secrets
echo "  Checking for secrets in tracked files..."
if git ls-files | xargs grep -E "(ghp_[a-zA-Z0-9]{36}|sk-ant-[a-zA-Z0-9-]{95,}|AKIA[0-9A-Z]{16})" 2>/dev/null; then
    echo "  ⚠️  WARNING: Secrets still found in tracked files!"
    exit 1
else
    echo "  ✅ No secrets found in tracked files"
fi

# Check for Claude Code references in tracked files
echo "  Checking for 'Claude Code' references..."
CLAUDE_REFS=$(git ls-files | grep -v ".claude/" | xargs grep -l "Claude Code" 2>/dev/null | wc -l)
if [ "$CLAUDE_REFS" -gt 0 ]; then
    echo "  ⚠️  WARNING: Found $CLAUDE_REFS files with 'Claude Code' references"
    git ls-files | grep -v ".claude/" | xargs grep -l "Claude Code" 2>/dev/null
else
    echo "  ✅ No Claude Code references in tracked files"
fi

# Verify .gitignore is working
echo "  Verifying .gitignore..."
if git status --ignored | grep -q ".env"; then
    echo "  ✅ .env files are properly ignored"
else
    echo "  ⚠️  WARNING: .env files might not be ignored"
fi

echo ""
echo "🎉 Sanitization complete!"
echo "========================="
echo ""
echo "Next steps:"
echo "1. Review changes: git status"
echo "2. Test pre-commit hooks: git add . && pre-commit run --all-files"
echo "3. Create clean initial commit: git add . && git commit -m 'Initial commit'"
echo "4. Push to private GitHub repo: git push origin main"
echo ""
echo "⚠️  IMPORTANT: Make sure to create a PRIVATE repository on GitHub!"
echo ""
