# Demo Data Quick Reference Card

## 🚀 Quick Start

```bash
export GH_TOKEN=your_github_token_here

# Full setup (run in order)
./scripts/manage-demo-data.sh status
./scripts/create-demo-branches.sh
./scripts/add-demo-commits.sh
./scripts/create-demo-prs.sh
./scripts/add-pr-collaboration.sh
./scripts/manage-demo-data.sh status
```

## 📊 Current Status

| Metric | Count |
|--------|-------|
| Issues | 33 (18 open, 15 closed) |
| PRs | 16 (5 open, 6 merged) |
| Branches | 8 demo branches |
| Commits | 30+ with AI co-authors |
| Labels | 6 demo labels |

## 🎯 Demo Branches

- `demo/feature/api-v2` - REST API v2
- `demo/feature/websocket-support` - WebSocket
- `demo/bugfix/memory-leak` - Memory fix
- `demo/refactor/database-layer` - DB refactor
- `demo/feature/monitoring` - Prometheus
- `demo/feature/graphql-api` - GraphQL
- `demo/feature/real-time-notifications` - Push notifications
- `demo/bugfix/race-condition` - Concurrency fix

## 🤖 AI Tools Represented

- **GitHub Copilot** - Features
- **Claude** - Bug fixes
- **Cursor** - Refactoring
- **Aider** - Infrastructure

## 📝 Common Tasks

### Check Status
```bash
GH_TOKEN=$GH_TOKEN ./scripts/manage-demo-data.sh status
```

### Add More Collaboration
```bash
GH_TOKEN=$GH_TOKEN ./scripts/add-pr-collaboration.sh
```

### Refresh All Data
```bash
GH_TOKEN=$GH_TOKEN ./scripts/manage-demo-data.sh cleanup
# Then re-run all populate scripts
```

### Clean Up for Production
```bash
GH_TOKEN=$GH_TOKEN ./scripts/manage-demo-data.sh cleanup
```

## 🔧 Troubleshooting

| Problem | Solution |
|---------|----------|
| `gh: command not found` | `brew install gh` |
| `GH_TOKEN not set` | `export GH_TOKEN=ghp_...` |
| Permission denied | `chmod +x scripts/*.sh` |
| Rate limiting | Wait or run scripts separately |

## 📁 Files

All scripts in `scripts/` directory:
- `manage-demo-data.sh` - Main script
- `create-demo-branches.sh` - Branches
- `add-demo-commits.sh` - Commits
- `create-demo-prs.sh` - Pull requests
- `add-pr-collaboration.sh` - Comments/reviews
- `README-DEMO-DATA.md` - Full docs

## ⚠️ Important Notes

- Demo data marked with `demo:` prefix
- Cleanup is **irreversible**
- Test cleanup script carefully
- Repo: armyknife-tools/github-metrics-demo
- Keep token secure (don't commit!)

## 🎬 Before Client Demo

1. `./scripts/manage-demo-data.sh status`
2. Load demo repo in dashboard
3. Verify metrics display correctly
4. Prepare demo narrative

---
Quick access: See DEMO-DATA-SUMMARY.md for full details
