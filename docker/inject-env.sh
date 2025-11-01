#!/bin/sh
# Inject environment variables into the built frontend at runtime

# This replaces the hardcoded API URLs in the JavaScript bundle
# with the correct values for the current environment

FRONTEND_DIR="/usr/share/nginx/html"
ASSETS_DIR="$FRONTEND_DIR/assets"

echo "[Env Injection] Replacing API URLs in frontend bundle..."
echo "[Env Injection] Target API URL: ${VITE_API_URL:-/api/v1}"

# Determine the API base URL
# If VITE_API_URL is set, use it (for AWS with ALB)
# Otherwise, use empty string for docker-compose (relative URLs)
if [ -n "$VITE_API_URL" ]; then
  # Extract base URL without /api/v1 suffix
  API_BASE_URL=$(echo "$VITE_API_URL" | sed 's|/api/v1$||')
  echo "[Env Injection] Using production mode: API_BASE_URL=$API_BASE_URL"
else
  API_BASE_URL=""
  echo "[Env Injection] Using docker-compose mode: relative URLs"
fi

# Find the main JS bundle
for file in "$ASSETS_DIR"/index-*.js; do
  if [ -f "$file" ]; then
    echo "[Env Injection] Processing: $(basename $file)"

    # Replace localhost URLs with the target API base URL
    sed -i "s|\"http://localhost:3001\"|\"$API_BASE_URL\"|g" "$file"
    sed -i "s|\"ws://localhost:3001\"|\"$API_BASE_URL\"|g" "$file"

    # Also replace any hardcoded localhost:8080 references
    sed -i "s|\"http://localhost:8080\"|\"$API_BASE_URL\"|g" "$file"

    echo "[Env Injection] ✓ Replaced API URLs in $(basename $file)"
  fi
done

echo "[Env Injection] Done! Starting Nginx..."
exec "$@"
