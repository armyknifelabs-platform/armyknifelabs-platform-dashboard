#!/bin/bash
# Run Phase 3 database migration

echo "🚀 Running Phase 3 database migration..."

# Check if PostgreSQL is running
if ! pg_isready > /dev/null 2>&1; then
  echo "❌ PostgreSQL is not running. Please start PostgreSQL first."
  exit 1
fi

# Run migration
psql $DATABASE_URL -f src/db/migrations/007_create_phase3_metrics.sql

if [ $? -eq 0 ]; then
  echo "✅ Phase 3 migration completed successfully!"
  echo ""
  echo "📊 Verifying tables..."
  psql $DATABASE_URL -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%_metrics' OR table_name LIKE '%_blockers' OR table_name LIKE '%_incidents' OR table_name LIKE '%_surveys' OR table_name LIKE '%_archetypes' OR table_name LIKE '%_confidence' ORDER BY table_name;"
else
  echo "❌ Migration failed!"
  exit 1
fi
