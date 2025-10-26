#!/bin/bash
#
# Build All Platforms - BarqNet
# Builds Android, Desktop, and iOS (if Xcode configured)
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  BarqNet - Build All Platforms${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SUCCESS=0
BUILD_FAILED=0

# Function to print section header
section() {
    echo ""
    echo -e "${YELLOW}▶ $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to print success
success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((BUILD_SUCCESS++))
}

# Function to print error
error() {
    echo -e "${RED}✗ $1${NC}"
    ((BUILD_FAILED++))
}

# Function to print info
info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

#######################################
# BUILD ANDROID
#######################################
section "Building Android"

if [ -d "$PROJECT_ROOT/barqnet-android" ]; then
    cd "$PROJECT_ROOT/barqnet-android"

    info "Building Android Debug APK..."
    if ./gradlew clean assembleDebug; then
        success "Android Debug APK built successfully"
        info "Location: app/build/outputs/apk/debug/app-debug.apk"
    else
        error "Android Debug build failed"
    fi

    info "Running Android tests..."
    if ./gradlew test; then
        success "Android tests passed"
    else
        error "Android tests failed"
    fi
else
    error "Android directory not found"
fi

#######################################
# BUILD DESKTOP
#######################################
section "Building Desktop"

if [ -d "$PROJECT_ROOT/barqnet-desktop" ]; then
    cd "$PROJECT_ROOT/barqnet-desktop"

    # Check if OpenVPN is installed
    if command -v openvpn &> /dev/null; then
        success "OpenVPN is installed"
    else
        error "OpenVPN not found - install with: brew install openvpn"
    fi

    info "Installing dependencies..."
    if npm install; then
        success "Dependencies installed"
    else
        error "npm install failed"
    fi

    info "Building Desktop app..."
    if npm run build; then
        success "Desktop app built successfully"
    else
        error "Desktop build failed"
    fi

    info "Running Desktop tests..."
    if npm test; then
        success "Desktop tests passed"
    else
        error "Desktop tests failed"
    fi
else
    error "Desktop directory not found"
fi

#######################################
# BUILD iOS
#######################################
section "Building iOS"

if [ -d "$PROJECT_ROOT/barqnet-ios" ]; then
    cd "$PROJECT_ROOT/barqnet-ios"

    # Check if xcworkspace exists
    if [ -f "BarqNet.xcworkspace/contents.xcworkspacedata" ]; then
        info "Xcode workspace found"

        # Check if xcodebuild is available
        if command -v xcodebuild &> /dev/null; then
            info "Building iOS app..."
            if xcodebuild -workspace BarqNet.xcworkspace \
                          -scheme BarqNet \
                          -configuration Debug \
                          -sdk iphoneos \
                          CODE_SIGNING_ALLOWED=NO; then
                success "iOS app built successfully"
            else
                error "iOS build failed"
            fi
        else
            error "xcodebuild not found - install Xcode"
        fi
    else
        info "iOS Xcode workspace not found"
        info "Run: cd barqnet-ios && pod install"
        info "Then open BarqNet.xcworkspace in Xcode"
    fi
else
    error "iOS directory not found"
fi

#######################################
# SUMMARY
#######################################
echo ""
section "Build Summary"
echo ""
echo -e "  ${GREEN}✓ Successful: $BUILD_SUCCESS${NC}"
echo -e "  ${RED}✗ Failed: $BUILD_FAILED${NC}"
echo ""

if [ $BUILD_FAILED -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  🎉 All builds successful!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ⚠️  Some builds failed${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi
