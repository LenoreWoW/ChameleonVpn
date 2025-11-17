#!/bin/bash
# Start All Backend Services
# Usage: ./start-all.sh

set -e

echo "==================================="
echo "BarqNet Backend - Start All Services"
echo "==================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${RED}ERROR: .env file not found!${NC}"
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo -e "${YELLOW}Please edit .env and set your database password${NC}"
    echo "Then run this script again."
    exit 1
fi

# Fix Go dependencies
echo -e "${YELLOW}[1/4] Fixing Go dependencies...${NC}"
go mod tidy
echo -e "${GREEN}✓ Dependencies fixed${NC}"
echo ""

# Build all services
echo -e "${YELLOW}[2/4] Building services...${NC}"

echo "  Building management server..."
go build -o management ./apps/management
echo -e "  ${GREEN}✓ management built${NC}"

echo "  Building VPN server..."
go build -o vpn ./apps/vpn
echo -e "  ${GREEN}✓ vpn built${NC}"

echo "  Building end node..."
go build -o end-node ./apps/end-node
echo -e "  ${GREEN}✓ end-node built${NC}"

echo -e "${GREEN}✓ All services built${NC}"
echo ""

# Check if database is accessible
echo -e "${YELLOW}[3/4] Checking database connection...${NC}"
source .env
if psql -U $DB_USER -d $DB_NAME -h $DB_HOST -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Database connection successful${NC}"
else
    echo -e "${RED}✗ Cannot connect to database${NC}"
    echo "Please check:"
    echo "  1. PostgreSQL is running"
    echo "  2. Database '$DB_NAME' exists"
    echo "  3. User '$DB_USER' has correct password in .env"
    exit 1
fi
echo ""

# Start services
echo -e "${YELLOW}[4/4] Starting services...${NC}"
echo ""
echo "Starting in separate terminal windows..."
echo "Close terminals to stop services"
echo ""

# macOS - use Terminal app
if [[ "$OSTYPE" == "darwin"* ]]; then
    osascript -e 'tell app "Terminal" to do script "cd '"$(pwd)"' && echo \"Management Server\" && ./management"'
    sleep 1
    osascript -e 'tell app "Terminal" to do script "cd '"$(pwd)"' && echo \"VPN Server\" && ./vpn"'
    sleep 1
    osascript -e 'tell app "Terminal" to do script "cd '"$(pwd)"' && echo \"End Node\" && ./end-node"'

    echo -e "${GREEN}✓ Services started in new terminal windows${NC}"
    echo ""
    echo "Services running on:"
    echo "  Management: http://localhost:8080"
    echo "  VPN:        http://localhost:8081"
    echo "  End Node:   http://localhost:8082"

# Linux - use gnome-terminal or xterm
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal -- bash -c "./management; exec bash"
        gnome-terminal -- bash -c "./vpn; exec bash"
        gnome-terminal -- bash -c "./end-node; exec bash"
    elif command -v xterm &> /dev/null; then
        xterm -e "./management" &
        xterm -e "./vpn" &
        xterm -e "./end-node" &
    else
        echo -e "${YELLOW}No terminal emulator found. Starting in background...${NC}"
        ./management > management.log 2>&1 &
        ./vpn > vpn.log 2>&1 &
        ./end-node > end-node.log 2>&1 &
        echo "Check logs: management.log, vpn.log, end-node.log"
    fi

    echo -e "${GREEN}✓ Services started${NC}"
fi

echo ""
echo -e "${GREEN}==================================="
echo "All services started successfully!"
echo "===================================${NC}"
echo ""
echo "Test with: curl http://localhost:8080/health"
