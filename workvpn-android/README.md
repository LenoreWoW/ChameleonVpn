# WorkVPN Android

Native Android VPN client with OpenVPN support built with Kotlin and Jetpack Compose.

## Features

- ✅ Import and parse `.ovpn` configuration files
- ✅ OpenVPN connection using ics-openvpn library
- ✅ Modern Material 3 UI with Jetpack Compose
- ✅ Real-time connection statistics (upload/download)
- ✅ Connection state management
- ✅ Persistent configuration storage (DataStore)
- ✅ Auto-connect on app launch
- ✅ Biometric authentication (fingerprint)
- ✅ Auto-start on device boot
- ✅ Foreground service with notifications

## Requirements

- Android Studio Hedgehog (2023.1.1) or later
- Android SDK 34
- Minimum Android version: 8.0 (API 26)
- Kotlin 1.9.20+
- Gradle 8.0+

## Project Structure

```
workvpn-android/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/workvpn/android/
│   │   │   │   ├── MainActivity.kt                  # Main entry point
│   │   │   │   ├── WorkVPNApplication.kt            # Application class
│   │   │   │   ├── model/
│   │   │   │   │   ├── VPNConfig.kt                 # VPN configuration model
│   │   │   │   │   ├── ConnectionState.kt           # Connection states
│   │   │   │   │   └── VPNStats.kt                  # Traffic statistics
│   │   │   │   ├── util/
│   │   │   │   │   └── OVPNParser.kt                # .ovpn file parser
│   │   │   │   ├── vpn/
│   │   │   │   │   └── OpenVPNService.kt            # VPN service
│   │   │   │   ├── viewmodel/
│   │   │   │   │   └── VPNViewModel.kt              # ViewModel
│   │   │   │   ├── repository/
│   │   │   │   │   └── VPNConfigRepository.kt       # Data persistence
│   │   │   │   ├── ui/
│   │   │   │   │   ├── theme/                       # Material 3 theme
│   │   │   │   │   ├── screens/                     # Compose screens
│   │   │   │   │   └── navigation/                  # Navigation
│   │   │   │   └── receiver/
│   │   │   │       └── BootReceiver.kt              # Boot receiver
│   │   │   ├── res/
│   │   │   │   ├── drawable/                        # Icons
│   │   │   │   ├── mipmap/                          # Launcher icons
│   │   │   │   ├── values/                          # Strings, themes, colors
│   │   │   │   └── xml/                             # Backup rules
│   │   │   └── AndroidManifest.xml
│   │   └── test/                                     # Unit tests
│   ├── build.gradle                                  # App dependencies
│   └── proguard-rules.pro
├── build.gradle                                      # Root build config
├── settings.gradle
└── gradle.properties

```

## Setup

### 1. Clone and Open Project

```bash
cd /Users/hassanalsahli/Desktop/ChameleonVpn/workvpn-android
```

Open the project in Android Studio:
- File → Open → Select `workvpn-android` folder

### 2. Sync Gradle

Android Studio will automatically detect and sync Gradle dependencies. If not:
- File → Sync Project with Gradle Files

### 3. Build Configuration

The app is configured with:
- **Namespace**: `com.workvpn.android`
- **Min SDK**: 26 (Android 8.0)
- **Target SDK**: 34 (Android 14)
- **Kotlin**: 1.9.20
- **Compose Compiler**: 1.5.4

### 4. Dependencies

Key dependencies (automatically managed by Gradle):

```gradle
// Jetpack Compose & Material 3
implementation 'androidx.compose.material3:material3'
implementation 'androidx.activity:activity-compose:1.8.1'

// OpenVPN - ics-openvpn
implementation 'com.github.schwabe:ics-openvpn:0.7.50'

// DataStore for persistence
implementation 'androidx.datastore:datastore-preferences:1.0.0'

// Biometric authentication
implementation 'androidx.biometric:biometric-ktx:1.2.0-alpha05'

// Coroutines
implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3'

// Kotlinx Serialization
implementation 'org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0'
```

## Building

### Debug Build

```bash
./gradlew assembleDebug
```

