# BarqNet Client Testing Guide

## Overview

This guide helps you test all three BarqNet client platforms: Desktop (Electron), iOS (Swift), and Android (Kotlin). It explains what can be tested at each stage and what dependencies are required.

---

## Quick Reference: What Can Be Tested Now?

| Component | Windows | macOS | Linux | iOS Device | Android Device |
|-----------|---------|-------|-------|------------|----------------|
| **Backend API** | ✅ Yes | ✅ Yes | ✅ Yes | N/A | N/A |
| **Desktop Client** | ✅ Yes | ✅ Yes | ✅ Yes | N/A | N/A |
| **iOS Client** | ❌ No | ✅ Yes (Xcode) | ❌ No | ✅ Yes | N/A |
| **Android Client** | ✅ Yes (Android Studio) | ✅ Yes (Android Studio) | ✅ Yes (Android Studio) | N/A | ✅ Yes |

---

## Testing Stages

### Stage 1: Backend API Only (No Clients)
**What to test:**
- Backend builds successfully
- Database connection works
- API endpoints respond
- Authentication flow works

**What's NOT tested:**
- Client UI/UX
- OpenVPN connection
- VPN functionality

### Stage 2: Backend + Desktop Client (Current Stage)
**What to test:**
- Desktop app launches
- Authentication UI works
- API communication works
- OTP flow (console bypass for now)

**What's NOT tested:**
- Actual VPN connection (requires VPN servers)
- iOS/Android clients

### Stage 3: Backend + All Clients
**What to test:**
- All three client platforms
- Cross-platform consistency
- Authentication on all platforms

**What's NOT tested:**
- Actual VPN connection (requires VPN servers)

### Stage 4: Full Production Testing
**What to test:**
- Everything including VPN connection
- End-to-end encrypted tunnel
- Multi-location VPN servers

---

## 1. Backend API Testing (Management Server)

### Prerequisites
- ✅ Go 1.21+ installed
- ✅ PostgreSQL 14+ installed
- ✅ Git installed

### Setup (Windows PowerShell)

#### Step 1: Build Backend
```powershell
cd ChameleonVpn\barqnet-backend

# Download dependencies
go mod download

# Build Management Server
go build -o management.exe .\apps\management
```

**Expected:** `management.exe` created with no errors

#### Step 2: Set Up Database
```powershell
# Start PostgreSQL (usually auto-starts)
Get-Service -Name postgresql*

# Create database
$env:PGPASSWORD = "postgres"
psql -U postgres -c "CREATE DATABASE barqnet;"
psql -U postgres -c "CREATE USER barqnet WITH PASSWORD 'barqnet123';"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE barqnet TO barqnet;"
```

**Expected:** Database created successfully

#### Step 3: Run Migrations
```powershell
cd migrations
$env:DATABASE_URL = "postgres://barqnet:barqnet123@localhost/barqnet?sslmode=disable"
go run run_migrations.go
```

**Expected Output:**
```
Connected to database successfully
Running migrations...
✓ Migration 002_add_phone_auth.sql
✓ Migration 003_add_statistics.sql
✓ Migration 004_add_locations.sql
All migrations completed successfully!
```

#### Step 4: Start Backend Server
```powershell
cd ..
$env:DATABASE_URL = "postgres://barqnet:barqnet123@localhost/barqnet?sslmode=disable"
$env:JWT_SECRET = "your-secret-key-change-in-production"
$env:PORT = "8080"
$env:ENABLE_OTP_CONSOLE = "true"

.\management.exe
```

**Expected Output:**
```
Starting BarqNet Management Server...
Database connected successfully
Server listening on :8080
```

#### Step 5: Test API (in new terminal)
```powershell
# Health check
curl http://localhost:8080/api/health

# Expected: {"status":"healthy","timestamp":1234567890}
```

**✅ If you see the health response, the backend is working!**

---

## 2. Desktop Client Testing (Electron)

### Prerequisites
- ✅ Node.js 18+ installed
- ✅ npm installed
- ✅ Backend API running (from Step 1)

### Setup (Any Platform)

#### Step 1: Install Dependencies
```bash
cd workvpn-desktop
npm install
```

