# iOS API Integration - Quick Reference

## 🚀 Quick Start

### 1. Configure Base URL

**Development** (default):
```swift
// APIClient.swift - line 162
self.baseURL = "http://localhost:8080"
```

**Production**:
```swift
// APIClient.swift - line 164
self.baseURL = "https://api.barqnet.com"
```

**Runtime**:
```swift
APIClient.shared.configure(baseURL: "https://your-api.com")
```

### 2. Start Backend Server

```bash
cd /path/to/backend
go run main.go
# Backend should start on http://localhost:8080
```

### 3. Test Authentication

```swift
// Send OTP
AuthManager.shared.sendOTP(phoneNumber: "+1234567890") { result in
    // Handle result
}

// Verify OTP
AuthManager.shared.verifyOTP(phoneNumber: "+1234567890", code: "123456") { result in
    // Handle result
}

// Register
AuthManager.shared.createAccount(phoneNumber: "+1234567890", password: "password123") { result in
    // Handle result
}

// Login
AuthManager.shared.login(phoneNumber: "+1234567890", password: "password123") { result in
    // Handle result
}
```

---

## 📋 API Endpoints

All endpoints use base URL + path:

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/auth/send-otp` | Send OTP to phone |
| POST | `/v1/auth/verify-otp` | Verify OTP code |
| POST | `/v1/auth/register` | Create account |
| POST | `/v1/auth/login` | Login with password |
| POST | `/v1/auth/refresh` | Refresh access token |
| POST | `/v1/auth/logout` | Logout and clear tokens |

---

## 🔑 Token Management

### Check Authentication
```swift
if AuthManager.shared.isAuthenticated {
    print("Logged in: \(AuthManager.shared.currentUser ?? "Unknown")")
}
```

### Check Token Validity
```swift
if APIClient.shared.hasValidToken() {
    print("Token is valid")
}
```

### Token Storage
- **Where**: iOS Keychain (`com.barqnet.ios` service)
- **What**: `auth_tokens`, `token_issued_at`, `current_user`
- **Access**: When device unlocked only

### Automatic Refresh
- **When**: 5 minutes before token expiry
- **How**: Timer-based automatic refresh
- **Failure**: Clears tokens, forces re-login

---

## 🔒 Certificate Pinning

### Configure Pins

**Extract Pin**:
```bash
openssl s_client -connect api.barqnet.com:443 < /dev/null 2>/dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  base64
```

**Add to Code** (`APIClient.swift` line 168):
```swift
let pins = [
    "sha256/YOUR_PRIMARY_PIN_HERE",
    "sha256/YOUR_BACKUP_PIN_HERE"
]
```

### Enable/Disable

- **Development**: Disabled (HTTP allowed)
- **Production**: Enabled (HTTPS required)
- **Force Disable**: Use HTTP URL (not recommended)

---

## 🐛 Debugging

### Enable Logs

Check Xcode console for:
```
[APIClient] Sending request to /v1/auth/send-otp
[AuthManager] OTP sent successfully
[KeychainHelper] Successfully saved item to Keychain
```

### Common Issues

**1. Connection Refused**
```
Error: Network error: Connection refused
```
→ Start backend server on localhost:8080

**2. Certificate Pinning Failed**
```
Error: Certificate validation failed
```
→ Verify pins are correct or disable for testing

**3. Token Expired**
```
Error: Unauthorized - please login again
```
→ Token expired, need to re-login

**4. Keychain Access Denied**
```
Error: Failed to save to Keychain - Status: -34018
```
→ Enable Keychain Sharing in Xcode capabilities

---

## 📱 Testing Flow

### 1. Fresh Install Test
1. Delete app from simulator
2. Install and run
3. Test registration flow:
   - Send OTP → Get code from backend logs
   - Verify OTP with code
   - Create account
   - Verify logged in

### 2. Existing User Test
1. Install app (keep existing data)
2. Test login flow:
   - Enter phone + password
   - Verify logged in
   - Check token refresh scheduled

### 3. Token Refresh Test
1. Login with short-lived token (60 seconds)
2. Wait 55 seconds
3. Check logs for refresh attempt
4. Verify new token saved

### 4. Logout Test
1. Login
2. Logout
3. Verify tokens cleared from Keychain
4. Verify API logout called

---

## 🛠️ Development Tips

### Mock vs Production

**Development Mode** (`DEBUG`):
- Base URL: `http://localhost:8080`
- Certificate pinning: Disabled
- Detailed logging: Enabled

**Production Mode** (`RELEASE`):
- Base URL: `https://api.barqnet.com`
- Certificate pinning: Enabled
- HTTPS: Required

### Switching Environments

```swift
// In AppDelegate or SceneDelegate
#if DEBUG
APIClient.shared.configure(baseURL: "http://localhost:8080")
#else
APIClient.shared.configure(baseURL: "https://api.production.com")
#endif
```

### Testing with Charles Proxy

1. Disable certificate pinning for testing:
```swift
// Temporarily comment out in APIClient.swift
// let pins = [...]
```

2. Install Charles certificate on device
3. Run app and monitor traffic
4. Re-enable pinning for production

---

## 🔐 Security Checklist

Before deploying:

- [ ] Base URL set to production
- [ ] Certificate pins configured
- [ ] HTTPS enforced
- [ ] Certificate pinning tested
- [ ] Token refresh working
- [ ] Logout clears all data
- [ ] No sensitive data in logs
- [ ] Keychain encryption verified
- [ ] Test on physical device

---

## 📞 Quick Help

### View Keychain Data
```swift
// In Xcode debugger
po KeychainHelper.load(service: "com.barqnet.ios", account: "auth_tokens")
```

### Clear Keychain
```swift
// Reset authentication state
_ = KeychainHelper.delete(service: "com.barqnet.ios", account: "auth_tokens")
_ = KeychainHelper.delete(service: "com.barqnet.ios", account: "token_issued_at")
_ = KeychainHelper.delete(service: "com.barqnet.ios", account: "current_user")
```

### Force Token Refresh
```swift
// Trigger manual refresh (private method - for debugging)
// Set breakpoint in APIClient.refreshAccessToken()
```

---

## 📚 Files to Know

| File | Purpose |
|------|---------|
| `APIClient.swift` | HTTP client, token management |
| `AuthManager.swift` | Auth flow orchestration |
| `KeychainHelper.swift` | Keychain storage wrapper |
| `CertificatePinning.swift` | Certificate validation |
| `IOS_BACKEND_INTEGRATION.md` | Full documentation |
| `IMPLEMENTATION_SUMMARY.md` | Implementation details |

---

## 🎯 Common Tasks

### Change Backend URL
→ Edit `APIClient.swift` line 162/164

### Update Certificate Pins
→ Edit `APIClient.swift` line 168

### Add New API Endpoint
1. Add method in `APIClient.swift`
2. Add wrapper in `AuthManager.swift` (if needed)
3. Call from View

### Debug Authentication Issue
1. Check `[APIClient]` logs
2. Check `[AuthManager]` logs
3. Check backend logs
4. Verify API contract matches

---

## 🚀 Ready to Test!

1. Start backend: `go run main.go`
2. Open Xcode: `open WorkVPN.xcodeproj`
3. Build and run: `Cmd + R`
4. Check logs: `Cmd + Shift + Y`
5. Test auth flow!

---

**Need more help?** See `IOS_BACKEND_INTEGRATION.md` for detailed documentation.
