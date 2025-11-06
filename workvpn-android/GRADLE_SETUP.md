# Android Gradle Setup Guide

This guide helps you fix Gradle version compatibility issues.

---

## Quick Fix (Just Updated!)

The project has been updated to use compatible stable versions:

- **Gradle**: 8.2.1
- **Android Gradle Plugin (AGP)**: 8.2.1
- **Java Version**: 17
- **Kotlin**: 1.9.20

Pull the latest code and Android Studio should sync correctly.

---

## Requirements

### Java 17 Required

AGP 8.0+ requires Java 17 or higher.

**Check your Java version:**
```bash
java -version
```

**Install Java 17 if needed:**

**macOS:**
```bash
brew install openjdk@17
```

**Ubuntu/Linux:**
```bash
sudo apt install openjdk-17-jdk
```

**Windows:**
Download from: https://adoptium.net/

---

## Configure Android Studio to Use Wrapper

If you're still getting Gradle errors, make sure Android Studio uses the project's Gradle wrapper:

### Step 1: Open Gradle Settings

1. Open Android Studio
2. Go to: **File → Settings** (or **Android Studio → Preferences** on macOS)
3. Navigate to: **Build, Execution, Deployment → Build Tools → Gradle**

### Step 2: Select Gradle Wrapper

Under **Gradle**, set:
- **Use Gradle from**: `'gradle-wrapper.properties' file` ✅

**DO NOT** select:
- ❌ Specified location
- ❌ Gradle wrapper (this can use bundled Gradle)

### Step 3: Set Java Version

Under **Gradle JDK**, select:
- Java 17 or higher ✅

If Java 17 isn't listed:
1. Click "Download JDK"
2. Select version 17
3. Download and install

### Step 4: Sync Project

1. Click **Apply** and **OK**
2. Click **File → Sync Project with Gradle Files**
3. Wait for sync to complete

---

## Troubleshooting

### Error: "Unsupported class file major version 61"

**Cause:** Android Studio is using Java version older than 17

**Fix:**
1. Install Java 17 (see Requirements section above)
2. Set Gradle JDK to Java 17 in Android Studio settings
3. Restart Android Studio
4. Sync project

---

### Error: "NoSuchMethodError: DependencyHandler.module()"

**Cause:** AGP version incompatible with Gradle version

**Fix:** Already fixed! Just pull the latest code:
```bash
git pull origin main
```

Then sync in Android Studio.

---

### Error: "Could not find AGP 8.2.1"

**Cause:** Gradle can't download AGP

**Fix:**
1. Check your internet connection
2. Clear Gradle cache:
   ```bash
   cd workvpn-android
   ./gradlew clean --refresh-dependencies
   ```
3. Restart Android Studio
4. Sync project

---

### Error: "Gradle sync failed"

**Generic troubleshooting:**

1. **Clean and rebuild:**
   ```bash
   cd workvpn-android
   ./gradlew clean
   ```

2. **Invalidate caches in Android Studio:**
   - File → Invalidate Caches → Invalidate and Restart

3. **Delete Gradle cache:**
   ```bash
   rm -rf ~/.gradle/caches/
   ```

4. **Verify Java version:**
   ```bash
   java -version  # Should show 17 or higher
   ```

5. **Check Gradle wrapper:**
   ```bash
   cd workvpn-android
   ./gradlew --version
   # Should show: Gradle 8.2.1
   ```

---

## Version Compatibility Matrix

| Gradle | AGP | Java | Status |
|--------|-----|------|--------|
| 8.2.1 | 8.2.1 | 17+ | ✅ Current (stable) |
| 7.6 | 7.4.2 | 11+ | ⚠️ Old (was causing issues) |
| 9.0+ | 8.2.1 | 17+ | ⚠️ Too new (milestone) |

**Current Configuration:** Gradle 8.2.1 + AGP 8.2.1 + Java 17 = ✅ **Stable**

---

## Command Line Build

If Android Studio sync fails, try building from command line:

```bash
cd workvpn-android

# Clean build
./gradlew clean

# Build debug APK
./gradlew assembleDebug

# Install to connected device
./gradlew installDebug

# Run all checks
./gradlew check
```

If command line works but Android Studio doesn't, the issue is with IDE settings (see "Configure Android Studio" section above).

---

## Still Having Issues?

1. **Check Java version** - Must be 17+
2. **Check Gradle wrapper** - Should be 8.2.1
3. **Check Android Studio settings** - Use wrapper, not bundled Gradle
4. **Clean everything** - Invalidate caches, delete `.gradle` folder
5. **Restart** - Close Android Studio completely and reopen

If all else fails, try command line build to verify the project is valid.

---

**Last Updated:** November 6, 2025
**Gradle Version:** 8.2.1
**AGP Version:** 8.2.1
**Java Version:** 17
