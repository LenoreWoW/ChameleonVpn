#!/bin/bash
#
# BarqNet Pre-Deployment Verification Script
#
# This script verifies that all components are ready for deployment:
# - Backend builds and configuration
# - Android build readiness (Java 17)
# - iOS dependencies
# - Desktop build
# - Database configuration
#
# Usage: ./verify-deployment.sh
#

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Functions
print_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}$1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}▶ $1${NC}"
}

print_pass() {
    echo -e "  ${GREEN}✅ $1${NC}"
    ((PASSED++))
}

print_fail() {
    echo -e "  ${RED}❌ $1${NC}"
    ((FAILED++))
}

print_warn() {
    echo -e "  ${YELLOW}⚠️  $1${NC}"
    ((WARNINGS++))
}

print_info() {
    echo -e "  ℹ️  $1"
}

# Start verification
clear
print_header "BarqNet Pre-Deployment Verification"
echo "Running comprehensive system check..."
echo "Date: $(date)"
echo ""

#############################################
# 1. JAVA VERSION CHECK
#############################################
print_section "1. Java Version (Required for Android)"

if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    MAJOR_VERSION=$(echo $JAVA_VERSION | cut -d'.' -f1)

    if [ "$MAJOR_VERSION" -ge 17 ]; then
        print_pass "Java $JAVA_VERSION (17+ required)"
        JAVA_OK=true
    else
        print_fail "Java $JAVA_VERSION detected - Java 17+ required"
        print_info "Run: ./install-java17.sh"
        JAVA_OK=false
    fi
else
    print_fail "Java not installed"
    print_info "Run: ./install-java17.sh"
    JAVA_OK=false
fi

#############################################
# 2. BACKEND VERIFICATION
#############################################
print_section "2. Backend Configuration"

# Check if backend directory exists
if [ -d "barqnet-backend" ]; then
    print_pass "Backend directory exists"

    # Check .env file
    if [ -f "barqnet-backend/.env" ]; then
        print_pass ".env file exists"

        # Verify key variables
        if grep -q "DB_NAME=" "barqnet-backend/.env" && \
           grep -q "DB_USER=" "barqnet-backend/.env" && \
           grep -q "JWT_SECRET=" "barqnet-backend/.env"; then
            print_pass "Environment variables configured"
        else
            print_fail "Missing required environment variables"
        fi
    else
        print_fail ".env file not found"
        print_info "Copy from: cp barqnet-backend/.env.example barqnet-backend/.env"
    fi

    # Check Go installation
    if command -v go &> /dev/null; then
        GO_VERSION=$(go version | awk '{print $3}')
        print_pass "Go installed ($GO_VERSION)"

        # Try to build backend
        print_info "Testing backend build..."
        cd barqnet-backend
        if go build -o /tmp/management-test ./apps/management 2>/dev/null; then
            print_pass "Backend (management) builds successfully"
            rm -f /tmp/management-test
        else
            print_fail "Backend build failed"
        fi

        if go build -o /tmp/endnode-test ./apps/endnode 2>/dev/null; then
            print_pass "Backend (endnode) builds successfully"
            rm -f /tmp/endnode-test
        else
            print_fail "Backend endnode build failed"
        fi
        cd ..
    else
        print_fail "Go not installed"
    fi
else
    print_fail "Backend directory not found"
fi

#############################################
# 3. DATABASE VERIFICATION
#############################################
print_section "3. Database Configuration"

if command -v psql &> /dev/null; then
    print_pass "PostgreSQL client installed"

    # Check if database exists (try to connect)
    if grep -q "DB_NAME=vpnmanager" "barqnet-backend/.env" 2>/dev/null; then
        DB_NAME="vpnmanager"
        print_info "Database name: $DB_NAME"

        # Try to verify database exists
        if psql -U postgres -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw $DB_NAME; then
            print_pass "Database '$DB_NAME' exists"
        else
            print_warn "Could not verify database existence (may need authentication)"
        fi
    elif grep -q "DB_NAME=" "barqnet-backend/.env" 2>/dev/null; then
        DB_NAME=$(grep "DB_NAME=" "barqnet-backend/.env" | cut -d'=' -f2)
        print_info "Database name: $DB_NAME"
    else
        print_warn "DB_NAME not configured in .env"
    fi
else
    print_warn "PostgreSQL client not installed (cannot verify database)"
fi

#############################################
# 4. ANDROID VERIFICATION
#############################################
print_section "4. Android Build Environment"

