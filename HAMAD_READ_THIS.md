# BarqNet - Testing Guide for Hamad

**Last Updated:** November 23, 2025
**Status:** Ready for Testing

---

## Quick Overview

BarqNet is a multi-platform VPN app (iOS, Android, Desktop) with a Go backend.

**What's Working:**
- ✅ Backend (Go) - Management Server
- ✅ iOS App - All build errors fixed
- ✅ Desktop App - Electron/TypeScript
- ✅ Android App - Kotlin/Jetpack Compose

**Your Job:** Test each platform and verify the authentication flow works.

---

## Prerequisites

Before testing ANY platform, you need:

### 1. PostgreSQL Running
```bash
# Check if running:
psql -U postgres -c "SELECT version();"

# If not running, start it:
# macOS: brew services start postgresql
# Linux: sudo systemctl start postgresql
```

### 2. Database Created
```bash
# Create database:
createdb -U postgres barqnet

# Verify:
psql -U postgres -l | grep barqnet
```

---

## Backend Setup (Required First!)

The backend must be running for ANY client app to work.

### Step 1: Navigate to Management Server
```bash
cd /Users/wolf/Desktop/ChameleonVpn/barqnet-backend/apps/management
```

### Step 2: Check .env File Exists
```bash
ls .env
```

If missing, copy from example:
```bash
cp .env.example .env
```

### Step 3: Start Backend
```bash
go run main.go
```

**Expected Output:**
```
[ENV] ✅ Loaded configuration from .env file
[DB] ✅ Connected to PostgreSQL successfully
[OTP] ✅ Resend email service initialized
[API] 🚀 Management API server starting on :8080
```

**If you see errors:**
- Database connection failed → Check PostgreSQL is running
- Environment variables missing → Check .env file exists
- Port 8080 in use → Kill existing process: `lsof -ti:8080 | xargs kill -9`

**Leave this terminal running!** Backend must stay running while testing.

---

## iOS Testing

### Quick Start (Automated)

```bash
cd /Users/wolf/Desktop/ChameleonVpn
./setup-ios.sh
```

The script will:
1. Install CocoaPods dependencies
2. Apply Xcode 16 fixes automatically
3. Open workspace in Xcode
4. Build and run on Simulator (if Xcode installed)

### Manual Steps (If Script Doesn't Work)

1. **Install Dependencies:**
   ```bash
   cd workvpn-ios
   pod install
   ```

2. **Open Workspace:**
   ```bash
   open WorkVPN.xcworkspace
   ```

3. **Build Settings in Xcode:**
   - Select "WorkVPN" scheme (top bar)
   - Select iPhone 15 Simulator (or any iPhone)
   - Press ⌘R to build and run

### What to Test

**Test 1: App Launches**
- App should show blue gradient background
- Floating email emoji 📧
- "Get Started" title
- Email input field

**Test 2: Create Account**
1. Enter email: `hamad@test.com`
2. Tap "CONTINUE"
3. Check backend terminal - you'll see OTP code:
   ```
   [OTP] DEBUG: Code for hamad@test.com = 123456
   ```
4. Enter the 6-digit code
5. Create password: `Test123!`
6. Confirm password: `Test123!`

**Test 3: Main Screen**
- You should see "No VPN Configuration" message
- This is NORMAL (VPN config not implemented yet)
- Tap settings gear icon (top right) - should open
- Tap logout icon (top left) - should return to login

**Test 4: Login**
1. Enter email: `hamad@test.com`
2. Enter password: `Test123!`
3. Should log in without OTP (password login)

**Success Criteria:**
- ✅ App doesn't crash
- ✅ All screens render correctly
- ✅ Can create account
- ✅ Can logout
- ✅ Can login with password

---

## Desktop Testing

### Quick Start

```bash
cd /Users/wolf/Desktop/ChameleonVpn/workvpn-desktop

# Install dependencies (first time only)
npm install

# Run app
npm start
```

### What to Test

**Same flow as iOS:**
1. Create account with email + OTP
2. Set password
3. See main screen
4. Test logout
5. Test login

**Desktop-Specific:**
- Window should be resizable
- Settings should be accessible (scroll if needed)
- All buttons should be visible

---

## Android Testing

### Quick Start

```bash
cd /Users/wolf/Desktop/ChameleonVpn/workvpn-android

# Build and run (requires Android Studio or connected device)
./gradlew installDebug

# Or open in Android Studio:
open -a "Android Studio" .
```

### Requirements
- Java 17+ installed
- Android SDK installed
- Android emulator or physical device

### What to Test

**Same authentication flow:**
1. Email entry → OTP → Password → Login
2. Verify all screens work
3. Test logout/login

---

## Testing Checklist

Copy this checklist and mark as you test:

```
BACKEND:
[ ] PostgreSQL running
[ ] Database created
[ ] Backend starts successfully on port 8080
[ ] See "Management API server starting" message

iOS:
[ ] App builds without errors
[ ] App launches and shows email screen
[ ] Can create account (email + OTP)
[ ] OTP code appears in backend logs
[ ] Can set password
[ ] See main VPN screen
[ ] Settings modal opens
[ ] Logout works
[ ] Login works (email + password)

DESKTOP:
[ ] npm install works
[ ] App launches
[ ] Same auth flow works
[ ] Window is resizable
[ ] All UI elements visible

ANDROID:
[ ] Gradle build succeeds
[ ] App installs on device/emulator
[ ] Same auth flow works
```

