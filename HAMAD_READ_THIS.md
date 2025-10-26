# 🚀 HAMAD - START HERE

**Hey Hamad!** This guide will walk you through testing the complete BarqNet VPN application across all platforms.

---

## 📋 What You're Testing

You have **4 components** to test:

1. **Backend API** (Go) - The server that handles authentication
2. **Desktop Client** (Electron) - Windows/macOS/Linux app
3. **iOS Client** (Swift) - iPhone/iPad app
4. **Android Client** (Kotlin) - Android phones/tablets app

---

## ⚡ Quick Start Checklist

Before you start, make sure you have:

- [ ] Git installed
- [ ] Go 1.21+ installed (for backend)
- [ ] PostgreSQL 14+ installed (for backend)
- [ ] Node.js 18+ installed (for Desktop client)
- [ ] Xcode 15+ installed (for iOS client - macOS only)
- [ ] Android Studio installed (for Android client)

---

## 🎯 STEP 1: Get the Latest Code

```bash
# Clone the repository (if you haven't already)
git clone https://github.com/LenoreWoW/ChameleonVpn.git
cd ChameleonVpn

# Or pull latest changes (if you already have it)
git pull origin main
```

**✅ Expected:** Code downloads successfully

---

## 🗄️ STEP 2: Set Up Backend (Management API Server)

**This is the most important step!** All clients need the backend to work.

### On Windows (PowerShell):

#### 2.1: Install PostgreSQL (if not installed)
```powershell
# Install using winget
winget install PostgreSQL.PostgreSQL

# Verify installation
psql --version
```

#### 2.2: Create Database
```powershell
# Set password environment variable
$env:PGPASSWORD = "postgres"

# Create database and user
psql -U postgres -c "CREATE DATABASE barqnet;"
psql -U postgres -c "CREATE USER barqnet WITH PASSWORD 'barqnet123';"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE barqnet TO barqnet;"
```

**✅ Expected:** You see "CREATE DATABASE" and "GRANT" messages

#### 2.3: Install Go (if not installed)
```powershell
# Install using winget
winget install GoLang.Go

# Verify installation
go version
```

**✅ Expected:** Shows Go version 1.21 or higher

#### 2.4: Build the Backend
```powershell
# Navigate to backend folder
cd barqnet-backend

# Download dependencies
go mod download

# Build Management Server
go build -o management.exe .\apps\management
```

**✅ Expected:** File `management.exe` is created with no errors

#### 2.5: Run Database Migrations
```powershell
# Navigate to migrations folder
cd migrations

# Set database connection string
$env:DATABASE_URL = "postgres://barqnet:barqnet123@localhost/barqnet?sslmode=disable"

# Run migrations
go run run_migrations.go
```

**✅ Expected Output:**
```
Connected to database successfully
Running migrations...
✓ Migration 002_add_phone_auth.sql
✓ Migration 003_add_statistics.sql
✓ Migration 004_add_locations.sql
All migrations completed successfully!
```

#### 2.6: Start the Backend Server
```powershell
# Go back to backend folder
cd ..

# Set environment variables
$env:DATABASE_URL = "postgres://barqnet:barqnet123@localhost/barqnet?sslmode=disable"
$env:JWT_SECRET = "your-secret-key-change-in-production"
$env:PORT = "8080"
$env:ENABLE_OTP_CONSOLE = "true"

# Start the server
.\management.exe
```

**✅ Expected Output:**
```
Starting BarqNet Management Server...
Database connected successfully
Server listening on :8080
```

**🎉 KEEP THIS TERMINAL OPEN!** The server must keep running while you test the clients.

#### 2.7: Test the Backend (Open NEW Terminal)
```powershell
# Test health endpoint
curl http://localhost:8080/api/health
```

**✅ Expected Response:**
```json
{"status":"healthy","timestamp":1234567890}
```

**🎉 If you see this, your backend is working perfectly!**

---

### On macOS/Linux:

#### 2.1: Install PostgreSQL
```bash
# macOS
brew install postgresql@14
brew services start postgresql@14

# Linux (Ubuntu/Debian)
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
```

