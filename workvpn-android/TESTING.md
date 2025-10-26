# BarqNet Android Testing Guide

Comprehensive testing guide for BarqNet Android application, including manual testing, automated tests with Appium MCP, and CI/CD integration.

## Table of Contents

- [Testing Overview](#testing-overview)
- [Phase 1: Pre-Build Verification](#phase-1-pre-build-verification)
- [Phase 2: Build Verification](#phase-2-build-verification)
- [Phase 3: Unit Testing](#phase-3-unit-testing)
- [Phase 4: UI Testing (Espresso)](#phase-4-ui-testing-espresso)
- [Phase 5: Manual Testing](#phase-5-manual-testing)
- [Phase 6: VPN Connection Testing](#phase-6-vpn-connection-testing)
- [Phase 7: Background Service Testing](#phase-7-background-service-testing)
- [Phase 8: Error Handling](#phase-8-error-handling)
- [Phase 9: Performance Testing](#phase-9-performance-testing)
- [Phase 10: Appium MCP Automation](#phase-10-appium-mcp-automation)
- [Test Coverage Goals](#test-coverage-goals)

---

## Testing Overview

**Target**: 100% test coverage across all critical paths

**Testing Levels**:
1. **Unit Tests**: Kotlin test files for parsers, models, repositories
2. **Integration Tests**: Espresso UI tests for Compose screens
3. **Manual Tests**: Physical device testing for VPN, biometrics
4. **Automated Tests**: Appium MCP for end-to-end flows

**Test Environment**:
- Android Studio with Android SDK 34
- Physical device or emulator with API 26+
- Appium MCP server for automation
- Valid `.ovpn` configuration file for testing

---

## Phase 1: Pre-Build Verification

**Goal**: Verify all source files and resources are present

### 1.1 Verify Source Files

```bash
# Check core source files exist
ls -la app/src/main/java/com/barqnet/android/MainActivity.kt
ls -la app/src/main/java/com/barqnet/android/BarqNetApplication.kt
ls -la app/src/main/java/com/barqnet/android/model/VPNConfig.kt
ls -la app/src/main/java/com/barqnet/android/util/OVPNParser.kt
ls -la app/src/main/java/com/barqnet/android/vpn/OpenVPNService.kt
ls -la app/src/main/java/com/barqnet/android/viewmodel/VPNViewModel.kt
```

**Expected**: All files exist (exit code 0)

### 1.2 Verify Resources

```bash
# Check resource files
ls -la app/src/main/res/values/strings.xml
ls -la app/src/main/res/values/themes.xml
ls -la app/src/main/res/values/colors.xml
ls -la app/src/main/res/drawable/ic_vpn_key.xml
ls -la app/src/main/AndroidManifest.xml
```

**Expected**: All resource files present

### 1.3 Verify Dependencies

```bash
# Check build.gradle contains required dependencies
grep "ics-openvpn" app/build.gradle
grep "compose.material3" app/build.gradle
grep "datastore-preferences" app/build.gradle
grep "kotlinx-serialization" app/build.gradle
```

**Expected**: All dependencies found

✅ **Phase 1 Pass Criteria**: All files and dependencies verified

---

## Phase 2: Build Verification

**Goal**: Successfully build debug and release APKs

### 2.1 Clean Build

```bash
./gradlew clean
```

**Expected**: Build cache cleared

### 2.2 Debug Build

```bash
./gradlew assembleDebug
```

**Expected**:
- Build succeeds
- APK created at `app/build/outputs/apk/debug/app-debug.apk`
- No compilation errors
- APK size reasonable (~10-20 MB)

### 2.3 Release Build

```bash
./gradlew assembleRelease
```

**Expected**:
- Build succeeds with ProGuard/R8
- APK created at `app/build/outputs/apk/release/app-release-unsigned.apk`
- No obfuscation errors

### 2.4 Lint Check

```bash
./gradlew lint
```

**Expected**:
- No critical lint errors
- Report at `app/build/reports/lint-results.html`

✅ **Phase 2 Pass Criteria**: All builds succeed, lint passes

---

## Phase 3: Unit Testing

**Goal**: Test individual components in isolation

### 3.1 OVPNParser Tests

Create `app/src/test/java/com/barqnet/android/util/OVPNParserTest.kt`:

```kotlin
package com.barqnet.android.util

import org.junit.Test
import org.junit.Assert.*

class OVPNParserTest {

    @Test
    fun `parse valid ovpn with inline certs`() {
        val ovpnContent = """
            client
            dev tun
            remote vpn.example.com 1194 udp
            <ca>
            -----BEGIN CERTIFICATE-----
            MIIDazCCAlOgAwIBAgIUG...
            -----END CERTIFICATE-----
            </ca>
            <cert>
            -----BEGIN CERTIFICATE-----
            MIIDVDCCAjygAwIBAgIBA...
            -----END CERTIFICATE-----
            </cert>
            <key>
            -----BEGIN PRIVATE KEY-----
            MIIEvgIBADANBgkqhkiG9...
            -----END PRIVATE KEY-----
            </key>
        """.trimIndent()

        val result = OVPNParser.parse(ovpnContent, "test.ovpn")

        assertTrue(result.isSuccess)
        val config = result.getOrNull()!!
        assertEquals("test.ovpn", config.name)
        assertEquals("vpn.example.com", config.serverAddress)
        assertEquals(1194, config.port)
        assertEquals("udp", config.protocol)
        assertNotNull(config.ca)
        assertNotNull(config.cert)
        assertNotNull(config.key)
    }

    @Test
    fun `parse ovpn with tls-auth`() {
        val ovpnContent = """
            remote vpn.example.com 443 tcp
            <tls-auth>
            -----BEGIN OpenVPN Static key V1-----
            6acef03f62675b4b1bbd03e53...
            -----END OpenVPN Static key V1-----
            </tls-auth>
        """.trimIndent()

        val result = OVPNParser.parse(ovpnContent, "test-tls.ovpn")
        val config = result.getOrNull()!!

        assertNotNull(config.tlsAuth)
        assertTrue(config.tlsAuth!!.contains("BEGIN OpenVPN Static key"))
    }

    @Test
    fun `parse ovpn with cipher and auth`() {
        val ovpnContent = """
            remote vpn.example.com 1194
            cipher AES-256-CBC
            auth SHA256
        """.trimIndent()

        val result = OVPNParser.parse(ovpnContent, "test.ovpn")
        val config = result.getOrNull()!!

        assertEquals("AES-256-CBC", config.cipher)
        assertEquals("SHA256", config.auth)
    }

    @Test
    fun `fail parse without remote`() {
        val ovpnContent = """
            client
            dev tun
        """.trimIndent()

        val result = OVPNParser.parse(ovpnContent, "invalid.ovpn")

        assertTrue(result.isFailure)
        assertTrue(result.exceptionOrNull() is OVPNParser.ParseError.MissingRemote)
    }

    @Test
    fun `extract protocol from remote line`() {
        val udpContent = "remote vpn.example.com 1194 udp"
        val tcpContent = "remote vpn.example.com 443 tcp"

        val udpResult = OVPNParser.parse(udpContent, "test.ovpn").getOrNull()!!
        val tcpResult = OVPNParser.parse(tcpContent, "test.ovpn").getOrNull()!!

        assertEquals("udp", udpResult.protocol)
        assertEquals("tcp", tcpResult.protocol)
    }
}
```

### 3.2 VPNConfigRepository Tests

Create `app/src/test/java/com/barqnet/android/repository/VPNConfigRepositoryTest.kt`:

```kotlin
package com.barqnet.android.repository

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.barqnet.android.model.VPNConfig
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.junit.Assert.*

@RunWith(RobolectricTestRunner::class)
class VPNConfigRepositoryTest {

    private lateinit var repository: VPNConfigRepository
    private lateinit var context: Context

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        repository = VPNConfigRepository(context)
    }

    @Test
    fun `save and retrieve config`() = runTest {
        val config = VPNConfig(
            name = "test.ovpn",
            content = "test content",
            serverAddress = "vpn.example.com",
            port = 1194,
            protocol = "udp"
        )

        repository.saveConfig(config)
        val retrieved = repository.getConfig()

        assertNotNull(retrieved)
        assertEquals(config.name, retrieved!!.name)
        assertEquals(config.serverAddress, retrieved.serverAddress)
    }

    @Test
    fun `delete config`() = runTest {
        val config = VPNConfig(
            name = "test.ovpn",
            content = "test content",
            serverAddress = "vpn.example.com"
        )

        repository.saveConfig(config)
        repository.deleteConfig()
        val retrieved = repository.getConfig()

        assertNull(retrieved)
    }

    @Test
    fun `auto-connect preferences`() = runTest {
        repository.setAutoConnect(true)
        assertTrue(repository.getAutoConnect())

        repository.setAutoConnect(false)
        assertFalse(repository.getAutoConnect())
    }

    @Test
    fun `biometric preferences`() = runTest {
        repository.setUseBiometric(true)
        assertTrue(repository.getUseBiometric())

        repository.setUseBiometric(false)
        assertFalse(repository.getUseBiometric())
    }
}
```

### 3.3 Run Unit Tests

```bash
./gradlew test
```

**Expected**:
- All unit tests pass
- Report at `app/build/reports/tests/testDebugUnitTest/index.html`
- Code coverage at `app/build/reports/jacoco/test/html/index.html`

✅ **Phase 3 Pass Criteria**: All unit tests pass (target: 25+ tests)

---

## Phase 4: UI Testing (Espresso)

**Goal**: Test Compose UI components

### 4.1 HomeScreen Tests

Create `app/src/androidTest/java/com/barqnet/android/ui/HomeScreenTest.kt`:

```kotlin
package com.barqnet.android.ui

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.barqnet.android.ui.screens.HomeScreen
import com.barqnet.android.viewmodel.VPNViewModel
import org.junit.Rule
import org.junit.Test

class HomeScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun noConfigScreen_showsImportButton() {
        composeTestRule.setContent {
            // Mock ViewModel with no config
            HomeScreen(
                vpnViewModel = /* mock */,
                onNavigateToImport = {},
                onNavigateToSettings = {}
            )
        }

        composeTestRule.onNodeWithText("No VPN Configuration").assertIsDisplayed()
        composeTestRule.onNodeWithText("Import .ovpn File").assertIsDisplayed()
    }

    @Test
    fun withConfig_showsConnectButton() {
        // Test with config present
        composeTestRule.onNodeWithText("Connect").assertIsDisplayed()
    }

    @Test
    fun connectedState_showsDisconnectButton() {
        // Test when VPN is connected
        composeTestRule.onNodeWithText("Disconnect").assertIsDisplayed()
    }

    @Test
    fun clickSettings_navigates() {
        var settingsClicked = false

        composeTestRule.setContent {
            HomeScreen(
                vpnViewModel = /* mock */,
                onNavigateToSettings = { settingsClicked = true }
            )
        }

        composeTestRule.onNodeWithContentDescription("Settings").performClick()
        assert(settingsClicked)
    }
}
```

### 4.2 Run Instrumented Tests

```bash
# Start emulator or connect device
adb devices

# Run Espresso tests
./gradlew connectedAndroidTest
```

**Expected**:
- All UI tests pass
- Report at `app/build/reports/androidTests/connected/index.html`

✅ **Phase 4 Pass Criteria**: All UI tests pass (target: 15+ tests)

---

## Phase 5: Manual Testing

**Goal**: Test app on physical device

### 5.1 Installation

```bash
# Install debug APK
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Launch app
adb shell am start -n com.barqnet.android/.MainActivity
```

**Expected**: App launches successfully

### 5.2 UI Verification

- [ ] Gradient background displays (purple to dark purple)
- [ ] "BarqNet" title visible at top
- [ ] "No VPN Configuration" message shows on first launch
- [ ] "Import .ovpn File" button visible
- [ ] Settings icon (gear) in top-right corner

### 5.3 Import Configuration

1. Prepare `.ovpn` file on device:
```bash
adb push /path/to/your/config.ovpn /sdcard/Download/config.ovpn
```

2. In app:
   - Tap "Import .ovpn File"
   - Select file from Downloads
   - Verify import success message

**Expected**: Config imported, UI shows server address and Connect button

### 5.4 Settings Screen

- [ ] Tap settings icon
- [ ] Settings screen displays
- [ ] "Auto-connect on app launch" toggle visible
- [ ] "Use biometric authentication" toggle visible
- [ ] "Delete Configuration" button visible
- [ ] Toggle auto-connect on/off (state persists)

### 5.5 Navigation

- [ ] Navigate: Home → Import → Home
- [ ] Navigate: Home → Settings → Home
- [ ] Back button works correctly

✅ **Phase 5 Pass Criteria**: All manual UI checks pass

---

## Phase 6: VPN Connection Testing

**Goal**: Verify OpenVPN connection functionality

### 6.1 VPN Permission

1. Tap "Connect" button
2. System VPN permission dialog appears
3. Tap "OK" to grant permission

**Expected**: VPN permission granted, connection starts

### 6.2 Connection Flow

- [ ] Status changes: Disconnected → Connecting → Connected
- [ ] Status color changes: Red → Orange → Green
- [ ] Notification appears: "VPN Connected"
- [ ] Android VPN icon in status bar
- [ ] Connection duration starts counting

### 6.3 Traffic Statistics

- [ ] Download bytes update in real-time
- [ ] Upload bytes update in real-time
- [ ] Values formatted correctly (KB, MB, GB)

### 6.4 Disconnect Flow

1. Tap "Disconnect" button
2. Status changes to "Disconnecting"
3. Status changes to "Disconnected"
4. VPN icon removed from status bar
5. Notification updated: "VPN Disconnected"

**Expected**: Clean disconnect, no errors

### 6.5 Network Validation

```bash
# Check VPN interface is active
adb shell ifconfig tun0

# Check routing table
adb shell ip route

# Verify DNS (when connected)
adb shell getprop net.dns1
```

**Expected**: tun0 interface active, routes via VPN

### 6.6 Connection Stability

- [ ] Connect and leave VPN running for 5 minutes
- [ ] Check logcat for errors: `adb logcat | grep OpenVPN`
- [ ] Verify connection remains stable

✅ **Phase 6 Pass Criteria**: VPN connects, routes traffic, disconnects cleanly

---

## Phase 7: Background Service Testing

**Goal**: Test VPN service resilience

### 7.1 App Backgrounding

1. Connect to VPN
2. Press Home button (app goes to background)
3. Verify VPN stays connected (check status bar icon)
4. Wait 2 minutes
5. Reopen app from launcher

**Expected**: VPN still connected, UI reflects correct state

### 7.2 App Force-Stop

1. Connect to VPN
2. Force-stop app: `adb shell am force-stop com.barqnet.android`
3. Check VPN icon in status bar

**Expected**: VPN disconnects when app is force-stopped

### 7.3 Screen Off

1. Connect to VPN
2. Turn off screen (power button)
3. Wait 1 minute
4. Turn on screen

**Expected**: VPN remains connected

### 7.4 Low Memory

```bash
# Simulate low memory
adb shell am send-trim-memory com.barqnet.android RUNNING_CRITICAL
```

**Expected**: VPN service survives, connection maintained

### 7.5 Boot Receiver

1. Enable "Auto-connect on app launch" in settings
2. Reboot device: `adb reboot`
3. Wait for boot to complete
4. Check if VPN auto-connects

**Expected**: VPN connects automatically after boot (requires testing on physical device)

✅ **Phase 7 Pass Criteria**: VPN service robust across all scenarios

---

## Phase 8: Error Handling

**Goal**: Test edge cases and error scenarios

### 8.1 Invalid Configuration

Test with malformed `.ovpn` files:

**Test 1**: Missing `remote` directive
```
client
dev tun
```
**Expected**: Import fails with "Missing remote server" error

**Test 2**: Missing certificates
```
remote vpn.example.com 1194
```
**Expected**: Import fails with "Missing CA certificate" error

**Test 3**: Invalid port
```
remote vpn.example.com 99999
```
**Expected**: Import fails or connection fails with clear error

### 8.2 Connection Failures

1. Import valid config with unreachable server
2. Attempt connection
3. Verify timeout handling

**Expected**: Error status, retry option, clear error message

### 8.3 Permission Denied

1. Connect to VPN
2. Deny VPN permission in system dialog
3. Check error handling

**Expected**: Clear error message, option to retry

### 8.4 Network Loss

1. Connect to VPN
2. Enable airplane mode
3. Disable airplane mode
4. Check reconnection

**Expected**: Detects network loss, attempts reconnection

### 8.5 Biometric Failures

1. Enable "Use biometric authentication"
2. Attempt connection without registered fingerprint
3. Verify fallback behavior

**Expected**: Falls back to manual connection, clear error

✅ **Phase 8 Pass Criteria**: All error cases handled gracefully

---

## Phase 9: Performance Testing

**Goal**: Measure performance metrics

### 9.1 App Launch Time

```bash
# Measure cold start time
adb shell am start -W com.barqnet.android/.MainActivity
```

**Expected**:
- TotalTime < 2000ms
- WaitTime < 2500ms

### 9.2 Memory Usage

```bash
# Monitor memory
adb shell dumpsys meminfo com.barqnet.android
```

**Expected**:
- Total PSS < 100 MB (idle)
- Total PSS < 150 MB (connected)

### 9.3 Battery Drain

1. Connect to VPN
2. Run for 1 hour
3. Check battery stats:
```bash
adb shell dumpsys batterystats com.barqnet.android
```

**Expected**: Reasonable battery usage (<5% per hour)

### 9.4 APK Size

```bash
ls -lh app/build/outputs/apk/release/app-release-unsigned.apk
```

**Expected**: APK size < 25 MB

### 9.5 Connection Latency

Measure time from tap "Connect" to "Connected" state

**Expected**: < 5 seconds on good network

✅ **Phase 9 Pass Criteria**: Performance within acceptable limits

---

## Phase 10: Appium MCP Automation

**Goal**: Automate end-to-end testing with Appium MCP

### 10.1 Setup Appium MCP

```bash
# Install Appium MCP server
npm install -g appium
npm install -g appium-uiautomator2-driver

# Start Appium server
appium --allow-insecure chromedriver_autodownload
```

### 10.2 Appium Capabilities

```json
{
  "platformName": "Android",
  "platformVersion": "14",
  "deviceName": "Android Emulator",
  "automationName": "UiAutomator2",
  "app": "/path/to/app-debug.apk",
  "appPackage": "com.barqnet.android",
  "appActivity": ".MainActivity",
  "noReset": false,
  "fullReset": true
}
```

### 10.3 Test Scenarios (Appium)

**Scenario 1: First Launch and Import**
1. Launch app
2. Verify "No VPN Configuration" text
3. Tap "Import .ovpn File" button
4. Select file from picker
5. Verify import success

**Scenario 2: Connect to VPN**
1. Launch app (with config)
2. Tap "Connect" button
3. Grant VPN permission
4. Wait for "Connected" status
5. Verify green status color
6. Tap "Disconnect"
7. Verify "Disconnected" status

**Scenario 3: Settings Management**
1. Tap settings icon
2. Toggle "Auto-connect" on
3. Navigate back
4. Kill app
5. Relaunch app
6. Verify auto-connect triggers

**Scenario 4: Delete Configuration**
1. Navigate to settings
2. Tap "Delete Configuration"
3. Confirm deletion
4. Verify returned to "No Configuration" state

### 10.4 MCP Test Script (JavaScript)

Create `appium-tests/barqnet.test.js`:

```javascript
const { remote } = require('webdriverio');

const capabilities = {
  platformName: 'Android',
  'appium:automationName': 'UiAutomator2',
  'appium:deviceName': 'Android Emulator',
  'appium:app': '/path/to/app-debug.apk',
  'appium:appPackage': 'com.barqnet.android',
  'appium:appActivity': '.MainActivity',
};

describe('BarqNet Android Tests', () => {
  let driver;

  beforeAll(async () => {
    driver = await remote({
      hostname: 'localhost',
      port: 4723,
      capabilities,
    });
  });

  afterAll(async () => {
    await driver.deleteSession();
  });

  test('First launch shows no config message', async () => {
    const noConfigText = await driver.$('android=new UiSelector().textContains("No VPN Configuration")');
    await expect(noConfigText).toBeDisplayed();
  });

  test('Import button is visible', async () => {
    const importButton = await driver.$('android=new UiSelector().text("Import .ovpn File")');
    await expect(importButton).toBeDisplayed();
    await importButton.click();
  });

  test('Connect and disconnect VPN', async () => {
    // Assuming config is imported
    const connectButton = await driver.$('android=new UiSelector().text("Connect")');
    await connectButton.click();

    // Grant VPN permission
    const okButton = await driver.$('android=new UiSelector().text("OK")');
    if (await okButton.isDisplayed()) {
      await okButton.click();
    }

    // Wait for connected state
    await driver.pause(5000);
    const disconnectButton = await driver.$('android=new UiSelector().text("Disconnect")');
    await expect(disconnectButton).toBeDisplayed();

    // Disconnect
    await disconnectButton.click();
    await driver.pause(2000);

    const connectAgain = await driver.$('android=new UiSelector().text("Connect")');
    await expect(connectAgain).toBeDisplayed();
  });

  test('Settings navigation', async () => {
    const settingsIcon = await driver.$('android=new UiSelector().descriptionContains("Settings")');
    await settingsIcon.click();

    const autoConnectToggle = await driver.$('android=new UiSelector().textContains("Auto-connect")');
    await expect(autoConnectToggle).toBeDisplayed();

    // Navigate back
    await driver.back();
  });
});
```

### 10.5 Run Appium Tests

```bash
cd appium-tests
npm install
npm test
```

**Expected**: All Appium tests pass

### 10.6 CI/CD Integration

```yaml
# .github/workflows/android-test.yml
name: Android Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v3

      - name: Set up JDK 17
        uses: actions/setup-java@v3
        with:
          java-version: '17'

      - name: Build Debug APK
        run: ./gradlew assembleDebug

      - name: Run Unit Tests
        run: ./gradlew test

      - name: Start Emulator
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 34
          script: ./gradlew connectedAndroidTest

      - name: Upload Test Reports
        uses: actions/upload-artifact@v3
        with:
          name: test-reports
          path: app/build/reports/
```

✅ **Phase 10 Pass Criteria**: All Appium tests pass, CI/CD integrated

---

## Test Coverage Goals

### Coverage Targets

| Component | Target | Actual | Status |
|-----------|--------|--------|--------|
| OVPNParser | 100% | TBD | 🔄 |
| VPNConfigRepository | 90% | TBD | 🔄 |
| VPNViewModel | 85% | TBD | 🔄 |
| OpenVPNService | 80% | TBD | 🔄 |
| Compose UI | 70% | TBD | 🔄 |
| Overall | 80% | TBD | 🔄 |

### Generate Coverage Report

```bash
./gradlew jacocoTestReport
open app/build/reports/jacoco/test/html/index.html
```

---

## Test Checklist

### Pre-Release Checklist

- [ ] All unit tests pass (Phase 3)
- [ ] All UI tests pass (Phase 4)
- [ ] Manual testing complete (Phase 5)
- [ ] VPN connection verified (Phase 6)
- [ ] Background service tested (Phase 7)
- [ ] Error handling verified (Phase 8)
- [ ] Performance metrics acceptable (Phase 9)
- [ ] Appium automation passes (Phase 10)
- [ ] Code coverage > 80%
- [ ] No critical lint errors
- [ ] APK size < 25 MB
- [ ] Memory usage < 150 MB
- [ ] No memory leaks (LeakCanary)
- [ ] Battery drain acceptable
- [ ] ProGuard build successful
- [ ] Security audit passed

### Device Matrix

Test on multiple devices:
- [ ] Pixel 6 (Android 14)
- [ ] Samsung Galaxy S21 (Android 13)
- [ ] OnePlus 9 (Android 12)
- [ ] Emulator API 26 (minimum)
- [ ] Emulator API 34 (target)

---

## Troubleshooting Test Issues

### Appium Connection Fails

```bash
# Check Appium server
lsof -i :4723

# Restart Appium
pkill -9 appium
appium --allow-insecure chromedriver_autodownload
```

### Espresso Tests Timeout

Add to `app/build.gradle`:
```gradle
android {
    testOptions {
        animationsDisabled = true
    }
}
```

### Coverage Report Not Generated

```bash
# Ensure JaCoCo plugin
./gradlew --refresh-dependencies
./gradlew clean jacocoTestReport
```

### VPN Test Fails on Emulator

Use emulator with Google APIs (not Google Play):
```bash
avdmanager create avd -n test_vpn -k "system-images;android-34;google_apis;x86_64"
```

---

## Success Criteria

**100% Test Completion** means:
- ✅ All 10 testing phases completed
- ✅ All unit tests pass (25+ tests)
- ✅ All UI tests pass (15+ tests)
- ✅ All Appium tests pass (10+ scenarios)
- ✅ Code coverage > 80%
- ✅ Performance metrics within limits
- ✅ No critical errors
- ✅ CI/CD pipeline green

**Ready for production when all criteria met!**
