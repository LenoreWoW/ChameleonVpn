# BarqNet - Manual Testing Guide
## Complete Testing Protocol for All Platforms

**Date:** 2025-10-26
**Purpose:** Verify production readiness before deployment
**Estimated Time:** 3-4 hours total
**Tester Requirements:** Access to Windows/macOS/Linux + iOS device + Android device

---

## Table of Contents

1. [Desktop Testing (50 minutes)](#desktop-testing)
2. [iOS Testing (40 minutes)](#ios-testing)
3. [Android Testing (45 minutes)](#android-testing)
4. [Cross-Platform Verification (30 minutes)](#cross-platform-verification)
5. [Security Testing (45 minutes)](#security-testing)
6. [Performance Testing (30 minutes)](#performance-testing)

---

## Pre-Testing Setup

### Required Test Environment

**Desktop:**
- Windows 10/11 OR macOS 10.15+ OR Ubuntu 20.04+
- OpenVPN installed (`brew install openvpn` on macOS)
- Test .ovpn configuration file

**iOS:**
- Physical iOS device (iOS 15.0+) - **VPN does NOT work in simulator**
- Xcode 13+ for installation
- Test VPN server for connection testing

**Android:**
- Physical Android device (Android 8.0+) or emulator
- Android Studio for installation
- Test VPN server for connection testing

**Test VPN Server:**
- OpenVPN server for testing connections
- OR use test credentials for demo server

---

## Desktop Testing

**Platform:** Electron (Windows/macOS/Linux)
**Time:** 50 minutes
**Status:** ✅ 98% Production Ready

### Phase 1: Application Launch (5 minutes)

**Test 1.1: Launch Application**
```bash
cd /Users/hassanalsahli/Desktop/ChameleonVpn/barqnet-desktop
npm start
```

**Expected Results:**
- ✅ Application window opens within 10 seconds
- ✅ No TypeScript errors in console
- ✅ Three.js animated background loads
- ✅ Phone entry screen displays

**Console Verification:**
```
[Main] API Base URL: http://localhost:8080
[Main] Environment: development
[CERT-PIN] Certificate pinning will be DISABLED
[Renderer] [App] Initialization complete!
```

**❌ Failed If:**
- Application crashes on startup
- White screen / blank window
- TypeScript compilation errors
- Missing assets (icons, styles)

---

### Phase 2: Authentication Flow (15 minutes)

**Current Status:** Development mode with OTP bypass enabled

**Test 2.1: Phone Number Entry**

1. Enter test phone number: `+1234567890`
2. Click "Send Code"

**Expected Console Output:**
```
╔═══════════════════════════════════════════════════════╗
║         🔐 DEVELOPMENT MODE - OTP CODE              ║
╠═══════════════════════════════════════════════════════╣
║  Phone: +1234567890                                 ║
║  Code:  123456                                       ║
╚═══════════════════════════════════════════════════════╝
```

**Expected UI:**
- ✅ Success message displayed
- ✅ UI transitions to OTP entry screen
- ✅ 6-digit input boxes appear

**Test 2.2: OTP Verification**

1. Copy OTP code from console output
2. Enter the 6-digit code
3. Click "Verify Code"

**Expected Console Output:**
```
[AUTH-DEV] ✅ OTP verified successfully
```

**Expected UI:**
- ✅ Success animation
- ✅ Transition to password creation screen

**Test 2.3: Account Creation**

1. Enter password: `Test1234!@#$` (8+ characters)
2. Confirm password: `Test1234!@#$`
3. Click "Create Account"

**Expected Console Output:**
```
[AUTH-DEV] ✅ Creating development account
[AUTH-DEV] Account created successfully
```

**Expected UI:**
- ✅ Account created success message
- ✅ Automatic login
- ✅ Redirect to VPN dashboard

**Test 2.4: Logout and Re-login**

1. Click Settings → Logout
2. Confirm logout
3. Enter same phone number: `+1234567890`
4. Click "Login" (not "Send Code")
5. Enter password: `Test1234!@#$`

**Expected:**
- ✅ Successful login
- ✅ Return to VPN dashboard
- ✅ Session restored

**❌ Failed If:**
- OTP not displayed in console
- OTP verification fails with correct code
- Password validation errors on valid password
- Cannot login after account creation
- Session not persisted

---

### Phase 3: VPN Configuration Import (10 minutes)

**Test 3.1: Import .ovpn File**

**Prerequisites:**
- Have a test `.ovpn` file ready
- File should be valid OpenVPN configuration

**Steps:**
1. Click "Import Config" or "No Config" state button
2. File picker dialog should open
3. Select test `.ovpn` file

**Expected:**
- ✅ File dialog opens
- ✅ File selection works
- ✅ Parsing progress indicator
- ✅ Config successfully parsed

**Console Verification:**
```
[Config] Parsing .ovpn file...
[Config] Found remote: vpn.server.com:1194
[Config] Protocol: UDP
[Config] Cipher: AES-256-CBC
[Config] Config validated successfully
```

**Expected UI Changes:**
- ✅ "No Config" state disappears
- ✅ Server info card appears
- ✅ Server address displayed
- ✅ Protocol and cipher shown
- ✅ "Connect" button enabled

**Test 3.2: Config Validation**

**Try importing invalid config:**
1. Create file `invalid.ovpn` with incomplete data:
```
# Missing required fields
client
dev tun
```

2. Import this file

**Expected:**
- ✅ Validation error message
- ✅ Clear indication of what's missing
- ✅ Helpful error message

**❌ Failed If:**
- File picker doesn't open
- Valid config rejected
- Invalid config accepted
- Application crashes on invalid config
- No error message for invalid config

---

### Phase 4: VPN Connection (15 minutes)

**Prerequisites:**
- Valid .ovpn config imported
- Test VPN server accessible

**Test 4.1: Initiate Connection**

1. Click "Connect" button

**Expected Immediate Changes:**
- ✅ Button changes to "Connecting..."
- ✅ Connection status: "Connecting"
- ✅ Loading animation appears

**Console Verification:**
```
[VPN] Starting OpenVPN connection...
[VPN] OpenVPN binary found at: /usr/local/bin/openvpn
[VPN] Config file: /tmp/barqnet-xxxxx.ovpn
[VPN] Starting process...
```

**Test 4.2: Connection Established**

**Wait for connection (15-30 seconds)**

**Expected:**
- ✅ Status changes to "Connected"
- ✅ Green connection indicator
- ✅ Local IP address displayed
- ✅ Traffic stats appear (0 MB initially)
- ✅ Connection duration counter starts

**Console Verification:**
```
[VPN] Initialization Sequence Completed
[VPN] Connection established
[Stats] Monitoring started
```

**Test 4.3: Verify Traffic Statistics**

**With VPN connected:**
1. Open web browser
2. Visit a few websites
3. Watch statistics panel

**Expected:**
- ✅ Bytes In counter increases
- ✅ Bytes Out counter increases
- ✅ Statistics update in real-time (every 1-2 seconds)
- ✅ Duration counter increments

**Test 4.4: Disconnect**

1. Click "Disconnect" button

**Expected:**
- ✅ Status changes to "Disconnecting"
- ✅ Status changes to "Disconnected"
- ✅ Traffic stats reset to 0
- ✅ Duration resets
- ✅ "Connect" button re-enabled

**Console Verification:**
```
[VPN] Disconnection requested
[VPN] Stopping OpenVPN process
[VPN] Process terminated successfully
[VPN] Cleanup complete
```

**❌ Failed If:**
- Connection attempt times out
- OpenVPN process doesn't start
- Process starts but doesn't connect
- Traffic stats show 0 MB during active use
- Cannot disconnect (process hangs)
- Application freezes during connection

---

### Phase 5: Settings & Features (5 minutes)

**Test 5.1: Settings Panel**

1. Click Settings button/icon

**Expected:**
- ✅ Settings panel opens
- ✅ Auto-connect toggle visible
- ✅ Auto-start toggle visible
- ✅ Kill switch toggle visible (disabled, future feature)

**Test 5.2: System Tray Integration** (macOS/Windows)

**macOS:**
- ✅ Menu bar icon appears
- ✅ Click shows menu with status
- ✅ Quick connect/disconnect from menu

**Windows:**
- ✅ System tray icon appears
- ✅ Right-click shows menu
- ✅ Can control VPN from tray

**Test 5.3: Window Management**

1. Minimize application
2. Check system tray menu
3. Click "Show Window" from tray

**Expected:**
- ✅ Application minimizes to tray
- ✅ Can restore from tray
- ✅ Connection persists when minimized

---

## iOS Testing

**Platform:** iOS 15.0+
**Time:** 40 minutes
**Status:** ✅ 85% Production Ready
**⚠️ CRITICAL:** Must use physical device (VPN doesn't work in simulator)

### Phase 1: Installation (5 minutes)

**Test 1.1: Build and Install**

```bash
cd /Users/hassanalsahli/Desktop/ChameleonVpn/barqnet-ios
open BarqNet.xcworkspace
```

**In Xcode:**
1. Select your development team
2. Connect iOS device
3. Select device as target
4. Click Run (▶️)

**Expected:**
- ✅ Build succeeds (0 errors)
- ✅ App installs on device
- ✅ App launches automatically

**Build Verification:**
```
Build Succeeded
Installing to [Device Name]
App launched successfully
```

**❌ Failed If:**
- Build errors
- Code signing issues
- App doesn't launch
- Crashes on startup

---

### Phase 2: Security Features Verification (10 minutes)

**Test 2.1: Password Hashing (PBKDF2)**

**This tests automatic migration from old Base64 to PBKDF2**

1. Launch app for first time
2. Create account with test credentials

**Console Verification (Xcode Console):**
```
[AuthManager] migratePasswordHashes() called
[AuthManager] No legacy passwords found
```

**If you have old test data:**
```
[AuthManager] Successfully migrated 1 password(s) from Base64 to PBKDF2
```

**Verification:**
- ✅ Password stored securely (not plaintext)
- ✅ Can login with same password
- ✅ Migration happens automatically on first launch

**Test 2.2: Keychain Storage**

**This tests VPN config storage in iOS Keychain**

1. Import a VPN config
2. Kill and restart app

**Expected:**
- ✅ VPN config persists after restart
- ✅ Server info still displayed
- ✅ No need to re-import

**Console Verification:**
```
[VPNManager] migrateConfigToKeychain() called
[VPNManager] Config loaded from Keychain successfully
```

**Verify Keychain:**
1. Go to Settings → Face ID & Passcode → [Enter passcode]
2. Scroll to "Saved Passwords"
3. Should NOT see VPN credentials (they're in Keychain, not keychain passwords)

**❌ Failed If:**
- Config lost after app restart
- Migration errors in console
- Keychain access errors

---

### Phase 3: Authentication Flow (10 minutes)

**Similar to Desktop testing:**

**Test 3.1: Account Creation**

1. Enter phone number
2. Tap "Send Code"
3. **Check for OTP** (currently local-only, no SMS)
4. Enter OTP code
5. Create password (8+ characters)
6. Tap "Create Account"

**Expected:**
- ✅ Smooth UI transitions
- ✅ Password strength validation
- ✅ Account created successfully
- ✅ Automatic login

**Test 3.2: Biometric Authentication** (if supported)

1. Go to Settings
2. Enable "Face ID / Touch ID"
3. Logout
4. Login again

**Expected:**
- ✅ Biometric prompt appears
- ✅ Successful authentication logs in
- ✅ Fallback to password if biometric fails

---

### Phase 4: VPN Connection (10 minutes)

**⚠️ CRITICAL: Must use physical device**

**Test 4.1: Import Config**

1. Tap "Import Config"
2. Select method (Files, iCloud, etc.)
3. Choose test .ovpn file

**Expected:**
- ✅ File picker appears
- ✅ Config parsed successfully
- ✅ Server info displayed

**Test 4.2: Request VPN Permission**

1. Tap "Connect"
2. iOS VPN permission dialog should appear

**Expected:**
- ✅ iOS system dialog: "BarqNet Would Like to Add VPN Configurations"
- ✅ Tap "Allow"
- ✅ VPN profile installed

**Test 4.3: Establish Connection**

**After permission granted:**

**Expected:**
- ✅ VPN icon appears in status bar (top of screen)
- ✅ Connection status: "Connected"
- ✅ Traffic statistics update
- ✅ Real encryption active (not simulated)

**Console Verification:**
```
[PacketTunnelProvider] startTunnel called
[OpenVPNAdapter] Connecting to vpn.server.com:1194
[OpenVPNAdapter] Connection established
[PacketTunnelProvider] VPN connected successfully
```

**Test 4.4: Verify Real Encryption**

**Console should show:**
```
[OpenVPNAdapter] Data channel: using AES-256-GCM
```

**NOT:**
```
"Stub class" or "Simulation" or "Mock"
```

**Test 4.5: Background Connectivity**

1. While connected, press Home button
2. Open other apps
3. Return to BarqNet

**Expected:**
- ✅ VPN stays connected in background
- ✅ Statistics continue updating
- ✅ Connection doesn't drop

**Test 4.6: Disconnect**

1. Tap "Disconnect"

**Expected:**
- ✅ VPN icon disappears from status bar
- ✅ Connection status: "Disconnected"
- ✅ Clean disconnection

---

### Phase 5: Migration Testing (5 minutes)

**Only if you have old version installed:**

**Test 5.1: Password Migration**

1. Install old version (with Base64 passwords)
2. Create account
3. Install new version (overwrite)
4. Launch app

**Expected:**
- ✅ Automatic migration on first launch
- ✅ Can still login with same password
- ✅ Password now stored as PBKDF2

**Test 5.2: Config Migration**

1. Install old version (with UserDefaults storage)
2. Import VPN config
3. Install new version (overwrite)
4. Launch app

**Expected:**
- ✅ Automatic migration on first launch
- ✅ Config now in Keychain
- ✅ Old UserDefaults data deleted

---

## Android Testing

**Platform:** Android 8.0+
**Time:** 45 minutes
**Status:** ⚠️ 65% Production Ready (Build issues present)

### Phase 0: Build Environment Fix (5 minutes)

**⚠️ CRITICAL: Must fix Java version first**

```bash
# Check Java version
java -version

# Should show Java 11 or higher
# If Java 8, set JAVA_HOME:
export JAVA_HOME=$(/usr/libexec/java_home -v 11)

# Verify
java -version
```

**Expected:**
```
openjdk version "11.0.x" or higher
```

---

### Phase 1: Build and Install (10 minutes)

**Test 1.1: Build APK**

```bash
cd /Users/hassanalsahli/Desktop/ChameleonVpn/barqnet-android
./gradlew clean assembleDebug
```

**Expected:**
- ✅ Build completes successfully
- ✅ APK created: `app/build/outputs/apk/debug/app-debug.apk`

**❌ Current Issue:**
```
Could not resolve com.android.tools.build:gradle:7.4.2
```

**Fix Required:** See Phase 0 above

**Test 1.2: Install to Device**

```bash
./gradlew installDebug
```

**OR:**

```bash
adb install app/build/outputs/apk/debug/app-debug.apk
```

**Expected:**
- ✅ App installs successfully
- ✅ Icon appears in app drawer
- ✅ App launches

---

### Phase 2: Authentication Flow (10 minutes)

**Test 2.1: Create Account**

1. Launch app
2. Enter phone number
3. Tap "Send Code"
4. Enter OTP
5. Create password
6. Tap "Create Account"

**Expected:**
- ✅ Material3 UI (beautiful design)
- ✅ Smooth animations
- ✅ Account created successfully

**Test 2.2: Biometric Authentication**

1. Enable in settings (if available)
2. Logout and login

**Expected:**
- ✅ Fingerprint/Face prompt
- ✅ Successful authentication

---

### Phase 3: VPN Configuration (10 minutes)

**Test 3.1: Import .ovpn File**

1. Tap "Import Config"
2. Use file picker to select .ovpn file

**Expected:**
- ✅ File picker opens
- ✅ Config parsed successfully
- ✅ Server details displayed

**Test 3.2: Verify Parsed Data**

**Check displayed info:**
- ✅ Server address
- ✅ Port number
- ✅ Protocol (UDP/TCP)
- ✅ Cipher (AES-256-GCM/CBC)

---

### Phase 4: VPN Connection (15 minutes)

**⚠️ WARNING: Current RealVPNService requires custom backend**

**Test 4.1: Request VPN Permission**

1. Tap "Connect"
2. Android VPN permission dialog should appear

**Expected:**
- ✅ Dialog: "Connection request"
- ✅ App info: BarqNet
- ✅ Tap "OK"

**Test 4.2: Check Logcat for Service Start**

```bash
adb logcat | grep RealVPNService
```

**Expected:**
```
RealVPNService: onCreate called
RealVPNService: Singleton instance set
RealVPNService: Starting VPN connection
RealVPNService: VPN interface created
RealVPNService: Encryption initialized: AES-256-GCM
```

**Test 4.3: Verify Kill Switch**

**Logcat should show:**
```
RealVPNService: Kill switch enabled (setBlocking=true)
```

**Test:**
1. While connecting, enable airplane mode
2. Disable airplane mode
3. VPN should block traffic until reconnected

**Expected:**
- ✅ No data leak during connection
- ✅ Traffic blocked until VPN reconnects

**Test 4.4: Verify DNS Leak Protection**

**Logcat should show:**
```
RealVPNService: DNS servers configured: [8.8.8.8, 8.8.4.4]
```

**Test 4.5: Check Statistics**

**While connected:**
1. Browse websites
2. Watch traffic counters

**Expected:**
- ✅ Bytes In increases
- ✅ Bytes Out increases
- ✅ Real data (not fake random numbers)

**Logcat Verification:**
```
RealVPNService: Bytes sent: 12345
RealVPNService: Bytes received: 67890
```

**NOT:**
```
"Random number" or "Fake stats"
```

---

### Phase 5: Known Issues (5 minutes)

**⚠️ Document these during testing:**

**Issue 1: RealVPNService NOT Registered**
- **Symptom:** App crashes when clicking "Connect"
- **Logcat Error:** "Unable to start service Intent { ... RealVPNService }"
- **Status:** KNOWN ISSUE - Fix pending

**Issue 2: Custom Protocol vs Standard OpenVPN**
- **Symptom:** Cannot connect to standard OpenVPN servers
- **Reason:** RealVPNService uses custom protocol
- **Workaround:** Requires matching custom backend

**Issue 3: Incomplete Key Derivation**
- **Security Risk:** Weak key generation
- **Status:** KNOWN ISSUE - Fix pending

---

## Cross-Platform Verification

**Time:** 30 minutes

### Test 1: Consistent User Experience

**Compare across all platforms:**

| Feature | Desktop | iOS | Android | Status |
|---------|---------|-----|---------|--------|
| Authentication Flow | ✅ Smooth | Test | Test | ? |
| VPN Import | ✅ Works | Test | Test | ? |
| Connection UI | ✅ Clear | Test | Test | ? |
| Statistics Display | ✅ Real | Test | Test | ? |
| Settings Panel | ✅ Complete | Test | Test | ? |

**Document any inconsistencies**

---

### Test 2: Feature Parity

**Verify all platforms have:**
- ✅ Account creation
- ✅ OTP verification
- ✅ Password authentication
- ✅ .ovpn file import
- ✅ VPN connection
- ✅ Traffic statistics
- ✅ Disconnect
- ✅ Settings

**Note:** Some platform-specific features are acceptable

---

## Security Testing

**Time:** 45 minutes
**Requires:** Network analysis tools (optional)

### Test 1: Password Security

**Desktop:**
1. Create account with password `TestPassword123`
2. Check electron-store data:
```bash
cat ~/Library/Application\ Support/barqnet-desktop/auth.json
```

**Expected:**
- ✅ Password NOT stored in plaintext
- ✅ Hashed with bcrypt or similar

**iOS:**
1. Create account
2. Check UserDefaults:
```bash
# In Xcode, cannot easily access Keychain
# But verify no errors in console about Keychain access
```

**Expected:**
- ✅ Password hashed with PBKDF2 (100k iterations)
- ✅ Stored in iOS Keychain

**Android:**
1. Create account
2. Check SharedPreferences:
```bash
adb shell run-as com.barqnet.android cat /data/data/com.barqnet.android/shared_prefs/*.xml
```

**Expected:**
- ✅ Password hashed with BCrypt
- ✅ NOT plaintext in XML

---

### Test 2: Certificate Pinning (Desktop)

**Test 2.1: With Correct Pins** (Production only)

**Prerequisites:**
- Set correct certificate pins in `.env`
- Set `NODE_ENV=production`

**Steps:**
1. Start app
2. Attempt to connect to backend

**Expected:**
- ✅ Connection succeeds
- ✅ Certificate validation passes

**Console Verification:**
```
[CERT-PIN] Certificate pinning enabled
[CERT-PIN] Verifying certificate for api.barqnet.com
[CERT-PIN] Certificate pin matched
```

**Test 2.2: With Wrong Pins** (Security Test)

1. Set INCORRECT certificate pins
2. Start app
3. Attempt connection

**Expected:**
- ❌ Connection REJECTED
- ❌ Security error displayed

**Console Verification:**
```
[CERT-PIN] Certificate pin mismatch!
[CERT-PIN] Connection rejected - MITM protection
```

**⚠️ This failure is CORRECT behavior (security working)**

---

### Test 3: VPN Encryption Verification

**Tool:** Wireshark (optional, advanced)

**Without VPN:**
1. Start Wireshark
2. Filter: `http`
3. Visit `http://example.com`

**Expected:**
- ✅ HTTP traffic visible in plaintext
- ✅ Can read website content

**With VPN:**
1. Connect to VPN
2. Start Wireshark
3. Filter: `openvpn` or `udp.port == 1194`
4. Visit `http://example.com`

**Expected:**
- ✅ Encrypted tunnel traffic visible
- ❌ CANNOT read HTTP content (encrypted)
- ✅ Only encrypted UDP packets to VPN server

---

## Performance Testing

**Time:** 30 minutes

### Test 1: Connection Speed

**Test 1.1: Connection Establishment Time**

**Measure:**
- Click "Connect" → Status changes to "Connected"

**Acceptable:**
- ✅ < 10 seconds (good)
- ⚠️ 10-30 seconds (acceptable)
- ❌ > 30 seconds (investigate)

**Test 1.2: Disconnection Time**

**Measure:**
- Click "Disconnect" → Status changes to "Disconnected"

**Acceptable:**
- ✅ < 2 seconds (good)
- ⚠️ 2-5 seconds (acceptable)
- ❌ > 5 seconds (investigate)

---

### Test 2: Resource Usage

**Desktop:**
```bash
# macOS
top -pid $(pgrep -f "Electron.*barqnet")

# Expected:
# CPU: < 5% when idle, < 20% when connecting
# Memory: < 200 MB
```

**iOS:**
- Check Xcode Instruments
- Memory: < 100 MB
- CPU: < 10% when idle

**Android:**
```bash
adb shell dumpsys meminfo com.barqnet.android

# Expected:
# Total PSS: < 150 MB
```

---

### Test 3: Statistics Update Frequency

**Measure:**
1. Connect to VPN
2. Start downloading a large file
3. Watch statistics counter

**Expected:**
- ✅ Updates every 1-2 seconds
- ✅ Accurate byte counts
- ✅ Smooth counter animation

---

## Test Results Summary Template

```markdown
# Test Results - [Date]
**Tester:** [Name]
**Platforms Tested:** Desktop / iOS / Android

## Desktop
- [ ] Launch: PASS / FAIL
- [ ] Authentication: PASS / FAIL
- [ ] VPN Import: PASS / FAIL
- [ ] VPN Connection: PASS / FAIL
- [ ] Statistics: PASS / FAIL
**Notes:**

## iOS
- [ ] Installation: PASS / FAIL
- [ ] Security Features: PASS / FAIL
- [ ] VPN Connection: PASS / FAIL
- [ ] Background Mode: PASS / FAIL
**Notes:**

## Android
- [ ] Build: PASS / FAIL
- [ ] Installation: PASS / FAIL
- [ ] VPN Connection: PASS / FAIL
- [ ] Kill Switch: PASS / FAIL
**Notes:**

## Critical Issues Found
1.
2.
3.

## Recommendations
1.
2.
3.
```

---

## Appendix: Test Data

### Test .ovpn Configuration

**Create file:** `test-config.ovpn`

```
client
dev tun
proto udp
remote vpn.test.server.com 1194
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-CBC
auth SHA256
verb 3

<ca>
-----BEGIN CERTIFICATE-----
[CA Certificate Here]
-----END CERTIFICATE-----
</ca>

<cert>
-----BEGIN CERTIFICATE-----
[Client Certificate Here]
-----END CERTIFICATE-----
</cert>

<key>
-----BEGIN PRIVATE KEY-----
[Client Private Key Here]
-----END PRIVATE KEY-----
</key>
```

### Test Credentials

**Phone Numbers:**
- `+1234567890`
- `+1987654321`

**Passwords:**
- `TestPassword123!`
- `SecurePass456@`

---

## Support & Troubleshooting

**Common Issues:**

1. **Desktop: OpenVPN not found**
   - Install: `brew install openvpn` (macOS)
   - Or download from https://openvpn.net/

2. **iOS: Code signing error**
   - Set development team in Xcode
   - Verify provisioning profile

3. **Android: Build fails**
   - Fix Java version (must be 11+)
   - Run `./gradlew clean`

4. **VPN connection timeout**
   - Check server is accessible
   - Verify .ovpn config is valid
   - Check firewall settings

---

**END OF MANUAL TESTING GUIDE**
