#!/bin/bash
# Desktop/Electron Build and Test Script
# Usage: ./build-and-test.sh

set -e

echo "===================================="
echo "BarqNet Desktop - Build and Test"
echo "===================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if OpenVPN is installed
echo -e "${YELLOW}[1/6] Checking OpenVPN installation...${NC}"

OPENVPN_PATHS=(
    "/opt/homebrew/sbin/openvpn"        # Homebrew ARM (M1/M2 Macs)
    "/usr/local/sbin/openvpn"           # Homebrew Intel
    "/usr/local/bin/openvpn"            # Manual install
    "/usr/sbin/openvpn"                 # Linux default
    "/usr/bin/openvpn"                  # Alternative Linux
)

OPENVPN_FOUND=""
for path in "${OPENVPN_PATHS[@]}"; do
    if [ -f "$path" ]; then
        OPENVPN_FOUND="$path"
        break
    fi
done

if [ -z "$OPENVPN_FOUND" ]; then
    echo -e "${RED}✗ OpenVPN not found${NC}"
    echo ""
    echo "OpenVPN is REQUIRED for the Desktop app to function."
    echo ""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Install on macOS:"
        echo "  brew install openvpn"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Install on Linux:"
        echo "  sudo apt-get install openvpn  # Debian/Ubuntu"
        echo "  sudo yum install openvpn      # RedHat/CentOS"
    fi
    echo ""
    exit 1
else
    echo -e "${GREEN}✓ OpenVPN found at: $OPENVPN_FOUND${NC}"
    $OPENVPN_FOUND --version | head -1
fi
echo ""

# Check if .env exists
echo -e "${YELLOW}[2/6] Checking .env configuration...${NC}"
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠ .env file not found${NC}"
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo -e "${GREEN}✓ Created .env (update API_BASE_URL if needed)${NC}"
else
    echo -e "${GREEN}✓ .env file exists${NC}"
fi
echo ""

# Install dependencies if needed
echo -e "${YELLOW}[3/6] Checking Node.js dependencies...${NC}"
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${GREEN}✓ Dependencies already installed${NC}"
fi
echo ""

# Build TypeScript
echo -e "${YELLOW}[4/6] Building TypeScript...${NC}"
npm run build

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    echo ""
    echo "Common issues:"
    echo "  1. TypeScript errors → Check src/ files for type errors"
    echo "  2. Missing dependencies → Run: npm install"
    exit 1
fi
echo ""

# Check if backend is running (optional)
echo -e "${YELLOW}[5/6] Checking backend connection (optional)...${NC}"
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Backend is running at http://localhost:8080${NC}"
else
    echo -e "${YELLOW}⚠ Backend not running (app will work but can't authenticate)${NC}"
    echo "To start backend:"
    echo "  cd ../barqnet-backend"
    echo "  ./start-all.sh"
fi
echo ""

# Test run (optional)
echo -e "${YELLOW}[6/6] Build summary${NC}"
echo "App name: BarqNet Desktop"
echo "Built with: Electron + TypeScript"
echo "OpenVPN: System binary at $OPENVPN_FOUND"
echo ""

echo -e "${GREEN}===================================="
echo "Desktop Build Complete!"
echo "===================================${NC}"
echo ""
echo "To start the app:"
echo "  npm start"
echo ""
echo "To package for distribution:"
echo "  npm run make"
echo ""
echo "Output locations:"
echo "  Development: dist/"
echo "  Packaged: out/"
echo ""
echo "IMPORTANT:"
echo "  - OpenVPN must be installed on target systems"
echo "  - Backend must be running for authentication"
echo "  - Update .env file for production deployment"
