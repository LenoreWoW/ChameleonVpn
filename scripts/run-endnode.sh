#!/bin/bash
#
# BarqNet/ChameleonVPN - Endnode (VPN Server) Launcher
# =====================================================
# Deploy this script on your VPN SERVER (Server 1)
#
# Prerequisites:
#   - Go 1.21+
#   - OpenVPN installed and configured
#   - EasyRSA initialized
#   - Management server running and accessible
#
# Usage: ./run-endnode.sh --server-id server-1
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENDNODE_DIR="${SCRIPT_DIR}/../barqnet-backend/apps/endnode"
ENDNODE_PORT="${ENDNODE_PORT:-8081}"
OPENVPN_DIR="${OPENVPN_DIR:-/etc/openvpn}"
CLIENTS_DIR="${CLIENTS_DIR:-/opt/vpnmanager/clients}"
EASYRSA_DIR="${EASYRSA_DIR:-/opt/vpnmanager/easyrsa}"
HEALTH_URL="http://127.0.0.1:${ENDNODE_PORT}/health"
LOG_FILE="/var/log/barqnet/endnode.log"
PID_FILE="/var/run/barqnet-endnode.pid"

# Parse command line arguments
SERVER_ID=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --server-id)
            SERVER_ID="$2"
            shift 2
            ;;
        --port)
            ENDNODE_PORT="$2"
            shift 2
            ;;
        --management-url)
            MANAGEMENT_URL="$2"
            shift 2
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --openvpn-dir)
            OPENVPN_DIR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 --server-id <id> [options]"
            echo ""
            echo "Required:"
            echo "  --server-id <id>       Unique server identifier (e.g., server-1)"
            echo ""
            echo "Optional:"
            echo "  --port <port>          API port (default: 8081)"
            echo "  --management-url <url> Management server URL"
            echo "  --api-key <key>        API key for authentication"
            echo "  --openvpn-dir <dir>    OpenVPN config directory (default: /etc/openvpn)"
            echo ""
            echo "Environment variables:"
            echo "  ENDNODE_SERVER_ID, MANAGEMENT_URL, API_KEY, ENDNODE_PORT"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Use environment variable if not provided via CLI
SERVER_ID="${SERVER_ID:-$ENDNODE_SERVER_ID}"

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || LOG_FILE="/tmp/barqnet_endnode.log"
mkdir -p "$CLIENTS_DIR" 2>/dev/null || true

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         BarqNet - Endnode (VPN Server) Launcher           ║${NC}"
echo -e "${BLUE}║                   (Deploy on Server 1)                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to cleanup on exit
cleanup() {
    if [ -n "$ENDNODE_PID" ]; then
        echo -e "\n${YELLOW}Shutting down endnode (PID: $ENDNODE_PID)...${NC}"
        kill $ENDNODE_PID 2>/dev/null || true
        wait $ENDNODE_PID 2>/dev/null || true
        rm -f "$PID_FILE"
        echo -e "${GREEN}Endnode stopped.${NC}"
    fi
}
trap cleanup EXIT INT TERM

# Function to check if endnode is ready
check_health() {
    curl -s -f "$HEALTH_URL" > /dev/null 2>&1
    return $?
}

# Function to kill any existing process on the port
kill_existing() {
    local existing_pid=$(lsof -ti:${ENDNODE_PORT} 2>/dev/null || true)
    if [ -n "$existing_pid" ]; then
        echo -e "${YELLOW}Found existing process on port ${ENDNODE_PORT} (PID: $existing_pid). Killing...${NC}"
        kill $existing_pid 2>/dev/null || true
        sleep 2
    fi
}

# Step 1: Check prerequisites
echo -e "${BLUE}[1/5]${NC} Checking prerequisites..."

if ! command -v go &> /dev/null; then
    echo -e "${RED}Error: Go is not installed. Please install Go 1.21+${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Go installed${NC}"

if [ ! -d "$ENDNODE_DIR" ]; then
    echo -e "${RED}Error: Endnode directory not found: $ENDNODE_DIR${NC}"
    exit 1
fi

# Check OpenVPN
if [ -d "$OPENVPN_DIR" ]; then
    echo -e "${GREEN}✓ OpenVPN directory exists: $OPENVPN_DIR${NC}"
else
    echo -e "${YELLOW}⚠ OpenVPN directory not found: $OPENVPN_DIR${NC}"
    echo -e "${YELLOW}  VPN functionality will not work until OpenVPN is configured${NC}"
fi

# Check EasyRSA
if [ -d "$EASYRSA_DIR" ]; then
    echo -e "${GREEN}✓ EasyRSA directory exists: $EASYRSA_DIR${NC}"
else
    echo -e "${YELLOW}⚠ EasyRSA directory not found: $EASYRSA_DIR${NC}"
    echo -e "${YELLOW}  Certificate generation will not work until EasyRSA is configured${NC}"
fi

# Step 2: Validate configuration
echo -e "${BLUE}[2/5]${NC} Validating configuration..."

# Load .env if exists
if [ -f "${ENDNODE_DIR}/.env" ]; then
    echo -e "${GREEN}✓ Loading .env file${NC}"
    set -a
    source "${ENDNODE_DIR}/.env"
    set +a