#### 2.2: Create Database
```bash
# Create database
sudo -u postgres psql -c "CREATE DATABASE barqnet;"
sudo -u postgres psql -c "CREATE USER barqnet WITH PASSWORD 'barqnet123';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE barqnet TO barqnet;"
```

#### 2.3: Build and Run Backend
```bash
cd barqnet-backend

# Download dependencies
go mod download

# Build
go build -o management ./apps/management

# Run migrations
cd migrations
export DATABASE_URL="postgres://barqnet:barqnet123@localhost/barqnet?sslmode=disable"
go run run_migrations.go
cd ..

# Start server
export DATABASE_URL="postgres://barqnet:barqnet123@localhost/barqnet?sslmode=disable"
export JWT_SECRET="your-secret-key-change-in-production"
export PORT="8080"
export ENABLE_OTP_CONSOLE="true"
./management
```

**✅ Expected:** Server listening on :8080

---

## 🖥️ STEP 3: Test Desktop Client (Electron)

**Make sure the backend is running first!**

### 3.1: Install Dependencies
```bash
# Navigate to Desktop client folder
cd workvpn-desktop

# Install Node.js dependencies
npm install
```

**✅ Expected:** Dependencies install successfully

### 3.2: Verify Configuration
The app should already be configured to use `http://localhost:8080` for development.

### 3.3: Start Desktop App
```bash
npm start
```

**✅ Expected:**
- Electron window opens
- You see "BarqNet" branding (not WorkVPN or ChameleonVPN)
- Phone entry screen appears
- No red errors in the console

### 3.4: Test Authentication Flow

#### A. Enter Phone Number
1. Enter a phone number with country code: `+1234567890`
2. Click "Send Code"

#### B. Get OTP from Backend Console
3. **Look at your backend terminal** (where management.exe is running)
4. You'll see something like:
   ```
   [OTP] Code for +1234567890: 123456
   ```
5. **Write down this 6-digit code**

#### C. Enter OTP
6. Type the 6-digit code in the app
7. Click "Verify"

#### D. Register
8. You'll see the registration screen
9. Enter a password (e.g., `SecurePass123!`)
10. Click "Register"

#### E. Success!
11. You should see the VPN dashboard
12. You'll see server locations
13. **Note:** VPN connection won't work yet (we need VPN servers for that)

**✅ Desktop Client Test PASSED if:**
- ✅ App shows BarqNet branding
- ✅ Phone entry works
- ✅ OTP appears in backend console
- ✅ Registration/login works
- ✅ You reach the VPN dashboard

---

## 📱 STEP 4: Test iOS Client (iPhone/iPad)

**Requirements:**
- macOS with Xcode 15+
- iOS device OR iOS Simulator
- Backend still running

### 4.1: Install Dependencies
```bash
# Navigate to iOS client folder
cd workvpn-ios

# Install CocoaPods dependencies
pod install
```

**✅ Expected:** Pods install successfully

### 4.2: Open in Xcode
```bash
open WorkVPN.xcworkspace
```

**⚠️ Important:** Open `.xcworkspace` NOT `.xcodeproj`

### 4.3: Configure Backend URL

**If testing on iOS Simulator:**
- You can use `localhost` - it's already configured

**If testing on a real iPhone/iPad:**
1. Find your computer's IP address:
   ```bash
   ipconfig getifaddr en0
   # Example output: 192.168.1.100
   ```

2. Edit `WorkVPN/Config/Config.swift`:
   ```swift
   // Change this line:
   static let apiBaseURL = "http://192.168.1.100:8080"
   // Replace with YOUR computer's IP
   ```

### 4.4: Build and Run
1. Select a target device (Simulator or your iPhone)
2. Click the ▶️ Run button (or press ⌘R)

**✅ Expected:**
- App builds successfully
- Launches on device/simulator
- Shows "BarqNet" branding
- Phone entry screen appears

### 4.5: Test Authentication
**Same flow as Desktop:**
1. Enter phone number: `+1234567890`
2. Check backend console for OTP code
3. Enter OTP in the app
4. Register with a password
5. Should reach VPN dashboard

