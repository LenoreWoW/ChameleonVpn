# BarqNet iOS - Testing Guide

Comprehensive testing guide for Platform 2 (iOS/iPadOS).

## Testing Overview

This guide covers all testing phases for the BarqNet iOS application, from unit tests to XcodeBuild MCP automated testing.

---

## Prerequisites

### Required Tools

- **Xcode** 14.0+ with iOS 15.0+ SDK
- **CocoaPods** for dependency management
- **Physical iOS device** (for VPN testing)
- **TestFlight** account (for distribution testing)
- **XcodeBuild MCP** for automated testing

### Setup

```bash
# Install CocoaPods
sudo gem install cocoapods

# Install dependencies
pod install

# Open workspace
open BarqNet.xcworkspace
```

---

## Phase 1: Build Verification

### 1.1 Clean Build

```bash
# Clean build folder
xcodebuild clean \
  -workspace BarqNet.xcworkspace \
  -scheme BarqNet

# Build for simulator
xcodebuild build \
  -workspace BarqNet.xcworkspace \
  -scheme BarqNet \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

**Success Criteria**:
- [ ] No build errors
- [ ] No compiler warnings
- [ ] All dependencies resolved
- [ ] Both targets build successfully (app + extension)

### 1.2 Archive Build

```bash
# Build archive for device
xcodebuild archive \
  -workspace BarqNet.xcworkspace \
  -scheme BarqNet \
  -archivePath build/BarqNet.xcarchive \
  -destination generic/platform=iOS
```

**Success Criteria**:
- [ ] Archive creates successfully
- [ ] Provisioning profiles valid
- [ ] Entitlements configured correctly
- [ ] Extension included in archive

---

## Phase 2: Unit Tests

### 2.1 OVPN Parser Tests

Test the configuration file parser:

```swift
// Test cases to verify:
- Parse basic config with remote server
- Parse inline CA certificate
- Parse inline client cert and key
- Parse protocol (UDP/TCP)
- Parse port number
- Handle comments and empty lines
- Validate required fields
- Reject invalid configs
- Handle malformed inline blocks
```

### 2.2 VPN Config Model Tests

```swift
// Test cases:
- Create config from parsed data
- Encode/decode config (Codable)
- Config persistence (UserDefaults)
- Config validation
- Display name formatting
```

### 2.3 Run Unit Tests

```bash
xcodebuild test \
  -workspace BarqNet.xcworkspace \
  -scheme BarqNet \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:BarqNetTests
