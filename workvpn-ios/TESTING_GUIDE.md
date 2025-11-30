# iOS Testing Guide - Email Bypass for Development

This guide explains how to use the testing bypass features in the BarqNet iOS app for development and testing purposes.

## Overview

The iOS app includes **DEBUG-only** testing features that allow you to bypass email verification and quickly test the full application without needing real email addresses or OTP codes.

## ⚠️ Important Security Notes

- **These features are ONLY available in DEBUG builds**
- They are **automatically disabled in RELEASE builds**
- The test account is for **development/testing purposes only**
- Never deploy test accounts to production

## Test Account Credentials

A test account has been created in the database for development:

```
Email:    test@barqnet.local
Username: testuser
Password: Test1234
```

## Testing Features

### 1. Quick Login Button (LoginView)

When running in DEBUG mode, the login screen will show a **yellow "Quick Test Login"** button below the "Create Account" link.

**What it does:**
- Auto-fills email: `test@barqnet.local`
- Auto-fills password: `Test1234`
- Automatically triggers login after 0.5 seconds

**How to use:**
1. Build and run the app in DEBUG mode (Xcode default)
2. Navigate to the Login screen
3. Tap the ⚡ **"Quick Test Login"** button
4. The app will auto-fill credentials and log you in

**Location:** `WorkVPN/Views/Onboarding/LoginView.swift:163-194`

---

### 2. Use Test Email Button (EmailEntryView)

When creating a new account in DEBUG mode, the email entry screen will show a **yellow "Use Test Email"** button.

**What it does:**
- Auto-fills email: `test@barqnet.local`
- Automatically continues to OTP verification after 0.5 seconds

**How to use:**
1. Build and run the app in DEBUG mode
2. Navigate to the signup flow (Email Entry screen)
3. Tap the ⚡ **"Use Test Email"** button
4. The app will auto-fill the test email and proceed

**Location:** `WorkVPN/Views/Onboarding/EmailEntryView.swift:129-159`

---

### 3. Use Test OTP Button (OTPVerificationView)

When verifying OTP codes in DEBUG mode, the verification screen will show a **yellow "Use Test OTP"** button.

**What it does:**
- Auto-fills all 6 OTP fields with: `123456`
- Automatically triggers verification after 0.5 seconds

**How to use:**
1. Build and run the app in DEBUG mode
2. Navigate to the OTP verification screen
3. Tap the ⚡ **"Use Test OTP"** button
4. The app will auto-fill the test OTP code and verify

**Location:** `WorkVPN/Views/Onboarding/OTPVerificationView.swift:131-167`

---

## Testing Configuration

All testing features are controlled by the `TestingConfig` struct located at:
`WorkVPN/Config/TestingConfig.swift`

### Configuration Options

```swift
// Enable/disable testing features
static let isTestingEnabled = true  // Only true in DEBUG

// Test credentials
static let testEmail = "test@barqnet.local"
static let testPassword = "Test1234"
static let testOTP = "123456"

// Feature flags
static let enableAutoFill = true     // Email auto-fill button
static let enableQuickLogin = true   // Quick login button
static let enableOTPBypass = true    // OTP auto-fill button
```

### Customizing Test Credentials

To use different test credentials:

1. **Update iOS Config:**
   Edit `WorkVPN/Config/TestingConfig.swift`:
   ```swift
   static let testEmail = "your-test@email.com"
   static let testPassword = "YourPassword123"
   ```

2. **Create Backend Test Account:**
   Run the test user creation script:
   ```bash
   cd barqnet-backend
   go run scripts/create_test_user.go \
     -email "your-test@email.com" \
     -username "youruser" \
     -password "YourPassword123" \
     -force
   ```

---

## Backend: Creating Test Accounts

### Script Usage

The backend includes a script to create test users:

```bash
cd barqnet-backend
go run scripts/create_test_user.go [options]
```

### Available Options

```bash
-email string
    Test user email (default: "test@barqnet.local")

-username string
    Test user username (default: "testuser")

-password string
    Test user password (default: "Test1234")

-server string
    Server ID for test user (default: "test-server")

-force
    Force recreate user if exists (deletes existing)
```

### Examples

**Create default test user:**
```bash
go run scripts/create_test_user.go
```

**Create custom test user:**
```bash
go run scripts/create_test_user.go \
  -email "dev@test.local" \
  -username "devuser" \
  -password "DevPass123" \
  -force
```

**Recreate existing test user:**
```bash
go run scripts/create_test_user.go -force
```

---

## Complete Testing Workflow

### Scenario 1: Quick Login (Existing User)

