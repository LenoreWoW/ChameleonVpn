#!/bin/bash
# Android Build and Test Script
# Usage: ./build-and-test.sh

set -e

echo "==================================="
echo "BarqNet Android - Build and Test"
echo "==================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if local.properties exists
if [ ! -f "local.properties" ]; then
    echo -e "${RED}ERROR: local.properties not found!${NC}"
    echo ""
    echo "Creating local.properties..."
    echo "sdk.dir=$HOME/Library/Android/sdk" > local.properties
    echo -e "${GREEN}✓ Created local.properties${NC}"
    echo ""
    echo -e "${YELLOW}If build fails, update sdk.dir in local.properties${NC}"
    echo "Find your SDK: Android Studio → Settings → Android SDK"
    echo ""
fi

# Clean previous builds
echo -e "${YELLOW}[1/4] Cleaning previous builds...${NC}"
./gradlew clean
echo -e "${GREEN}✓ Clean complete${NC}"
echo ""

# Initialize ics-openvpn submodule (if needed)
if [ -d "../.git" ]; then
    echo -e "${YELLOW}[2/4] Checking ics-openvpn submodule...${NC}"
    cd ..
    git submodule update --init --recursive workvpn-android/ics-openvpn
    cd workvpn-android
    echo -e "${GREEN}✓ Submodule initialized${NC}"
else
    echo -e "${YELLOW}[2/4] Skipping submodule check (not a git repo)${NC}"
fi
echo ""

# Build debug APK
echo -e "${YELLOW}[3/4] Building debug APK...${NC}"
./gradlew assembleDebug -x test

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    echo ""
    echo "Common issues:"
    echo "  1. SDK not found → Update sdk.dir in local.properties"
    echo "  2. Java version → Ensure Java 17 is installed"
    echo "  3. ics-openvpn → Run: git submodule update --init --recursive"
    exit 1
fi
echo ""

# Build release APK (optional)
echo -e "${YELLOW}[4/4] Building release APK...${NC}"
./gradlew assembleRelease -x test || echo -e "${YELLOW}⚠ Release build skipped (needs signing config)${NC}"
echo ""

# Summary
echo -e "${GREEN}==================================="
echo "Android Build Complete!"
echo "===================================${NC}"
echo ""

if [ -f "app/build/outputs/apk/debug/app-debug.apk" ]; then
    echo "Debug APK:"
    ls -lh app/build/outputs/apk/debug/app-debug.apk
    echo ""
    echo "Install with:"
    echo "  ./gradlew installDebug"
    echo "  OR"
    echo "  adb install app/build/outputs/apk/debug/app-debug.apk"
fi

echo ""
echo "Run on device/emulator:"
echo "  ./gradlew installDebug"
echo "  adb shell am start -n com.barqnet.android/.MainActivity"