```

**Success Criteria**:
- [ ] All parser tests pass
- [ ] All model tests pass
- [ ] Code coverage > 80%

---

## Phase 3: UI Tests (Simulator)

### 3.1 No Config State

**Test Steps**:
1. Launch app (first time)
2. Verify "No VPN Configuration" screen shows
3. Verify import button is visible
4. Tap import button
5. Verify file picker appears

**Success Criteria**:
- [ ] No config state displays correctly
- [ ] Lock icon visible
- [ ] Import button functional
- [ ] File picker opens

### 3.2 Config Import

**Test Steps**:
1. Prepare test .ovpn file
2. Import via Files app
3. Verify config parsing
4. Verify UI switches to VPN state

**Success Criteria**:
- [ ] File import works
- [ ] Parser validates config
- [ ] Error shown for invalid config
- [ ] Config saved successfully
- [ ] UI updates to show VPN controls

### 3.3 VPN Status View

**Test Steps**:
1. With config imported
2. Verify disconnect state shown
3. Verify server info displayed
4. Verify connect button enabled

**Success Criteria**:
- [ ] Status icon shows (red for disconnected)
- [ ] Server address displayed
- [ ] Protocol displayed
- [ ] Connect button enabled

### 3.4 Settings View

**Test Steps**:
1. Tap settings icon
2. Verify settings sheet appears
3. Toggle auto-connect
4. Toggle Face ID
5. Close settings

**Success Criteria**:
- [ ] Settings view opens
- [ ] Toggles work
- [ ] Settings persist
- [ ] Delete config button visible

---

## Phase 4: VPN Connection Tests (Physical Device)

### 4.1 First Connection

**Test Steps**:
1. Install on physical iOS device
2. Import valid .ovpn config
3. Tap "Connect"
4. Approve VPN permission dialog
5. Wait for connection

**Success Criteria**:
- [ ] VPN permission requested
- [ ] Permission approved
- [ ] Connection establishes
- [ ] Status changes to "Connected"
- [ ] VPN icon appears in status bar
- [ ] Green status indicator shows

### 4.2 Connection Monitoring

**While Connected**:
- [ ] Duration counter updates every second
- [ ] Traffic statistics update
- [ ] Status remains "Connected"
- [ ] Network traffic routes through VPN

### 4.3 Disconnection

**Test Steps**:
1. While connected
2. Tap "Disconnect"
3. Wait for disconnection

**Success Criteria**:
- [ ] Disconnects successfully
- [ ] Status changes to "Disconnected"
- [ ] VPN icon disappears
- [ ] Red status indicator shows
- [ ] Statistics stop updating

### 4.4 Reconnection

**Test Steps**:
1. After disconnecting
2. Tap "Connect" again
3. Verify reconnection

**Success Criteria**:
- [ ] Reconnects without permission dialog
- [ ] Connection faster (no dialog)
- [ ] All stats reset
- [ ] Connection establishes successfully

---

## Phase 5: Background Testing

### 5.1 App Background

**Test Steps**:
1. Connect to VPN
2. Press home button (background app)
3. Wait 5 minutes
4. Return to app

**Success Criteria**:
- [ ] VPN stays connected in background
- [ ] Connection doesn't drop
- [ ] App resumes correctly
- [ ] Stats continue updating

### 5.2 Device Lock

**Test Steps**:
1. Connect to VPN
2. Lock device
3. Wait 5 minutes
4. Unlock device

**Success Criteria**:
- [ ] VPN stays connected while locked
- [ ] No disconnection
- [ ] Stats accurate after unlock

### 5.3 Network Changes

**Test Steps**:
1. Connect to VPN on Wi-Fi
2. Turn off Wi-Fi (switch to cellular)
3. Observe VPN behavior

**Success Criteria**:
- [ ] VPN reconnects automatically
- [ ] Or shows reconnecting state
- [ ] Eventually re-establishes connection

---

## Phase 6: Error Handling

### 6.1 Invalid Config

**Test Steps**:
1. Import .ovpn with missing `remote`
2. Import .ovpn with missing `ca`
3. Import malformed file

**Success Criteria**:
- [ ] Error message shown
- [ ] Specific error described
- [ ] App doesn't crash
- [ ] Can retry import

### 6.2 Connection Errors

**Test Steps**:
1. Import config with unreachable server
2. Try to connect
3. Wait for timeout

**Success Criteria**:
- [ ] Connection fails gracefully
- [ ] Error message shown
- [ ] Can retry
- [ ] App doesn't crash

### 6.3 Permission Denied

**Test Steps**:
1. On first connection, deny VPN permission
2. Observe behavior

**Success Criteria**:
- [ ] Error shown
- [ ] Instructions to enable VPN in Settings
- [ ] Can retry after enabling

---

## Phase 7: Face ID Testing

### 7.1 Enable Face ID

**Test Steps**:
1. Go to Settings
2. Enable "Quick connect with Face ID"
3. Return to main screen
4. Tap Connect

**Success Criteria**:
- [ ] Face ID prompt appears
- [ ] Authenticate with Face ID
- [ ] Connection starts after auth
- [ ] Skip auth if disabled

### 7.2 Face ID Failure

**Test Steps**:
1. With Face ID enabled
2. Tap Connect
3. Fail Face ID (look away)

**Success Criteria**:
- [ ] Connection doesn't start
- [ ] Can retry
- [ ] Fallback to passcode option

---

## Phase 8: Configuration Management

### 8.1 Config Deletion

**Test Steps**:
1. With config imported
2. Go to Settings
3. Tap "Delete Configuration"
4. Confirm deletion

**Success Criteria**:
- [ ] Confirmation dialog shows
- [ ] Config deleted
- [ ] Returns to "No Config" state
- [ ] VPN disconnects if connected

### 8.2 Config Replacement

**Test Steps**:
1. Import first config
2. Import second config (different server)
3. Verify replacement

**Success Criteria**:
- [ ] New config replaces old
- [ ] New server shows
- [ ] Can connect to new server

---

## Phase 9: Performance Testing

### 9.1 Memory Usage

**Test Steps**:
1. Launch app
2. Monitor memory in Xcode Instruments
3. Connect to VPN
4. Use app for 30 minutes

**Success Criteria**:
- [ ] Memory usage < 100MB
- [ ] No memory leaks
- [ ] No significant growth over time

### 9.2 CPU Usage

**Test Steps**:
1. Monitor CPU during connection
2. Monitor while idle (connected)

**Success Criteria**:
- [ ] CPU < 5% while connected but idle
- [ ] CPU spike during connection is brief
- [ ] No excessive background activity

### 9.3 Battery Impact

**Test Steps**:
1. Connect to VPN
2. Use device normally for 4 hours
3. Check battery usage in Settings

**Success Criteria**:
- [ ] App not in top battery consumers
- [ ] Battery impact reasonable for VPN app

---

## Phase 10: XcodeBuild MCP Automated Testing

### 10.1 Automated UI Tests

```bash
# Run full UI test suite with XcodeBuild MCP
xcodebuild test \
  -workspace BarqNet.xcworkspace \
  -scheme BarqNet \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:BarqNetUITests \
  -resultBundlePath TestResults.xcresult