Output: `app/build/outputs/apk/debug/app-debug.apk`

### Release Build

```bash
./gradlew assembleRelease
```

Output: `app/build/outputs/apk/release/app-release-unsigned.apk`

### Build AAB (for Google Play)

```bash
./gradlew bundleRelease
```

Output: `app/build/outputs/bundle/release/app-release.aab`

## Installation

### Via ADB

```bash
adb install app/build/outputs/apk/debug/app-debug.apk
```

### Via Android Studio

1. Connect Android device or start emulator
2. Click Run (▶️) or press Shift+F10
3. Select target device

## Usage

### Import OpenVPN Configuration

1. Tap "Import .ovpn File" on home screen
2. Select your `.ovpn` configuration file
3. App will parse and validate the configuration
4. Configuration is encrypted and stored locally

### Connect to VPN

1. After importing, tap "Connect" button
2. Grant VPN permission when prompted
3. View connection status and statistics
4. Tap "Disconnect" to stop VPN

### Settings

Access settings via the gear icon:
- **Auto-connect on app launch**: Automatically connect when app starts
- **Use biometric authentication**: Quick connect with fingerprint

## Architecture

### MVVM Pattern

- **Model**: `VPNConfig`, `ConnectionState`, `VPNStats`
- **ViewModel**: `VPNViewModel` (state management)
- **View**: Jetpack Compose screens

### Data Flow

1. User imports `.ovpn` → `OVPNParser` parses file
2. Parsed config → `VPNConfigRepository` stores encrypted
3. User taps connect → `VPNViewModel` updates state
4. `OpenVPNService` starts VPN with ics-openvpn
5. Service updates state → UI reacts via StateFlow

### VPN Service

`OpenVPNService` extends Android `VpnService`:
- Runs as foreground service with notification
- Uses ics-openvpn library for OpenVPN protocol
- Monitors connection state and traffic statistics
- Broadcasts state changes to ViewModel

## Testing

See [TESTING.md](TESTING.md) for comprehensive testing guide.

### Run Unit Tests

```bash
./gradlew test
```

### Run Instrumented Tests

```bash
./gradlew connectedAndroidTest
```

## Troubleshooting

### Gradle Sync Issues

If Gradle sync fails:
1. File → Invalidate Caches → Invalidate and Restart
2. Delete `.gradle` folder and rebuild
3. Update Gradle wrapper: `./gradlew wrapper --gradle-version=8.0`

### ics-openvpn Build Errors

If ics-openvpn native library fails:
1. Ensure NDK is installed (Android Studio → SDK Manager → SDK Tools → NDK)
2. Add to `local.properties`:
   ```
   ndk.dir=/Users/[your-user]/Library/Android/sdk/ndk/[version]
   ```

### VPN Permission Denied

If VPN connection fails with permission error:
1. Uninstall app completely
2. Reinstall APK
3. Grant VPN permission when prompted
4. Check `AndroidManifest.xml` has `BIND_VPN_SERVICE`

### Biometric Authentication Not Working

If fingerprint auth fails:
1. Ensure device has biometric hardware
2. Check Settings → Security → Fingerprint is set up
3. Verify `AndroidManifest.xml` has `USE_BIOMETRIC` permission

## Code Signing (Release)

For production release builds:

1. Generate signing key:
```bash
keytool -genkey -v -keystore workvpn-release.keystore -alias workvpn -keyalg RSA -keysize 2048 -validity 10000
```

2. Add to `app/build.gradle`:
```gradle
android {
    signingConfigs {
        release {
            storeFile file('workvpn-release.keystore')
            storePassword 'your-password'
            keyAlias 'workvpn'
            keyPassword 'your-password'
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

3. Build signed APK:
```bash
./gradlew assembleRelease
```

## Security

- VPN configurations stored encrypted in DataStore
- No plaintext credentials in memory
- Biometric authentication for quick access
- VPN traffic excluded from backups (see `backup_rules.xml`)
- ProGuard/R8 code obfuscation in release builds

## License

See LICENSE file.

## Support

For issues and feature requests, visit the GitHub repository.
