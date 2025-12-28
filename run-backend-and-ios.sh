#!/bin/bash
#
# BarqNet/ChameleonVPN - One-Shot Backend + iOS Launcher
# ========================================================
# This script starts the backend server and launches the iOS app
# once the backend is healthy and ready to accept connections.
#
# Usage: ./run-backend-and-ios.sh
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
BACKEND_DIR="${SCRIPT_DIR}/barqnet-backend/apps/management"
IOS_WORKSPACE="${SCRIPT_DIR}/workvpn-ios/WorkVPN.xcworkspace"
BACKEND_PORT="${MANAGEMENT_PORT:-8085}"
HEALTH_URL="http://127.0.0.1:${BACKEND_PORT}/health"
MAX_WAIT_SECONDS=60
LOG_FILE="/tmp/barqnet_backend.log"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     BarqNet/ChameleonVPN - Backend + iOS Launcher         ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to cleanup on exit
cleanup() {
    if [ -n "$BACKEND_PID" ]; then
        echo -e "\n${YELLOW}Shutting down backend (PID: $BACKEND_PID)...${NC}"
        kill $BACKEND_PID 2>/dev/null || true
        wait $BACKEND_PID 2>/dev/null || true
        echo -e "${GREEN}Backend stopped.${NC}"
    fi
}
trap cleanup EXIT INT TERM

# Function to check if backend is ready
check_backend_health() {
    curl -s -f "$HEALTH_URL" > /dev/null 2>&1
    return $?
}

# Function to kill any existing backend process on the port
kill_existing_backend() {
    local existing_pid=$(lsof -ti:${BACKEND_PORT} 2>/dev/null || true)
    if [ -n "$existing_pid" ]; then
        echo -e "${YELLOW}Found existing process on port ${BACKEND_PORT} (PID: $existing_pid). Killing...${NC}"
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

if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: Xcode command line tools not found.${NC}"
    exit 1
fi

if [ ! -d "$BACKEND_DIR" ]; then
    echo -e "${RED}Error: Backend directory not found: $BACKEND_DIR${NC}"
    exit 1
fi

if [ ! -d "$IOS_WORKSPACE" ]; then
    echo -e "${RED}Error: iOS workspace not found: $IOS_WORKSPACE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"

# Step 2: Kill any existing backend
echo -e "${BLUE}[2/5]${NC} Checking for existing backend processes..."
kill_existing_backend
echo -e "${GREEN}✓ Port ${BACKEND_PORT} is available${NC}"

# Step 3: Start backend
echo -e "${BLUE}[3/5]${NC} Starting backend server..."

cd "$BACKEND_DIR"

# Set environment variables
export MANAGEMENT_PORT=${BACKEND_PORT}
export JWT_SECRET="${JWT_SECRET:-development-jwt-secret-change-in-production-32chars}"
export API_KEY="${API_KEY:-development-api-key-change-in-production}"

# Check for .env file
if [ -f ".env" ]; then
    echo -e "${GREEN}✓ Loading .env file${NC}"
    set -a
    source .env
    set +a
fi

# Start backend in background
echo -e "${YELLOW}Starting backend on port ${BACKEND_PORT}...${NC}"
go run main.go > "$LOG_FILE" 2>&1 &
BACKEND_PID=$!

echo -e "${GREEN}✓ Backend started (PID: $BACKEND_PID)${NC}"
echo -e "${YELLOW}  Logs: $LOG_FILE${NC}"

# Step 4: Wait for backend to be healthy
echo -e "${BLUE}[4/5]${NC} Waiting for backend to be ready..."

waited=0
while [ $waited -lt $MAX_WAIT_SECONDS ]; do
    if check_backend_health; then
        echo -e "${GREEN}✓ Backend is healthy and ready!${NC}"
        break
    fi
    
    # Check if process is still running
    if ! kill -0 $BACKEND_PID 2>/dev/null; then
        echo -e "${RED}Error: Backend process died unexpectedly.${NC}"
        echo -e "${RED}Check logs: $LOG_FILE${NC}"
        tail -20 "$LOG_FILE"
        exit 1
    fi
    
    printf "."
    sleep 1
    waited=$((waited + 1))
done

if [ $waited -ge $MAX_WAIT_SECONDS ]; then
    echo -e "${RED}Error: Backend did not become healthy within ${MAX_WAIT_SECONDS} seconds.${NC}"
    echo -e "${RED}Check logs: $LOG_FILE${NC}"
    tail -20 "$LOG_FILE"
    exit 1
fi

# Verify with a test request
echo -e "${YELLOW}Testing backend health endpoint...${NC}"
HEALTH_RESPONSE=$(curl -s "$HEALTH_URL")
echo -e "${GREEN}✓ Health response: $HEALTH_RESPONSE${NC}"

# Step 5: Launch iOS app
echo -e "${BLUE}[5/5]${NC} Launching iOS app in Xcode..."

# Find available simulators
echo -e "${YELLOW}Finding available iOS simulators...${NC}"
SIMULATOR=$(xcrun simctl list devices available | grep -E "iPhone (14|15|16)" | head -1 | sed 's/.*(\([A-F0-9-]*\)).*/\1/')

if [ -z "$SIMULATOR" ]; then
    # Fallback to any available iPhone
    SIMULATOR=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed 's/.*(\([A-F0-9-]*\)).*/\1/')