#### Step 2: Verify Configuration
Check that `.env` or environment variables point to backend:
```bash
# Should be set to your backend URL
API_BASE_URL=http://localhost:8080
```

#### Step 3: Start Desktop App
```bash
npm start
```

**Expected:**
- Electron window opens
- Shows "BarqNet" branding
- Phone entry screen appears
- No connection errors in console

#### Step 4: Test Authentication Flow

1. **Enter phone number:**
   - Format: `+1234567890`
   - Click "Send Code"

2. **Check backend console for OTP:**
   - Backend will print OTP code to console
   - Example: `[OTP] Code for +1234567890: 123456`

3. **Enter OTP code:**
   - Type the 6-digit code
   - Should show registration screen

4. **Register/Login:**
   - Enter password
   - Should authenticate and show VPN screen

**✅ If authentication works, Desktop client + Backend integration is working!**

---

## 3. iOS Client Testing (Swift)

### Prerequisites
- ✅ macOS with Xcode 15+
- ✅ iOS device OR iOS Simulator
- ✅ Backend API running

### Setup (macOS Only)

#### Step 1: Install Dependencies
```bash
cd workvpn-ios
pod install
```

#### Step 2: Open in Xcode
```bash
open WorkVPN.xcworkspace
```

#### Step 3: Configure Backend URL
Edit `WorkVPN/Config/Config.swift`:
```swift
// Change to your backend URL
static let apiBaseURL = "http://YOUR-BACKEND-IP:8080"
```

**Note:** If testing on real device, use your computer's IP address, not `localhost`

#### Step 4: Build and Run
1. Select target device (Simulator or real device)
2. Click Run (⌘R)

**Expected:**
- App launches on device/simulator
- Shows "BarqNet" branding
- Phone entry screen appears

#### Step 5: Test Authentication
Same flow as Desktop:
1. Enter phone number
2. Get OTP from backend console
3. Enter OTP
4. Register/Login