---

## Troubleshooting

### Backend Issues

**"Connection refused" or "Database error"**
```bash
# Start PostgreSQL
brew services start postgresql    # macOS
sudo systemctl start postgresql   # Linux

# Create database
createdb -U postgres barqnet
```

**"Port 8080 already in use"**
```bash
# Find and kill process on port 8080
lsof -ti:8080 | xargs kill -9

# Then restart backend
go run main.go
```

**"Environment variables missing"**
```bash
# Copy .env.example
cd barqnet-backend/apps/management
cp .env.example .env

# Edit if needed
nano .env
```

### iOS Issues

**"Cannot find 'EmailEntryView' in scope"**
- Fixed in latest commit (576b95c)
- Run: `pod install` again
- Clean build folder: Product → Clean Build Folder

**"Sandbox rsync error" on Simulator**
- Fixed in latest commit (7d7b58e)
- Run: `pod install` to apply fix
- The post_install hook patches this automatically

**Simulator warnings (AlertService, CA Event, preview-shell)**
- These are NORMAL
- Ignore them - they don't affect functionality
- Only appear in Simulator, not on real devices

### Desktop Issues

**"Cannot find module" errors**
```bash
rm -rf node_modules package-lock.json
npm install
```

**"App window too small"**
- Fixed in recent commits
- Window now resizable: 520x800px default
- Can resize to 480x600 (min) or 800x1200 (max)

### Android Issues

**"Java version" errors**
```bash
# Install Java 17
brew install openjdk@17    # macOS

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64  # Linux
```

**Build errors**
```bash
# Clean build
./gradlew clean

# Rebuild
./gradlew build
```

---

## Understanding the Backend Logs

When testing, you'll see these logs:

**OTP Code (IMPORTANT!):**
```
[OTP] DEBUG: Code for hamad@test.com = 123456
```
**Use this code** in the app when testing!

**Successful Login:**
```
[AUTH] Login attempt for hamad@test.com
[AUTH] ✅ Password verified
[JWT] ✅ Issued token for hamad@test.com
```

**Failed Login:**
```
[AUTH] ❌ Invalid credentials for hamad@test.com
```

**OTP Sent:**
```
[OTP] Sending OTP to hamad@test.com
[OTP] ✅ OTP sent successfully via Resend
```

---

## What Success Looks Like

### Backend
```
✅ Server starts on port 8080
✅ Database connects
✅ OTP service initializes
✅ Logs show API requests when you use the apps
```

### iOS/Desktop/Android (All Platforms)
```
✅ App launches without crashing
✅ Email entry screen appears
✅ Can enter email and get OTP
✅ Can verify OTP (check backend logs for code)
✅ Can create password
✅ Main screen appears (showing "No VPN Configuration" is OK!)
✅ Settings modal opens
✅ Logout returns to login screen
✅ Login works with email + password
```

---

## Quick Reference

### Start Backend
```bash
cd /Users/wolf/Desktop/ChameleonVpn/barqnet-backend/apps/management
go run main.go
```

### Start iOS
```bash
cd /Users/wolf/Desktop/ChameleonVpn
./setup-ios.sh
```

### Start Desktop
```bash
cd /Users/wolf/Desktop/ChameleonVpn/workvpn-desktop
npm start
```

### Start Android
```bash
cd /Users/wolf/Desktop/ChameleonVpn/workvpn-android
./gradlew installDebug
```

### Get OTP Code
```bash
# Look in backend terminal for:
[OTP] DEBUG: Code for <your-email> = 123456
```

---

## Common Test Credentials

Use these when testing:

**Email:** `hamad@test.com` (or any email)
**OTP:** Check backend logs for 6-digit code
**Password:** `Test123!` (or any password 8+ chars)

---

## What's NOT Implemented Yet

These features are planned but not done:

- ❌ VPN server configuration (shows "No VPN Configuration")
- ❌ Actual VPN connection (OpenVPN integration incomplete)
- ❌ Server location selection
- ❌ Connection statistics
- ❌ Real email OTP delivery (uses backend logs for now)

**This is OK!** Focus on testing the authentication flow.

---

## Need Help?

**iOS Build Errors:**
- Read: `workvpn-ios/README.md`
- All recent fixes documented there

**Backend Errors:**
- Read: `barqnet-backend/README.md`
- Check: `.env.example` for required variables

**Endnode (VPN Server) Questions:**
- Read: `barqnet-backend/apps/endnode/README.md`
- Note: Endnode doesn't need database credentials!

**General Architecture:**
- Management Server: Handles auth, users, database
- Endnode Server: Handles VPN traffic (API-only, no database)
- Clients: Desktop, iOS, Android apps

---

## Summary

1. **Start backend first** (always!)
2. **Test iOS** with automated script: `./setup-ios.sh`
3. **Test Desktop** with: `npm start`
4. **Test Android** with: `./gradlew installDebug`
5. **Check backend logs** for OTP codes
6. **Verify auth flow** works on all platforms

**Questions?** Check the detailed READMEs in each directory.

**Found bugs?** That's great! Document what doesn't work and we'll fix it.

**Everything working?** Amazing! BarqNet is ready for VPN feature implementation.

---

**Good luck testing! 🚀**
