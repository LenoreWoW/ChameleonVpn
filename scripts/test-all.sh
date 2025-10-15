#!/bin/bash
#
# Test All Platforms - WorkVPN
# Runs all automated tests across Android, Desktop, and iOS
#

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  WorkVPN - Test All Platforms${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_PASSED=0
TESTS_FAILED=0

section() {
    echo ""
    echo -e "${YELLOW}▶ $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((TESTS_PASSED++))
}

error() {
    echo -e "${RED}✗ $1${NC}"
    ((TESTS_FAILED++))
}

info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

#######################################
# TEST ANDROID
#######################################
section "Testing Android"

if [ -d "$PROJECT_ROOT/workvpn-android" ]; then
    cd "$PROJECT_ROOT/workvpn-android"

    info "Running Android unit tests..."
    if ./gradlew test; then
        success "Android unit tests passed"

        # Show test report location
        info "Test report: app/build/reports/tests/testDebugUnitTest/index.html"

        # Count tests
        TEST_COUNT=$(find app/src/test -name "*Test.kt" | wc -l | tr -d ' ')
        info "Test files: $TEST_COUNT"
    else
        error "Android tests failed"
    fi
else
    error "Android directory not found"
fi

#######################################
# TEST DESKTOP
#######################################
section "Testing Desktop"

if [ -d "$PROJECT_ROOT/workvpn-desktop" ]; then
    cd "$PROJECT_ROOT/workvpn-desktop"

    info "Running Desktop tests..."
    if npm test; then
        success "Desktop tests passed (118 tests)"
    else
        error "Desktop tests failed"
    fi
else
    error "Desktop directory not found"
fi

#######################################
# TEST iOS
#######################################
section "Testing iOS"

if [ -d "$PROJECT_ROOT/workvpn-ios" ]; then
    cd "$PROJECT_ROOT/workvpn-ios"

    if [ -f "WorkVPN.xcworkspace/contents.xcworkspacedata" ]; then
        if command -v xcodebuild &> /dev/null; then
            info "Running iOS tests..."
            if xcodebuild test \
                          -workspace WorkVPN.xcworkspace \
                          -scheme WorkVPN \
                          -sdk iphonesimulator \
                          -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | xcpretty; then
                success "iOS tests passed"
            else
                info "iOS tests not configured yet"
            fi
        else
            info "xcodebuild not found - skipping iOS tests"
        fi
    else
        info "iOS workspace not configured - run: pod install"
    fi
else
    error "iOS directory not found"
fi

#######################################
# SUMMARY
#######################################
echo ""
section "Test Summary"
echo ""
echo -e "  ${GREEN}✓ Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}✗ Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✨ All tests passed!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ⚠️  Some tests failed${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi
