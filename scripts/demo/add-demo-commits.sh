#!/bin/bash

######################################################################
# Add Commits to Demo Branches
######################################################################

set -e

REPO_DIR="/tmp/github-metrics-demo"

if [ ! -d "$REPO_DIR" ]; then
    echo "Repository not found at $REPO_DIR"
    echo "Cloning repository..."
    git clone https://github.com/armyknife-tools/github-metrics-demo.git "$REPO_DIR"
fi

cd "$REPO_DIR"

# Pull latest changes
git fetch origin
git checkout main
git pull origin main

# Branch definitions: branch:title:body:coauthor_name:coauthor_email:file_content_type
declare -a BRANCH_COMMITS=(
    "demo/feature/api-v2:feat: add REST API v2 with performance improvements:Implement new REST API v2 with improved error handling, better performance, and comprehensive OpenAPI documentation.:GitHub Copilot:noreply@github.com:api_v2"
    "demo/feature/websocket-support:feat: add WebSocket support for real-time data:Add WebSocket server for real-time bidirectional communication with automatic reconnection.:Cursor:noreply@cursor.sh:websocket"
    "demo/bugfix/memory-leak:fix: resolve memory leak in event handlers:Fix critical memory leak by properly removing event listeners in cleanup lifecycle.:Claude:noreply@anthropic.com:event_cleanup"
    "demo/refactor/database-layer:refactor: modernize database layer with async/await:Refactor database layer to use modern async/await patterns with connection pooling.:GitHub Copilot:noreply@github.com:db_modern"
    "demo/feature/monitoring:feat: add Prometheus metrics and monitoring:Integrate Prometheus for application monitoring with custom business metrics.:Aider:git@aider.chat:prometheus"
    "demo/feature/graphql-api:feat: implement GraphQL API endpoint:Add GraphQL API with DataLoader optimization and comprehensive schema.:GitHub Copilot:noreply@github.com:graphql"
    "demo/feature/real-time-notifications:feat: add real-time push notifications:Implement WebSocket-based push notification system with user preferences.:Cursor:noreply@cursor.sh:notifications"
    "demo/bugfix/race-condition:fix: resolve race condition in concurrent requests:Fix race condition with proper locking and optimistic concurrency control.:Claude:noreply@anthropic.com:concurrency"
)

for commit_data in "${BRANCH_COMMITS[@]}"; do
    IFS=':' read -r branch_name commit_title commit_body coauthor_name coauthor_email file_type <<< "$commit_data"

    echo "Processing branch: $branch_name"

    # Fetch remote branches
    git fetch origin 2>/dev/null || true

    # Delete local branch if it exists, then checkout from remote or create new
    git branch -D "$branch_name" 2>/dev/null || true

    if git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
        # Branch exists on remote, checkout from there
        git checkout -b "$branch_name" "origin/$branch_name"
    else
        # Branch doesn't exist on remote, create from main
        git checkout -b "$branch_name" origin/main
    fi

    # Create meaningful code changes based on file type
    FILE_NAME="src/${file_type}.js"

    case $file_type in
        api_v2)
            cat > "$FILE_NAME" << 'EOF'
/**
 * REST API v2 - High Performance Edition
 *
 * This module implements API v2 with significant performance improvements:
 * - Response time improved by 40%
 * - Better error handling with structured responses
 * - Comprehensive input validation
 * - OpenAPI 3.0 documentation
 */

import express from 'express';
import { validateRequest } from './validators.js';
import { asyncHandler } from './async-handler.js';

const router = express.Router();

/**
 * GET /api/v2/users
 * List all users with pagination and filtering
 */
router.get('/users', asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, filter } = validateRequest(req.query);

  const users = await db.users.findMany({
    skip: (page - 1) * limit,
    take: limit,
    where: filter,
  });

  res.json({
    data: users,
    meta: {
      page,
      limit,
      total: await db.users.count({ where: filter }),
    },
  });
}));

/**
 * POST /api/v2/users
 * Create a new user with validation
 */
router.post('/users', asyncHandler(async (req, res) => {
  const userData = validateRequest(req.body);

  const user = await db.users.create({
    data: userData,
  });

  res.status(201).json({ data: user });
}));

export default router;
EOF
            ;;
        websocket)
            cat > "$FILE_NAME" << 'EOF'
/**
 * WebSocket Server for Real-Time Communication
 *
 * Features:
 * - Bidirectional real-time communication
 * - Automatic reconnection with exponential backoff
 * - Message acknowledgment and replay
 * - Connection pooling and load balancing
 */

import { WebSocketServer } from 'ws';
import { EventEmitter } from 'events';

export class RealtimeServer extends EventEmitter {
  constructor(server, options = {}) {
    super();
    this.wss = new WebSocketServer({
      server,
      path: options.path || '/ws',
    });
    this.clients = new Map();
    this.setupHandlers();
  }

  setupHandlers() {
    this.wss.on('connection', (ws, req) => {
      const clientId = this.generateClientId();
      this.clients.set(clientId, { ws, req });

      ws.on('message', (data) => this.handleMessage(clientId, data));
      ws.on('close', () => this.handleDisconnect(clientId));
      ws.on('error', (error) => this.handleError(clientId, error));

      this.sendToClient(clientId, {
        type: 'connected',
        clientId,
        timestamp: new Date().toISOString(),
      });
    });
  }

  broadcast(message) {
    const data = JSON.stringify(message);
    this.clients.forEach((client) => {
      if (client.ws.readyState === 1) {  // OPEN
        client.ws.send(data);
      }
    });
  }

  sendToClient(clientId, message) {
    const client = this.clients.get(clientId);
    if (client && client.ws.readyState === 1) {
      client.ws.send(JSON.stringify(message));
    }
  }

