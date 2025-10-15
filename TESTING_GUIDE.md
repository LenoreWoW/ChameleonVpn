# WorkVPN - Testing Guide for Backend Developer

**Version**: 1.0.0
**Last Updated**: 2025-10-15
**For**: Backend Developer (OpenVPN Server)

---

## 🎯 Quick Start (5 Minutes)

Your OpenVPN server + WorkVPN clients = Ready to test!

### What You Need
1. ✅ OpenVPN server running
2. ✅ `.ovpn` configuration file
3. ✅ One test device (Android phone recommended)

### Fastest Test
```bash
# 1. Build Android app
cd workvpn-android
./gradlew assembleDebug

# 2. Install on device
adb install app/build/outputs/apk/debug/app-debug.apk

# 3. Import your .ovpn file in app
# 4. Tap "Connect"
# 5. Done! ✅
```

---

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Generate .ovpn File](#generate-ovpn-file)
- [Android Testing](#android-testing)
- [iOS Testing](#ios-testing)
- [Desktop Testing](#desktop-testing)
- [Backend API Testing](#backend-api-testing)
- [Testing Checklist](#testing-checklist)
- [Troubleshooting](#troubleshooting)
- [Performance Expectations](#performance-expectations)

---

## Prerequisites

### Your OpenVPN Server

**Required**:
- ✅ OpenVPN server running (port 1194 UDP/TCP or custom)
- ✅ Server accessible from internet
- ✅ Certificate infrastructure (CA, server cert, client certs)

**Verify server is running**:
```bash
# Check OpenVPN service
sudo systemctl status openvpn@server

# Check port is open
sudo netstat -tulpn | grep 1194

# Test from external network
nc -zv your-server-ip 1194
```

### Test Devices

**At least one of**:
- Android device (API 26+ / Android 8.0+)
- iOS device (iOS 15.0+) + macOS with Xcode
- Desktop computer (macOS/Windows/Linux)

---

## Generate .ovpn File

### Method 1: Auto-Generate Script

**Create** `generate-test-client.sh` on your OpenVPN server:

```bash
#!/bin/bash
# Save as: generate-test-client.sh

CLIENT_NAME="workvpn-test"
SERVER_ADDRESS="your-server-ip-or-domain"  # CHANGE THIS
SERVER_PORT="1194"
PROTOCOL="udp"  # or tcp

cd /etc/openvpn/easy-rsa || exit

# Generate client certificate
./easyrsa build-client-full "$CLIENT_NAME" nopass

# Create .ovpn file
cat > "/tmp/${CLIENT_NAME}.ovpn" << EOF
client
dev tun
proto $PROTOCOL
remote $SERVER_ADDRESS $SERVER_PORT
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-GCM
auth SHA256
key-direction 1
verb 3
keepalive 10 120

<ca>
$(cat pki/ca.crt)
</ca>

<cert>
$(cat pki/issued/${CLIENT_NAME}.crt)
</cert>

<key>
$(cat pki/private/${CLIENT_NAME}.key)
</key>

<tls-auth>
$(cat ta.key)
</tls-auth>
EOF

echo "✅ Generated: /tmp/${CLIENT_NAME}.ovpn"
echo "📤 Download this file and import into WorkVPN apps"
```

**Run**:
```bash
chmod +x generate-test-client.sh
sudo ./generate-test-client.sh
```

**Download** `/tmp/workvpn-test.ovpn` to your test devices.

---

### Method 2: Manual Generation

**Step 1: Generate client certificate**
```bash
cd /etc/openvpn/easy-rsa
./easyrsa build-client-full workvpn-test nopass
```

**Step 2: Create .ovpn file**
```bash
cat > workvpn-test.ovpn << 'EOF'
client
dev tun
proto udp
remote YOUR_SERVER_IP_OR_DOMAIN 1194
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-GCM
auth SHA256
verb 3

<ca>
# Paste contents of pki/ca.crt here
</ca>

<cert>
# Paste contents of pki/issued/workvpn-test.crt here
</cert>

<key>
# Paste contents of pki/private/workvpn-test.key here
</key>
EOF
```

**Step 3: Fill in certificates**
- Replace `YOUR_SERVER_IP_OR_DOMAIN`
- Copy contents of certificates between the tags

---

## Android Testing

### Build & Install

**Prerequisites**:
```bash
# Install Android SDK and tools
# Enable USB debugging on device
```

**Build APK**:
```bash
cd workvpn-android

# Debug build (recommended for testing)
./gradlew assembleDebug

# Output: app/build/outputs/apk/debug/app-debug.apk
```

**Install on device**:
```bash
# Method 1: ADB
adb install app/build/outputs/apk/debug/app-debug.apk

# Method 2: Direct install
./gradlew installDebug

# Method 3: Manual
# Copy APK to device and install via file manager
```

---

### Test VPN Connection

**Step 1: Transfer .ovpn file to device**
```bash
# Via ADB
adb push workvpn-test.ovpn /sdcard/Download/

# Or: Email, Dropbox, Google Drive, etc.
```

**Step 2: Open WorkVPN app**

**Step 3: Import .ovpn file**
- Tap "Import .ovpn File" button
- Navigate to Downloads folder
- Select `workvpn-test.ovpn`
- App parses and validates configuration ✅

**Step 4: Connect to VPN**
- Tap "Connect" button
- Grant VPN permission (first time only)
- Status changes: DISCONNECTED → CONNECTING → CONNECTED
- Time: 3-10 seconds

**Step 5: Verify connection**
- ✅ VPN icon appears in Android status bar
- ✅ IP address changed (visit https://ifconfig.me)
- ✅ Traffic statistics updating (bytes in/out)
- ✅ Green "Connected" indicator in app

---

### Test OpenVPN vs WireGuard

**WorkVPN Android supports both protocols!**

**Test OpenVPN** (your server):
- Import `.ovpn` file → Connects to your OpenVPN server ✅

**Test WireGuard** (if you have WireGuard server):
- Import `.conf` file → Uses WireGuard protocol ✅
- Faster, lower latency than OpenVPN

---

### Android Test Checklist

- [ ] APK installs successfully
- [ ] App opens without crashes
- [ ] Import `.ovpn` file works
- [ ] Configuration parsed correctly
- [ ] Connect establishes in < 10 seconds
- [ ] VPN icon appears in status bar
- [ ] IP address changes to server IP
- [ ] Traffic statistics show real data (not zeros)
- [ ] Can browse websites while connected
- [ ] Disconnect works properly
- [ ] Reconnect works
- [ ] Auto-reconnect after network change (toggle WiFi/airplane mode)
- [ ] Kill switch blocks traffic when enabled (in settings)
- [ ] Connection survives app restart
- [ ] Fingerprint/biometric authentication works

---

## iOS Testing

### Prerequisites

**Required**:
- macOS with Xcode 15.0+
- Physical iOS device (iOS 15.0+)
- Apple Developer account (free tier OK)
- USB cable

**Install tools**:
```bash
# Install CocoaPods
sudo gem install cocoapods

# Verify Xcode
xcode-select --install
```

---

### Build & Install

**Step 1: Install dependencies**
```bash
cd workvpn-ios
pod install
```

**Step 2: Open in Xcode**
```bash
open WorkVPN.xcworkspace
```

**Step 3: Configure signing**
1. Select **WorkVPN** target
2. Go to **Signing & Capabilities** tab
3. Select your **Team** (Apple Developer account)
4. Change **Bundle Identifier** if needed: `com.yourname.workvpn`

**Step 4: Repeat for extension**
1. Select **WorkVPNTunnelExtension** target
2. Same signing configuration
3. Bundle ID: `com.yourname.workvpn.TunnelExtension`

**Step 5: Add VPN capabilities**
- **WorkVPN** target → Signing & Capabilities → + Capability
  - Add "Personal VPN"
  - Add "Network Extensions"
- **WorkVPNTunnelExtension** target → Same capabilities

**Step 6: Build & Run**
- Connect iOS device via USB
- Select device in Xcode
- Click Run (▶️) or press `Cmd + R`
- App installs and launches on device ✅

---

### Test VPN Connection

**Step 1: Transfer .ovpn file to iOS device**
- AirDrop from Mac
- Email to yourself
- Upload to iCloud Drive
- Save to Files app

**Step 2: Open WorkVPN app**

**Step 3: Import .ovpn file**
- Tap "Import .ovpn File"
- Use Files app to select `workvpn-test.ovpn`
- App parses configuration ✅

**Step 4: Connect to VPN**
- Tap "Connect" button
- **First time**: iOS shows VPN permission dialog
  - Tap "Allow"
  - Enter device passcode or use Face ID
- Status: DISCONNECTED → CONNECTING → CONNECTED
- Time: 3-10 seconds

**Step 5: Verify connection**
- ✅ VPN icon in iOS status bar (top right)
- ✅ Settings → General → VPN shows "Connected"
- ✅ IP address changed
- ✅ Traffic statistics updating in app

---

### iOS Test Checklist

- [ ] App builds successfully in Xcode
- [ ] App installs on physical device
- [ ] Import `.ovpn` file works
- [ ] VPN permission granted
- [ ] Connection establishes
- [ ] VPN icon appears in status bar
- [ ] Settings app shows WorkVPN as connected
- [ ] IP address changes
- [ ] Traffic statistics update
- [ ] Can browse internet
- [ ] Disconnect works
- [ ] Reconnect works
- [ ] Face ID/Touch ID authentication works
- [ ] Connection persists when app backgrounded
- [ ] Connection persists when device locked
- [ ] Auto-reconnect after network change

---

## Desktop Testing

### Prerequisites

**Install OpenVPN binary**:

**macOS**:
```bash
brew install openvpn

# Verify
which openvpn
# Should output: /usr/local/sbin/openvpn
```

**Windows**:
```powershell
choco install openvpn
```

**Linux**:
```bash
# Debian/Ubuntu
sudo apt update
sudo apt install openvpn

# RHEL/CentOS/Fedora
sudo yum install openvpn

# Verify
which openvpn
```

**Install Node.js 20+**:
```bash
# macOS
brew install node@20

# Windows
choco install nodejs-lts

# Linux
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

---

### Build & Run

**Step 1: Install dependencies**
```bash
cd workvpn-desktop
npm install
```

**Step 2: Run in development mode**
```bash
npm start
```

App opens in Electron window ✅

**Step 3: (Optional) Build production installer**
```bash
npm run build
npm run make

# Output:
# macOS: out/make/dmg/WorkVPN-1.0.0.dmg
# Windows: out/make/exe/WorkVPN-1.0.0.exe
# Linux: out/make/deb/workvpn_1.0.0_amd64.deb
```

---

### Test VPN Connection

**Step 1: Open app**
- Run `npm start` or open installed app

**Step 2: Import .ovpn file**
- Click "Import .ovpn File" button
- Select `workvpn-test.ovpn` from file browser
- Configuration loaded ✅

**Step 3: Connect to VPN**
- Click "Connect" button
- **First time**: Grant admin/sudo permission
  - macOS: Enter password
  - Windows: UAC prompt - click "Yes"
  - Linux: Enter sudo password
- Status: DISCONNECTED → CONNECTING → CONNECTED
- Time: 3-10 seconds

**Step 4: Verify connection**
- ✅ System tray icon shows "Connected"
- ✅ IP address changed (visit https://ifconfig.me)
- ✅ Traffic statistics updating in real-time
- ✅ OpenVPN process running (check Activity Monitor/Task Manager)

**Step 5: Check logs** (if issues)
- Help → View Logs
- Located at: `~/.workvpn/logs/workvpn.log`

---

### Desktop Test Checklist

- [ ] App builds and runs
- [ ] OpenVPN binary detected
- [ ] Import `.ovpn` file works
- [ ] Admin permission granted
- [ ] OpenVPN process spawns
- [ ] Management interface connects
- [ ] Connection establishes
- [ ] System tray shows status
- [ ] IP address changes
- [ ] Traffic statistics update (real data from management interface)
- [ ] Can browse internet
- [ ] Disconnect works
- [ ] Reconnect works
- [ ] Minimize to system tray works
- [ ] Auto-launch on startup works
- [ ] Connection survives sleep/wake

---

## Backend API Testing

**Optional**: If you implement the backend API endpoints

### API Endpoints

See [API_CONTRACT.md](API_CONTRACT.md) for full specification.

**Authentication**:
```
POST /api/auth/otp/send       - Send OTP to phone
POST /api/auth/otp/verify     - Verify OTP code
POST /api/auth/register       - Register new user
POST /api/auth/login          - Login with credentials
POST /api/auth/logout         - Logout
```

**VPN**:
```
GET  /api/vpn/config          - Download .ovpn file
GET  /api/vpn/servers         - List available servers
POST /api/vpn/status          - Client reports connection status
POST /api/vpn/stats           - Client reports traffic statistics
```

---

### Test Phone + OTP Flow

**Step 1: Configure API endpoint in app**

**Android**: Edit `local.properties`
```properties
api.endpoint=https://your-api-server.com/api
```

**iOS**: Edit `AppConfig.swift`
```swift
static let apiBaseURL = "https://your-api-server.com/api"
```

**Desktop**: Edit `.env`
```
API_BASE_URL=https://your-api-server.com/api
```

**Step 2: Test onboarding**
1. Open app (first time)
2. Enter phone number: `+1234567890`
3. Tap "Send Code"
4. App calls: `POST /api/auth/otp/send`
5. Backend sends SMS with OTP code
6. Enter OTP code in app
7. Tap "Verify"
8. App calls: `POST /api/auth/otp/verify`
9. Backend validates code
10. Success → User logged in ✅

**Step 3: Test VPN config download**
1. After login, app calls: `GET /api/vpn/config`
2. Backend returns `.ovpn` file content
3. App auto-imports configuration
4. User can now connect without manual import ✅

---

### Test Statistics Reporting

**When connected**, app periodically sends:

```bash
# POST /api/vpn/stats
{
  "user_id": "user123",
  "session_id": "session456",
  "bytes_in": 1048576,
  "bytes_out": 524288,
  "connected_duration": 600,
  "timestamp": "2025-10-15T10:30:00Z"
}
```

**Verify**:
- Check your backend logs
- Stats arrive every 30 seconds while connected
- Values match what app displays

---

## Testing Checklist

### Basic Functionality

**All Platforms**:
- [ ] App builds without errors
- [ ] App launches successfully
- [ ] Import `.ovpn` file works
- [ ] Configuration parsed correctly
- [ ] VPN connects in < 10 seconds
- [ ] Connection indicator shows "Connected"
- [ ] IP address changes to VPN server
- [ ] Can browse websites while connected
- [ ] Traffic statistics show real data
- [ ] Disconnect works properly
- [ ] Reconnect works

### Advanced Features

- [ ] Auto-reconnect after network change
- [ ] Connection survives app restart/backgrounding
- [ ] Kill switch blocks traffic (Android)
- [ ] Biometric authentication works (mobile)
- [ ] Multiple connect/disconnect cycles work
- [ ] Connection stable for 30+ minutes
- [ ] No memory leaks (check after 1 hour)
- [ ] No crashes or freezes

### Error Handling

- [ ] Invalid `.ovpn` file shows error
- [ ] Network unavailable shows error
- [ ] Server unreachable shows timeout
- [ ] Wrong credentials handled gracefully
- [ ] Connection retry works (exponential backoff)

### Performance

- [ ] Connection time: 3-10 seconds ✅
- [ ] Reconnection time: 5-8 seconds ✅
- [ ] Latency overhead: +5-20ms ✅
- [ ] Throughput: 90-95% of baseline ✅
- [ ] Memory usage acceptable ✅
- [ ] CPU usage < 5% when active ✅

---

## Troubleshooting

### OpenVPN Server Issues

**Problem**: "Connection timeout"

**Solution**:
```bash
# Check OpenVPN service running
sudo systemctl status openvpn@server

# Check firewall allows port
sudo ufw allow 1194/udp
sudo firewall-cmd --add-port=1194/udp --permanent

# Check OpenVPN logs
sudo tail -f /var/log/openvpn.log

# Verify server config
sudo openvpn --config /etc/openvpn/server.conf
```

---

**Problem**: "Certificate validation failed"

**Solution**:
```bash
# Check certificate validity
openssl x509 -in /etc/openvpn/easy-rsa/pki/ca.crt -noout -dates

# Regenerate client certificate if expired
cd /etc/openvpn/easy-rsa
./easyrsa revoke workvpn-test
./easyrsa build-client-full workvpn-test nopass
```

---

### Android Issues

**Problem**: "OpenVPN binary not found"

**Solution**: Not an issue - Android uses ics-openvpn library (built-in)

---

**Problem**: "VPN permission denied"

**Solution**:
```bash
# Uninstall completely
adb uninstall com.workvpn.android

# Reinstall
./gradlew installDebug

# Grant permission when prompted
```

---

**Problem**: "Battery optimization killing VPN"

**Solution**:
- Settings → Apps → WorkVPN → Battery
- Select "Unrestricted" or "Don't optimize"

---

### iOS Issues

**Problem**: "Code signing failed"

**Solution**:
- Xcode → Signing & Capabilities
- Select your Team
- Change Bundle ID to unique identifier
- Clean Build Folder (Cmd + Shift + K)

---

**Problem**: "VPN doesn't work in Simulator"

**Solution**: iOS Simulator doesn't support VPN. Use physical device.

---

### Desktop Issues

**Problem**: "OpenVPN binary not found"

**Solution**:
```bash
# macOS
brew install openvpn
export PATH="/usr/local/sbin:$PATH"

# Verify
which openvpn
```

---

**Problem**: "Permission denied spawning OpenVPN"

**Solution**:
- macOS/Linux: Run with sudo permission (app will prompt)
- Windows: Run as Administrator

---

**Problem**: "Management interface connection failed"

**Solution**: Check OpenVPN is running with management enabled:
```bash
ps aux | grep openvpn
# Should see: --management 127.0.0.1 7505
```

---

## Performance Expectations

### Connection Times

| Action | Expected Time |
|--------|--------------|
| Initial connection | 3-10 seconds |
| Reconnection | 5-8 seconds |
| Disconnect | 1-2 seconds |

### Network Performance

| Metric | Expected Value |
|--------|---------------|
| Latency overhead | +5-20ms |
| Throughput | 90-95% of baseline |
| Packet loss | < 1% |

### Resource Usage

| Platform | Memory | CPU (idle) | CPU (active) |
|----------|--------|-----------|-------------|
| Android | ~50 MB | < 1% | 2-5% |
| iOS | ~40 MB | < 1% | 2-5% |
| Desktop | ~120 MB | < 1% | 2-5% |

---

## Test Report Template

**After testing**, please provide feedback:

```markdown
## Test Report - WorkVPN

**Date**: 2025-10-15
**Tester**: Your Name
**OpenVPN Server**: Version X.X.X

### Platforms Tested
- [ ] Android (version: ___)
- [ ] iOS (version: ___)
- [ ] Desktop (OS: ___)

### Results
- Connection Success: ✅ / ❌
- Time to Connect: ___ seconds
- IP Changed: ✅ / ❌
- Traffic Stats: ✅ / ❌
- Stable Connection: ✅ / ❌

### Issues Found
1. Issue description
2. Steps to reproduce
3. Expected vs actual behavior

### Performance
- Latency: ___ ms
- Download Speed: ___ Mbps
- Upload Speed: ___ Mbps

### Overall Assessment
✅ Ready for production
⚠️ Minor issues found
❌ Major issues found

### Notes
Additional comments...
```

---

## Next Steps After Testing

### If Tests Pass ✅

1. **Production deployment**:
   - Use same `.ovpn` generation process
   - Distribute to real users
   - Monitor connection logs

2. **App Store submission**:
   - Android: Google Play Console
   - iOS: App Store Connect
   - Desktop: Direct download or auto-update

3. **Backend API** (optional):
   - Implement endpoints per API_CONTRACT.md
   - Enable phone + OTP onboarding
   - Track usage statistics

### If Issues Found ❌

1. **Report issues**:
   - Use test report template above
   - Include logs from app and server
   - Provide `.ovpn` file (sanitized)

2. **Debug together**:
   - Share screen if needed
   - Check server logs
   - Verify configuration

---

## Quick Reference

### Important Files

- `.ovpn` file: OpenVPN client configuration
- `API_CONTRACT.md`: Backend API specification
- `README.md`: Project overview
- `CONTRIBUTING.md`: Development guidelines

### Build Commands

```bash
# Android
cd workvpn-android && ./gradlew assembleDebug

# iOS
cd workvpn-ios && pod install && open WorkVPN.xcworkspace

# Desktop
cd workvpn-desktop && npm install && npm start
```

### Logs Locations

- **Android**: `adb logcat | grep WorkVPN`
- **iOS**: Xcode → Window → Devices → View Device Logs
- **Desktop**: `~/.workvpn/logs/workvpn.log`

---

## Support

**Questions?**
- Email: support@workvpn.com
- GitHub Issues: https://github.com/yourusername/workvpn/issues
- Documentation: See README.md

---

**Happy Testing! 🚀**

Your OpenVPN server + WorkVPN clients = Secure multi-platform VPN solution ✅

---

**Version**: 1.0.0
**Last Updated**: 2025-10-15
**Status**: Production-Ready
