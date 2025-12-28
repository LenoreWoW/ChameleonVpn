#!/bin/bash
#
# BarqNet/ChameleonVPN - Management Server Launcher
# ==================================================
# Deploy this script on your MANAGEMENT SERVER (Server 2)
#
# Prerequisites:
#   - Go 1.21+
#   - PostgreSQL running
#   - Redis (optional, for rate limiting)
#
# Usage: ./run-management.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="${SCRIPT_DIR}/../barqnet-backend/apps/management"
BACKEND_PORT="${MANAGEMENT_PORT:-8085}"
HEALTH_URL="http://127.0.0.1:${BACKEND_PORT}/health"
LOG_FILE="/var/log/barqnet/management.log"
PID_FILE="/var/run/barqnet-management.pid"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || LOG_FILE="/tmp/barqnet_management.log"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       BarqNet - Management Server Launcher                ║${NC}"
echo -e "${BLUE}║                   (Deploy on Server 2)                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to cleanup on exit
cleanup() {
    if [ -n "$BACKEND_PID" ]; then
        echo -e "\n${YELLOW}Shutting down management server (PID: $BACKEND_PID)...${NC}"
        kill $BACKEND_PID 2>/dev/null || true
        wait $BACKEND_PID 2>/dev/null || true
        rm -f "$PID_FILE"
        echo -e "${GREEN}Management server stopped.${NC}"
    fi
}
trap cleanup EXIT INT TERM

# Function to check if backend is ready
check_health() {
    curl -s -f "$HEALTH_URL" > /dev/null 2>&1
    return $?
}

# Function to kill any existing process on the port
kill_existing() {
    local existing_pid=$(lsof -ti:${BACKEND_PORT} 2>/dev/null || true)
    if [ -n "$existing_pid" ]; then
        echo -e "${YELLOW}Found existing process on port ${BACKEND_PORT} (PID: $existing_pid). Killing...${NC}"
        kill $existing_pid 2>/dev/null || true
        sleep 2
    fi
}

# Step 1: Check prerequisites
echo -e "${BLUE}[1/4]${NC} Checking prerequisites..."

if ! command -v go &> /dev/null; then
    echo -e "${RED}Error: Go is not installed. Please install Go 1.21+${NC}"
    echo -e "${YELLOW}  Ubuntu: sudo apt install golang-go${NC}"
    echo -e "${YELLOW}  Or: wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz${NC}"
    exit 1
fi

GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
echo -e "${GREEN}✓ Go version: $GO_VERSION${NC}"

if [ ! -d "$BACKEND_DIR" ]; then
    echo -e "${RED}Error: Backend directory not found: $BACKEND_DIR${NC}"
    exit 1
fi

# Step 2: Check environment variables
echo -e "${BLUE}[2/4]${NC} Checking environment configuration..."

# Load .env if exists
if [ -f "${BACKEND_DIR}/.env" ]; then
    echo -e "${GREEN}✓ Loading .env file${NC}"
    set -a
    source "${BACKEND_DIR}/.env"
    set +a
elif [ -f "${SCRIPT_DIR}/../.env" ]; then
    echo -e "${GREEN}✓ Loading root .env file${NC}"
    set -a
    source "${SCRIPT_DIR}/../.env"
    set +a
fi

# Set defaults for required variables
export MANAGEMENT_PORT="${MANAGEMENT_PORT:-8085}"
export JWT_SECRET="${JWT_SECRET:-CHANGE_THIS_IN_PRODUCTION_32_CHARS_MIN}"
export API_KEY="${API_KEY:-CHANGE_THIS_API_KEY_IN_PRODUCTION}"

# Warn about missing critical variables
MISSING_VARS=0

if [ -z "$DB_HOST" ]; then
    echo -e "${YELLOW}⚠ DB_HOST not set (defaulting to localhost)${NC}"
    export DB_HOST="localhost"
fi

if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}⚠ WARNING: DB_PASSWORD not set!${NC}"
    MISSING_VARS=1
fi

if [ "$JWT_SECRET" = "CHANGE_THIS_IN_PRODUCTION_32_CHARS_MIN" ]; then
    echo -e "${RED}⚠ WARNING: Using default JWT_SECRET - change in production!${NC}"
fi

if [ "$API_KEY" = "CHANGE_THIS_API_KEY_IN_PRODUCTION" ]; then
    echo -e "${RED}⚠ WARNING: Using default API_KEY - change in production!${NC}"
fi

echo -e "${GREEN}✓ Environment configured${NC}"

# Step 3: Kill existing and start server
echo -e "${BLUE}[3/4]${NC} Starting management server..."

kill_existing

cd "$BACKEND_DIR"

# Build first for production
echo -e "${YELLOW}Building management server...${NC}"
go build -o management . 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful${NC}"

# Start server
echo -e "${YELLOW}Starting server on port ${BACKEND_PORT}...${NC}"
./management > "$LOG_FILE" 2>&1 &
BACKEND_PID=$!
echo $BACKEND_PID > "$PID_FILE" 2>/dev/null || true

echo -e "${GREEN}✓ Management server started (PID: $BACKEND_PID)${NC}"

# Step 4: Wait for health
echo -e "${BLUE}[4/4]${NC} Waiting for server to be ready..."

MAX_WAIT=60
waited=0
while [ $waited -lt $MAX_WAIT ]; do
    if check_health; then
        echo -e "${GREEN}✓ Management server is healthy!${NC}"
        break
    fi
    
    if ! kill -0 $BACKEND_PID 2>/dev/null; then
        echo -e "${RED}Error: Server process died unexpectedly.${NC}"
        echo -e "${RED}Last 20 lines of log:${NC}"
        tail -20 "$LOG_FILE"
        exit 1
    fi
    
    printf "."
    sleep 1
    waited=$((waited + 1))
done

if [ $waited -ge $MAX_WAIT ]; then
    echo -e "${RED}Error: Server did not become healthy within ${MAX_WAIT} seconds.${NC}"
    tail -20 "$LOG_FILE"
    exit 1
fi

# Display status
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           MANAGEMENT SERVER RUNNING                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Server Status:${NC}"
echo -e "  • URL:      ${GREEN}http://0.0.0.0:${BACKEND_PORT}${NC}"
echo -e "  • Health:   ${GREEN}${HEALTH_URL}${NC}"
echo -e "  • Logs:     ${YELLOW}${LOG_FILE}${NC}"
echo -e "  • PID:      ${YELLOW}${BACKEND_PID}${NC}"
echo ""
echo -e "${BLUE}API Endpoints:${NC}"
echo -e "  • Auth:     POST /v1/auth/login, /v1/auth/register"
echo -e "  • VPN:      GET  /v1/vpn/locations, /v1/vpn/config"
echo -e "  • Health:   GET  /health"
echo ""
echo -e "${BLUE}For Endnodes:${NC}"
echo -e "  • Set MANAGEMENT_URL=http://YOUR_SERVER_IP:${BACKEND_PORT}"
echo -e "  • Set API_KEY=${API_KEY}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the server.${NC}"
echo ""

# Follow logs
tail -f "$LOG_FILE" &
TAIL_PID=$!

# Wait for main process
wait $BACKEND_PID
kill $TAIL_PID 2>/dev/null || true

