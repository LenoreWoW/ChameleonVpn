# 📱 Client Build Instructions - Quick Start

**BarqNet/ChameleonVPN Client Applications**

This guide provides simple, step-by-step instructions for building all client applications (Android, iOS, Desktop).

---

## ⚡ Prerequisites

Before building any client, ensure you have:

- [ ] **Backend running** on `http://localhost:8080` (or your server URL)
- [ ] **Database configured** and migrations applied
- [ ] **.env file** properly configured in `barqnet-backend/`

---

## 🤖 Android Client

### Requirements
- **Java 17 or higher** (CRITICAL - build will fail with Java 8/11)
- Android SDK (via Android Studio)

### Java 17 Installation

**⚠️  IMPORTANT: Android Gradle Plugin 8.2.1 REQUIRES Java 17 or higher**

**Check Current Java Version:**
```bash
java -version

# ❌ If you see "1.8" or "11" - YOU MUST INSTALL JAVA 17
# ✅ If you see "17" or higher - You're good to go
```

**Install Java 17:**

**macOS (Homebrew):**
```bash
# Install Java 17
brew install openjdk@17

# Set JAVA_HOME for current session
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"

# Make permanent (add to your shell config)
echo 'export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home' >> ~/.zshrc
echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Verify installation
java -version
# Should show: openjdk version "17.x.x"
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install openjdk-17-jdk

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc
source ~/.bashrc

# Verify
java -version
```

**Windows:**
1. Download Java 17 from: https://adoptium.net/temurin/releases/
2. Install and set JAVA_HOME in System Environment Variables
3. Add `%JAVA_HOME%\bin` to PATH
4. Verify in CMD: `java -version`

### Build Steps

```bash
cd workvpn-android

# Clean previous builds
./gradlew clean

# Build debug APK (for testing)
./gradlew assembleDebug

# Build release APK (for production)
./gradlew assembleRelease
```

### Output Locations
- **Debug APK:** `app/build/outputs/apk/debug/app-debug.apk` (~21 MB)
- **Release APK:** `app/build/outputs/apk/release/app-release-unsigned.apk` (~7.9 MB)

### Installation

**On Emulator:**
```bash
adb install app/build/outputs/apk/debug/app-debug.apk
```

**On Physical Device:**
```bash
# Enable USB debugging on your device
adb devices  # Verify device is connected
adb install app/build/outputs/apk/debug/app-debug.apk
```

### Configuration

Before building for production, update the API URL:

**File:** `workvpn-android/app/src/main/java/com/workvpn/android/api/ApiService.kt`

```kotlin
// Line 28 - Update to your production API
private const val BASE_URL = "https://api.your-domain.com/"

// Lines 33-36 - Add your SSL certificate pins
private val CERTIFICATE_PINS = listOf(
    "sha256/YOUR_PRIMARY_PIN=",
    "sha256/YOUR_BACKUP_PIN="
)
```

---

## 🍎 iOS Client

### Requirements
- macOS with Xcode 14+
- CocoaPods (`sudo gem install cocoapods`)

### Build Steps

```bash
cd workvpn-ios

# Install dependencies
pod install

# Open the workspace (NOT .xcodeproj!)
open WorkVPN.xcworkspace
```

**In Xcode:**
1. Select a simulator (e.g., iPhone 15)
2. Product → Clean Build Folder (⌘⇧K)
3. Product → Build (⌘B)
4. Product → Run (⌘R) to launch

### Configuration

Before deploying to production, update the API URL:

**File:** `workvpn-ios/WorkVPN/Services/APIClient.swift`

```swift
// Line 164 - Update to your production API
self.baseURL = "https://api.your-domain.com"

// Line 168 - Add your SSL certificate pins
let pins = [
    "sha256/YOUR_PRIMARY_PIN=",
    "sha256/YOUR_BACKUP_PIN="
]
```

### Build for App Store

```bash
xcodebuild -scheme WorkVPN -archivePath build/WorkVPN.xcarchive archive
```

---

## 🖥️ Desktop Client (Electron)

