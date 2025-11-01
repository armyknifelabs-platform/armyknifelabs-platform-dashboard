#!/bin/bash
# Docker Auto-Restart Helper Script
# Ensures Docker daemon is running before executing Docker commands
# Usage: source scripts/ensure-docker-running.sh

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if Docker is running
check_docker() {
    if docker info >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to start Docker
start_docker() {
    echo -e "${YELLOW}Starting Docker Desktop...${NC}"
    open -a Docker

    # Wait for Docker to be ready (max 2 minutes)
    local max_wait=120
    local elapsed=0

    while [ $elapsed -lt $max_wait ]; do
        if check_docker; then
            echo -e "${GREEN}✅ Docker is ready!${NC}"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        echo -ne "${YELLOW}Waiting for Docker... ${elapsed}s${NC}\r"
    done

    echo -e "${RED}❌ Docker failed to start within ${max_wait}s${NC}"
    return 1
}

# Main logic
if check_docker; then
    echo -e "${GREEN}✅ Docker is already running${NC}"
else
    echo -e "${YELLOW}⚠️  Docker is not running${NC}"
    start_docker || {
        echo -e "${RED}❌ Failed to start Docker. Please start Docker Desktop manually.${NC}"
        exit 1
    }
fi