1. Launch app in DEBUG mode (Xcode)
2. App opens to onboarding
3. Tap "Already have an account? Sign In"
4. Tap ⚡ **"Quick Test Login"** button
5. ✅ Logged in immediately!

**Time saved:** ~30 seconds of manual typing

---

### Scenario 2: Signup Flow with Bypass

1. Launch app in DEBUG mode
2. App opens to email entry
3. Tap ⚡ **"Use Test Email"** button
4. OTP screen appears
5. Tap ⚡ **"Use Test OTP"** button
6. Password creation screen appears
7. Enter password manually
8. ✅ Account created!

**Time saved:** ~60 seconds of email/OTP entry

---

### Scenario 3: Full Manual Testing (No Bypass)

You can still test the full flow manually:

1. Use a real email or temporary email service
2. Enter email manually
3. Check email for OTP code
4. Enter OTP manually
5. Create password
6. Complete signup

The bypass buttons are **optional** - they don't interfere with normal testing.

---

## Visual Indicators

All testing bypass buttons have a consistent design:

- **Color:** Yellow (`Color.yellow`)
- **Icon:** Lightning bolt (⚡ `bolt.fill`)
- **Border:** Dashed yellow outline
- **Background:** Semi-transparent yellow

This makes them easy to identify and distinguishes them from production UI elements.

---

## Disabling Testing Features

### Method 1: Release Build

Testing features are **automatically disabled** in Release builds:

1. In Xcode: Product → Scheme → Edit Scheme
2. Select "Run" → Build Configuration → "Release"
3. Build and run
4. ✅ No testing buttons will appear

### Method 2: Manual Toggle

Edit `WorkVPN/Config/TestingConfig.swift`:

```swift
// Disable specific features
static let enableQuickLogin = false    // Hide quick login
static let enableAutoFill = false      // Hide email auto-fill
static let enableOTPBypass = false     // Hide OTP bypass
```

### Method 3: Complete Disable

Comment out all `#if DEBUG` blocks in:
- `LoginView.swift`
- `EmailEntryView.swift`
- `OTPVerificationView.swift`

---

## Troubleshooting

### Testing buttons not appearing

**Solution:**
- Verify you're running a DEBUG build (not Release)
- Check Build Settings → Swift Compiler - Custom Flags → Active Compilation Conditions
- Ensure "DEBUG" flag is present

### Quick login fails with "Invalid credentials"

**Solution:**
- Test account might not exist in database
- Run: `go run scripts/create_test_user.go -force`
- Verify backend is running and accessible

### OTP bypass doesn't work

**Solution:**
- OTP bypass only fills the fields, it doesn't skip backend verification
- Backend must accept the test OTP code `123456`
- Check backend OTP validation settings

### Test email already registered

**Solution:**
- Test account exists in database
- Use Quick Login instead of signup flow
- Or delete user: `go run scripts/create_test_user.go -force`

---

## Files Modified for Testing

### iOS Files Created/Modified:

1. **Created:**
   - `WorkVPN/Config/TestingConfig.swift` - Testing configuration

2. **Modified:**
   - `WorkVPN/Views/Onboarding/LoginView.swift` - Added Quick Login button
   - `WorkVPN/Views/Onboarding/EmailEntryView.swift` - Added Use Test Email button
   - `WorkVPN/Views/Onboarding/OTPVerificationView.swift` - Added Use Test OTP button

### Backend Files Created:

1. **Created:**
   - `barqnet-backend/scripts/create_test_user.go` - Test user creation script

---

## Production Safety Checklist

Before deploying to production:

- [ ] Verify Release build configuration
- [ ] Confirm no `#if DEBUG` code is executing
- [ ] Test that bypass buttons don't appear
- [ ] Remove or disable test accounts in production database
- [ ] Verify all authentication flows work without bypass

---

## Additional Notes

### Logging

All testing actions are logged to the console with the `[TESTING]` prefix:

```
[TESTING] Quick test login triggered
[TESTING] Quick test email auto-fill triggered
[TESTING] Quick OTP bypass triggered
```

This helps debug testing flows during development.

### Performance

- Bypass buttons add minimal overhead (~0.5 second delay for auto-fill)
- No performance impact on Release builds (code is compiled out)
- Database test account has no impact on performance

### Security

- Test accounts use bcrypt password hashing (same as production)
- All testing features require DEBUG compiler flag
- Cannot be enabled in production without recompiling

---

## Support

For issues or questions about testing features:

1. Check this guide first
2. Review console logs with `[TESTING]` prefix
3. Verify DEBUG build configuration
4. Check backend connectivity

---

**Last Updated:** 2025-11-30
**iOS App Version:** Development
**Backend Version:** Development