**Known Limitation:**
- VPN connection requires real device (Simulator can't use VPN)
- Certificate pinning not implemented yet

**✅ If authentication works on iOS, iOS client + Backend integration is working!**

---

## 4. Android Client Testing (Kotlin)

### Prerequisites
- ✅ Android Studio installed
- ✅ Android device OR Android emulator
- ✅ Backend API running

### Setup (Any Platform)

#### Step 1: Open Project
```bash
cd workvpn-android
# Open in Android Studio
```

#### Step 2: Configure Backend URL
Edit `app/src/main/java/com/barqnet/android/network/ApiConfig.kt`:
```kotlin
// Change to your backend URL
const val BASE_URL = "http://YOUR-BACKEND-IP:8080"
```

**Note:**
- For emulator: Use `10.0.2.2` instead of `localhost`
- For real device: Use your computer's IP address

#### Step 3: Sync Gradle
```bash
./gradlew sync
```

#### Step 4: Build and Run
1. Select target device (Emulator or real device)
2. Click Run

**Expected:**
- App launches on device/emulator
- Shows "BarqNet" branding
- Phone entry screen appears

#### Step 5: Test Authentication
Same flow as Desktop and iOS:
1. Enter phone number
2. Get OTP from backend console
3. Enter OTP
4. Register/Login

**Known Limitation:**
- OpenVPN integration not complete yet
- Can test authentication but NOT VPN connection

**✅ If authentication works on Android, Android client + Backend integration is working!**

---

## What Can/Cannot Be Tested Right Now

### ✅ Can Test (Backend + Clients)

| Feature | Desktop | iOS | Android |
|---------|---------|-----|---------|
| **App Launch** | ✅ | ✅ | ✅ |
| **UI/Branding** | ✅ | ✅ | ✅ |
| **Phone Entry** | ✅ | ✅ | ✅ |
| **OTP Send** | ✅ | ✅ | ✅ |
| **OTP Verify** | ✅ | ✅ | ✅ |
| **Registration** | ✅ | ✅ | ✅ |
| **Login** | ✅ | ✅ | ✅ |
| **JWT Tokens** | ✅ | ✅ | ✅ |
| **API Communication** | ✅ | ✅ | ✅ |

### ❌ Cannot Test (Requires VPN Servers)

| Feature | Desktop | iOS | Android |
|---------|---------|-----|---------|
| **VPN Connection** | ❌ | ❌ | ❌ |
| **OpenVPN Tunnel** | ❌ | ❌ | ❌ |
| **Server Selection** | ❌ | ❌ | ❌ |
| **Traffic Encryption** | ❌ | ❌ | ❌ |
| **Disconnect/Reconnect** | ❌ | ❌ | ❌ |

**Reason:** VPN functionality requires:
1. End-Node VPN servers deployed on Linux
2. OpenVPN configured with certificates
3. Public IP addresses for VPN servers

---

## Current Testing Strategy

### What Your Colleague Should Test Now:

#### 1. Backend API (Windows)
- ✅ Build succeeds
- ✅ Database connection works
- ✅ Server starts without errors
- ✅ Health endpoint responds
- ✅ Authentication endpoints work

**Time:** 15-30 minutes

#### 2. Desktop Client (Windows/macOS/Linux)
- ✅ App launches
- ✅ Shows BarqNet branding
- ✅ Phone entry works
- ✅ OTP flow works (console bypass)
- ✅ Registration/login works

**Time:** 15-30 minutes

#### 3. iOS Client (macOS + Device/Simulator)
- ✅ App builds in Xcode
- ✅ Launches on simulator/device
- ✅ Shows BarqNet branding
- ✅ Authentication flow works

**Time:** 30-45 minutes

#### 4. Android Client (Any OS + Device/Emulator)
- ✅ App builds in Android Studio
- ✅ Launches on emulator/device
- ✅ Shows BarqNet branding
- ✅ Authentication flow works

**Time:** 30-45 minutes

**Total Testing Time:** 2-3 hours for all platforms

---

## Common Issues and Solutions

### Issue 1: Backend Won't Start

**Error:** `database connection failed`

**Solution:**
```powershell
# Check PostgreSQL is running
Get-Service -Name postgresql*

# If stopped
Start-Service postgresql-x64-14

# Verify database exists
psql -U postgres -c "\l" | grep barqnet
```

---

### Issue 2: Desktop Client Can't Connect to Backend

**Error:** `Network Error` or `Failed to connect`

**Solution:**
1. Verify backend is running:
   ```powershell
   curl http://localhost:8080/api/health
   ```

2. Check Desktop app environment:
   ```bash
   # Should point to running backend
   API_BASE_URL=http://localhost:8080
   ```

3. Check firewall (Windows):
   ```powershell
   # Allow port 8080
   New-NetFirewallRule -DisplayName "BarqNet API" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
   ```

---

### Issue 3: iOS App Can't Connect to Backend

**Error:** `Request failed` or `Connection refused`

**Solution:**
1. **Use correct IP address** (not localhost):
   ```bash
   # Find your computer's IP
   ipconfig getifaddr en0  # macOS
   ```

2. **Update iOS config:**
   ```swift
   // Use your computer's IP, not localhost
   static let apiBaseURL = "http://192.168.1.100:8080"
   ```

3. **iOS 17+ requires secure connections:**
   - Edit `Info.plist` to allow HTTP (for testing only)
   - Already configured in project

---

### Issue 4: Android App Can't Connect to Backend

**Error:** `java.net.ConnectException: Connection refused`

**Solution:**
1. **For Emulator**, use special IP:
   ```kotlin
   // 10.0.2.2 maps to host machine's localhost
   const val BASE_URL = "http://10.0.2.2:8080"
   ```

2. **For Real Device**, use computer's IP:
   ```kotlin
   const val BASE_URL = "http://192.168.1.100:8080"
   ```

3. **Check network permissions** (already in AndroidManifest.xml):
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```

---

### Issue 5: OTP Not Appearing

**Error:** OTP code doesn't show in backend console

**Solution:**
1. **Verify console bypass is enabled:**
   ```powershell
   $env:ENABLE_OTP_CONSOLE = "true"
   ```

2. **Check backend logs:**
   - Should see: `[OTP] Code for +1234567890: 123456`

3. **Phone number format:**
   - Must include country code: `+1234567890`
   - Not valid: `1234567890` (missing +)

---

## Testing Checklist

### Backend API
- [ ] Go build succeeds
- [ ] PostgreSQL connection works
- [ ] Migrations run successfully
- [ ] Management server starts
- [ ] Health endpoint responds
- [ ] Send OTP endpoint works
- [ ] Verify OTP endpoint works
- [ ] Register endpoint works
- [ ] Login endpoint works

### Desktop Client
- [ ] npm install succeeds
- [ ] npm start launches app
- [ ] BarqNet branding visible
- [ ] Phone entry UI works
- [ ] OTP verification UI works
- [ ] Registration UI works
- [ ] Login UI works
- [ ] JWT token stored
- [ ] No console errors

### iOS Client
- [ ] pod install succeeds
- [ ] Xcode build succeeds
- [ ] App launches on simulator
- [ ] App launches on device (optional)
- [ ] BarqNet branding visible
- [ ] Phone entry works
- [ ] OTP verification works
- [ ] Registration works
- [ ] Login works
- [ ] Keychain storage works

### Android Client
- [ ] Gradle sync succeeds
- [ ] Build succeeds
- [ ] App launches on emulator
- [ ] App launches on device (optional)
- [ ] BarqNet branding visible
- [ ] Phone entry works
- [ ] OTP verification works
- [ ] Registration works
- [ ] Login works
- [ ] SharedPreferences storage works

---

## Next Steps After Testing

### If All Tests Pass:
1. ✅ Backend API is production-ready
2. ✅ All client platforms are ready
3. ✅ Authentication flow works end-to-end
4. ⏭️ **Next:** Deploy VPN servers for actual VPN functionality

### If Tests Fail:
1. Note which platform fails
2. Capture error messages
3. Check corresponding section in this guide
4. Report specific error for debugging

---

## Production Deployment (After Testing)

### What's Needed for Full VPN Functionality:

1. **Ubuntu Server for Backend**
   - Management API
   - PostgreSQL database

2. **Ubuntu Servers for VPN (End-Nodes)**
   - OpenVPN configured
   - Certificates generated
   - Public IP addresses

3. **Update Client Configuration**
   - Point to production backend URL
   - Enable certificate pinning
   - Remove OTP bypass

4. **Production SMS/OTP Service**
   - Twilio or similar
   - Remove console OTP bypass

---

## Summary

**Current Status:**
- ✅ All code pushed to GitHub
- ✅ Backend builds on Windows
- ✅ All clients ready for testing
- ✅ Documentation complete

**What Can Be Tested Now:**
- ✅ Backend API (Management Server)
- ✅ Desktop client authentication
- ✅ iOS client authentication
- ✅ Android client authentication

**What Cannot Be Tested Yet:**
- ❌ Actual VPN connection (requires VPN servers on Linux)
- ❌ Production SMS/OTP (using console bypass)
- ❌ Certificate pinning (using development mode)

**Recommended Testing Order:**
1. Backend API first (30 min)
2. Desktop client second (30 min)
3. iOS client third (45 min)
4. Android client last (45 min)

**Total Time:** 2-3 hours for complete multi-platform testing

---

## Getting Help

If you encounter issues:

1. **Check logs:**
   - Backend: Console output where management.exe runs
   - Desktop: Dev console (Ctrl+Shift+I / Cmd+Option+I)
   - iOS: Xcode console
   - Android: Android Studio Logcat

2. **Verify versions:**
   ```bash
   go version      # Should be 1.21+
   node --version  # Should be 18+
   psql --version  # Should be 14+
   ```

3. **Check documentation:**
   - `WINDOWS_TESTING_GUIDE.md` - Windows-specific backend setup
   - `DEPLOYMENT_ARCHITECTURE.md` - Architecture overview
   - `barqnet-backend/README.md` - Backend documentation

4. **Common mistakes:**
   - Backend not running when testing clients
   - Using `localhost` from mobile devices (use IP address)
   - Firewall blocking port 8080
   - PostgreSQL not running
   - Wrong phone number format (missing +)

---

**Good luck with testing! 🚀**
