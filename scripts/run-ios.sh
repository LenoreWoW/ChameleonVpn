#!/bin/bash
#
# BarqNet/ChameleonVPN - iOS App Launcher
# =======================================
# Run this script on your DEVELOPMENT MAC to test the iOS app
#
# Prerequisites:
#   - Xcode 15+
#   - CocoaPods installed
#   - Backend server running (can be remote)
#
# Usage: ./run-ios.sh [--backend-url http://your-server:8085]
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
IOS_DIR="${SCRIPT_DIR}/../workvpn-ios"
IOS_WORKSPACE="${IOS_DIR}/WorkVPN.xcworkspace"
BACKEND_URL="${BACKEND_URL:-http://127.0.0.1:8085}"
BUNDLE_ID="com.workvpn.ios"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --backend-url)
            BACKEND_URL="$2"
            shift 2
            ;;
        --simulator)
            PREFERRED_SIMULATOR="$2"
            shift 2
            ;;
        --device)
            USE_DEVICE=true
            shift
            ;;
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --backend-url <url>   Backend server URL (default: http://127.0.0.1:8085)"
            echo "  --simulator <name>    Preferred simulator (e.g., 'iPhone 15 Pro')"
            echo "  --device              Build for physical device instead of simulator"
            echo "  --build-only          Only build, don't run"
            echo ""
            echo "Environment variables:"
            echo "  BACKEND_URL           Backend server URL"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            BarqNet - iOS App Launcher                     ║${NC}"
echo -e "${BLUE}║               (Run on Development Mac)                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check prerequisites
echo -e "${BLUE}[1/5]${NC} Checking prerequisites..."

if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: Xcode command line tools not found.${NC}"
    echo -e "${YELLOW}  Install: xcode-select --install${NC}"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1)
echo -e "${GREEN}✓ $XCODE_VERSION${NC}"

if [ ! -d "$IOS_WORKSPACE" ]; then
    echo -e "${RED}Error: iOS workspace not found: $IOS_WORKSPACE${NC}"
    exit 1
fi
echo -e "${GREEN}✓ iOS workspace found${NC}"

# Check for CocoaPods
if [ -f "${IOS_DIR}/Podfile" ]; then
    if [ ! -d "${IOS_DIR}/Pods" ]; then
        echo -e "${YELLOW}Installing CocoaPods dependencies...${NC}"
        cd "$IOS_DIR"
        pod install
    fi
    echo -e "${GREEN}✓ CocoaPods dependencies installed${NC}"
fi

# Step 2: Test backend connectivity
echo -e "${BLUE}[2/5]${NC} Testing backend connectivity..."

HEALTH_URL="${BACKEND_URL}/health"
if curl -s -f "$HEALTH_URL" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Backend is reachable at $BACKEND_URL${NC}"
else
    echo -e "${YELLOW}⚠ Cannot reach backend at $HEALTH_URL${NC}"
    echo -e "${YELLOW}  Make sure your backend server is running${NC}"
    echo -e "${YELLOW}  The iOS app may not function correctly without backend${NC}"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 3: Find or boot simulator
echo -e "${BLUE}[3/5]${NC} Setting up iOS Simulator..."

if [ "$USE_DEVICE" = true ]; then
    echo -e "${YELLOW}Building for physical device...${NC}"
    DESTINATION="generic/platform=iOS"
