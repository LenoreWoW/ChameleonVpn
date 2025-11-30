#!/bin/bash

# ============================================
# BarqNet iOS Testing Diagnostics
# Run this before testing the iOS app
# ============================================

echo "=================================="
echo "BarqNet System Diagnostics"
echo "=================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Check if backend is running
echo "1. Checking if backend is running..."
BACKEND_PROCESS=$(lsof -i :8080 -t 2>/dev/null)
if [ -z "$BACKEND_PROCESS" ]; then
    echo -e "${RED}✗ FAIL: Nothing listening on port 8080${NC}"
    echo "  Action: Start backend with: cd ~/Desktop/ChameleonVpn/barqnet-backend/apps/management && go run main.go"
else
    PROCESS_NAME=$(ps -p $BACKEND_PROCESS -o comm=)
    echo -e "${GREEN}✓ PASS: Process listening on port 8080 (PID: $BACKEND_PROCESS)${NC}"
    echo "  Process: $PROCESS_NAME"

    # Check if it's nginx blocking
    if [[ "$PROCESS_NAME" == *"nginx"* ]]; then
        echo -e "${RED}  ⚠️  WARNING: NGINX is blocking port 8080!${NC}"
        echo "  Action: Stop nginx with: sudo pkill -9 nginx"
    fi
fi
echo ""

# 2. Check if PostgreSQL is running
echo "2. Checking PostgreSQL..."
if command -v psql &> /dev/null; then
    if psql -U vpnmanager -d vpnmanager -c "SELECT 1;" &>/dev/null; then
        echo -e "${GREEN}✓ PASS: PostgreSQL is running and accessible${NC}"

        # Check test user
        USER_COUNT=$(psql -U vpnmanager -d vpnmanager -t -c "SELECT COUNT(*) FROM users WHERE email='test@barqnet.local';" 2>/dev/null | xargs)
        if [ "$USER_COUNT" == "1" ]; then
            echo -e "${GREEN}✓ PASS: Test user exists (test@barqnet.local)${NC}"
        else
            echo -e "${RED}✗ FAIL: Test user does not exist${NC}"
            echo "  Action: Create test user with: cd ~/Desktop/ChameleonVpn/barqnet-backend && go run scripts/create_test_user.go"
        fi
    else
        echo -e "${RED}✗ FAIL: Cannot connect to database${NC}"
        echo "  Action: Run database setup from HAMAD_READ_THIS.md Step 0A"
    fi
else
    echo -e "${RED}✗ FAIL: PostgreSQL not installed${NC}"
    echo "  Action: Install PostgreSQL"
fi
echo ""

# 3. Test backend health endpoint
echo "3. Testing backend health endpoint..."
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" http://127.0.0.1:8080/health 2>&1)
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$HEALTH_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" == "404" ] && echo "$RESPONSE_BODY" | grep -q "nginx"; then
    echo -e "${RED}✗ FAIL: Nginx is blocking port 8080${NC}"
    echo "  Response: $RESPONSE_BODY"
    echo "  Action: Stop nginx with: sudo pkill -9 nginx"
elif [ "$HTTP_CODE" == "000" ]; then
    echo -e "${RED}✗ FAIL: Cannot connect to backend${NC}"
    echo "  Action: Start backend first"
else
    echo -e "${GREEN}✓ PASS: Backend is responding${NC}"
    echo "  HTTP Status: $HTTP_CODE"
fi
echo ""

# 4. Test login endpoint
echo "4. Testing login endpoint..."
LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://127.0.0.1:8080/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@barqnet.local","password":"Test1234"}' 2>&1)
HTTP_CODE=$(echo "$LOGIN_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$LOGIN_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" == "200" ]; then
    if echo "$RESPONSE_BODY" | grep -q "access_token"; then
        echo -e "${GREEN}✓ PASS: Login endpoint working!${NC}"
        echo "  Response contains access_token ✓"
    else
        echo -e "${YELLOW}⚠️  WARNING: Got 200 but no access_token${NC}"
        echo "  Response: $RESPONSE_BODY"
    fi
elif [ "$HTTP_CODE" == "404" ] && echo "$RESPONSE_BODY" | grep -q "nginx"; then
    echo -e "${RED}✗ FAIL: Nginx blocking requests${NC}"
    echo "  Action: sudo pkill -9 nginx"
elif [ "$HTTP_CODE" == "401" ]; then
    echo -e "${YELLOW}⚠️  WARNING: Login failed (wrong password?)${NC}"
    echo "  Response: $RESPONSE_BODY"
elif [ "$HTTP_CODE" == "000" ]; then
    echo -e "${RED}✗ FAIL: Cannot connect to backend${NC}"
    echo "  Action: Start backend"
else
    echo -e "${RED}✗ FAIL: Unexpected response${NC}"
    echo "  HTTP Status: $HTTP_CODE"
    echo "  Response: $RESPONSE_BODY"
fi
echo ""

# 5. Check iOS Simulator can reach localhost
echo "5. Checking iOS Simulator connectivity..."
if curl -s http://127.0.0.1:8080 &>/dev/null; then
    echo -e "${GREEN}✓ PASS: Can reach 127.0.0.1:8080${NC}"
else
    echo -e "${YELLOW}⚠️  WARNING: Cannot reach 127.0.0.1:8080${NC}"
fi
echo ""

# Summary
echo "=================================="
echo "Summary"
echo "=================================="
echo ""

ALL_PASS=true

if [ -z "$BACKEND_PROCESS" ]; then
    echo -e "${RED}• Backend not running${NC}"
    ALL_PASS=false
elif [[ "$PROCESS_NAME" == *"nginx"* ]]; then
    echo -e "${RED}• Nginx blocking port 8080${NC}"
    ALL_PASS=false
fi

if ! psql -U vpnmanager -d vpnmanager -c "SELECT 1;" &>/dev/null; then
    echo -e "${RED}• Database not accessible${NC}"
    ALL_PASS=false
fi

if [ "$USER_COUNT" != "1" ]; then
    echo -e "${RED}• Test user missing${NC}"
    ALL_PASS=false
fi

if [ "$ALL_PASS" = true ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "You can now test the iOS app:"
    echo "  1. Launch app in Xcode"
    echo "  2. Tap 'Sign In'"
    echo "  3. Tap ⚡ 'Quick Test Login'"
    echo "  4. Should login successfully!"
else
    echo ""
    echo "Fix the issues above before testing iOS app."
fi

echo ""
echo "=================================="
