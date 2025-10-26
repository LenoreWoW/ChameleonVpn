# BarqNet Desktop - Setup and Testing Guide

## Prerequisites

### 1. OpenVPN Installation

The application requires OpenVPN to be installed on your system.

#### macOS
```bash
# Using Homebrew
brew install openvpn

# Verify installation
which openvpn
# Should output: /usr/local/bin/openvpn or /opt/homebrew/bin/openvpn
```

#### Windows
1. Download OpenVPN from https://openvpn.net/community-downloads/
2. Install to default location: `C:\Program Files\OpenVPN\`
3. Run installer as Administrator

#### Linux (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install openvpn
```

### 2. Node.js and npm
- Node.js v16 or higher
- npm v8 or higher

## Installation

```bash
# Clone the repository
cd barqnet-desktop

# Install dependencies
npm install

# Build TypeScript
npm run build
```

## Running the Application

### Development Mode
```bash
npm start
```

This will:
1. Compile TypeScript files
2. Copy HTML/CSS assets
3. Start Electron in development mode

### Production Build

#### macOS (.dmg)
```bash
npm run make
```
Output: `out/make/` directory

#### Windows (.exe)
```bash
npm run make
```
Output: `out/make/` directory

## Testing Checklist

### Phase 1: Basic UI Testing (No VPN Connection)

- [ ] Application starts without errors
- [ ] Window appears with correct size (500x700)
- [ ] Title bar shows "BarqNet"
- [ ] "No VPN Configuration" state is displayed
- [ ] "Import .ovpn File" button is visible and clickable
- [ ] Settings section at bottom shows three checkboxes
- [ ] System tray icon appears (macOS menu bar / Windows system tray)
- [ ] System tray menu shows:
  - [ ] Connection status indicator
  - [ ] Connect/Disconnect option (disabled when no config)
  - [ ] Show Window
  - [ ] Import Config
  - [ ] Quit BarqNet

### Phase 2: Config Import Testing

**Preparation**: Create a test .ovpn file (see below for sample)

- [ ] Click "Import .ovpn File" button
- [ ] File dialog opens
- [ ] Select test .ovpn file
- [ ] Config is imported successfully
- [ ] UI switches from "No Config" to "VPN State" view
- [ ] Server address is displayed correctly
- [ ] Protocol and port are shown
- [ ] "Connect" button is enabled
- [ ] System tray "Connect" option is enabled

### Phase 3: VPN Connection Testing

**Prerequisites**:
- OpenVPN installed
- Valid .ovpn config with accessible VPN server
- Sufficient permissions (may require sudo/admin)

#### macOS Permission Setup
```bash
# Grant Electron permission to run OpenVPN
sudo chmod +x /usr/local/bin/openvpn
# OR
sudo chmod +x /opt/homebrew/bin/openvpn
```

#### Windows Permission Setup
- Run application as Administrator

#### Connection Tests
- [ ] Click "Connect" button
- [ ] UI switches to "Connecting..." state with loading spinner
- [ ] Connection establishes successfully
- [ ] UI switches to "Connected" state
- [ ] Status icon shows green (🟢)
- [ ] Status text shows "CONNECTED"
- [ ] Local IP is displayed
- [ ] Duration counter starts
- [ ] Traffic statistics update (Download/Upload)
- [ ] System tray shows "🟢 Connected"
- [ ] "Disconnect" button is visible

#### Disconnection Tests
- [ ] Click "Disconnect" button
- [ ] Connection terminates successfully
- [ ] UI switches to "Disconnected" state
- [ ] Status icon shows red (🔴)
- [ ] Duration resets
- [ ] Traffic statistics reset
- [ ] System tray shows "🔴 Disconnected"

#### Error Handling Tests
- [ ] Test with invalid .ovpn file → Error message displays
- [ ] Test with unreachable server → Connection timeout error shows
- [ ] Test disconnecting while connecting → Graceful cancellation
- [ ] Close window while connected → App minimizes to tray (stays connected)

### Phase 4: Settings Testing

