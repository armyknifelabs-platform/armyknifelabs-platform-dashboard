# Service Management Scripts

These scripts help you manage all services for the AI Performance Dashboard.

## Available Scripts

### `pnpm start-all`
**Start all services automatically**

Starts all required services in the correct order:
1. PostgreSQL (port 5432)
2. Redis (port 6379)
3. Backend API (port 3001)
4. Frontend (port 5173)

Features:
- Checks if services are already running
- Waits for each service to be ready before proceeding
- Creates log files in `logs/` directory
- Stores PIDs for graceful shutdown
- Shows service URLs and status

Usage:
```bash
pnpm start-all
```

Output:
```
🚀 Starting AI Performance Dashboard...

[1/4] Starting PostgreSQL...
  ✓ PostgreSQL started

[2/4] Starting Redis...
  ✓ Redis started

[3/4] Starting Backend API...
  ✓ Backend started (PID: 12345)
  → Logs: logs/backend.log

[4/4] Starting Frontend...
  ✓ Frontend started (PID: 12346)
  → Logs: logs/frontend.log

✨ All services started successfully!

📊 Service URLs:
  • Frontend:  http://localhost:5173
  • Backend:   http://localhost:3001
  • Health:    http://localhost:3001/api/v1/health
```

### `pnpm status`
**Check status of all services**

Shows which services are currently running and their health status.

Usage:
```bash
pnpm status
```

Output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AI Performance Dashboard - Service Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PostgreSQL (5432):  ● Running (PID: 12345)
Redis (6379):       ● Running (PID: 12346)
Backend (3001):     ● Running (PID: 12347)
  → Health check: OK
Frontend (5173):    ● Running (PID: 12348)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Service URLs:
  • Frontend:  http://localhost:5173
  • Backend:   http://localhost:3001
  • Health:    http://localhost:3001/api/v1/health

📁 Log Files:
  • Backend:   logs/backend.log (2.3M)
  • Frontend:  logs/frontend.log (1.5M)
```

### `pnpm stop-all`
**Stop all services gracefully**

Stops all development services with graceful shutdown:
1. Frontend (Vite dev server)
2. Backend (Fastify API + BullMQ workers)
3. Redis (optional - prompts user)
4. PostgreSQL (optional - prompts user)

Features:
- Sends SIGTERM for graceful shutdown
- Waits up to 10 seconds for process to exit
- Forces kill (SIGKILL) if needed
- Prompts before stopping Redis and PostgreSQL
- Cleans up PID files

Usage:
```bash
pnpm stop-all
```

Output:
```
🛑 Stopping AI Performance Dashboard...

[1/4] Stopping Frontend...
  ✓ Frontend stopped

[2/4] Stopping Backend...
  ✓ Backend stopped

[3/4] Redis...
  Stop Redis? (y/N) n
  ⊘ Redis left running

[4/4] PostgreSQL...
  Stop PostgreSQL? (y/N) n
  ⊘ PostgreSQL left running

✨ Services stopped successfully!
```

## Log Files

Service logs are stored in the `logs/` directory:
- `logs/backend.log` - Backend API and BullMQ worker logs
- `logs/frontend.log` - Frontend Vite dev server logs
- `logs/backend.pid` - Backend process ID
- `logs/frontend.pid` - Frontend process ID

View logs in real-time:
```bash
# Backend logs
tail -f logs/backend.log

# Frontend logs
tail -f logs/frontend.log

# Both logs
tail -f logs/*.log
```

## Troubleshooting

### Services won't start
1. Check if ports are already in use:
   ```bash
   lsof -i :5432  # PostgreSQL
   lsof -i :6379  # Redis
   lsof -i :3001  # Backend
   lsof -i :5173  # Frontend
   ```

2. Check service logs for errors:
   ```bash
   cat logs/backend.log
   cat logs/frontend.log
   ```

3. Manually kill processes on ports:
   ```bash
   lsof -i :3001 -t | xargs kill -9
   lsof -i :5173 -t | xargs kill -9
   ```

### Services crash after starting
1. Check logs for error messages
2. Ensure PostgreSQL and Redis are running
3. Verify environment variables in `packages/backend/.env`
4. Check database migrations are applied

### Can't access services
1. Verify services are running: `pnpm status`
2. Test backend health: `curl http://localhost:3001/api/v1/health`
3. Check firewall/network settings
4. Ensure `.env` has correct CORS settings

## Manual Service Management

If you prefer manual control, you can start services individually:

```bash
# Start PostgreSQL and Redis
brew services start postgresql@14
brew services start redis

# Start Backend (in one terminal)
cd packages/backend
pnpm dev

# Start Frontend (in another terminal)
cd packages/frontend
pnpm dev
```

See [STARTUP.md](../STARTUP.md) for detailed manual setup instructions.
