# iOS App Configuration Guide

## Overview

This directory contains environment-specific configuration files (`.xcconfig`) for managing different deployment environments. This is the **industry best practice** for iOS app configuration.

## Configuration Files

- **Development.xcconfig** - Local development (localhost)
- **Staging.xcconfig** - Testing with network servers
- **Production.xcconfig** - App Store release

## Setup Instructions

### 1. Add Configuration Files to Xcode

1. Open `WorkVPN.xcodeproj` in Xcode
2. In Project Navigator, right-click on the project root
3. Select **Add Files to "WorkVPN"...**
4. Navigate to the `Configuration` folder
5. Select all `.xcconfig` files
6. Check **"Copy items if needed"** and **"Create groups"**
7. Click **Add**

### 2. Configure Build Settings

1. In Xcode, select the **WorkVPN** project (blue icon at top)
2. Select the **WorkVPN** target
3. Go to the **Info** tab
4. Click on **Configurations** section
5. For each configuration:
   - **Debug**: Set to `Development.xcconfig`
   - **Release**: Set to `Production.xcconfig`

### 3. Create a Staging Scheme (Optional but Recommended)

1. In Xcode, go to **Product** → **Scheme** → **Manage Schemes...**
2. Click **+** to add a new scheme
3. Name it **"WorkVPN (Staging)"**
4. Set **Build Configuration** to **Release**
5. Close the scheme editor
6. In Project settings → Configurations:
   - Duplicate **Release** configuration
   - Rename it to **"Staging"**
   - Set Staging configuration to use `Staging.xcconfig`
7. Edit **WorkVPN (Staging)** scheme:
   - Set all steps (Run, Test, Archive) to use **Staging** configuration

### 4. Update Info.plist

Add these keys to your `Info.plist`:

```xml
<key>API_BASE_URL</key>
<string>$(API_BASE_URL)</string>
<key>ENVIRONMENT_NAME</key>
<string>$(ENVIRONMENT_NAME)</string>
<key>ENABLE_DEBUG_LOGGING</key>
<string>$(ENABLE_DEBUG_LOGGING)</string>
<key>ENABLE_CERTIFICATE_PINNING</key>
<string>$(ENABLE_CERTIFICATE_PINNING)</string>
<key>API_TIMEOUT_INTERVAL</key>
<string>$(API_TIMEOUT_INTERVAL)</string>
```

### 5. Update APIClient.swift

Replace the hardcoded baseURL initialization with:

```swift
private override init() {
    // Read API base URL from Info.plist (configured via xcconfig files)
    if let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
        self.baseURL = baseURL
    } else {
        // Fallback for safety
        self.baseURL = "http://127.0.0.1:8080"
        NSLog("[APIClient] WARNING: API_BASE_URL not found in Info.plist, using fallback")
    }

    // Read other configuration values
    let envName = Bundle.main.object(forInfoDictionaryKey: "ENVIRONMENT_NAME") as? String ?? "Unknown"
    let debugLoggingEnabled = Bundle.main.object(forInfoDictionaryKey: "ENABLE_DEBUG_LOGGING") as? String == "YES"
    let certPinningEnabled = Bundle.main.object(forInfoDictionaryKey: "ENABLE_CERTIFICATE_PINNING") as? String == "YES"

    NSLog("[APIClient] Environment: \(envName)")
    NSLog("[APIClient] Base URL: \(baseURL)")
    NSLog("[APIClient] Debug Logging: \(debugLoggingEnabled)")
    NSLog("[APIClient] Certificate Pinning: \(certPinningEnabled)")

    // Initialize certificate pinning based on environment
    self.certificatePinning = CertificatePinning()

    super.init()

    // Configure URLSession
    let configuration = URLSessionConfiguration.default
    if let timeoutString = Bundle.main.object(forInfoDictionaryKey: "API_TIMEOUT_INTERVAL") as? String,
       let timeout = TimeInterval(timeoutString) {
        configuration.timeoutIntervalForRequest = timeout
    }
    configuration.timeoutIntervalForResource = 60
    self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

    // Initialize certificate pins only if enabled
    if certPinningEnabled {
        initializeCertificatePins()
    }

    // Start token refresh timer if authenticated
    scheduleTokenRefresh()
}
```