### Requirements
- Node.js 18+ (`node --version`)
- npm (`npm --version`)

### Build Steps

```bash
cd workvpn-desktop

# Install dependencies
npm install

# Run in development mode
npm start

# Build for production
npm run build

# Create installers
npm run make
```

### Configuration

Before building for production, update the API URL:

**File:** `workvpn-desktop/src/main/auth/service.ts`

```typescript
// Update to your production API
this.apiBaseUrl = 'https://api.your-domain.com'
```

### Output Locations

After `npm run make`, installers will be in:
- **macOS:** `out/make/dmg/`
- **Windows:** `out/make/squirrel.windows/`
- **Linux:** `out/make/deb/` or `out/make/rpm/`

---

## 🔐 SSL Certificate Pinning

For production deployments, generate certificate pins for your API domain:

```bash
# Extract your SSL certificate's public key hash
openssl s_client -connect api.your-domain.com:443 < /dev/null 2>/dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  base64

# Result: sha256/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=
```

Add this hash to the certificate pins in each client application (see Configuration sections above).

---

## ✅ Quick Verification Checklist

### After Building Each Client:

**Android:**
- [ ] APK builds without errors
- [ ] App installs on device/emulator
- [ ] App opens without crashing
- [ ] Can connect to backend API
- [ ] VPN connection works

**iOS:**
- [ ] Xcode build succeeds
- [ ] App runs on simulator
- [ ] Can connect to backend API
- [ ] VPN configuration saves to Keychain
- [ ] VPN connection works

**Desktop:**
- [ ] Application opens
- [ ] Phone/email validation works
- [ ] Can authenticate with backend
- [ ] VPN connection works
- [ ] Credentials stored securely

---

## 🆘 Common Issues

### Android

**Issue:** `Build fails with Java version error`
```bash
# Install Java 17
brew install openjdk@17  # macOS
# OR
sudo apt install openjdk-17-jdk  # Linux

# Set JAVA_HOME
export JAVA_HOME=/path/to/java17
```

**Issue:** `compileSdk version error`
- Solution: Already fixed in latest code (compileSdk = 34)
- Run: `git pull origin main`

### iOS

**Issue:** `Missing AppIcon or AccentColor`
- Solution: Already fixed (Assets.xcassets created with defaults)
- Clean build folder and rebuild

**Issue:** `Protocol conformance error`
- Solution: Already fixed in latest code
- Run: `git pull origin main && pod install`

### Desktop

**Issue:** `npm install fails`
```bash
# Clear npm cache and retry
npm cache clean --force
rm -rf node_modules package-lock.json
npm install
```

---

## 🚀 Quick Build All Clients

If you want to build all clients at once:

```bash
# From project root
cd ChameleonVpn

# Android
(cd workvpn-android && ./gradlew clean assembleDebug assembleRelease)

# iOS (macOS only)
(cd workvpn-ios && pod install)
# Then open WorkVPN.xcworkspace and build in Xcode

# Desktop
(cd workvpn-desktop && npm install && npm run build)

echo "All clients built successfully!"
```

---

## 📚 Additional Resources

- **Comprehensive Guide:** See `HAMAD_READ_THIS.md` for detailed testing and deployment
- **Android Details:** `workvpn-android/ANDROID_IMPLEMENTATION_COMPLETE.md`
- **iOS Details:** `workvpn-ios/IOS_BACKEND_INTEGRATION.md`
- **Backend Setup:** `barqnet-backend/README.md`

---

## 🎯 Production Deployment Checklist

Before deploying to production:

- [ ] Update API URLs in all clients to production domain
- [ ] Generate and add SSL certificate pins
- [ ] Build release versions (not debug)
- [ ] Test on physical devices
- [ ] Verify VPN connections work end-to-end
- [ ] Test authentication flows
- [ ] Enable production environment variables
- [ ] Sign Android APK/AAB
- [ ] Submit iOS app for App Store review
- [ ] Distribute desktop installers

---

**Need Help?** See the troubleshooting section above or check `HAMAD_READ_THIS.md` for comprehensive testing instructions.
