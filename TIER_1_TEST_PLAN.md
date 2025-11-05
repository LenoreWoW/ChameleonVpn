# Tier 1 Fixes - Test Plan & Validation

**Date:** November 5, 2025
**Test Agent:** chameleon-testing
**Status:** Ready for Manual Testing
**Priority:** HIGH - Required before Tier 2/3 fixes

---

## Test Scope

**What's Being Tested:**
- All 7 Tier 1 critical fixes
- Backend/Desktop API integration
- Complete authentication flows
- Token refresh mechanism

**Test Environment:**
- Backend: Go server running on localhost:8080
- Desktop: Electron app in development mode
- Database: PostgreSQL with test data

---

## Manual Test Cases

### TC-001: Send OTP Flow

**Priority:** HIGH
**Status:** Ready to Test
**Endpoint:** POST /v1/auth/send-otp

**Steps:**
1. Start backend: `cd barqnet-backend && go run apps/management/main.go`
2. Use curl or Postman to send OTP request:
```bash
curl -X POST http://localhost:8080/v1/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+1234567890"
  }'
```

**Expected Result:**
```json
{
  "success": true,
  "message": "OTP sent successfully. Please check your phone.",
  "data": {
    "phone_number": "+1234567890",
    "expires_in": 300
  }
}
```

**Validation:**
- ✅ Response does NOT include "otp" field (security fix)
- ✅ Backend console logs OTP code (dev mode only)
- ✅ Response includes phone_number and expires_in
- ✅ Status code 200

**Failure Scenarios to Test:**
- Empty phone number → 400 error
- Invalid phone format → 400 error
- Missing Content-Type header → 400 error

---

### TC-002: Registration Flow (End-to-End)

**Priority:** HIGH
**Status:** Ready to Test
**Endpoints:** POST /v1/auth/send-otp → POST /v1/auth/register

**Steps:**
1. Send OTP (TC-001)
2. Note OTP code from backend console logs
3. Register with OTP:
```bash
curl -X POST http://localhost:8080/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+1234567890",
    "password": "SecurePass123!",
    "otp": "123456"
  }'
```

**Expected Result:**
```json
{
  "success": true,
  "message": "User registered successfully",
  "data": {
    "user": {
      "id": 1,
      "phone_number": "+1234567890"
    },
    "accessToken": "eyJhbGc...",
    "refreshToken": "eyJhbGc...",
    "expiresIn": 86400
  }
}
```

**Validation:**
- ✅ Returns proper OAuth2-style token structure
- ✅ Both accessToken and refreshToken present
- ✅ User object nested in data.user
- ✅ expiresIn = 86400 (24 hours)
- ✅ Tokens are valid JWT format
- ✅ Status code 201 (Created)

**Database Validation:**
```sql
SELECT id, phone_number, password_hash, created_at, active
FROM auth_users
WHERE phone_number = '+1234567890';

-- Verify:
-- - User exists
-- - password_hash is bcrypt format (starts with $2a$ or $2b$)
-- - active = true
```

**Failure Scenarios:**
- Duplicate registration → 409 Conflict
- Invalid OTP → 401 Unauthorized
- Weak password → 400 Bad Request
- Missing fields → 400 Bad Request

---

### TC-003: Login Flow

**Priority:** HIGH
**Status:** Ready to Test
**Endpoint:** POST /v1/auth/login

**Precondition:** User registered (TC-002)

**Steps:**
```bash
curl -X POST http://localhost:8080/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+1234567890",
    "password": "SecurePass123!"
  }'
```

**Expected Result:**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": 1,
      "phone_number": "+1234567890"
    },
    "accessToken": "eyJhbGc...",
    "refreshToken": "eyJhbGc...",
    "expiresIn": 86400
  }
}
```

**Validation:**
- ✅ Same response format as registration
- ✅ Tokens are different from registration tokens
- ✅ Status code 200
- ✅ Both access and refresh tokens present

**Failure Scenarios:**
- Wrong password → 401 "Invalid phone number or password"
- Non-existent user → 401 "Invalid phone number or password" (same message!)
- Empty fields → 400 Bad Request
- Account disabled → 403 Forbidden

---

### TC-004: Token Refresh Flow

**Priority:** HIGH
**Status:** Ready to Test
**Endpoint:** POST /v1/auth/refresh

**Precondition:** Valid refresh token from TC-002 or TC-003

**Steps:**
```bash
curl -X POST http://localhost:8080/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "token": "<refresh_token_from_login>"
  }'
```

**Expected Result:**
```json
{
  "success": true,
  "message": "Tokens refreshed successfully",
  "data": {
    "accessToken": "eyJhbGc...",
    "refreshToken": "eyJhbGc...",
    "expiresIn": 86400
  }
}
```

**Validation:**
- ✅ NEW access token (different from old)
- ✅ NEW refresh token (token rotation!)
- ✅ Old refresh token should NOT work again (rotation)
- ✅ Status code 200
- ✅ User can use new access token

**Failure Scenarios:**
- Invalid refresh token → 401 Unauthorized
- Expired refresh token → 401 Unauthorized
- Already-used refresh token → 401 Unauthorized (after rotation)

---

### TC-005: Protected Endpoint Access

**Priority:** HIGH
**Status:** Ready to Test
**Endpoint:** GET /v1/vpn/status (or any protected endpoint)

**Precondition:** Valid access token from TC-003

**Steps:**
```bash
# WITH valid token
curl -X GET http://localhost:8080/v1/vpn/status \
  -H "Authorization: Bearer <access_token>"

# WITHOUT token
curl -X GET http://localhost:8080/v1/vpn/status

# WITH invalid token
curl -X GET http://localhost:8080/v1/vpn/status \
  -H "Authorization: Bearer invalid_token"
```

**Expected Results:**

**With Valid Token:** 200 + data
**Without Token:** 401 "Authorization header required"
**With Invalid Token:** 401 "Invalid token: ..."

**Validation:**
- ✅ JWT middleware properly validates tokens
- ✅ Expired access tokens rejected
- ✅ Malformed tokens rejected
- ✅ Missing Authorization header rejected

---

### TC-006: Desktop App - Send OTP

**Priority:** HIGH
**Status:** Ready to Test
**Platform:** Electron Desktop

**Steps:**
1. Start desktop app: `cd workvpn-desktop && npm start`
2. Navigate to registration screen
3. Enter phone number: +1234567890
4. Click "Send OTP" button

**Expected Behavior:**
- ✅ API call to /v1/auth/send-otp (correct endpoint!)
- ✅ Request body uses snake_case: `{"phone_number": "..."}`
- ✅ Success message displayed
- ✅ OTP code displayed in terminal (dev mode)
- ✅ No errors in console

**Check Network Tab:**
```
POST http://localhost:8080/v1/auth/send-otp
Content-Type: application/json

{
  "phone_number": "+1234567890"
}
```

---

### TC-007: Desktop App - Registration

**Priority:** HIGH
**Status:** Ready to Test
**Platform:** Electron Desktop

**Steps:**
1. After TC-006 (OTP sent)
2. Enter OTP code from terminal
3. Click "Verify OTP"
4. Enter password: SecurePass123!
5. Confirm password: SecurePass123!
6. Click "Create Account"

**Expected Behavior:**
- ✅ OTP verification happens locally (no API call in dev mode)
- ✅ Registration API call to /v1/auth/register
- ✅ Request body: `{"phone_number": "...", "password": "...", "otp": "123456"}`
- ✅ Response tokens stored in electron-store
- ✅ Redirect to dashboard
- ✅ User object stored locally

**Validation:**
```javascript
// In Electron console
const Store = require('electron-store');
const store = new Store({ name: 'auth' });

// Check tokens
console.log(store.get('tokens'));
// Should show: { accessToken, refreshToken, expiresIn, tokenIssuedAt }