- [ ] Enable "Auto-connect on startup" → Setting saves
- [ ] Restart app → Auto-connects if configured
- [ ] Enable "Launch at system startup" → Setting saves
- [ ] Enable "Kill switch" → Setting saves
- [ ] Disable each setting → Changes persist

### Phase 5: Config Management Testing

- [ ] Click "Delete Configuration" button
- [ ] Confirmation dialog appears
- [ ] Click "Cancel" → Config not deleted
- [ ] Click "Delete Configuration" again
- [ ] Click "OK" → Config deleted
- [ ] UI returns to "No Config" state
- [ ] Import new config → Works correctly

### Phase 6: System Integration Testing

#### macOS
- [ ] App appears in Applications folder (after .dmg install)
- [ ] Icon shows in Dock when running
- [ ] Icon shows in menu bar (system tray)
- [ ] Cmd+Q quits the application
- [ ] Red close button minimizes to tray
- [ ] Notifications work (if implemented)

#### Windows
- [ ] App installs to Program Files
- [ ] Icon shows in system tray
- [ ] Start menu shortcut works
- [ ] Desktop shortcut works (if created)
- [ ] Close button (X) minimizes to tray
- [ ] Right-click tray → Quit works

### Phase 7: Performance Testing

- [ ] Memory usage stays below 200MB
- [ ] CPU usage is minimal when idle
- [ ] Stats update every second without lag
- [ ] UI remains responsive during connection
- [ ] No memory leaks after multiple connect/disconnect cycles

## Sample Test .ovpn File

Create a file named `test-config.ovpn` for testing:

```ovpn
client
dev tun
proto udp
remote vpn.example.com 1194
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-CBC
auth SHA256
verb 3

<ca>
-----BEGIN CERTIFICATE-----
[Your CA Certificate Here]
-----END CERTIFICATE-----
</ca>

<cert>
-----BEGIN CERTIFICATE-----
[Your Client Certificate Here]
-----END CERTIFICATE-----
</cert>

<key>
-----BEGIN PRIVATE KEY-----
[Your Private Key Here]
-----END PRIVATE KEY-----
</key>
```

**Note**: Replace the certificate placeholders with actual certificates from your OpenVPN server.

## Common Issues and Solutions

### Issue: "OpenVPN binary not found"
**Solution**: Install OpenVPN using the instructions above

### Issue: "Permission denied" when connecting
**macOS Solution**:
```bash
sudo npm start
# OR grant permissions to openvpn binary
```

**Windows Solution**: Run app as Administrator

### Issue: App doesn't start
**Solution**:
1. Check console for errors: `npm start`
2. Verify all dependencies installed: `npm install`
3. Rebuild: `npm run build`

### Issue: Config import fails
**Solution**:
1. Verify .ovpn file is valid
2. Check file contains required fields: `remote`, `ca`
3. Ensure file is UTF-8 encoded

### Issue: Connection fails
**Solution**:
1. Verify OpenVPN server is accessible
2. Check firewall settings
3. Review OpenVPN logs in app console

## Debugging

### View Console Logs
Development mode automatically opens DevTools. Check:
- Main process logs: Terminal output
- Renderer process logs: DevTools console
- OpenVPN logs: Look for `[OpenVPN]` prefix

### Enable Verbose Logging
Edit `src/main/vpn/manager.ts`:
```typescript
this.process = spawn(openvpnBinary, [
  '--config', configPath,
  '--verb', '5'  // Change from 3 to 5 for verbose
]);
```

## Next Steps After macOS Testing

Once all tests pass on macOS at 100%:
1. Move to Windows testing
2. Build Windows installer
3. Test on Windows 10/11
4. Move to Platform 2 (iOS)

## Completion Criteria

**Platform 1 is considered 100% complete when**:
- ✅ All Phase 1-7 tests pass
- ✅ macOS .dmg builds successfully
- ✅ Windows .exe builds successfully
- ✅ Connection works on both platforms
- ✅ No critical bugs
- ✅ Performance meets requirements