elif [ -f "${SCRIPT_DIR}/../.env" ]; then
    echo -e "${GREEN}✓ Loading root .env file${NC}"
    set -a
    source "${SCRIPT_DIR}/../.env"
    set +a
fi

# Check required variables
if [ -z "$SERVER_ID" ]; then
    echo -e "${RED}Error: Server ID is required.${NC}"
    echo -e "${YELLOW}  Use: $0 --server-id server-1${NC}"
    echo -e "${YELLOW}  Or set ENDNODE_SERVER_ID environment variable${NC}"
    exit 1
fi

if [ -z "$MANAGEMENT_URL" ]; then
    echo -e "${RED}Error: Management URL is required.${NC}"
    echo -e "${YELLOW}  Use: --management-url http://management-server:8085${NC}"
    echo -e "${YELLOW}  Or set MANAGEMENT_URL environment variable${NC}"
    exit 1
fi

if [ -z "$API_KEY" ]; then
    echo -e "${YELLOW}⚠ WARNING: API_KEY not set - endnode may fail to authenticate${NC}"
fi

echo -e "${GREEN}✓ Server ID: $SERVER_ID${NC}"
echo -e "${GREEN}✓ Management URL: $MANAGEMENT_URL${NC}"
echo -e "${GREEN}✓ Port: $ENDNODE_PORT${NC}"

# Step 3: Test management server connectivity
echo -e "${BLUE}[3/5]${NC} Testing management server connectivity..."

MGMT_HEALTH="${MANAGEMENT_URL}/health"
if curl -s -f "$MGMT_HEALTH" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Management server is reachable${NC}"
else
    echo -e "${YELLOW}⚠ Cannot reach management server at $MGMT_HEALTH${NC}"
    echo -e "${YELLOW}  Endnode will retry registration after starting${NC}"
fi

# Step 4: Build and start endnode
echo -e "${BLUE}[4/5]${NC} Building and starting endnode..."

kill_existing

cd "$ENDNODE_DIR"

# Build
echo -e "${YELLOW}Building endnode...${NC}"
go build -o endnode . 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Build failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Build successful${NC}"

# Set environment variables
export ENDNODE_SERVER_ID="$SERVER_ID"
export MANAGEMENT_URL="$MANAGEMENT_URL"
export API_KEY="$API_KEY"
export OPENVPN_DIR="$OPENVPN_DIR"
export CLIENTS_DIR="$CLIENTS_DIR"
export EASYRSA_DIR="$EASYRSA_DIR"
export ENDNODE_PORT="$ENDNODE_PORT"

# Start endnode
echo -e "${YELLOW}Starting endnode on port ${ENDNODE_PORT}...${NC}"
./endnode \
    --server-id "$SERVER_ID" \
    --port "$ENDNODE_PORT" \
    --openvpn-dir "$OPENVPN_DIR" \
    --clients-dir "$CLIENTS_DIR" \
    --easyrsa-dir "$EASYRSA_DIR" \
    > "$LOG_FILE" 2>&1 &

ENDNODE_PID=$!
echo $ENDNODE_PID > "$PID_FILE" 2>/dev/null || true

echo -e "${GREEN}✓ Endnode started (PID: $ENDNODE_PID)${NC}"

# Step 5: Wait for health
echo -e "${BLUE}[5/5]${NC} Waiting for endnode to be ready..."

MAX_WAIT=30
waited=0
while [ $waited -lt $MAX_WAIT ]; do
    if check_health; then
        echo -e "${GREEN}✓ Endnode is healthy!${NC}"
        break
    fi
    
    if ! kill -0 $ENDNODE_PID 2>/dev/null; then
        echo -e "${RED}Error: Endnode process died unexpectedly.${NC}"
        echo -e "${RED}Last 20 lines of log:${NC}"
        tail -20 "$LOG_FILE"
        exit 1
    fi
    
    printf "."
    sleep 1
    waited=$((waited + 1))
done

if [ $waited -ge $MAX_WAIT ]; then
    echo -e "${RED}Error: Endnode did not become healthy within ${MAX_WAIT} seconds.${NC}"
    tail -20 "$LOG_FILE"
    exit 1
fi

# Display status
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ENDNODE (VPN SERVER) RUNNING                 ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Endnode Status:${NC}"
echo -e "  • Server ID:      ${GREEN}$SERVER_ID${NC}"
echo -e "  • API URL:        ${GREEN}http://0.0.0.0:${ENDNODE_PORT}${NC}"
echo -e "  • Health:         ${GREEN}${HEALTH_URL}${NC}"
echo -e "  • Management:     ${GREEN}${MANAGEMENT_URL}${NC}"
echo -e "  • Logs:           ${YELLOW}${LOG_FILE}${NC}"
echo -e "  • PID:            ${YELLOW}${ENDNODE_PID}${NC}"
echo ""
echo -e "${BLUE}Directories:${NC}"
echo -e "  • OpenVPN:        ${YELLOW}${OPENVPN_DIR}${NC}"
echo -e "  • Clients:        ${YELLOW}${CLIENTS_DIR}${NC}"
echo -e "  • EasyRSA:        ${YELLOW}${EASYRSA_DIR}${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the endnode.${NC}"
echo ""

# Follow logs
tail -f "$LOG_FILE" &
TAIL_PID=$!

wait $ENDNODE_PID
kill $TAIL_PID 2>/dev/null || true