else
    # Find available simulators using better regex
    if [ -n "$PREFERRED_SIMULATOR" ]; then
        SIMULATOR_UDID=$(xcrun simctl list devices available | grep "$PREFERRED_SIMULATOR" | grep -oE '[A-F0-9]{8}-([A-F0-9]{4}-){3}[A-F0-9]{12}' | head -1)
    fi

    if [ -z "$SIMULATOR_UDID" ]; then
        # Try to find iPhone 16, 15, 14, or any iPhone
        SIMULATOR_UDID=$(xcrun simctl list devices available | grep -E "iPhone (16|15|14)" | grep -oE '[A-F0-9]{8}-([A-F0-9]{4}-){3}[A-F0-9]{12}' | head -1)
    fi

    if [ -z "$SIMULATOR_UDID" ]; then
        SIMULATOR_UDID=$(xcrun simctl list devices available | grep "iPhone" | grep -oE '[A-F0-9]{8}-([A-F0-9]{4}-){3}[A-F0-9]{12}' | head -1)
    fi

    if [ -z "$SIMULATOR_UDID" ]; then
        echo -e "${RED}Error: No iOS simulator found.${NC}"
        echo -e "${YELLOW}  Create one in Xcode: Window > Devices and Simulators${NC}"
        exit 1
    fi

    SIMULATOR_NAME=$(xcrun simctl list devices | grep "$SIMULATOR_UDID" | sed -E 's/^[[:space:]]*(.+) \([A-F0-9-]+\) .*/\1/')

    # Get the iOS runtime version for this simulator
    RUNTIME_VERSION=$(xcrun simctl list devices | grep -B 1 "$SIMULATOR_UDID" | grep "-- iOS" | sed 's/-- iOS \(.*\) --.*/\1/' | head -1)

    if [ -z "$RUNTIME_VERSION" ]; then
        # Fallback: check all runtimes
        RUNTIME_VERSION=$(xcrun simctl list runtimes | grep iOS | tail -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    fi

    echo -e "${GREEN}✓ Using simulator: $SIMULATOR_NAME${NC}"
    echo -e "${GREEN}  UDID: $SIMULATOR_UDID${NC}"
    echo -e "${GREEN}  iOS Runtime: $RUNTIME_VERSION${NC}"

    # Check if already booted
    BOOT_STATUS=$(xcrun simctl list devices | grep "$SIMULATOR_UDID" | grep -o "(Booted)" || echo "")

    if [ -z "$BOOT_STATUS" ]; then
        # Boot simulator
        echo -e "${YELLOW}Booting simulator...${NC}"
        xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true

        # Wait for simulator to fully boot
        echo -e "${YELLOW}Waiting for simulator to be ready...${NC}"
        for i in {1..30}; do
            BOOT_STATUS=$(xcrun simctl list devices | grep "$SIMULATOR_UDID" | grep -o "(Booted)" || echo "")
            if [ -n "$BOOT_STATUS" ]; then
                echo -e "${GREEN}✓ Simulator booted${NC}"
                break
            fi
            sleep 1
            printf "."
        done
        echo ""

        if [ -z "$BOOT_STATUS" ]; then
            echo -e "${RED}Warning: Simulator may not be fully booted${NC}"
        fi
    else
        echo -e "${GREEN}✓ Simulator already booted${NC}"
    fi

    # Open Simulator app
    open -a Simulator
    sleep 2

    # Try multiple destination formats for better compatibility
    # For Xcode 26.x, the destination format needs to be precise
    if [ -n "$RUNTIME_VERSION" ]; then
        DESTINATION="platform=iOS Simulator,OS=$RUNTIME_VERSION,name=$SIMULATOR_NAME"
        echo -e "${BLUE}Using destination: $DESTINATION${NC}"
    else
        DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
        echo -e "${BLUE}Using destination: $DESTINATION${NC}"
    fi
fi

# Step 4: Build the app
echo -e "${BLUE}[4/5]${NC} Building iOS app..."

cd "$IOS_DIR"

# Clean derived data to fix bundle ID issues
echo -e "${YELLOW}Cleaning build cache...${NC}"
rm -rf ~/Library/Developer/Xcode/DerivedData/WorkVPN-* 2>/dev/null || true

echo -e "${YELLOW}Building WorkVPN...${NC}"

if [ "$USE_DEVICE" = true ]; then
    SDK="iphoneos"
else
    SDK="iphonesimulator"
fi

# Show available destinations for debugging
echo -e "${BLUE}Available destinations:${NC}"
xcodebuild -workspace WorkVPN.xcworkspace -scheme WorkVPN -showdestinations 2>&1 | grep -E "platform|name|id" | head -10

echo ""
echo -e "${YELLOW}Building with destination: $DESTINATION${NC}"
echo ""

xcodebuild \
    -workspace WorkVPN.xcworkspace \
    -scheme WorkVPN \
    -destination "$DESTINATION" \
    -configuration Debug \
    build 2>&1 | while read line; do
        if [[ "$line" == *"error:"* ]]; then
            echo -e "${RED}$line${NC}"
        elif [[ "$line" == *"warning:"* ]]; then
            echo -e "${YELLOW}$line${NC}"
        elif [[ "$line" == *"BUILD SUCCEEDED"* ]]; then
            echo -e "${GREEN}$line${NC}"
        fi
    done

BUILD_RESULT=${PIPESTATUS[0]}

if [ $BUILD_RESULT -ne 0 ]; then
    echo -e "${RED}Error: Build failed${NC}"
    echo -e "${YELLOW}Try opening Xcode manually: open $IOS_WORKSPACE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful!${NC}"

if [ "$BUILD_ONLY" = true ]; then
    echo -e "${GREEN}Build complete. Skipping run.${NC}"
    exit 0
fi

# Step 5: Install and launch
echo -e "${BLUE}[5/5]${NC} Installing and launching app..."

if [ "$USE_DEVICE" = true ]; then
    echo -e "${YELLOW}For physical device, use Xcode to install and run.${NC}"
    open "$IOS_WORKSPACE"
else
    # Find the built app - look in Build/Products, not Index
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "WorkVPN.app" -path "*/Build/Products/Debug-iphonesimulator/*" -type d 2>/dev/null | head -1)

    if [ -z "$APP_PATH" ]; then
        echo -e "${RED}Could not find built app in DerivedData.${NC}"
        echo -e "${YELLOW}Trying alternative search...${NC}"
        APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "WorkVPN.app" -path "*iphonesimulator*" -type d 2>/dev/null | grep -v "Index.noindex" | head -1)
    fi

    if [ -z "$APP_PATH" ]; then
        echo -e "${RED}Could not find built app. Opening Xcode...${NC}"
        open "$IOS_WORKSPACE"
    else
        echo -e "${GREEN}Found app at: $APP_PATH${NC}"

        # Verify bundle ID exists in built app
        BUILT_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null)
        if [ -z "$BUILT_BUNDLE_ID" ]; then
            echo -e "${RED}Error: Built app has no bundle identifier!${NC}"
            echo -e "${YELLOW}This indicates a build configuration issue.${NC}"
            echo -e "${YELLOW}Opening Xcode for manual inspection...${NC}"
            open "$IOS_WORKSPACE"
            exit 1
        fi

        echo -e "${GREEN}Bundle ID: $BUILT_BUNDLE_ID${NC}"

        echo -e "${YELLOW}Installing app to simulator...${NC}"
        xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"

        echo -e "${YELLOW}Launching app...${NC}"
        xcrun simctl launch "$SIMULATOR_UDID" "$BUILT_BUNDLE_ID"

        echo -e "${GREEN}✓ App launched successfully!${NC}"
    fi
fi

# Display status
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                iOS APP READY                              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo -e "  • Backend URL:    ${GREEN}${BACKEND_URL}${NC}"
if [ "$USE_DEVICE" != true ]; then
    echo -e "  • Simulator:      ${GREEN}${SIMULATOR_NAME}${NC}"
fi
echo ""
echo -e "${BLUE}Testing the App:${NC}"
echo -e "  1. The app should now be running in the Simulator"
echo -e "  2. Try registering a new account"
echo -e "  3. Check backend logs for OTP codes"
echo -e "  4. Login and test VPN connection"
echo ""
echo -e "${BLUE}Troubleshooting:${NC}"
echo -e "  • If app crashes, check Xcode console"
echo -e "  • If API fails, verify backend is running"
echo -e "  • View backend logs: tail -f /tmp/barqnet_management.log"
echo ""
echo -e "${YELLOW}To rebuild: $0${NC}"
echo -e "${YELLOW}To open Xcode: open $IOS_WORKSPACE${NC}"