if [ -d "workvpn-android" ]; then
    print_pass "Android directory exists"

    # Check Gradle wrapper
    if [ -f "workvpn-android/gradlew" ]; then
        print_pass "Gradle wrapper exists"

        if [ "$JAVA_OK" = true ]; then
            # Try to validate Gradle configuration
            print_info "Testing Android build configuration..."
            cd workvpn-android
            if ./gradlew tasks --quiet 2>&1 | grep -q "build"; then
                print_pass "Android Gradle configuration valid"
            else
                print_warn "Could not validate Gradle configuration"
            fi
            cd ..
        else
            print_warn "Skipping Android build test (Java 17+ required)"
        fi
    else
        print_fail "Gradle wrapper not found"
    fi
else
    print_fail "Android directory not found"
fi

#############################################
# 5. iOS VERIFICATION
#############################################
print_section "5. iOS Build Environment"

if [ -d "workvpn-ios" ]; then
    print_pass "iOS directory exists"

    # Check CocoaPods
    if command -v pod &> /dev/null; then
        print_pass "CocoaPods installed"

        # Check if Podfile exists
        if [ -f "workvpn-ios/Podfile" ]; then
            print_pass "Podfile exists"

            # Check if pods are installed
            if [ -d "workvpn-ios/Pods" ]; then
                print_pass "CocoaPods dependencies installed"
            else
                print_warn "Pods not installed - run: cd workvpn-ios && pod install"
            fi
        else
            print_fail "Podfile not found"
        fi
    else
        print_warn "CocoaPods not installed (iOS builds unavailable)"
    fi

    # Check Assets
    if [ -d "workvpn-ios/Assets.xcassets" ]; then
        print_pass "Assets.xcassets directory exists"

        if [ -f "workvpn-ios/Assets.xcassets/AppIcon.appiconset/Contents.json" ]; then
            print_pass "AppIcon configured"
        else
            print_warn "AppIcon not configured"
        fi

        if [ -f "workvpn-ios/Assets.xcassets/AccentColor.colorset/Contents.json" ]; then
            print_pass "AccentColor configured"
        else
            print_warn "AccentColor not configured"
        fi
    else
        print_fail "Assets.xcassets not found"
    fi
else
    print_fail "iOS directory not found"
fi

#############################################
# 6. DESKTOP VERIFICATION
#############################################
print_section "6. Desktop Build Environment"

if [ -d "workvpn-desktop" ]; then
    print_pass "Desktop directory exists"

    # Check Node.js
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_pass "Node.js installed ($NODE_VERSION)"

        # Check if node_modules exists
        if [ -d "workvpn-desktop/node_modules" ]; then
            print_pass "npm dependencies installed"

            # Check if TypeScript compiles
            print_info "Testing Desktop build..."
            cd workvpn-desktop
            if npm run build >/dev/null 2>&1; then
                print_pass "Desktop builds successfully"
            else
                print_fail "Desktop build failed"
            fi
            cd ..
        else
            print_warn "Dependencies not installed - run: cd workvpn-desktop && npm install"
        fi
    else
        print_fail "Node.js not installed"
    fi
else
    print_fail "Desktop directory not found"
fi

#############################################
# 7. DOCUMENTATION CHECK
#############################################
print_section "7. Documentation"

DOCS=("CLIENT_BUILD_INSTRUCTIONS.md" "HAMAD_READ_THIS.md" "COMPREHENSIVE_AUDIT_REPORT_NOV_17.md")
for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        print_pass "$doc exists"
    else
        print_warn "$doc missing"
    fi
done

#############################################
# SUMMARY
#############################################
print_header "Verification Summary"

echo "Results:"
echo -e "  ${GREEN}✅ Passed:   $PASSED${NC}"
echo -e "  ${YELLOW}⚠️  Warnings: $WARNINGS${NC}"
echo -e "  ${RED}❌ Failed:   $FAILED${NC}"
echo ""

# Overall status
if [ $FAILED -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ ALL CHECKS PASSED - READY FOR DEPLOYMENT!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        print_info "Next steps:"
        echo "  1. Backend: cd barqnet-backend && ./management"
        echo "  2. Android: cd workvpn-android && ./gradlew assembleDebug"
        echo "  3. iOS:     cd workvpn-ios && open WorkVPN.xcworkspace"
        echo "  4. Desktop: cd workvpn-desktop && npm start"
        echo ""
        exit 0
    else
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}⚠️  DEPLOYMENT READY WITH $WARNINGS WARNING(S)${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        print_info "Warnings can usually be ignored for initial deployment."
        echo ""
        exit 0
    fi
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ DEPLOYMENT BLOCKED - $FAILED CRITICAL ISSUE(S)${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    print_info "Fix the issues above before deployment."
    echo ""

    # Specific guidance
    if [ "$JAVA_OK" != true ]; then
        echo "📌 Critical: Java 17 required"
        echo "   Run: ./install-java17.sh"
        echo ""
    fi

    exit 1
fi
