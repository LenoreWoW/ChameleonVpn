# iOS Backend Integration - Testing Checklist

## Pre-Testing Setup

### Backend Server
- [ ] Backend server is running on `http://localhost:8080`
- [ ] PostgreSQL database is running and initialized
- [ ] Backend logs are visible (check OTP codes here)
- [ ] Test database is clean (or reset if needed)

### iOS Project
- [ ] Xcode project opens without errors
- [ ] All dependencies resolved
- [ ] Keychain Sharing capability enabled (if needed)
- [ ] Info.plist allows HTTP to localhost (for dev)
- [ ] Build succeeds without errors

---

## 1. Fresh Install - Registration Flow

### Test Case 1.1: Send OTP
**Steps**:
1. Launch app on simulator
2. Enter phone number: `+1234567890`
3. Tap "Continue"

**Expected Results**:
- [ ] Loading indicator shows
- [ ] No errors displayed
- [ ] Navigates to OTP verification screen
- [ ] Backend logs show OTP code (check terminal)

**Logs to Check**:
```
[AuthManager] Sending OTP to phone: ***7890
[APIClient] POST /v1/auth/send-otp
[APIClient] OTP sent successfully
```

### Test Case 1.2: Verify OTP
**Steps**:
1. Get OTP code from backend logs
2. Enter the 6-digit code
3. Tap "Verify"

**Expected Results**:
- [ ] Loading indicator shows
- [ ] Code accepts 6 digits only
- [ ] No errors displayed
- [ ] Navigates to password creation screen

**Logs to Check**:
```
[AuthManager] Verifying OTP for phone: ***7890
[APIClient] POST /v1/auth/verify-otp
[AuthManager] OTP verified successfully
```

### Test Case 1.3: Invalid OTP
**Steps**:
1. Enter wrong OTP: `000000`
2. Tap "Verify"

**Expected Results**:
- [ ] Error message displays: "Invalid OTP code"
- [ ] Stays on OTP screen
- [ ] Can retry with correct code

### Test Case 1.4: Create Account
**Steps**:
1. Enter password: `TestPassword123!`
2. Confirm password: `TestPassword123!`
3. Tap "Create Account"

**Expected Results**:
- [ ] Password validation works (8+ chars)
- [ ] Loading indicator shows
- [ ] Account created successfully
- [ ] Navigates to main VPN screen
- [ ] User is logged in

**Logs to Check**:
```
[AuthManager] Creating account for phone: ***7890
[APIClient] POST /v1/auth/register
[KeychainHelper] Successfully saved item to Keychain
[AuthManager] Account created successfully
```

**Verify Keychain**:
```swift
// In debugger (po command)
KeychainHelper.load(service: "com.barqnet.ios", account: "auth_tokens")
// Should return token data
```

---

## 2. Existing User - Login Flow

### Test Case 2.1: Login Success
**Steps**:
1. Restart app (should show login screen)
2. Enter phone: `+1234567890`
3. Enter password: `TestPassword123!`
4. Tap "Login"

**Expected Results**:
- [ ] Loading indicator shows
- [ ] Login succeeds
- [ ] Navigates to main VPN screen
- [ ] Tokens stored in Keychain

**Logs to Check**:
```
[AuthManager] Logging in user: ***7890
[APIClient] POST /v1/auth/login
[KeychainHelper] Successfully saved item to Keychain
[AuthManager] Login successful
```

### Test Case 2.2: Login Failure - Wrong Password
**Steps**:
1. Enter phone: `+1234567890`
2. Enter wrong password: `WrongPassword`
3. Tap "Login"

**Expected Results**:
- [ ] Error message: "Invalid password" or similar
- [ ] Stays on login screen
- [ ] Can retry

### Test Case 2.3: Login Failure - Unknown User
**Steps**:
1. Enter phone: `+9999999999`
2. Enter any password
3. Tap "Login"

**Expected Results**:
- [ ] Error message: "Account not found" or similar
- [ ] Stays on login screen

---

## 3. Token Management

### Test Case 3.1: Token Storage
**Steps**:
1. Login successfully
2. Check Keychain in debugger

**Expected Results**:
- [ ] `auth_tokens` exists in Keychain
- [ ] `token_issued_at` exists in Keychain
- [ ] `current_user` exists in Keychain
- [ ] All data is valid JSON/string format