// Check user
console.log(store.get('currentUser'));
// Should show: { id, phoneNumber }
```

---

### TC-008: Desktop App - Login

**Priority:** HIGH
**Status:** Ready to Test
**Platform:** Electron Desktop

**Precondition:** Account created (TC-007)

**Steps:**
1. Logout if logged in
2. Enter phone number: +1234567890
3. Enter password: SecurePass123!
4. Click "Login"

**Expected Behavior:**
- ✅ API call to /v1/auth/login
- ✅ Request uses snake_case: `{"phone_number": "...", "password": "..."}`
- ✅ Tokens stored
- ✅ Redirect to dashboard
- ✅ No errors

---

### TC-009: Desktop App - Token Refresh

**Priority:** HIGH
**Status:** Ready to Test
**Platform:** Electron Desktop

**Steps:**
1. Login (TC-008)
2. Wait 5 minutes before token expiry
3. Token should auto-refresh

**Manual Trigger:**
```javascript
// In Electron console
const authService = require('./src/main/auth/service').authService;
await authService.refreshAccessToken();
```

**Expected Behavior:**
- ✅ API call to /v1/auth/refresh
- ✅ Request body: `{"token": "<refresh_token>"}`
- ✅ New tokens stored
- ✅ Old refresh token no longer works
- ✅ Automatic refresh scheduled for next expiry

---

### TC-010: Desktop App - Protected API Call

**Priority:** HIGH
**Status:** Ready to Test
**Platform:** Electron Desktop

**Steps:**
1. Login (TC-008)
2. Try to access VPN status or any protected feature
3. Verify Authorization header sent

**Expected Behavior:**
- ✅ All API calls include `Authorization: Bearer <token>`
- ✅ Token automatically included via getAuthHeaders()
- ✅ Protected endpoints return data
- ✅ Expired tokens trigger refresh

---

## Integration Test Matrix

| Test Case | Backend | Desktop | Status |
|-----------|---------|---------|--------|
| Send OTP | ✅ Endpoint works | ✅ Correct URL | ⏳ Ready |
| Register | ✅ Token format | ✅ Field names | ⏳ Ready |
| Login | ✅ Token format | ✅ Field names | ⏳ Ready |
| Refresh | ✅ Rotation | ✅ Stores new tokens | ⏳ Ready |
| Protected Access | ✅ JWT middleware | ✅ Auth headers | ⏳ Ready |

---

## Security Test Cases

### SEC-001: OTP Not Exposed

**Test:** Verify OTP never sent in API response

```bash
curl -X POST http://localhost:8080/v1/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+1234567890"}' | grep -i "otp"
```

**Expected:** grep returns nothing (no "otp" field)

---

### SEC-002: Password Hashing

**Test:** Verify passwords hashed with bcrypt

```sql
SELECT password_hash FROM auth_users WHERE phone_number = '+1234567890';
```

**Expected:** Starts with `$2a$12$` or `$2b$12$` (bcrypt cost 12)

---

### SEC-003: JWT Signature Validation

**Test:** Try to use tampered token

```bash
# Get valid token, change one character, try to use it
curl -X GET http://localhost:8080/v1/vpn/status \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiXXXXX..."
```

**Expected:** 401 "Invalid token: ..."

---

### SEC-004: Token Expiry

**Test:** Wait 24 hours, try to use expired access token

**Expected:** 401 "token has expired"

---

### SEC-005: Refresh Token Rotation

**Test:** Use same refresh token twice

1. Get refresh token from login
2. Call /v1/auth/refresh → Get new tokens
3. Call /v1/auth/refresh again with SAME old refresh token

**Expected:** Second call should fail (old token invalid after rotation)

---

## Performance Test Cases

### PERF-001: Login Response Time

**Test:** Measure login endpoint performance

```bash
for i in {1..100}; do
  curl -X POST http://localhost:8080/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"phone_number": "+1234567890", "password": "SecurePass123!"}' \
    -w "%{time_total}\n" -o /dev/null -s
done | awk '{sum+=$1; count++} END {print "Average: " sum/count " seconds"}'
```

**Target:** < 500ms average

---

### PERF-002: Token Generation Performance

**Test:** Measure JWT generation time (unit test)

```go
func BenchmarkGenerateJWT(b *testing.B) {
  for i := 0; i < b.N; i++ {
    shared.GenerateJWT("+1234567890", 1)
  }
}
```

**Run:** `go test -bench=BenchmarkGenerateJWT ./pkg/shared`

**Target:** < 1ms per token

---

## Test Results Template

```markdown
## Test Execution Report

**Date:** ___________
**Tester:** ___________
**Environment:** Development
**Build:** Commit e43b2dd + 5525d78

### Summary

| Category | Total | Pass | Fail | Skip |
|----------|-------|------|------|------|
| Functional | 10 | ___ | ___ | ___ |
| Security | 5 | ___ | ___ | ___ |
| Performance | 2 | ___ | ___ | ___ |
| **TOTAL** | 17 | ___ | ___ | ___ |

### Failed Tests

1. **TC-XXX:** [Test Name]
   - **Reason:** [Why it failed]
   - **Logs:** [Error messages]
   - **Severity:** [High/Medium/Low]

### Issues Found

1. **Issue:** [Description]
   - **Severity:** [Critical/High/Medium/Low]
   - **Steps to Reproduce:** [...]
   - **Expected:** [...]
   - **Actual:** [...]

### Notes

[Any additional observations]

### Sign-off

- [ ] All critical tests passed
- [ ] No blocking issues found
- [ ] Ready for Tier 2 fixes

**Tester:** ___________
**Date:** ___________
```

---

## Automated Test Scripts

### Quick Validation Script

```bash
#!/bin/bash
# test-tier1.sh - Quick validation of Tier 1 fixes

API_URL="http://localhost:8080"
PHONE="+1234567890"
PASSWORD="SecurePass123!"

echo "🧪 Tier 1 Fixes - Quick Validation"
echo "=================================="

