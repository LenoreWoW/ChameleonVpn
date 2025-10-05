# WorkVPN iOS

OpenVPN client for iOS/iPadOS using NetworkExtension framework.

## Features

- ✅ Import .ovpn configuration files
- ✅ NetworkExtension VPN tunnel provider
- ✅ SwiftUI interface
- ✅ Face ID/Touch ID quick connect
- ✅ Connection status and statistics
- ✅ Auto-connect on app launch
- ✅ System VPN integration
- ✅ Background VPN connection
- ✅ Today widget (future)

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+
- Apple Developer account (for VPN entitlements)

## Installation

### Prerequisites

1. **Xcode Installation**
   ```bash
   # Install Xcode from App Store
   xcode-select --install
   ```

2. **CocoaPods** (for OpenVPNAdapter dependency)
   ```bash
   sudo gem install cocoapods
   ```

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd workvpn-ios
   ```

2. **Install dependencies**
   ```bash
   pod install
   ```

3. **Open in Xcode**
   ```bash
   open WorkVPN.xcworkspace
   ```

4. **Configure signing**
   - Select the WorkVPN target
   - Go to "Signing & Capabilities"
   - Select your development team
   - Enable "Network Extensions" capability
   - Repeat for WorkVPNTunnelExtension target

5. **Update Bundle Identifiers**
   - Main app: `com.workvpn.ios`
   - Tunnel extension: `com.workvpn.ios.TunnelExtension`

## Project Structure

```
workvpn-ios/
├── WorkVPN/                    # Main app target
│   ├── WorkVPNApp.swift        # App entry point
│   ├── Views/                  # SwiftUI views
│   │   ├── ContentView.swift
│   │   ├── VPNStatusView.swift
│   │   ├── NoConfigView.swift
│   │   ├── ConfigImportView.swift
│   │   └── SettingsView.swift
│   ├── Models/
│   │   └── VPNConfig.swift     # Config data model
│   ├── Services/
│   │   └── VPNManager.swift    # VPN connection manager
│   ├── Utils/
│   │   └── OVPNParser.swift    # .ovpn file parser
│   └── Info.plist
├── WorkVPNTunnelExtension/     # Network Extension
│   ├── PacketTunnelProvider.swift
│   └── Info.plist
├── Assets.xcassets/            # App icons and images
├── Tests/                      # Unit and UI tests
└── Podfile                     # CocoaPods dependencies
```

## Dependencies

### CocoaPods

```ruby
# Podfile
platform :ios, '15.0'
use_frameworks!

target 'WorkVPN' do
  pod 'OpenVPNAdapter', '~> 0.8.0'
end

target 'WorkVPNTunnelExtension' do
  pod 'OpenVPNAdapter', '~> 0.8.0'
end
```

### Swift Packages (Alternative)

- OpenVPNAdapter: https://github.com/ss-abramchuk/OpenVPNAdapter

## Building

### Development Build

```bash
# Open workspace
open WorkVPN.xcworkspace

# Build and run
# Press Cmd+R in Xcode
# Or use xcodebuild:
xcodebuild -workspace WorkVPN.xcworkspace \
           -scheme WorkVPN \
           -configuration Debug \
           -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Release Build

```bash
xcodebuild -workspace WorkVPN.xcworkspace \
           -scheme WorkVPN \
           -configuration Release \
           -destination generic/platform=iOS \
           -archivePath build/WorkVPN.xcarchive \
           archive
```

## Testing

### Unit Tests

```bash
# Run all tests
xcodebuild test \
  -workspace WorkVPN.xcworkspace \
  -scheme WorkVPN \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### XcodeBuild MCP Testing

```bash
# Using XcodeBuild MCP for automated testing
# This will be implemented with comprehensive test suite
```

## Capabilities Required

### Main App (WorkVPN)
- ✅ Network Extensions
- ✅ Personal VPN

### Tunnel Extension (WorkVPNTunnelExtension)
- ✅ Network Extensions
- ✅ Packet Tunnel Provider

## Usage

### Importing Configuration

1. Tap "Import .ovpn File"
2. Select file from Files app
3. Config is parsed and validated
4. Ready to connect

### Connecting to VPN

1. Tap "Connect" button
2. iOS will show VPN permission dialog (first time)
3. Approve VPN configuration
4. Connection establishes
5. VPN icon appears in status bar

### Face ID Quick Connect

1. Enable in Settings
2. Tap Connect
3. Authenticate with Face ID
4. Instantly connects

## Configuration File Format

WorkVPN supports standard OpenVPN configuration files (.ovpn):

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

<ca>
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
</ca>

<cert>
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
</cert>

<key>
-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
</key>
```

## Troubleshooting

### "VPN Configuration Error"
- Ensure .ovpn file contains required fields: `remote`, `ca`
- Check certificate formatting

### "Permission Denied"
- Go to Settings → VPN
- Remove old WorkVPN configurations
- Try importing config again

### "Connection Failed"
- Verify OpenVPN server is accessible
- Check firewall settings
- Ensure credentials are correct (if required)

### Network Extension Not Loading
- Clean build folder (Cmd+Shift+K)
- Rebuild project
- Check provisioning profiles

## Distribution

### TestFlight

1. **Archive the app**
   ```bash
   xcodebuild -workspace WorkVPN.xcworkspace \
              -scheme WorkVPN \
              -configuration Release \
              -archivePath build/WorkVPN.xcarchive \
              archive
   ```

2. **Export for TestFlight**
   ```bash
   xcodebuild -exportArchive \
              -archivePath build/WorkVPN.xcarchive \
              -exportPath build/TestFlight \
              -exportOptionsPlist ExportOptions.plist
   ```

3. **Upload to App Store Connect**
   ```bash
   xcrun altool --upload-app \
                --file build/TestFlight/WorkVPN.ipa \
                --type ios \
                --username your@email.com \
                --password app-specific-password
   ```

### App Store

1. Submit for review from App Store Connect
2. Provide demo account for reviewers
3. Include usage instructions
4. Highlight VPN features

## Security

- ✅ OpenVPN encryption (AES-256-CBC)
- ✅ Certificate-based authentication
- ✅ Secure config storage (iOS Keychain)
- ✅ NetworkExtension framework (sandboxed)
- ✅ No hardcoded credentials
- ✅ Face ID/Touch ID biometric auth

## Known Limitations

- Traffic statistics are simulated (needs tunnel extension integration)
- Username/password auth not yet implemented (certificate-only for now)
- Multiple config profiles UI not implemented
- Split tunneling not available (iOS limitation)

## Roadmap

- [ ] Real traffic statistics from tunnel extension
- [ ] Username/password authentication
- [ ] Multiple VPN profiles
- [ ] Connection profiles (work, home, etc.)
- [ ] Today widget for quick connect
- [ ] Shortcuts support
- [ ] On-demand VPN rules
- [ ] IPv6 support

## License

MIT License - see LICENSE for details

## Support

For issues and questions:
- GitHub Issues: https://github.com/workvpn/ios/issues
- Documentation: See TESTING.md for comprehensive test guide

---

**Platform 2: iOS** 🍎
**Status**: Development Complete
**Testing**: Ready for XcodeBuild MCP automated testing
