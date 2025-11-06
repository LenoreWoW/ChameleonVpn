# Quick Start Guide - Android Backend Integration

## Immediate Actions Required

### 1. Update Backend URL (CRITICAL)
**File:** `app/src/main/java/com/workvpn/android/api/ApiService.kt`
```kotlin
// Line 28
private const val BASE_URL = "https://api.barqnet.com/"  // ← Your backend URL here
```

### 2. Update Certificate Pins (CRITICAL)
**Generate pins from your backend:**
```bash
openssl s_client -connect api.barqnet.com:443 < /dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  base64
```

**Update in ApiService.kt (lines 33-36):**
```kotlin
private val CERTIFICATE_PINS = listOf(
    "sha256/YOUR_PIN_HERE=",
    "sha256/YOUR_BACKUP_PIN_HERE="
)
```

### 3. Initialize Token Refresh
**File:** `app/src/main/java/com/workvpn/android/BarqNetApplication.kt`
```kotlin
override fun onCreate() {
    super.onCreate()
    createNotificationChannel()
    TokenRefreshWorker.schedule(this)  // ← Add this line
}
```

---

## What Changed

### New Files (11):
```
api/
  ├── ApiService.kt          - Backend API client
  └── models/ApiModels.kt    - API data models

auth/
  ├── AuthManager.kt         - Rewritten with backend
  └── TokenStorage.kt        - Encrypted token storage

worker/
  └── TokenRefreshWorker.kt  - Background token refresh

util/
  ├── VpnPermissionHelper.kt - VPN permission handling
  └── SettingsManager.kt     - Settings persistence

vpn/
  └── VpnServiceConnection.kt - Memory-leak-free communication

docs/
  ├── ANDROID_IMPLEMENTATION_COMPLETE.md
  ├── UI_INTEGRATION_GUIDE.md
  └── IMPLEMENTATION_SUMMARY.md
```

### Modified Files (5):
```
✓ app/build.gradle              - Added dependencies
✓ AndroidManifest.xml           - Registered RealVPNService
✓ auth/AuthManager.kt           - Backend integration
✓ viewmodel/RealVPNViewModel.kt - Fixed memory leak
✓ vpn/RealVPNService.kt         - Global state updates
```

---

## How to Use in Your Code

### Authentication Flow:
```kotlin
// 1. Send OTP
val result = authManager.sendOTP("+1234567890")

// 2. Verify OTP
val result = authManager.verifyOTP("+1234567890", "123456")

// 3. Create Account
val result = authManager.createAccount("+1234567890", "password")

// 4. Login
val result = authManager.login("+1234567890", "password")

// 5. Logout
authManager.logout()
```

### Settings:
```kotlin
val settingsManager = SettingsManager(context)

// Save
settingsManager.setAutoConnect(true)

// Read
val enabled = settingsManager.getAutoConnect()

// Observe
settingsManager.autoConnectFlow.collect { enabled ->
    // React to changes
}
```

### VPN Connection:
```kotlin
// Check permission
val vpnPermissionHelper = VpnPermissionHelper(activity) { granted ->
    if (granted) {
        viewModel.connect(context)
    }
}
vpnPermissionHelper.requestPermission()
```

---

## Testing Checklist

### Before Testing:
- [ ] Updated BASE_URL in ApiService.kt
- [ ] Updated CERTIFICATE_PINS in ApiService.kt
- [ ] Added TokenRefreshWorker.schedule() to Application
- [ ] Backend is running and accessible

### Test Flow:
1. [ ] Send OTP → Check SMS received
2. [ ] Verify OTP → Check success
3. [ ] Create account → Check token stored
4. [ ] Close app → Reopen → Check auto-login
5. [ ] VPN connect → Check permission dialog
6. [ ] Settings → Check persistence
7. [ ] Logout → Check data cleared

---

## Common Issues

| Issue | Solution |
|-------|----------|
| SSL/Certificate error | Update certificate pins |
| "Failed to send OTP" | Check BASE_URL is correct |
| Token expired | Check system time sync |
| VPN permission denied | Use VpnPermissionHelper |
| Settings not persisting | Check DataStore init |
| Memory leak | Use global StateFlows, not singleton |

---

## API Contract

Your backend must implement these endpoints:

```
POST /v1/auth/send-otp      - Send OTP
POST /v1/auth/verify-otp    - Verify OTP
POST /v1/auth/register      - Create account
POST /v1/auth/login         - Login
POST /v1/auth/refresh       - Refresh token
```

See `ANDROID_IMPLEMENTATION_COMPLETE.md` for full API contract.

---

## Key Features Implemented

✅ Real backend API integration (Retrofit + OkHttp)
✅ Secure token storage (AES-256 encryption)
✅ Automatic token refresh (5 min before expiry)
✅ VPN permission flow (ActivityResultContracts)
✅ Settings persistence (DataStore)
✅ Certificate pinning (SHA-256)
✅ Memory leak fix (no singleton)
✅ Background token refresh (WorkManager)

---

## Security Notes

- All tokens encrypted with AES-256
- Keys stored in Android Keystore
- Certificate pinning enforced
- No tokens in logs
- Logout clears all data

---

## Need Help?

1. Check `ANDROID_IMPLEMENTATION_COMPLETE.md` for technical details
2. Check `UI_INTEGRATION_GUIDE.md` for UI examples
3. Check LogCat for error messages
4. Verify backend is reachable
5. Verify certificate pins are correct

---

**Status:** Ready for configuration and testing
**Next Step:** Update BASE_URL and CERTIFICATE_PINS
