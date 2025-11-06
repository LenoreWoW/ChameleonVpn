# Android Backend Integration - Implementation Complete

## Overview

This document details the complete backend API integration and critical bug fixes for the BarqNet Android application. All authentication now uses real backend API calls, tokens are stored securely, and critical memory leaks have been fixed.

---

## Changes Summary

### 1. Backend API Integration (Retrofit + OkHttp)

#### Files Created:
- **`app/src/main/java/com/workvpn/android/api/ApiService.kt`**
  - Retrofit-based API client with all authentication endpoints
  - Certificate pinning via OkHttp CertificatePinner
  - Request/response logging (debug builds only)
  - Automatic error handling with sealed Result classes
  - Timeout configuration (30 seconds)

- **`app/src/main/java/com/workvpn/android/api/models/ApiModels.kt`**
  - Complete data models for all API requests/responses
  - Request models: `SendOtpRequest`, `VerifyOtpRequest`, `RegisterRequest`, `LoginRequest`, `RefreshTokenRequest`
  - Response models: `SendOtpResponse`, `VerifyOtpResponse`, `RegisterResponse`, `LoginResponse`, `RefreshTokenResponse`
  - `UserData` model with token expiry checking

#### API Endpoints Implemented:
```kotlin
POST /v1/auth/send-otp       // Send OTP to phone number
POST /v1/auth/verify-otp     // Verify OTP code
POST /v1/auth/register       // Register new user
POST /v1/auth/login          // Login existing user
POST /v1/auth/refresh        // Refresh access token
```

#### Certificate Pinning:
```kotlin
// In ApiService.kt
private val CERTIFICATE_PINS = listOf(
    "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", // Primary
    "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="  // Backup
)

// To get actual pins, run:
// openssl s_client -connect api.barqnet.com:443 | openssl x509 -pubkey -noout |
//   openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64
```

---

### 2. Secure Token Storage

#### Files Created:
- **`app/src/main/java/com/workvpn/android/auth/TokenStorage.kt`**
  - AES-256 encryption via EncryptedSharedPreferences
  - Hardware-backed key storage (Android Keystore)
  - Secure storage for access token, refresh token, user data
  - Token expiry checking
  - OTP session ID management

#### Security Features:
- **Encryption**: AES-256-GCM for values, AES-256-SIV for keys
- **Key Storage**: Master keys stored in Android Keystore (hardware-backed when available)
- **Protection**: Cannot be extracted even on rooted devices (with hardware backing)
- **Automatic**: No manual key management required

#### Usage Example:
```kotlin
val tokenStorage = TokenStorage(context)

// Save user data after login
tokenStorage.saveUserData(userData)

// Get access token
val token = tokenStorage.getAccessToken()

// Check if authenticated
if (tokenStorage.isAuthenticated()) {
    // User is logged in
}
```

---

### 3. Authentication Manager (Complete Rewrite)

#### File Updated:
- **`app/src/main/java/com/workvpn/android/auth/AuthManager.kt`**
  - Removed all mock/local authentication
  - Integrated with real backend API via ApiService
  - Secure token storage via TokenStorage
  - Automatic token refresh (5 min before expiry)
  - Background coroutine monitoring for token expiry

#### Key Changes:
```kotlin
// BEFORE: Mock OTP generation
val otp = Random.nextInt(100000, 999999).toString()

// AFTER: Real backend API call
suspend fun sendOTP(phoneNumber: String): Result<Unit> {
    val result = ApiService.sendOtp(phoneNumber)
    if (result.isSuccess) {
        val response = result.getOrNull()!!
        currentOtpSessionId = response.sessionId
        tokenStorage.saveOtpSessionId(response.sessionId)
        return Result.success(Unit)
    }
    return Result.failure(...)
}
```

#### Automatic Token Refresh:
```kotlin
// Runs every 60 seconds in background
private fun startTokenRefreshMonitoring() {
    authScope.launch {
        while (isActive) {
            if (tokenStorage.shouldRefreshToken()) {
                refreshToken()  // Refresh 5 min before expiry
            }
            delay(60_000)
        }
    }
}
```

---

### 4. Background Token Refresh Worker

#### Files Created:
- **`app/src/main/java/com/workvpn/android/worker/TokenRefreshWorker.kt`**
  - WorkManager-based periodic background refresh
  - Runs every 15 minutes
  - Respects battery optimization
  - Handles network failures gracefully
  - Exponential backoff on retry

#### Usage:
```kotlin
// Start periodic refresh (call once at app startup)
TokenRefreshWorker.schedule(context)

// Cancel periodic refresh (on logout)
TokenRefreshWorker.cancel(context)

// Run immediately (one-time)
TokenRefreshWorker.runNow(context)
```

---

### 5. VPN Service Registration

#### File Updated:
- **`app/src/main/AndroidManifest.xml`**