**✅ iOS Client Test PASSED if:**
- ✅ App builds in Xcode
- ✅ Shows BarqNet branding
- ✅ Authentication flow works
- ✅ Reaches VPN dashboard

**⚠️ Known Limitation:** VPN connection only works on real devices (not simulator)

---

## 🤖 STEP 5: Test Android Client

**Requirements:**
- Android Studio installed
- Android device OR Android emulator
- Backend still running

### 5.1: Open Project
```bash
# Navigate to Android client folder
cd workvpn-android

# Open in Android Studio
# (Use File > Open in Android Studio and select this folder)
```

### 5.2: Configure Backend URL

**If testing on Android Emulator:**
1. Edit `app/src/main/java/com/barqnet/android/network/ApiConfig.kt`
2. Change:
   ```kotlin
   const val BASE_URL = "http://10.0.2.2:8080"
   ```
   **Note:** `10.0.2.2` is the special IP that emulator uses to reach your computer's localhost

**If testing on a real Android device:**
1. Find your computer's IP address:

   **Windows:**
   ```powershell
   ipconfig
   # Look for "IPv4 Address" (e.g., 192.168.1.100)
   ```

   **macOS/Linux:**
   ```bash
   ifconfig | grep "inet "
   # Look for your local IP (e.g., 192.168.1.100)
   ```

2. Edit `app/src/main/java/com/barqnet/android/network/ApiConfig.kt`:
   ```kotlin
   const val BASE_URL = "http://192.168.1.100:8080"
   // Replace with YOUR computer's IP
   ```

### 5.3: Sync Gradle
1. Click "Sync Now" in Android Studio
2. Or run:
   ```bash
   ./gradlew sync
   ```

**✅ Expected:** Gradle sync completes successfully

### 5.4: Build and Run
1. Select a target device (Emulator or your Android phone)
2. Click the ▶️ Run button

**✅ Expected:**
- App builds successfully
- Launches on device/emulator
- Shows "BarqNet" branding
- Phone entry screen appears

### 5.5: Test Authentication
**Same flow as Desktop and iOS:**
1. Enter phone number: `+1234567890`
2. Check backend console for OTP code
3. Enter OTP in the app
4. Register with a password
5. Should reach VPN dashboard

**✅ Android Client Test PASSED if:**
- ✅ App builds in Android Studio
- ✅ Shows BarqNet branding
- ✅ Authentication flow works
- ✅ Reaches VPN dashboard

**⚠️ Known Limitation:** OpenVPN integration not complete yet - VPN connection won't work

---

## 🎯 Testing Summary

### What You CAN Test Right Now:

| Feature | Backend | Desktop | iOS | Android |
|---------|---------|---------|-----|---------|
| App Launch | ✅ | ✅ | ✅ | ✅ |
| BarqNet Branding | N/A | ✅ | ✅ | ✅ |
| Phone Entry | ✅ | ✅ | ✅ | ✅ |
| Send OTP | ✅ | ✅ | ✅ | ✅ |
| Verify OTP | ✅ | ✅ | ✅ | ✅ |
| Registration | ✅ | ✅ | ✅ | ✅ |
| Login | ✅ | ✅ | ✅ | ✅ |
| View Dashboard | N/A | ✅ | ✅ | ✅ |

### What You CANNOT Test Yet:

| Feature | Why Not? |
|---------|----------|
| VPN Connection | Requires VPN servers deployed on Ubuntu Linux |
| Actual Traffic Encryption | Requires VPN servers with OpenVPN |
| Server Selection | Requires multiple VPN servers in different locations |
| Production SMS/OTP | Currently using console output for testing |

**This is expected!** We're testing the authentication layer first, then will deploy VPN servers later.

---

## 🐛 Common Issues and Solutions

### Issue 1: Backend Won't Start

**Error:** `pq: password authentication failed`

**Solution:**
```powershell
# Recreate database user
psql -U postgres -c "ALTER USER barqnet WITH PASSWORD 'barqnet123';"
```

---

