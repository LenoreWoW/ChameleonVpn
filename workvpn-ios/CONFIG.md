# BarqNet iOS - Configuration Guide

This guide explains how to configure the BarqNet iOS application for development and production.

---

## Table of Contents

- [Xcode Configuration](#xcode-configuration)
- [Info.plist Settings](#infoplist-settings)
- [Build Settings](#build-settings)
- [Entitlements](#entitlements)
- [Signing & Provisioning](#signing--provisioning)
- [Build Configurations](#build-configurations)
- [Runtime Configuration](#runtime-configuration)

---

## Xcode Configuration

### Project Settings

**File**: `BarqNet.xcodeproj/project.pbxproj`

Key settings to configure:

1. **Bundle Identifier**:
   - Main app: `com.barqnet.ios` (or your own)
   - Tunnel extension: `com.barqnet.ios.TunnelExtension`

2. **Development Team**:
   - Select your Apple Developer team
   - Required for VPN entitlements

3. **Deployment Target**:
   - iOS 15.0 minimum
   - iOS 17.0 recommended

4. **Swift Version**:
   - Swift 5.7+

### Build Schemes

**BarqNet** scheme configurations:

- **Debug**: Development builds with logging
- **Release**: Production builds, optimized

---

## Info.plist Settings

### Main App Info.plist

**File**: `BarqNet/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Display Name -->
    <key>CFBundleDisplayName</key>
    <string>BarqNet</string>

    <!-- Bundle Version -->
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>

    <key>CFBundleVersion</key>
    <string>1</string>

    <!-- Face ID Usage -->
    <key>NSFaceIDUsageDescription</key>
    <string>Authenticate to connect to VPN quickly and securely</string>

    <!-- File Import -->
    <key>LSSupportsOpeningDocumentsInPlace</key>
    <true/>

    <key>UIFileSharingEnabled</key>
    <true/>

    <!-- .ovpn File Type -->
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>public.ovpn-file</string>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>ovpn</string>
                </array>
            </dict>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.plain-text</string>
            </array>
            <key>UTTypeDescription</key>
            <string>OpenVPN Configuration</string>
        </dict>
    </array>

    <!-- Document Types (for .ovpn import) -->
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>OpenVPN Configuration</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.ovpn-file</string>
            </array>
        </dict>
    </array>

    <!-- App Transport Security -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <!-- Allow insecure connections for development only -->
        <!-- REMOVE FOR PRODUCTION -->
        <!-- <key>NSAllowsArbitraryLoads</key>
        <false/> -->
    </dict>

    <!-- Background Modes -->
    <key>UIBackgroundModes</key>
    <array>
        <string>fetch</string>
        <string>processing</string>
    </array>
</dict>
</plist>
```

### Tunnel Extension Info.plist

**File**: `BarqNetTunnelExtension/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Bundle Version (must match main app) -->
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>

    <key>CFBundleVersion</key>
    <string>1</string>

    <!-- Network Extension Provider -->
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.networkextension.packet-tunnel</string>

        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).PacketTunnelProvider</string>
    </dict>

    <!-- Network Extension Provider Classes -->
    <key>NEProviderClasses</key>
    <dict>
        <key>com.apple.networkextension.packet-tunnel</key>
        <string>$(PRODUCT_MODULE_NAME).PacketTunnelProvider</string>
    </dict>
</dict>
</plist>
```

---

## Build Settings

### Custom Build Settings

Add these to your Xcode project:

1. **Open Xcode** → Select project → Build Settings tab

2. **Add User-Defined Settings**:

```
API_BASE_URL = https://your-vpn-backend.com/api
```

3. **Access in code**:

```swift
if let apiUrl = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
    print("API URL: \(apiUrl)")
}
```

### Configuration Files

Create separate configuration files for each environment:

**File**: `BarqNet/Config.xcconfig` (Debug)

```xcconfig
// Debug Configuration
API_BASE_URL = https://dev.your-vpn-backend.com/api
LOG_LEVEL = debug
ENABLE_ANALYTICS = false
SKIP_CERT_VALIDATION = false
```

**File**: `BarqNet/Config-Release.xcconfig` (Release)

```xcconfig
// Release Configuration
API_BASE_URL = https://your-vpn-backend.com/api
LOG_LEVEL = info
ENABLE_ANALYTICS = true
SKIP_CERT_VALIDATION = false
```

**Apply configuration**:
1. Project settings → Info tab
2. Under Configurations, select Config.xcconfig for Debug
3. Select Config-Release.xcconfig for Release

---

## Entitlements

### Main App Entitlements

**File**: `BarqNet/BarqNet.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Network Extension Capabilities -->
    <key>com.apple.developer.networking.networkextension</key>
    <array>
        <string>personal-vpn</string>
        <string>packet-tunnel-provider</string>
    </array>

    <!-- Keychain Access Groups -->
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.barqnet.ios</string>
    </array>

    <!-- App Groups (for data sharing with extension) -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.barqnet.ios</string>
    </array>
</dict>
</plist>
```

### Tunnel Extension Entitlements

**File**: `BarqNetTunnelExtension/BarqNetTunnelExtension.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Network Extension Capabilities -->
    <key>com.apple.developer.networking.networkextension</key>
    <array>
        <string>packet-tunnel-provider</string>
    </array>

    <!-- Keychain Access Groups (shared with main app) -->
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.barqnet.ios</string>
    </array>

    <!-- App Groups (shared with main app) -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.barqnet.ios</string>
    </array>
</dict>
</plist>
```

---

## Signing & Provisioning

### Development Signing

1. **Select target** (BarqNet or BarqNetTunnelExtension)
2. **Signing & Capabilities** tab
3. **Team**: Select your development team
4. **Automatically manage signing**: ✅ Enabled (recommended)

### Production Signing

For App Store distribution:

1. **Create App ID** in Apple Developer Portal:
   - Identifier: `com.barqnet.ios`
   - Capabilities: Personal VPN, Network Extensions

2. **Create App ID for Extension**:
   - Identifier: `com.barqnet.ios.TunnelExtension`
   - Capabilities: Network Extensions

3. **Create Provisioning Profiles**:
   - Distribution profile for main app
   - Distribution profile for extension

4. **Configure in Xcode**:
   - Signing & Capabilities → Provisioning Profile → Import profiles

### Code Signing Certificate

**Distribution Certificate** required for App Store:

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Certificates, Identifiers & Profiles
3. Create **iOS Distribution** certificate
4. Download and install in Keychain

---

## Build Configurations

### Debug Configuration

**Purpose**: Development and testing

**Settings**:
- Optimization: `-Onone` (no optimization)
- Debug Info: Full debug info
- Logging: Verbose
- Assertions: Enabled

**To use**:
```bash
xcodebuild -workspace BarqNet.xcworkspace \
           -scheme BarqNet \
           -configuration Debug
```

### Release Configuration

**Purpose**: App Store distribution

**Settings**:
- Optimization: `-O` (optimize for speed)
- Debug Info: Minimal (for crash reports)
- Logging: Error/Warning only
- Assertions: Disabled
- Bitcode: Enabled (if required)

**To use**:
```bash
xcodebuild -workspace BarqNet.xcworkspace \
           -scheme BarqNet \
           -configuration Release \
           archive
```

---

## Runtime Configuration

### AppConfig.swift

Create a configuration file for runtime settings:

**File**: `BarqNet/Config/AppConfig.swift`

```swift
import Foundation

struct AppConfig {
    // API Configuration
    static let apiBaseURL = "https://your-vpn-backend.com/api"
    static let apiTimeout: TimeInterval = 30.0

    // Feature Flags
    static let enableAnalytics = false
    static let enableCertificatePinning = true
    static let enableBiometricAuth = true

    // VPN Configuration
    static let defaultDNSServers = ["1.1.1.1", "8.8.8.8"]
    static let connectionTimeout: TimeInterval = 30.0
    static let reconnectAttempts = 5
    static let reconnectDelay: TimeInterval = 5.0

    // Security
    static let certificatePins = [
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
    ]

    // UI Configuration
    static let theme = "system" // light, dark, system
    static let showNotifications = true

    // Logging
    #if DEBUG
    static let logLevel: LogLevel = .debug
    #else
    static let logLevel: LogLevel = .info
    #endif

    enum LogLevel {
        case verbose, debug, info, warning, error
    }
}
```

### Environment-Specific Configuration

For different environments (dev, staging, production):

```swift
enum Environment {
    case development
    case staging
    case production

    static var current: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    var apiBaseURL: String {
        switch self {
        case .development:
            return "https://dev.your-vpn-backend.com/api"
        case .staging:
            return "https://staging.your-vpn-backend.com/api"
        case .production:
            return "https://your-vpn-backend.com/api"
        }
    }
}
```

---

## App Groups Configuration

For sharing data between main app and tunnel extension:

1. **Enable App Groups** in both targets:
   - BarqNet → Signing & Capabilities → + Capability → App Groups
   - BarqNetTunnelExtension → Same

2. **Add group identifier**: `group.com.barqnet.ios`

3. **Access shared data**:

```swift
let groupID = "group.com.barqnet.ios"

// Write to shared UserDefaults
if let userDefaults = UserDefaults(suiteName: groupID) {
    userDefaults.set("value", forKey: "key")
}

// Access shared container
if let containerURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: groupID
) {
    let fileURL = containerURL.appendingPathComponent("config.json")
    // Read/write files
}
```

---

## CI/CD Configuration

### GitHub Actions Secrets

Add these secrets in GitHub repository settings:

- `APPLE_TEAM_ID`: Your Apple Developer Team ID
- `MATCH_PASSWORD`: Password for match (if using fastlane)
- `APP_STORE_CONNECT_API_KEY`: API key for upload
- `CERTIFICATE_P12`: Base64-encoded certificate
- `CERTIFICATE_PASSWORD`: Certificate password

---

## Troubleshooting

### Common Issues

**Issue**: "Provisioning profile doesn't include network extensions"

**Solution**: Recreate provisioning profile with Network Extensions capability enabled

---

**Issue**: "Code signing failed"

**Solution**:
1. Check Team ID is correct
2. Verify certificate is installed
3. Try "Clean Build Folder" (Cmd+Shift+K)
4. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`

---

**Issue**: "Extension doesn't load"

**Solution**:
1. Verify bundle IDs are correct (extension must be `mainapp.TunnelExtension`)
2. Check entitlements match between app and extension
3. Ensure provisioning profiles are valid

---

## Additional Resources

- **Xcode**: [Apple Developer Documentation](https://developer.apple.com/documentation/xcode)
- **Network Extensions**: [NEPacketTunnelProvider](https://developer.apple.com/documentation/networkextension/nepackettunnelprovider)
- **App Groups**: [Sharing Data](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html)

---

**Last Updated**: 2025-10-15
**iOS Version**: 15.0+
**Xcode Version**: 15.0+
