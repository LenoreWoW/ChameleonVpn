#!/bin/bash

# BarqNet iOS - Automated Setup and Run Script
# This script sets up all dependencies and runs the iOS app on Simulator
# Usage: ./setup-ios.sh

set -e  # Exit on error

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 BarqNet iOS - Automated Setup & Run Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="${SCRIPT_DIR}/workvpn-ios"

echo -e "${BLUE}📍 Working directory: ${NC}${SCRIPT_DIR}"
echo ""

# Step 1: Check if we're in the right directory
echo -e "${BLUE}[1/6]${NC} Checking project structure..."
if [ ! -d "$IOS_DIR" ]; then
    echo -e "${RED}❌ Error: workvpn-ios directory not found${NC}"
    echo "Please run this script from the ChameleonVpn project root"
    exit 1
fi
echo -e "${GREEN}✓${NC} Project structure verified"
echo ""

# Step 2: Check for CocoaPods
echo -e "${BLUE}[2/6]${NC} Checking CocoaPods installation..."
if ! command -v pod &> /dev/null; then
    echo -e "${YELLOW}⚠️  CocoaPods not found. Installing...${NC}"

    # Check if we have sudo access
    if sudo -n true 2>/dev/null; then
        sudo gem install cocoapods
    else
        echo -e "${YELLOW}Installing CocoaPods (you may be prompted for password)...${NC}"
        sudo gem install cocoapods
    fi

    if ! command -v pod &> /dev/null; then
        echo -e "${RED}❌ Failed to install CocoaPods${NC}"
        echo "Please install manually: sudo gem install cocoapods"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} CocoaPods installed successfully"
else
    POD_VERSION=$(pod --version)
    echo -e "${GREEN}✓${NC} CocoaPods already installed (v${POD_VERSION})"
fi
echo ""

# Step 3: Navigate to iOS directory and install pods
echo -e "${BLUE}[3/6]${NC} Installing iOS dependencies..."
cd "$IOS_DIR"

# Clean any existing pod cache
echo "  Cleaning pod cache..."
rm -rf Pods Podfile.lock

echo "  Running pod install..."
pod install --repo-update

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ pod install failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Dependencies installed successfully"
echo ""

# Step 4: Verify workspace exists
echo -e "${BLUE}[4/6]${NC} Verifying Xcode workspace..."
if [ ! -f "WorkVPN.xcworkspace/contents.xcworkspacedata" ]; then
    echo -e "${RED}❌ Workspace not created properly${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Workspace verified"
echo ""

# Step 5: Check for Xcode
echo -e "${BLUE}[5/6]${NC} Checking Xcode installation..."
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${YELLOW}⚠️  Xcode command-line tools not found${NC}"
    echo -e "${YELLOW}Opening workspace manually...${NC}"
    open WorkVPN.xcworkspace
    echo ""
    echo -e "${GREEN}✓${NC} Workspace opened in Xcode"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ Setup Complete!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Next steps in Xcode:"
    echo "  1. Select 'WorkVPN' scheme"
    echo "  2. Select any iOS Simulator (iPhone 15 recommended)"
    echo "  3. Press ⌘R to build and run"
    echo ""
    exit 0
fi

XCODE_VERSION=$(xcodebuild -version | head -n 1)
echo -e "${GREEN}✓${NC} ${XCODE_VERSION} found"
echo ""

# Step 6: Build and run
echo -e "${BLUE}[6/6]${NC} Building and running app..."
echo ""

# Get list of available simulators
echo "Available iOS Simulators:"
xcrun simctl list devices available | grep "iPhone" | head -5

# Try to find iPhone 15 or latest iPhone simulator
SIMULATOR=$(xcrun simctl list devices available | grep "iPhone 15" | head -n 1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')

if [ -z "$SIMULATOR" ]; then
    # Fallback to any iPhone simulator
    SIMULATOR=$(xcrun simctl list devices available | grep "iPhone" | head -n 1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
fi

if [ -z "$SIMULATOR" ]; then
    echo -e "${RED}❌ No iPhone simulator found${NC}"
    echo -e "${YELLOW}Opening workspace manually...${NC}"
    open WorkVPN.xcworkspace
    exit 0
fi

echo ""
echo "Selected simulator: ${SIMULATOR}"
echo ""
echo "Building WorkVPN..."

# Build the app
xcodebuild \
    -workspace WorkVPN.xcworkspace \
    -scheme WorkVPN \
    -destination "id=${SIMULATOR}" \
    -configuration Debug \
    clean build \
    | tee /tmp/xcodebuild.log \
    | grep -E "Building|Compiling|Linking|error:|warning:|BUILD SUCCEEDED|BUILD FAILED"

BUILD_STATUS=${PIPESTATUS[0]}

if [ $BUILD_STATUS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓${NC} Build successful!"
    echo ""
    echo "Installing and launching app on simulator..."

    # Boot simulator if not already running
    xcrun simctl boot "$SIMULATOR" 2>/dev/null || true

    # Open Simulator app
    open -a Simulator

    # Install and launch the app
    xcodebuild \
        -workspace WorkVPN.xcworkspace \
        -scheme WorkVPN \
        -destination "id=${SIMULATOR}" \
        -configuration Debug \
        run &

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ Setup Complete! App is launching on simulator...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "The iOS Simulator should open automatically with the BarqNet app."
    echo ""
    echo "To rebuild and run again:"
    echo "  ./setup-ios.sh"
    echo ""
    echo "Or use Xcode:"
    echo "  1. Open WorkVPN.xcworkspace"
    echo "  2. Select WorkVPN scheme + iPhone Simulator"
    echo "  3. Press ⌘R"
    echo ""
else
    echo ""
    echo -e "${RED}❌ Build failed${NC}"
    echo ""
    echo "Build log saved to: /tmp/xcodebuild.log"
    echo ""
    echo "Common issues:"
    echo "  1. Make sure Xcode is fully installed (not just command-line tools)"
    echo "  2. Open Xcode and accept any license agreements"
    echo "  3. Try opening WorkVPN.xcworkspace manually and building from Xcode"
    echo ""
    echo "Opening workspace for manual build..."
    open WorkVPN.xcworkspace
    exit 1
fi