### Issue 2: Backend Won't Start - Port Already in Use

**Error:** `bind: address already in use`

**Solution:**
```powershell
# Windows: Find what's using port 8080
netstat -ano | findstr :8080

# Kill the process (replace PID with the number you see)
taskkill /PID <PID> /F

# Then restart backend
.\management.exe
```

---

### Issue 3: Desktop Client Shows "Network Error"

**Error:** `Failed to connect to backend`

**Solution:**
1. **Verify backend is running:**
   ```powershell
   curl http://localhost:8080/api/health
   ```
   Should return: `{"status":"healthy",...}`

2. **Check Windows Firewall:**
   ```powershell
   # Allow port 8080
   New-NetFirewallRule -DisplayName "BarqNet API" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
   ```

---

### Issue 4: iOS App Can't Connect (Real Device)

**Error:** `Request failed` or `Connection refused`

**Solution:**
1. **Make sure you're using your computer's IP, not localhost**
   ```bash
   # Get your IP
   ipconfig getifaddr en0
   ```

2. **Update iOS config** in `WorkVPN/Config/Config.swift`:
   ```swift
   static let apiBaseURL = "http://YOUR-COMPUTER-IP:8080"
   ```

3. **Make sure iPhone and computer are on the same Wi-Fi network**

4. **Check firewall** allows incoming connections on port 8080

---

### Issue 5: Android Emulator Can't Connect

**Error:** `java.net.ConnectException: Connection refused`

**Solution:**
Use the special emulator IP:
```kotlin
// In ApiConfig.kt
const val BASE_URL = "http://10.0.2.2:8080"
```

**Not** `localhost` or `127.0.0.1` - emulator requires `10.0.2.2`

---

### Issue 6: No OTP Code Appearing

**Error:** OTP code doesn't show in backend console

**Solution:**
1. **Check environment variable is set:**
   ```powershell
   $env:ENABLE_OTP_CONSOLE = "true"
   ```

2. **Restart backend** after setting the variable

3. **Check phone number format:**
   - Must include country code with `+`: `+1234567890`
   - NOT valid: `1234567890` (missing +)

---

### Issue 7: Go Build Errors

**Error:** `package not found` or `import errors`

**Solution:**
```powershell
# Clean and rebuild
cd barqnet-backend
go clean
go mod tidy
go mod download
go build -o management.exe .\apps\management
```

---

### Issue 8: PostgreSQL Not Running

**Windows:**
```powershell
# Check service
Get-Service -Name postgresql*

# Start if stopped
Start-Service postgresql-x64-14
```

**macOS:**
```bash
brew services start postgresql@14
```

**Linux:**
```bash
sudo systemctl start postgresql
```

---

## 📊 Final Checklist

After completing all tests, you should have verified:

### Backend
- [ ] PostgreSQL installed and running
- [ ] Database created
- [ ] Migrations completed
- [ ] Management server starts
- [ ] Health endpoint responds
- [ ] OTP codes appear in console
- [ ] Registration creates users
- [ ] Login generates JWT tokens

### Desktop Client
- [ ] npm install succeeds
- [ ] App launches
- [ ] Shows "BarqNet" (not WorkVPN)
- [ ] Phone entry works
- [ ] OTP verification works
- [ ] Registration works
- [ ] Login works
- [ ] Dashboard appears

### iOS Client (if you have macOS)
- [ ] pod install succeeds
- [ ] Xcode build succeeds
- [ ] App launches on simulator/device
- [ ] Shows "BarqNet" (not WorkVPN)
- [ ] Phone entry works
- [ ] OTP verification works
- [ ] Registration works
- [ ] Login works
- [ ] Dashboard appears

### Android Client
- [ ] Gradle sync succeeds
- [ ] Build succeeds
- [ ] App launches on emulator/device
- [ ] Shows "BarqNet" (not WorkVPN)
- [ ] Phone entry works
- [ ] OTP verification works
- [ ] Registration works
- [ ] Login works
- [ ] Dashboard appears

---

## 🚀 What Happens Next?

### After You Complete Testing:

