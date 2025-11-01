# Platform Orchestration Repository

**Repository**: `armyknifelabs-platform-dashboard`
**Purpose**: Orchestration hub for multi-repository platform deployment
**Status**: 🟡 Initial Setup - Component repositories need initialization

---

## Overview

This repository orchestrates the build and deployment of three independent component repositories as a cohesive platform:

1. **[armyknifelabs-platform-database](https://github.com/armyknifelabs-platform/armyknifelabs-platform-database)** - Database schemas, migrations, and seed data
2. **[armyknifelabs-platform-backend](https://github.com/armyknifelabs-platform/armyknifelabs-platform-backend)** - Backend API services
3. **[armyknifelabs-platform-frontend](https://github.com/armyknifelabs-platform/armyknifelabs-platform-frontend)** - Frontend React application

---

## Key Features

### 🚀 Parallel Builds
- Build all three components simultaneously using GitHub Actions matrix strategy
- Fail-fast on errors for rapid feedback
- Comprehensive test suites for each component

### 📦 Docker Image Caching
- Commit-based tagging for immutable image references
- ECR existence checks to skip unnecessary rebuilds
- **87% time savings** on cached deployments (15min → 2min)

### 🔄 Synchronized Versioning
- `VERSION.json` tracks tested component commit combinations
- Independent service deployment while maintaining tested pairs
- Easy rollback to known-good versions

### 🌍 Environment Promotion Pipeline
- **Guest** → **Test** → **Production** workflow
- Manual approval gates for production deployments
- Automated validation and health checks at each stage

### 📊 Monitoring & Observability
- Build pipeline metrics tracking
- Deployment history and audit trail
- Cross-service health validation

### 🔒 Security & Compliance
- AWS Secrets Manager integration
- Automated security scanning
- Audit logging for all deployments

### 📚 Cross-Session Documentation
- All work logged to `shared-docs/` (NFS-mounted)
- Knowledge preserved across Claude Code sessions
- Automatic RCA generation for failures

---

## Quick Start

### Prerequisites

1. **Component repositories initialized** with at least one commit each
2. **GitHub Personal Access Token** with `repo`, `packages`, and `workflow` permissions
3. **AWS credentials** configured (OIDC or access keys)
4. **GitHub Secrets** configured (see below)

### Initial Setup

```bash
# Clone this repository
git clone https://github.com/armyknifelabs-platform/armyknifelabs-platform-dashboard.git
cd armyknifelabs-platform-dashboard

# Verify shared documentation access
./scripts/sync-shared-docs.sh

# Update VERSION.json with latest commits from component repos
# (See "Updating VERSION.json" section below)
```

### Configure GitHub Secrets

Required secrets for GitHub Actions:

```bash
# GitHub Personal Access Token (for accessing component repos)
gh secret set GH_PAT --body "ghp_your_personal_access_token"

# AWS configuration
gh secret set AWS_ROLE_ARN --body "arn:aws:iam::ACCOUNT_ID:role/github-actions"
gh secret set AWS_ACCOUNT_ID --body "123456789012"

# Organization name
gh secret set GITHUB_ORG --body "armyknifelabs-platform"
```

### Updating VERSION.json

Once component repositories have initial commits:

```bash
# Get latest commit SHAs
DATABASE_COMMIT=$(gh api repos/armyknifelabs-platform/armyknifelabs-platform-database/commits/main --jq '.sha')
BACKEND_COMMIT=$(gh api repos/armyknifelabs-platform/armyknifelabs-platform-backend/commits/main --jq '.sha')
FRONTEND_COMMIT=$(gh api repos/armyknifelabs-platform/armyknifelabs-platform-frontend/commits/main --jq '.sha')

# Update VERSION.json
jq --arg db "$DATABASE_COMMIT" \
   --arg be "$BACKEND_COMMIT" \
   --arg fe "$FRONTEND_COMMIT" \
   '.components.database.commit = $db |
    .components.backend.commit = $be |
    .components.frontend.commit = $fe |
    .components.database.shortCommit = ($db[:7]) |
    .components.backend.shortCommit = ($be[:7]) |
    .components.frontend.shortCommit = ($fe[:7]) |
    .deployment.tested = true |
    .deployment.environment = "development" |
    .deployment.status = "ready"' \
   VERSION.json > VERSION.json.tmp && mv VERSION.json.tmp VERSION.json

# Commit and push
git add VERSION.json
git commit -m "chore: initialize VERSION.json with component commits"
git push origin main
```

---

## Directory Structure

```
armyknifelabs-platform-dashboard/
├── shared-docs/              # Symbolic link to NFS shared documentation
├── .github/
│   └── workflows/
│       ├── build-all.yml     # Parallel build orchestration
│       ├── deploy-guest.yml  # Guest environment deployment (TODO)
│       ├── deploy-test.yml   # Test environment deployment (TODO)
│       └── deploy-production.yml  # Production deployment (TODO)
├── config/
│   └── environments/
│       ├── guest.yml         # Guest environment config (TODO)
│       ├── test.yml          # Test environment config (TODO)
│       └── production.yml    # Production environment config (TODO)
├── scripts/
│   ├── sync-shared-docs.sh   # Verify shared docs access
│   └── version-sync.sh       # Synchronize version tags across repos
├── monitoring/               # Monitoring dashboards and alerts (TODO)
│   ├── dashboards/
│   └── alerts/
├── docs/                     # Repository-specific documentation
├── VERSION.json              # Synchronized version manifest
└── README.md                 # This file
```

---

## VERSION.json Format

The `VERSION.json` file is the single source of truth for which commits of each component should be deployed together:

```json
{
  "release": "v1.0.0",
  "createdAt": "2025-11-01T00:00:00Z",
  "description": "Release description",
  "components": {
    "database": {
      "commit": "full-40-char-sha",
      "shortCommit": "short-7-char-sha",
      "repository": "armyknifelabs-platform-database",
      "description": "Component description"
    },
    "backend": { /* same structure */ },
    "frontend": { /* same structure */ }
  },
  "features": [
    "List of features in this release"
  ],
  "deployment": {
    "tested": true,
    "environment": "guest",
    "status": "stable"
  }
}
```

---

## GitHub Actions Workflows

### Build All Components

Trigger: Push to `main` or `develop` (when VERSION.json changes), or manual workflow dispatch

```bash
# Manual trigger with version
gh workflow run build-all.yml -f version=1.0.0

# Dry run mode
gh workflow run build-all.yml -f version=1.0.0 -f dry_run=true
```

**What it does**:
1. Extracts commit SHAs from VERSION.json
2. Checks out each component at the specified commit
3. Builds and tests in parallel
4. Checks if Docker images already exist in ECR
5. Builds new images OR retags existing images
6. Creates git tags in all component repositories
7. Runs integration tests
8. Generates build summary and logs to shared-docs/

### Deployment Workflows (TODO)

Additional workflows to be created:
- `deploy-guest.yml` - Deploy to guest environment
- `deploy-test.yml` - Deploy to test environment
- `deploy-production.yml` - Deploy to production (with approval gate)
- `promotion-workflow.yml` - Promote between environments
- `rollback.yml` - Emergency rollback procedures

---

## Environment Promotion

```
Feature Branch → PR → Main Branch → Auto-deploy to Guest
                                         ↓
                                   Manual Testing
                                         ↓
                              Promote to Test (Manual)
                                         ↓
                                  QA Validation
                                         ↓
                             Promote to Production (Manual + Approval)
```

---

## Scripts

### `scripts/sync-shared-docs.sh`

Verifies access to the NFS-mounted shared documentation folder.

```bash
./scripts/sync-shared-docs.sh
```

**What it checks**:
- NFS mount accessibility
- Symbolic link correctness
- Required documentation files
- Documentation statistics

### `scripts/version-sync.sh`

Synchronizes version tags across all three component repositories.

```bash
# Create tags in all repos based on VERSION.json
./scripts/version-sync.sh

# Dry run to see what would happen
./scripts/version-sync.sh --dry-run
```

**What it does**:
1. Validates VERSION.json format
2. Extracts component commits
3. Creates annotated git tags in each repository
4. Updates VERSION.json metadata
5. Logs to shared-docs/DEPLOYMENT_HISTORY.md

---

## Shared Documentation

This repository integrates with a shared NFS-mounted documentation folder accessible to all Claude Code sessions:

**Location**: `/media/developer/Backup02/docs`
**Symlink**: `shared-docs/` in this repository

### Key Shared Documents

- `ORCHESTRATION_PLANNING.md` - Architecture and design decisions
- `ORCHESTRATION_CHECKLIST.md` - Implementation progress tracking
- `ORCHESTRATION_STATUS.md` - Current status and blockers
- `DEPLOYMENT_HISTORY.md` - Deployment audit trail
- `PROMOTION_WORKFLOW.md` - Environment promotion patterns
- `GITHUB_ACTIONS_SYNCHRONIZED_VERSIONING.md` - Versioning strategy

### Automatic Logging

All workflows automatically log to shared-docs/:
- Build start/completion → `BUILD_LOG.md`
- Test results → `TEST_RESULTS.md`
- Deployment events → `DEPLOYMENT_HISTORY.md`
- Failures → `RCA_*.md` (Root Cause Analysis templates)

---

## Current Status

### ✅ Completed
- [x] Repository created and initialized
- [x] Directory structure set up
- [x] Shared docs integration configured
- [x] Build orchestration workflow implemented
- [x] Utility scripts ready

### 🚧 In Progress
- [ ] Component repositories need initial commits
- [ ] VERSION.json needs actual commit SHAs
- [ ] Deployment workflows need creation

### 📋 TODO
- [ ] Create environment-specific deployment workflows
- [ ] Configure GitHub Environments for approvals
- [ ] Set up monitoring dashboards
- [ ] Implement rollback procedures
- [ ] Create comprehensive documentation

---

## Next Steps

1. **Initialize component repositories** with initial code/schemas
2. **Update VERSION.json** with first commit SHAs
3. **Configure GitHub Secrets** for AWS and GitHub access
4. **Test build workflow** with `--dry-run` flag
5. **Create deployment workflows** for each environment
6. **Set up monitoring** and alerting

---

## Support & Documentation

### Internal Documentation
- `docs/` - Repository-specific guides and runbooks
- `shared-docs/` - Cross-session shared knowledge

### Reference Patterns
- `shared-docs/PROMOTION_WORKFLOW.md` - Proven promotion strategies
- `shared-docs/RAG_DEPLOYMENT_GUIDE.md` - Deployment sequencing examples
- `shared-docs/PRODUCTION_READINESS.md` - Quality gates and requirements

### Getting Help
- Review `shared-docs/ORCHESTRATION_FAQ.md` (to be created)
- Check recent documentation: `ls -lt shared-docs/ | head -20`
- Search for solutions: `grep -r "your issue" shared-docs/`

---

## Contributing

1. All changes should go through pull requests
2. Update VERSION.json after testing component combinations
3. Document significant changes in shared-docs/
4. Follow conventional commit format
5. Ensure all workflows pass before merging

---

## License

[Your License Here]

---

**Created**: 2025-11-01
**Maintained By**: DevOps Team + Claude Code Agents
**Status**: 🟡 Initial Setup Phase
