#!/bin/bash

##############################################################################
# Token Revocation System Test Script
#
# This script tests the token revocation/blacklist functionality:
# 1. User registration
# 2. Login (get access + refresh tokens)
# 3. Use refresh token
# 4. Revoke refresh token
# 5. Try to use revoked token (should fail)
# 6. Test revoke-all endpoint
#
# Usage:
#   chmod +x test-token-revocation.sh
#   ./test-token-revocation.sh
#
# Requirements:
#   - curl
#   - jq (JSON processor)
#   - Backend server running on localhost:8080
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="${BASE_URL:-http://localhost:8080}"
PHONE_NUMBER="+1234567890$(date +%s)"  # Unique phone number
PASSWORD="TestPassword123"

# Check dependencies
command -v curl >/dev/null 2>&1 || { echo "Error: curl is required"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required"; exit 1; }

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Token Revocation System Test${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Test 1: Send OTP
echo -e "${YELLOW}[1/7] Sending OTP to ${PHONE_NUMBER}...${NC}"
OTP_RESPONSE=$(curl -s -X POST "${BASE_URL}/auth/send-otp" \
  -H "Content-Type: application/json" \
  -d "{\"phone_number\": \"${PHONE_NUMBER}\"}")

echo "$OTP_RESPONSE" | jq '.'

if [ "$(echo "$OTP_RESPONSE" | jq -r '.success')" != "true" ]; then
  echo -e "${RED}✗ Failed to send OTP${NC}"
  exit 1
fi
echo -e "${GREEN}✓ OTP sent successfully${NC}"
echo ""

# Get OTP from mock service (in production, user would receive via SMS)
# For testing, we'll use a known OTP pattern
OTP="123456"  # Mock OTP - update based on your mock service

# Test 2: Register user
echo -e "${YELLOW}[2/7] Registering user...${NC}"
REGISTER_RESPONSE=$(curl -s -X POST "${BASE_URL}/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"phone_number\": \"${PHONE_NUMBER}\",
    \"password\": \"${PASSWORD}\",
    \"otp\": \"${OTP}\"
  }")

echo "$REGISTER_RESPONSE" | jq '.'

if [ "$(echo "$REGISTER_RESPONSE" | jq -r '.success')" != "true" ]; then
  echo -e "${RED}✗ Registration failed${NC}"
  exit 1
fi

ACCESS_TOKEN=$(echo "$REGISTER_RESPONSE" | jq -r '.data.accessToken')
REFRESH_TOKEN=$(echo "$REGISTER_RESPONSE" | jq -r '.data.refreshToken')

echo -e "${GREEN}✓ User registered successfully${NC}"
echo -e "Access Token: ${ACCESS_TOKEN:0:50}..."
echo -e "Refresh Token: ${REFRESH_TOKEN:0:50}..."
echo ""

# Test 3: Use refresh token (should work)
echo -e "${YELLOW}[3/7] Using refresh token (should succeed)...${NC}"
REFRESH_RESPONSE=$(curl -s -X POST "${BASE_URL}/v1/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"${REFRESH_TOKEN}\"}")

echo "$REFRESH_RESPONSE" | jq '.'

if [ "$(echo "$REFRESH_RESPONSE" | jq -r '.success')" != "true" ]; then
  echo -e "${RED}✗ Token refresh failed${NC}"
  exit 1
fi

NEW_ACCESS_TOKEN=$(echo "$REFRESH_RESPONSE" | jq -r '.data.accessToken')
NEW_REFRESH_TOKEN=$(echo "$REFRESH_RESPONSE" | jq -r '.data.refreshToken')

echo -e "${GREEN}✓ Token refresh successful${NC}"
echo -e "New Access Token: ${NEW_ACCESS_TOKEN:0:50}..."
echo -e "New Refresh Token: ${NEW_REFRESH_TOKEN:0:50}..."
echo ""

# Test 4: Revoke the new refresh token
echo -e "${YELLOW}[4/7] Revoking refresh token...${NC}"
REVOKE_RESPONSE=$(curl -s -X POST "${BASE_URL}/v1/auth/revoke" \
  -H "Content-Type: application/json" \
  -d "{
    \"refresh_token\": \"${NEW_REFRESH_TOKEN}\",
    \"reason\": \"test_revocation\"
  }")

echo "$REVOKE_RESPONSE" | jq '.'

if [ "$(echo "$REVOKE_RESPONSE" | jq -r '.success')" != "true" ]; then
  echo -e "${RED}✗ Token revocation failed${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Token revoked successfully${NC}"
echo ""

# Test 5: Try to use revoked token (should fail)
echo -e "${YELLOW}[5/7] Using revoked token (should fail)...${NC}"
REVOKED_REFRESH_RESPONSE=$(curl -s -X POST "${BASE_URL}/v1/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"${NEW_REFRESH_TOKEN}\"}")

echo "$REVOKED_REFRESH_RESPONSE" | jq '.'

if [ "$(echo "$REVOKED_REFRESH_RESPONSE" | jq -r '.success')" == "true" ]; then
  echo -e "${RED}✗ SECURITY ISSUE: Revoked token still works!${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Revoked token correctly rejected${NC}"
echo ""

# Test 6: Login again to get new tokens
echo -e "${YELLOW}[6/7] Logging in to get new tokens...${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/auth/login" \
  -H "Content-Type: application/json" \
  -d "{
    \"phone_number\": \"${PHONE_NUMBER}\",
    \"password\": \"${PASSWORD}\"
  }")

echo "$LOGIN_RESPONSE" | jq '.'

if [ "$(echo "$LOGIN_RESPONSE" | jq -r '.success')" != "true" ]; then
  echo -e "${RED}✗ Login failed${NC}"
  exit 1
fi

ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.data.accessToken')
REFRESH_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.data.refreshToken')

echo -e "${GREEN}✓ Login successful${NC}"
echo ""

# Test 7: Test revoke-all endpoint
echo -e "${YELLOW}[7/7] Testing revoke-all endpoint...${NC}"
REVOKE_ALL_RESPONSE=$(curl -s -X POST "${BASE_URL}/v1/auth/revoke-all" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d "{
    \"password\": \"${PASSWORD}\",
    \"reason\": \"test_revoke_all\"
  }")

echo "$REVOKE_ALL_RESPONSE" | jq '.'

if [ "$(echo "$REVOKE_ALL_RESPONSE" | jq -r '.success')" != "true" ]; then
  echo -e "${RED}✗ Revoke-all failed${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Revoke-all successful${NC}"
echo ""

# Summary
echo -e "${BLUE}=======================================${NC}"
echo -e "${GREEN}All tests passed! ✓${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""
echo "Token revocation system is working correctly:"
echo "  ✓ Tokens can be revoked"
echo "  ✓ Revoked tokens are rejected"
echo "  ✓ Revoke-all endpoint works"
echo "  ✓ Blacklist validation is active"
echo ""
echo "Test user: ${PHONE_NUMBER}"
echo "Password: ${PASSWORD}"
echo ""

# Optional: Query database to verify entries
echo -e "${BLUE}Database Verification:${NC}"
echo "Run the following SQL to verify blacklist entries:"
echo ""
echo "  SELECT * FROM token_blacklist WHERE phone_number = '${PHONE_NUMBER}';"
echo "  SELECT * FROM v_blacklist_statistics;"
echo ""

exit 0