**If Everything Works:**
1. ✅ All authentication is working
2. ✅ All clients can communicate with backend
3. ✅ Database operations work
4. ✅ Ready for VPN server deployment

**Next Steps:**
1. Deploy backend to Ubuntu server
2. Set up VPN servers (End-Nodes) on Ubuntu
3. Configure OpenVPN with certificates
4. Update clients to use production backend URL
5. Enable production SMS/OTP (Twilio)
6. Test actual VPN connections

**If Something Doesn't Work:**
1. Check the "Common Issues" section above
2. Look at console/log output for errors
3. Verify all prerequisites are installed
4. Make sure backend is running before testing clients
5. Contact us with specific error messages

---

## 🆘 Getting Help

### Where to Find Logs:

**Backend:**
- Console output where `management.exe` is running
- Look for errors in red

**Desktop:**
- Press `Ctrl+Shift+I` (Windows/Linux) or `Cmd+Option+I` (macOS)
- Check "Console" tab for errors

**iOS:**
- In Xcode, open "Debug area" (bottom panel)
- Look for errors in red

**Android:**
- In Android Studio, open "Logcat" (bottom panel)
- Filter by your app name: `com.barqnet.android`

### What to Report:

When reporting issues, include:
1. Which component (Backend, Desktop, iOS, or Android)
2. Exact error message
3. What step you were on
4. Operating system (Windows 10/11, macOS version, etc.)
5. Screenshots if helpful

### Verify Versions:

```bash
# Go version (backend)
go version
# Should be: 1.21 or higher

# Node.js version (Desktop)
node --version
# Should be: 18.x or higher

# PostgreSQL version (backend)
psql --version
# Should be: 14.x or higher

# Xcode version (iOS - macOS only)
xcodebuild -version
# Should be: 15.x or higher
```

---

## 📚 Additional Documentation

If you need more details:

- **`CLIENT_TESTING_GUIDE.md`** - Comprehensive testing guide for all platforms
- **`WINDOWS_TESTING_GUIDE.md`** - Windows-specific backend setup details
- **`DEPLOYMENT_ARCHITECTURE.md`** - System architecture overview
- **`barqnet-backend/README.md`** - Backend documentation
- **`barqnet-backend/API_DOCUMENTATION.md`** - API reference

---

## 💡 Tips for Successful Testing

1. **Test in order:**
   - Backend first (most important)
   - Desktop second (easiest)
   - iOS third (requires macOS)
   - Android fourth (works on any OS)

2. **Keep backend running:**
   - Don't close the backend terminal
   - All clients need it running

3. **Use the same phone number:**
   - Makes testing easier
   - Example: `+1234567890`

4. **Watch backend console:**
   - OTP codes appear here
   - Error messages show here
   - Connection logs appear here

5. **One platform at a time:**
   - Don't try to test everything at once
   - Complete one platform fully before moving to next

6. **Take notes:**
   - Write down what works
   - Write down what doesn't work
   - Screenshot any errors

---

## ✅ Success Criteria

**Testing is successful when:**

1. ✅ Backend responds to health check
2. ✅ Desktop app authenticates successfully
3. ✅ iOS app authenticates successfully (if you have macOS)
4. ✅ Android app authenticates successfully
5. ✅ All apps show "BarqNet" branding (not old names)
6. ✅ OTP codes appear in backend console
7. ✅ Users can register and login
8. ✅ Dashboard appears after login

**It's OK if:**
- ❌ VPN connection doesn't work (expected - we need VPN servers)
- ❌ Server list is empty (expected - we need VPN servers)
- ⚠️ Certificate pinning warnings (expected in development mode)

---

## 🎉 You're Ready!

**Start with STEP 2** (Backend) and work through each step in order.

**Estimated Time:**
- Backend setup: 30-60 minutes (first time)
- Desktop testing: 30 minutes
- iOS testing: 45 minutes (if you have macOS)
- Android testing: 45 minutes

**Total: 2-3 hours** to test everything

Good luck! 🚀

---

**Questions?** Check the troubleshooting section or contact us with specific error messages.