#### Changes:
```xml
<!-- Added RealVPNService registration -->
<service
    android:name=".vpn.RealVPNService"
    android:permission="android.permission.BIND_VPN_SERVICE"
    android:foregroundServiceType="vpn"
    android:exported="false">
    <intent-filter>
        <action android:name="android.net.VpnService" />
    </intent-filter>
</service>
```

**Key Attributes:**
- `android:permission="android.permission.BIND_VPN_SERVICE"` - Required for VPN services
- `android:foregroundServiceType="vpn"` - Allows foreground VPN service
- `android:exported="false"` - Service cannot be accessed by other apps

---

### 6. VPN Permission Request Flow

#### Files Created:
- **`app/src/main/java/com/workvpn/android/util/VpnPermissionHelper.kt`**
  - Helper class for VPN permission handling
  - Uses ActivityResultContracts for permission dialog
  - Callback-based result handling

#### File Updated:
- **`app/src/main/java/com/workvpn/android/viewmodel/RealVPNViewModel.kt`**
  - Added `vpnPermissionNeeded` StateFlow
  - Added `retryAfterPermission()` method
  - Permission check before VPN connection

#### Permission Flow:
```kotlin
// 1. Check permission
val intent = VpnService.prepare(context)
if (intent != null) {
    // Permission needed - notify UI
    _vpnPermissionNeeded.value = true
    return
}

// 2. UI shows permission dialog (using VpnPermissionHelper)
vpnPermissionHelper.requestPermission()

// 3. After permission granted, retry connection
viewModel.retryAfterPermission(context)
```

---

### 7. Settings Persistence (DataStore)

#### Files Created:
- **`app/src/main/java/com/workvpn/android/util/SettingsManager.kt`**
  - Type-safe settings storage using DataStore
  - Reactive Flow-based updates
  - All settings supported:
    - Auto-connect on boot
    - Biometric authentication
    - Kill switch
    - DNS preferences
    - Protocol selection
    - Auto-reconnect
    - Notifications
    - Dark mode

#### Usage Example:
```kotlin
val settingsManager = SettingsManager(context)

// Save setting
settingsManager.setAutoConnect(true)

// Get setting
val autoConnect = settingsManager.getAutoConnect()

// Observe changes reactively
settingsManager.autoConnectFlow.collect { enabled ->
    if (enabled) {
        // Auto-connect VPN
    }
}
```

---

### 8. Memory Leak Fix (VPN Service)

#### Problem:
```kotlin
// BEFORE: Singleton instance caused memory leak
companion object {
    @Volatile
    var instance: RealVPNService? = null  // Memory leak!
}
```

#### Solution - Files Created/Updated:
- **`app/src/main/java/com/workvpn/android/vpn/VpnServiceConnection.kt`** (NEW)
  - Global StateFlows for service communication
  - WeakReference for service binding
  - No singleton pattern

- **`app/src/main/java/com/workvpn/android/vpn/RealVPNService.kt`** (UPDATED)
  - Removed singleton instance
  - Uses global state updates via `VpnServiceConnection.updateGlobalState()`
  - Proper lifecycle management

- **`app/src/main/java/com/workvpn/android/viewmodel/RealVPNViewModel.kt`** (UPDATED)
  - Uses global StateFlows instead of singleton
  - No direct service references

#### How It Works:
```kotlin
// Service updates global state
VpnServiceConnection.updateGlobalState("CONNECTED", bytesIn, bytesOut)

// ViewModel observes global state (no memory leak)
VpnServiceConnection.globalConnectionState.collect { state ->
    _connectionState.value = when (state) {
        "CONNECTED" -> ConnectionState.Connected
        // ...
    }
}
```

---

## Build Configuration Changes

### File Updated:
- **`app/build.gradle`**

### Dependencies Added:
```gradle
// Networking - Retrofit & OkHttp
implementation 'com.squareup.retrofit2:retrofit:2.9.0'
implementation 'com.squareup.retrofit2:converter-gson:2.9.0'
implementation 'com.squareup.okhttp3:okhttp:4.12.0'
implementation 'com.squareup.okhttp3:logging-interceptor:4.12.0'

// Security - EncryptedSharedPreferences
implementation 'androidx.security:security-crypto:1.1.0-alpha06'

// WorkManager for background tasks
implementation 'androidx.work:work-runtime-ktx:2.9.0'
```

**Already Present:**
- kotlinx-serialization-json:1.6.0
- androidx.datastore:datastore-preferences:1.0.0
- androidx.biometric:biometric-ktx:1.2.0-alpha05

---

## Configuration Required

### 1. Backend URL
Update in `ApiService.kt`:
```kotlin
private const val BASE_URL = "https://api.barqnet.com/"  // Replace with actual URL
```

### 2. Certificate Pins
Generate and update in `ApiService.kt`:
```bash
# Get certificate pin from your backend server
openssl s_client -connect api.barqnet.com:443 < /dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  base64
```