fi

if [ -z "$SIMULATOR" ]; then
    echo -e "${YELLOW}No simulator found. Opening Xcode for manual run...${NC}"
    open "$IOS_WORKSPACE"
else
    echo -e "${GREEN}✓ Found simulator: $SIMULATOR${NC}"
    
    # Boot simulator if needed
    echo -e "${YELLOW}Booting simulator...${NC}"
    xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
    
    # Open Simulator app
    open -a Simulator
    
    # Wait for simulator to boot
    sleep 3
    
    # Build and run the iOS app
    echo -e "${YELLOW}Building and running iOS app...${NC}"
    
    cd "$SCRIPT_DIR/workvpn-ios"
    
    # Build using xcodebuild
    xcodebuild \
        -workspace WorkVPN.xcworkspace \
        -scheme WorkVPN \
        -sdk iphonesimulator \
        -destination "id=$SIMULATOR" \
        -configuration Debug \
        build 2>&1 | tail -5
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo -e "${GREEN}✓ iOS app built successfully!${NC}"
        
        # Install and launch the app
        APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "WorkVPN.app" -path "*Debug-iphonesimulator*" 2>/dev/null | head -1)
        
        if [ -n "$APP_PATH" ]; then
            echo -e "${YELLOW}Installing app to simulator...${NC}"
            xcrun simctl install "$SIMULATOR" "$APP_PATH"
            
            echo -e "${YELLOW}Launching app...${NC}"
            xcrun simctl launch "$SIMULATOR" com.barqnet.workvpn
            
            echo -e "${GREEN}✓ iOS app launched successfully!${NC}"
        else
            echo -e "${YELLOW}Could not find built app. Opening Xcode instead...${NC}"
            open "$IOS_WORKSPACE"
        fi
    else
        echo -e "${YELLOW}Build failed. Opening Xcode for manual build...${NC}"
        open "$IOS_WORKSPACE"
    fi
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    SETUP COMPLETE!                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Backend Status:${NC}"
echo -e "  • Running on: ${GREEN}http://127.0.0.1:${BACKEND_PORT}${NC}"
echo -e "  • Health:     ${GREEN}${HEALTH_URL}${NC}"
echo -e "  • Logs:       ${YELLOW}${LOG_FILE}${NC}"
echo -e "  • PID:        ${YELLOW}${BACKEND_PID}${NC}"
echo ""
echo -e "${BLUE}iOS App:${NC}"
echo -e "  • Should be running in Simulator"
echo -e "  • Or open Xcode manually and press ▶"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the backend and exit.${NC}"
echo ""

# Keep script running to maintain backend
wait $BACKEND_PID