## Usage

### Development (Local Backend)

1. Select **WorkVPN** scheme
2. Build configuration: **Debug**
3. Runs with `http://127.0.0.1:8080`

**Start local backend:**
```bash
cd ~/ChameleonVpn/barqnet-backend/apps/management
./start-local-management.sh
```

### Staging (Network Server)

1. Update `Staging.xcconfig` with your server IP:
   ```
   API_BASE_URL = http:/$()/YOUR_SERVER_IP:8080
   ```
2. Select **WorkVPN (Staging)** scheme
3. Build configuration: **Staging**
4. Runs with your configured server IP

### Production (App Store)

1. Select **WorkVPN** scheme
2. Build configuration: **Release**
3. Runs with `https://api.barqnet.com`
4. Certificate pinning enabled
5. Debug logging disabled

## Updating Server IP

### For Hamad's Testing

To test with a specific server:

1. Open `Configuration/Staging.xcconfig`
2. Update the IP address:
   ```
   API_BASE_URL = http:/$()/192.168.10.217:8080
   ```
3. In Xcode, select **WorkVPN (Staging)** scheme
4. Clean build folder (⌘+Shift+K)
5. Build and run (⌘+R)

**Note:** The `$(/)` in the xcconfig file is a workaround for Xcode's parsing of `//`. It gets replaced with `/` at build time.

## Environment Variables Reference

| Variable | Development | Staging | Production |
|----------|-------------|---------|------------|
| API_BASE_URL | http://127.0.0.1:8080 | http://192.168.10.217:8080 | https://api.barqnet.com |
| ENVIRONMENT_NAME | Development | Staging | Production |
| ENABLE_DEBUG_LOGGING | YES | YES | NO |
| ENABLE_CERTIFICATE_PINNING | NO | NO | YES |
| API_TIMEOUT_INTERVAL | 30 | 30 | 30 |

## Benefits of This Approach

✅ **No hardcoded values** - Easy to update server IPs
✅ **Environment separation** - Clear distinction between dev/staging/prod
✅ **Build schemes** - Switch environments with a dropdown
✅ **Version control friendly** - Config files track environment changes
✅ **Industry standard** - Follows iOS best practices
✅ **Easy testing** - Hamad can easily switch between environments
✅ **Production safe** - Production config clearly separated

## Troubleshooting

### Issue: App still using old URL

**Solution:**
1. Clean build folder (⌘+Shift+K)
2. Delete derived data: Xcode → Preferences → Locations → Derived Data → Click arrow → Delete folder
3. Rebuild

### Issue: Configuration not loading

**Solution:**
1. Verify `.xcconfig` files are added to project
2. Check Project Settings → Info → Configurations
3. Ensure correct configuration is selected for current scheme
4. Check Info.plist contains the configuration keys

### Issue: Cannot connect to server

**Solution:**
1. Check Xcode console for `[APIClient]` logs
2. Verify server IP in appropriate `.xcconfig` file
3. Test server connectivity: `curl http://SERVER_IP:8080/health`
4. Check firewall rules on server

## Testing Checklist

Before giving to Hamad for testing:

- [ ] All `.xcconfig` files added to Xcode project
- [ ] Info.plist updated with configuration keys
- [ ] APIClient.swift updated to read from Info.plist
- [ ] Clean build completed successfully
- [ ] Development scheme connects to localhost
- [ ] Staging scheme connects to network server
- [ ] Console logs show correct environment and URL
- [ ] App doesn't crash on launch
- [ ] Health check endpoint accessible from app

## Security Notes

- ⚠️ **Never commit production API keys** to `.xcconfig` files
- ⚠️ **Use environment variables or CI/CD secrets** for sensitive data
- ⚠️ **Enable certificate pinning** only for HTTPS in production
- ⚠️ **Staging environment** should use test credentials only

---

**Last Updated:** 2025-12-04
**Maintained By:** Development Team