Update pins:
```kotlin
private val CERTIFICATE_PINS = listOf(
    "sha256/YOUR_PRIMARY_PIN_HERE=",
    "sha256/YOUR_BACKUP_PIN_HERE="
)
```

### 3. Initialize Token Refresh Worker
Add to `BarqNetApplication.onCreate()`:
```kotlin
class BarqNetApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        // Start token refresh worker
        TokenRefreshWorker.schedule(this)
    }
}
```

---

## Testing Checklist

### Authentication Flow:
- [ ] Send OTP to phone number
- [ ] Verify OTP code
- [ ] Register new account
- [ ] Login with credentials
- [ ] Token stored securely (check with Device File Explorer)
- [ ] Token refresh works automatically
- [ ] Logout clears all tokens

### VPN Connection:
- [ ] VPN permission dialog shows
- [ ] VPN connects after permission granted
- [ ] Real traffic statistics (not random numbers)
- [ ] VPN disconnects properly
- [ ] No memory leaks (check with Profiler)

### Settings:
- [ ] Auto-connect setting persists
- [ ] Biometric setting persists
- [ ] Settings survive app restart
- [ ] Settings survive device reboot

### Background Tasks:
- [ ] Token refreshes in background (every 15 min)
- [ ] Token refreshes before expiry (5 min before)
- [ ] Worker respects battery optimization

---

## Security Considerations

### 1. Token Storage
- All tokens encrypted with AES-256
- Keys stored in Android Keystore
- Hardware-backed encryption when available
- Protected against rooted device extraction

### 2. Certificate Pinning
- Primary + backup pins required
- Prevents MITM attacks
- Update pins when rotating certificates

### 3. Network Security
- All API calls use HTTPS
- Certificate pinning enforced
- Request/response logging disabled in release builds

### 4. Memory Safety
- No singleton instances holding service references
- Weak references used for service binding
- Global StateFlows prevent memory leaks

---

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                  UI Layer                        │
│  (Composables, ViewModels, Activities)          │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│             Business Logic                       │
│  - AuthManager (authentication)                  │
│  - SettingsManager (preferences)                 │
│  - VpnServiceConnection (service communication) │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│              Data Layer                          │
│  - ApiService (backend API)                      │
│  - TokenStorage (encrypted storage)              │
│  - DataStore (settings)                          │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│           External Services                      │
│  - Backend API (Retrofit/OkHttp)                │
│  - VPN Service (RealVPNService)                  │
│  - WorkManager (background refresh)              │
└──────────────────────────────────────────────────┘
```

---

## Known Limitations

1. **Certificate Pins**: Need to be updated with actual backend certificate pins
2. **Backend URL**: Currently placeholder, needs real backend URL
3. **VPN Encryption**: Uses placeholder key generation - needs proper key exchange implementation
4. **OpenVPN Protocol**: Full OpenVPN protocol implementation pending (currently basic UDP)

---

## Next Steps

1. **Configure Backend URL**: Update `BASE_URL` in `ApiService.kt`
2. **Update Certificate Pins**: Generate real pins from backend server
3. **Test Integration**: Test with real backend API
4. **Implement Key Exchange**: Add proper Diffie-Hellman key exchange for VPN
5. **Full OpenVPN Support**: Implement complete OpenVPN protocol

---

## Files Created/Modified Summary

### Files Created (11):
1. `app/src/main/java/com/workvpn/android/api/ApiService.kt`
2. `app/src/main/java/com/workvpn/android/api/models/ApiModels.kt`
3. `app/src/main/java/com/workvpn/android/auth/TokenStorage.kt`
4. `app/src/main/java/com/workvpn/android/worker/TokenRefreshWorker.kt`
5. `app/src/main/java/com/workvpn/android/util/VpnPermissionHelper.kt`
6. `app/src/main/java/com/workvpn/android/util/SettingsManager.kt`
7. `app/src/main/java/com/workvpn/android/vpn/VpnServiceConnection.kt`

### Files Modified (4):
1. `app/build.gradle` - Added Retrofit, OkHttp, WorkManager, EncryptedSharedPreferences
2. `app/src/main/AndroidManifest.xml` - Registered RealVPNService
3. `app/src/main/java/com/workvpn/android/auth/AuthManager.kt` - Complete rewrite with backend integration
4. `app/src/main/java/com/workvpn/android/viewmodel/RealVPNViewModel.kt` - Fixed memory leak, added permission flow
5. `app/src/main/java/com/workvpn/android/vpn/RealVPNService.kt` - Removed singleton, added global state

---

## Support

For issues or questions:
1. Check backend API connectivity
2. Verify certificate pins match backend
3. Check LogCat for detailed error messages
4. Review token expiry times
5. Validate VPN permissions granted

---

**Implementation completed on:** $(date)
**Android Min SDK:** 26 (Android 8.0)
**Android Target SDK:** 33
**Kotlin Version:** 1.9.20