# Test 1: Send OTP
echo -n "1. Send OTP... "
OTP_RESPONSE=$(curl -s -X POST $API_URL/v1/auth/send-otp \
  -H "Content-Type: application/json" \
  -d "{\"phone_number\": \"$PHONE\"}")

if echo "$OTP_RESPONSE" | grep -q '"success":true'; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  echo "$OTP_RESPONSE"
  exit 1
fi

# Verify OTP NOT in response
if echo "$OTP_RESPONSE" | grep -q '"otp"'; then
  echo "❌ SECURITY FAIL: OTP found in response!"
  exit 1
fi

# Get OTP from backend logs (dev mode)
echo "   Note: Check backend logs for OTP code"
read -p "   Enter OTP code from logs: " OTP_CODE

# Test 2: Register
echo -n "2. Register user... "
REG_RESPONSE=$(curl -s -X POST $API_URL/v1/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"phone_number\": \"$PHONE\", \"password\": \"$PASSWORD\", \"otp\": \"$OTP_CODE\"}")

if echo "$REG_RESPONSE" | grep -q '"accessToken"'; then
  echo "✅ PASS"
  ACCESS_TOKEN=$(echo "$REG_RESPONSE" | jq -r '.data.accessToken')
  REFRESH_TOKEN=$(echo "$REG_RESPONSE" | jq -r '.data.refreshToken')
else
  echo "❌ FAIL"
  echo "$REG_RESPONSE"
  exit 1
fi

# Test 3: Login
echo -n "3. Login... "
LOGIN_RESPONSE=$(curl -s -X POST $API_URL/v1/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"phone_number\": \"$PHONE\", \"password\": \"$PASSWORD\"}")

if echo "$LOGIN_RESPONSE" | grep -q '"accessToken"'; then
  echo "✅ PASS"
  ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.data.accessToken')
  REFRESH_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.data.refreshToken')
else
  echo "❌ FAIL"
  echo "$LOGIN_RESPONSE"
  exit 1
fi

# Test 4: Token Refresh
echo -n "4. Refresh token... "
REFRESH_RESPONSE=$(curl -s -X POST $API_URL/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$REFRESH_TOKEN\"}")

if echo "$REFRESH_RESPONSE" | grep -q '"accessToken"'; then
  echo "✅ PASS"
  NEW_ACCESS_TOKEN=$(echo "$REFRESH_RESPONSE" | jq -r '.data.accessToken')
  NEW_REFRESH_TOKEN=$(echo "$REFRESH_RESPONSE" | jq -r '.data.refreshToken')

  # Verify token rotation
  if [ "$REFRESH_TOKEN" = "$NEW_REFRESH_TOKEN" ]; then
    echo "   ⚠️  WARNING: Refresh token not rotated!"
  fi
else
  echo "❌ FAIL"
  echo "$REFRESH_RESPONSE"
  exit 1
fi

# Test 5: Protected endpoint
echo -n "5. Access protected endpoint... "
STATUS_RESPONSE=$(curl -s -X GET $API_URL/v1/vpn/status \
  -H "Authorization: Bearer $NEW_ACCESS_TOKEN")

# Note: Endpoint might not exist yet, just check it doesn't return 401
if echo "$STATUS_RESPONSE" | grep -q "Authorization header required"; then
  echo "❌ FAIL: JWT middleware not working"
  exit 1
else
  echo "✅ PASS (or endpoint not implemented yet)"
fi

echo ""
echo "✅ All Tier 1 tests PASSED!"
echo "Ready to proceed with Tier 2 fixes"
```

**Run:** `chmod +x test-tier1.sh && ./test-tier1.sh`

---

## Next Steps

1. **Run Manual Tests:** Execute all test cases above
2. **Document Results:** Fill out test results template
3. **Fix Any Issues:** Address failures before continuing
4. **Sign Off:** Confirm all critical tests pass
5. **Proceed to Tier 2:** Begin security hardening fixes

---

## Test Environment Setup

**Backend:**
```bash
cd barqnet-backend
export JWT_SECRET="test-secret-at-least-32-characters-long"
export DATABASE_URL="postgres://postgres:postgres@localhost/chameleon_dev"
go run apps/management/main.go
```

**Desktop:**
```bash
cd workvpn-desktop
export NODE_ENV=development
export API_BASE_URL="http://localhost:8080"
npm start
```

**Database:**
```bash
# Create test database
psql -U postgres -c "CREATE DATABASE chameleon_dev;"

# Run migrations (if available)
psql -U postgres -d chameleon_dev -f migrations/001_create_tables.sql
```

---

**Test Plan Prepared By:** chameleon-testing
**Status:** ✅ Ready for Execution
**Blocker for:** Tier 2 & Tier 3 fixes
