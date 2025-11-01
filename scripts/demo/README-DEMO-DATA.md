# Demo Data Management for GitHub Metrics Demo

## Overview

This directory contains scripts to populate and manage demo data for the [armyknife-tools/github-metrics-demo](https://github.com/armyknife-tools/github-metrics-demo) repository. The demo data simulates a team using GitHub with AI-assisted development tools to showcase the AI Performance Dashboard to prospective clients.

## Current Demo Data Status

As of last update:
- **33 Issues** (18 open, 15 closed) - realistic bug reports, features, and enhancements
- **16 Pull Requests** (5 open, 6 merged) - with AI co-authors and reviews
- **8 Demo Branches** - feature branches with meaningful commits
- **30+ Commits** - diverse patterns with AI co-authorship
- **6 Demo Labels** - categorizing AI-assisted work

## Scripts

### 1. `manage-demo-data.sh` - Main Management Script

Comprehensive script for managing all demo data.

```bash
# Check current demo data status
GH_TOKEN=your_token ./manage-demo-data.sh status

# Populate demo data (issues, labels, branches, PRs)
GH_TOKEN=your_token ./manage-demo-data.sh populate

# Clean up all demo data (when transitioning to production)
GH_TOKEN=your_token ./manage-demo-data.sh cleanup
```

**Features:**
- Creates demo labels (demo:high-priority, demo:ai-assisted, etc.)
- Generates 10+ realistic issues across different categories
- Automatically closes some issues to show activity
- Creates feature branches (attempts git operations)
- Generates pull requests with comprehensive descriptions
- Adds collaboration comments and reviews

**Note:** The git clone functionality in this script may fail due to authentication. Use the specialized scripts below instead.

### 2. `create-demo-branches.sh` - Branch Creator

Creates demo branches via GitHub API (no git clone needed).

```bash
GH_TOKEN=your_token ./create-demo-branches.sh
```

Creates 8 demo branches:
- `demo/feature/api-v2`
- `demo/feature/websocket-support`
- `demo/bugfix/memory-leak`
- `demo/refactor/database-layer`
- `demo/feature/monitoring`
- `demo/feature/graphql-api`
- `demo/feature/real-time-notifications`
- `demo/bugfix/race-condition`

### 3. `add-demo-commits.sh` - Commit Generator

Adds meaningful commits to demo branches with AI co-authors.

```bash
./add-demo-commits.sh
```

**What it does:**
- Clones repo to `/tmp/github-metrics-demo`
- Checks out each demo branch
- Creates realistic source code files
- Commits with AI co-author trailers:
  - GitHub Copilot for features
  - Claude for bug fixes
  - Cursor for refactoring
  - Aider for monitoring

**Generated Files:**
- `src/api_v2.js` - REST API v2 implementation
- `src/websocket.js` - WebSocket server
- `src/event_cleanup.js` - Memory leak fix
- `src/db_modern.js` - Modern database layer
- `src/prometheus.js` - Prometheus metrics
- And more...

### 4. `create-demo-prs.sh` - Pull Request Creator

Creates PRs from demo branches with comprehensive descriptions.

```bash
GH_TOKEN=your_token ./create-demo-prs.sh
```

**Features:**
- Creates PRs with detailed descriptions
- Includes AI co-author attribution
- Randomly merges ~50% of PRs
- Adds demo:ai-assisted label
- Includes test plans and performance impact
- Mentions AI-assisted development benefits

### 5. `add-pr-collaboration.sh` - Team Collaboration Simulator

Adds comments and reviews to open PRs to simulate team activity.

```bash
GH_TOKEN=your_token ./add-pr-collaboration.sh
```

**Adds:**
- 2-3 comments per PR with varied tones
- Review comments (LGTM, questions, approvals)
- PR approvals (~50% of PRs)
- Realistic collaboration patterns

## Complete Workflow

To fully populate the demo repository from scratch:

```bash
# Set your GitHub token
export GH_TOKEN=ghp_your_token_here

# 1. Check current status
./manage-demo-data.sh status

# 2. Create base demo data (labels, issues)
./manage-demo-data.sh populate

# 3. Create branches (if not already created)
./create-demo-branches.sh

# 4. Add commits to branches
./add-demo-commits.sh

# 5. Create pull requests
./create-demo-prs.sh

# 6. Add collaboration data
./add-pr-collaboration.sh

# 7. Verify everything
./manage-demo-data.sh status
```

## Cleanup (Transition to Production)

When you have paying clients and need to remove demo data:

```bash
export GH_TOKEN=ghp_your_token_here

# This will prompt for confirmation before deleting:
# - All demo branches (demo/*)
# - All issues with demo: labels
# - All PRs with [DEMO] prefix
# - All demo labels
./manage-demo-data.sh cleanup
```

**Warning:** This action cannot be undone! Make sure you really want to remove all demo data.

## Demo Data Characteristics

The demo data showcases:

### AI-Assisted Development Patterns
- **Co-authored commits**: Show AI tools (Copilot, Claude, Cursor, Aider) as co-authors
- **High velocity**: Multiple features developed in short time
- **Quality**: Comprehensive test coverage and documentation
- **Modern patterns**: async/await, connection pooling, real-time features

### Realistic Team Activity
- **Mixed PR states**: Open, closed, merged PRs
- **Active collaboration**: Comments, reviews, questions
- **Issue tracking**: Bugs, features, refactors, incidents
- **Code owners**: CODEOWNERS file compliance

### Metrics-Friendly
- **DORA metrics**: Lead time, deployment frequency visible
- **AI amplification**: Clear before/after AI adoption patterns
- **Developer velocity**: Commit frequency and code churn
- **Quality metrics**: Bug rates, review cycles

## Customization

### Adding More Issues

Edit `manage-demo-data.sh` and add to the `ISSUES` array:

```bash
"Your issue title|label1,label2|Issue body description"
```

### Adding More Branches/PRs

Edit `add-demo-commits.sh` and `create-demo-prs.sh`:

```bash
# In add-demo-commits.sh
"demo/feature/new-feature:feat: your title:description:AI Tool:email:file_type"

# In create-demo-prs.sh
"demo/feature/new-feature|PR Title|PR summary description"
```

### Changing AI Tools

Modify the co-author patterns in `add-demo-commits.sh`:

```bash
Co-authored-by: Your AI Tool <email@example.com>
```

## Troubleshooting

### "gh: command not found"

Install GitHub CLI:
```bash
brew install gh
```

### "GH_TOKEN not set"

Set your GitHub personal access token:
```bash
export GH_TOKEN=ghp_your_token_here
```

Token needs these scopes:
- `repo` (full control)
- `workflow` (for GitHub Actions)

### "Permission denied" errors

Make scripts executable:
```bash
chmod +x scripts/*.sh
```

### Git clone fails in manage-demo-data.sh

Use the specialized scripts instead:
1. `create-demo-branches.sh` (API-based, no clone needed)
2. `add-demo-commits.sh` (handles cloning separately)

### Rate limiting errors

The scripts include sleep delays, but if you hit rate limits:
- Wait a few minutes
- Run scripts separately instead of all at once
- Check your rate limit: `gh api rate_limit`

## Maintenance

### Refreshing Demo Data

To refresh stale demo data:

```bash
# Clean up old data
./manage-demo-data.sh cleanup

# Repopulate
./create-demo-branches.sh
./add-demo-commits.sh
./create-demo-prs.sh
./add-pr-collaboration.sh
```

### Updating After Main Changes

If main branch gets new commits:

```bash
cd /tmp/github-metrics-demo
git checkout main
git pull origin main

# Recreate demo branches from new main
./scripts/add-demo-commits.sh
```

## Best Practices

1. **Before Client Demos**: Run status check to ensure data is fresh
2. **After Each Demo**: Add 1-2 new issues to show ongoing activity
3. **Monthly**: Refresh PR comments to show recent collaboration
4. **Before Production**: Test cleanup script in dry-run mode first
5. **Documentation**: Keep this README updated with changes

## Future Enhancements

Potential improvements:
- [ ] Add GitHub Actions workflow runs
- [ ] Create security alerts (Dependabot)
- [ ] Add code scanning results
- [ ] Generate commit activity over time (backdating)
- [ ] Add discussions and wiki content
- [ ] Create releases and tags
- [ ] Add project boards
- [ ] Simulate multiple team members (not just AI)

## Support

For issues or questions:
1. Check this README first
2. Review script comments for detailed logic
3. Test scripts individually to isolate problems
4. Check GitHub API documentation

---

**Remember**: This is demo data for client presentations. Remove it before using the repository for actual company projects.