```

### 10.2 Test Coverage Report

```bash
# Generate code coverage
xcrun xccov view --report TestResults.xcresult

# Export coverage to JSON
xcrun xccov view --report --json TestResults.xcresult > coverage.json
```

**Success Criteria**:
- [ ] All UI tests pass
- [ ] Code coverage > 70%
- [ ] No flaky tests
- [ ] Test execution time < 5 minutes

---

## Testing Checklist Summary

### Pre-Flight
- [ ] Xcode project builds without errors
- [ ] CocoaPods dependencies installed
- [ ] Both targets configured correctly
- [ ] Provisioning profiles valid

### Functional Tests
- [ ] Config import works
- [ ] Config parsing validates correctly
- [ ] VPN connects successfully
- [ ] VPN disconnects cleanly
- [ ] Auto-reconnect works
- [ ] Background connection maintained

### UI Tests
- [ ] All views render correctly
- [ ] Animations smooth
- [ ] Navigation works
- [ ] Settings persist

### Error Handling
- [ ] Invalid config rejected
- [ ] Connection errors handled
- [ ] Permission errors handled
- [ ] Network errors handled

### Performance
- [ ] Memory usage acceptable
- [ ] CPU usage low
- [ ] Battery impact reasonable
- [ ] No crashes or hangs

### Security
- [ ] Face ID works
- [ ] Config stored securely
- [ ] No data leaks
- [ ] VPN traffic encrypted

---

## Known Issues

### Simulator Limitations
- ❌ Cannot test actual VPN connection in simulator
- ❌ NetworkExtension not fully functional
- ✅ Can test UI and config parsing

### Device Requirements
- ✅ Physical device required for full VPN testing
- ✅ Developer account needed for VPN entitlements
- ✅ TestFlight for beta distribution

---

## Test Results Template

```
Platform 2: iOS Testing Results
================================

Date: [DATE]
Tester: [NAME]
Device: [iPhone 15 Pro / iPad Pro / etc]
iOS Version: [17.0 / 16.5 / etc]

Build Verification: [PASS/FAIL]
Unit Tests: [PASS/FAIL] - [X/Y tests passed]
UI Tests (Simulator): [PASS/FAIL]
VPN Connection Tests: [PASS/FAIL]
Background Tests: [PASS/FAIL]
Error Handling: [PASS/FAIL]
Face ID Tests: [PASS/FAIL]
Performance Tests: [PASS/FAIL]
XcodeBuild MCP: [PASS/FAIL] - [X/Y tests passed]

Overall Status: [PASS/FAIL]
Ready for Production: [YES/NO]

Notes:
- [Any issues found]
- [Performance observations]
- [Recommendations]
```

---

## Next Steps After 100% Testing

1. ✅ All tests pass
2. ✅ No critical bugs
3. ✅ Performance acceptable
4. ✅ Ready for TestFlight beta
5. → Move to Platform 3 (Android)

---

**Testing Standard**: 100% of tests must pass before proceeding to next platform
**Quality Bar**: No crashes, no data loss, secure VPN connection
**User Experience**: Smooth, fast, reliable