  generateClientId() {
    return `client_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  handleMessage(clientId, data) {
    try {
      const message = JSON.parse(data);
      this.emit('message', { clientId, message });
    } catch (error) {
      this.handleError(clientId, error);
    }
  }

  handleDisconnect(clientId) {
    this.clients.delete(clientId);
    this.emit('disconnect', clientId);
  }

  handleError(clientId, error) {
    console.error(`WebSocket error for ${clientId}:`, error);
    this.emit('error', { clientId, error });
  }
}

export default RealtimeServer;
EOF
            ;;
        event_cleanup)
            cat > "$FILE_NAME" << 'EOF'
/**
 * Event Handler Cleanup - Memory Leak Fix
 *
 * This module ensures proper cleanup of event listeners to prevent memory leaks.
 * The bug was causing ~50MB memory growth per hour in production.
 */

export class EventManager {
  constructor() {
    this.listeners = new Map();
    this.cleanupCallbacks = [];
  }

  /**
   * Register an event listener with automatic cleanup tracking
   */
  addEventListener(target, eventName, handler, options) {
    const wrappedHandler = (...args) => handler(...args);

    target.addEventListener(eventName, wrappedHandler, options);

    // Track for cleanup
    const key = this.getListenerKey(target, eventName);
    if (!this.listeners.has(key)) {
      this.listeners.set(key, []);
    }
    this.listeners.get(key).push({ handler: wrappedHandler, options });

    // Return cleanup function
    return () => this.removeEventListener(target, eventName, wrappedHandler);
  }

  /**
   * Remove specific event listener
   */
  removeEventListener(target, eventName, handler) {
    target.removeEventListener(eventName, handler);

    const key = this.getListenerKey(target, eventName);
    const listeners = this.listeners.get(key);
    if (listeners) {
      const index = listeners.findIndex(l => l.handler === handler);
      if (index !== -1) {
        listeners.splice(index, 1);
      }
      if (listeners.length === 0) {
        this.listeners.delete(key);
      }
    }
  }

  /**
   * Remove all event listeners for cleanup
   * THIS WAS MISSING IN THE ORIGINAL CODE - CAUSING THE MEMORY LEAK
   */
  removeAllListeners() {
    for (const [key, listeners] of this.listeners.entries()) {
      const [target, eventName] = this.parseListenerKey(key);
      listeners.forEach(({ handler }) => {
        target.removeEventListener(eventName, handler);
      });
    }
    this.listeners.clear();

    // Run cleanup callbacks
    this.cleanupCallbacks.forEach(cb => cb());
    this.cleanupCallbacks = [];
  }

  /**
   * Register a cleanup callback to run on destroy
   */
  onCleanup(callback) {
    this.cleanupCallbacks.push(callback);
  }

  getListenerKey(target, eventName) {
    return `${target.constructor.name}_${eventName}`;
  }

  parseListenerKey(key) {
    const [targetType, eventName] = key.split('_');
    return [targetType, eventName];
  }

  /**
   * Destroy and cleanup - CRITICAL FOR PREVENTING MEMORY LEAKS
   */
  destroy() {
    this.removeAllListeners();
  }
}

export default EventManager;
EOF
            ;;
        db_modern)
            cat > "$FILE_NAME" << 'EOF'
/**
 * Modern Database Layer with Connection Pooling
 *
 * Refactored to use async/await instead of callbacks
 * Performance improvements: 40% faster query execution
 */

import pg from 'pg';
const { Pool } = pg;

class DatabaseService {
  constructor(config) {
    this.pool = new Pool({
      host: config.host || 'localhost',
      port: config.port || 5432,
      database: config.database,
      user: config.user,
      password: config.password,
      max: config.maxConnections || 20,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 2000,
    });

    this.pool.on('error', (err) => {
      console.error('Unexpected database error:', err);
    });
  }

  /**
   * Execute a query with automatic connection management
   */
  async query(sql, params = []) {
    const start = Date.now();
    try {
      const result = await this.pool.query(sql, params);
      const duration = Date.now() - start;

      console.log('Query executed', {
        sql: sql.substring(0, 100),
        duration,
        rows: result.rowCount,
      });

      return result;
    } catch (error) {
      console.error('Database query error:', { sql, error });
      throw error;
    }
  }

  /**
   * Execute multiple queries in a transaction
   */
  async transaction(callback) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Get connection pool statistics
   */
  getStats() {
    return {
      total: this.pool.totalCount,
      idle: this.pool.idleCount,
      waiting: this.pool.waitingCount,
    };
  }

  /**
   * Gracefully shutdown the connection pool
   */
  async close() {
    await this.pool.end();
  }
}

export default DatabaseService;
EOF
            ;;
        *)
            # Generic file for other types
            CLASS_NAME=$(echo "$file_type" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1' | sed 's/ //g')
            cat > "$FILE_NAME" << EOF
/**
 * ${CLASS_NAME} Module
 *
 * Implementation for ${branch_name}
 * Generated for demo purposes
 */

export class ${CLASS_NAME}Service {
  constructor(options = {}) {
    this.options = options;
    this.initialized = false;
  }

  async initialize() {
    // Initialization logic
    this.initialized = true;
    console.log('${CLASS_NAME} service initialized');
  }

  async execute(data) {
    if (!this.initialized) {
      throw new Error('Service not initialized');
    }

    // Implementation logic
    return {
      success: true,
      timestamp: new Date().toISOString(),
      data,
    };
  }

  async cleanup() {
    this.initialized = false;
    console.log('${CLASS_NAME} service cleaned up');
  }
}

export default ${CLASS_NAME}Service;
EOF
            ;;
    esac

    # Stage the file
    git add "$FILE_NAME"

    # Create commit with co-author
    COMMIT_MSG="${commit_title}

${commit_body}

Co-authored-by: ${coauthor_name} <${coauthor_email}>"

    git commit --no-verify -m "$COMMIT_MSG" 2>/dev/null || echo "  → No changes to commit"

    # Push branch
    git push origin "$branch_name" 2>&1 | grep -v "To https://" || true

    echo "✓ Committed to branch: $branch_name"
    echo ""
done

echo "All demo branches updated with commits!"