**Debugger Commands**:
```swift
po KeychainHelper.load(service: "com.barqnet.ios", account: "auth_tokens")
po KeychainHelper.load(service: "com.barqnet.ios", account: "current_user")
```

### Test Case 3.2: Token Refresh (Manual Trigger)
**Note**: This requires backend support for short-lived tokens

**Steps**:
1. Login with token that expires in 60 seconds
2. Wait 55 seconds
3. Check logs for refresh

**Expected Results**:
- [ ] Refresh triggered at 55 seconds (5 min before expiry)
- [ ] New tokens saved to Keychain
- [ ] No user interruption
- [ ] App continues working

**Logs to Check**:
```
[APIClient] Token refresh scheduled in X minutes
[APIClient] Refreshing access token...
[APIClient] Token refreshed successfully
```

### Test Case 3.3: Token Refresh on App Launch
**Steps**:
1. Login successfully
2. Kill app (don't logout)
3. Relaunch app immediately

**Expected Results**:
- [ ] App loads directly to main screen (no login)
- [ ] Token refresh scheduled
- [ ] No re-authentication required

**Logs to Check**:
```
[AuthManager] Restored authentication state for user: ***7890
[APIClient] Token refresh scheduled in X minutes
```

### Test Case 3.4: Expired Token Handling
**Steps**:
1. Login with very short-lived token
2. Wait for token to expire
3. Try to use app

**Expected Results**:
- [ ] Refresh attempt fails (token expired)
- [ ] Tokens cleared from Keychain
- [ ] User logged out automatically
- [ ] Redirected to login screen

---

## 4. Logout Flow

### Test Case 4.1: Normal Logout
**Steps**:
1. Login successfully
2. Navigate to Settings
3. Tap "Logout"

**Expected Results**:
- [ ] Logout API called
- [ ] Tokens cleared from Keychain
- [ ] User state cleared
- [ ] Redirected to login/onboarding screen

**Logs to Check**:
```
[AuthManager] Logging out user
[APIClient] POST /v1/auth/logout
[KeychainHelper] Successfully deleted item from Keychain
[AuthManager] Logout successful
```

**Verify Keychain Cleared**:
```swift
// In debugger
KeychainHelper.load(service: "com.barqnet.ios", account: "auth_tokens")
// Should return nil
```

---

## 5. Network Error Handling

### Test Case 5.1: No Backend Connection
**Steps**:
1. Stop backend server
2. Try to send OTP

**Expected Results**:
- [ ] Error message: "Network error" or "Connection refused"
- [ ] User can retry when backend is back
- [ ] App doesn't crash

### Test Case 5.2: Backend Returns Error
**Steps**:
1. Send invalid phone number (if backend validates)
2. Check error handling

**Expected Results**:
- [ ] Error message from backend displayed
- [ ] User can correct and retry

### Test Case 5.3: Timeout Handling
**Steps**:
1. Simulate slow network (Network Link Conditioner)
2. Try authentication operation

**Expected Results**:
- [ ] Request times out after 30 seconds
- [ ] Error message shown
- [ ] Can retry

---

## 6. Certificate Pinning (Production Only)

**Note**: Only testable with production backend and HTTPS

### Test Case 6.1: Valid Certificate
**Steps**:
1. Configure production URL
2. Add correct certificate pins
3. Try to login

**Expected Results**:
- [ ] Certificate validation passes
- [ ] Authentication succeeds
- [ ] No certificate errors

### Test Case 6.2: Invalid Certificate
**Steps**:
1. Configure production URL
2. Add wrong certificate pins
3. Try to login

**Expected Results**:
- [ ] Certificate validation fails
- [ ] Error: "Certificate validation failed"
- [ ] No authentication attempted

**Logs to Check**:
```
[CERT-PIN] Certificate validation failed for api.barqnet.com
[CERT-PIN] Expected one of: [pins]
[CERT-PIN] Got: [actual_pin]
```

---

## 7. Edge Cases

### Test Case 7.1: Rapid OTP Requests
**Steps**:
1. Send OTP
2. Immediately send OTP again (don't wait)
3. Check behavior

**Expected Results**:
- [ ] Both requests succeed or second is rate limited
- [ ] No crashes
- [ ] Latest OTP is valid

### Test Case 7.2: OTP Expiry
**Steps**:
1. Send OTP
2. Wait for OTP to expire (10 minutes)
3. Try to verify

**Expected Results**:
- [ ] Error: "OTP expired"
- [ ] Can request new OTP

### Test Case 7.3: Password Edge Cases
**Steps**:
Test passwords:
- Empty: `` (should fail)
- Short: `abc` (should fail - less than 8)
- Valid: `12345678` (should succeed)
- Special chars: `P@ssw0rd!` (should succeed)

**Expected Results**:
- [ ] Validation works correctly
- [ ] Clear error messages
- [ ] No crashes

### Test Case 7.4: Multiple Quick Logins
**Steps**:
1. Login
2. Logout immediately
3. Login again
4. Repeat 3 times

**Expected Results**:
- [ ] All operations succeed
- [ ] No token conflicts
- [ ] No crashes

---

## 8. UI/UX Testing

### Test Case 8.1: Loading States
**Check**:
- [ ] Loading indicators show during API calls
- [ ] Buttons disabled during loading
- [ ] Can't double-submit forms

### Test Case 8.2: Error Messages
**Check**:
- [ ] All errors show user-friendly messages
- [ ] Errors are dismissible
- [ ] Can retry after error

### Test Case 8.3: Form Validation
**Check**:
- [ ] Phone number format validation
- [ ] OTP accepts only 6 digits
- [ ] Password strength indication
- [ ] Required fields validated

---

## 9. Memory and Performance

### Test Case 9.1: Memory Leaks
**Steps**:
1. Login/logout 10 times
2. Check memory usage in Instruments

**Expected Results**:
- [ ] Memory doesn't continuously grow
- [ ] No retain cycles
- [ ] Proper cleanup on logout

### Test Case 9.2: API Response Time
**Check**:
- [ ] OTP send: < 2 seconds
- [ ] OTP verify: < 1 second
- [ ] Register: < 2 seconds
- [ ] Login: < 2 seconds

---

## 10. Security Testing

### Test Case 10.1: Data in Logs
**Check**:
- [ ] Passwords NOT logged anywhere
- [ ] Phone numbers masked (***1234)
- [ ] Tokens NOT logged in plain text
- [ ] OTP codes NOT logged (except in dev mode)

### Test Case 10.2: Keychain Security
**Check**:
- [ ] Tokens only in Keychain (not UserDefaults)
- [ ] Data requires device unlock
- [ ] Data persists across app launches
- [ ] Data cleared on logout

### Test Case 10.3: Network Traffic
**Check** (using Charles Proxy or similar):
- [ ] All requests use HTTPS (in production)
- [ ] Passwords sent in request body (encrypted)
- [ ] Bearer tokens in Authorization header
- [ ] No sensitive data in URL params

---

## Test Summary

### Critical Tests (Must Pass)
- [ ] Registration flow end-to-end
- [ ] Login flow end-to-end
- [ ] Logout clears all data
- [ ] Token storage in Keychain
- [ ] Network error handling

### Important Tests (Should Pass)
- [ ] Token refresh works
- [ ] Invalid credentials handled
- [ ] OTP expiry handled
- [ ] Password validation works
- [ ] UI loading states work

### Optional Tests (Nice to Have)
- [ ] Certificate pinning (if production available)
- [ ] Performance benchmarks
- [ ] Memory leak testing
- [ ] Rapid retry scenarios

---

## Bug Reporting Template

If you find issues, report with:

```
**Test Case**: [Number and name]
**Steps**: 
1. ...
2. ...

**Expected**: [What should happen]
**Actual**: [What happened]
**Logs**:
```
[Paste relevant logs]
```

**Environment**:
- iOS Version: 
- Device: Simulator/Real Device
- Backend Version:
- Xcode Version:

**Screenshots**: [If applicable]
```

---

## Sign Off

After completing all critical tests:

- [ ] All critical tests passed
- [ ] No blocking bugs found
- [ ] Documentation reviewed
- [ ] Code committed to git

**Tested By**: ________________
**Date**: ________________
**Status**: PASS / FAIL / BLOCKED

---

## Next Steps After Testing

1. If all tests pass:
   - [ ] Configure production URL
   - [ ] Add production certificate pins
   - [ ] Test with production backend
   - [ ] Prepare for app store submission

2. If tests fail:
   - [ ] Document all failures
   - [ ] Fix critical bugs
   - [ ] Re-test
   - [ ] Update documentation if needed
