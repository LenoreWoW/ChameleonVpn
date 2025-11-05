# 🚀 HAMAD - START HERE

**Hey Hamad!** This guide will walk you through testing and deploying the complete BarqNet VPN application.

---

## 📋 Two Paths: Testing vs Production

### Path 1: Testing on Windows (For Development)
- Test backend API on Windows
- Test all client apps (Desktop, iOS, Android)
- Use development features (OTP console bypass)
- **Follow STEP 2-5 below**

### Path 2: Production Deployment on Ubuntu (For Real Use)
- Deploy Management Server on Ubuntu
- Deploy VPN servers on Ubuntu (multiple locations)
- Production-ready with real SMS/OTP
- **See "PRODUCTION DEPLOYMENT" section at the end**

---

## 📋 What You're Testing (Development)

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

# Run migrations using psql (RECOMMENDED)
psql -U postgres -d barqnet -f 001_initial_schema.sql
psql -U postgres -d barqnet -f 002_add_phone_auth.sql
psql -U postgres -d barqnet -f 003_add_statistics.sql
psql -U postgres -d barqnet -f 004_add_locations.sql

# Verify all 4 migrations applied
psql -U postgres -d barqnet -c "SELECT version, applied_at FROM schema_migrations ORDER BY version;"
```

**✅ Expected Output:**
```
Connected to database successfully
Running migrations...
✓ Migration 001_initial_schema.sql
✓ Migration 002_add_phone_auth.sql
✓ Migration 003_add_statistics.sql
✓ Migration 004_add_locations.sql
All migrations completed successfully!
```

#### 2.6: Start the Backend Server
```powershell
# Go back to backend folder
cd ..

# Set environment variables for database connection
$env:DB_USER = "postgres"
$env:DB_PASSWORD = "postgres"
$env:DB_NAME = "barqnet"
$env:DB_HOST = "localhost"
$env:DB_SSLMODE = "disable"

# Set environment variables for backend
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
sudo -u postgres psql -d barqnet -f 001_initial_schema.sql
sudo -u postgres psql -d barqnet -f 002_add_phone_auth.sql
sudo -u postgres psql -d barqnet -f 003_add_statistics.sql
sudo -u postgres psql -d barqnet -f 004_add_locations.sql

# Verify migrations
sudo -u postgres psql -d barqnet -c "SELECT version, applied_at FROM schema_migrations ORDER BY version;"
cd ..

# Set environment variables for database connection
export DB_USER="postgres"
export DB_PASSWORD="postgres"
export DB_NAME="barqnet"
export DB_HOST="localhost"
export DB_SSLMODE="disable"

# Set environment variables for backend
export JWT_SECRET="your-secret-key-change-in-production"
export PORT="8080"
export ENABLE_OTP_CONSOLE="true"

# Start server
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

**⚠️ IMPORTANT: READ THIS FIRST!**

**DO NOT RENAME ANY FOLDERS!** Keep all folder names as `WorkVPN`. The app will show "BarqNet" branding automatically in the UI. If you rename `WorkVPN` → `BarqNet`, Xcode will fail with color errors. See Issue 9 if this happens.

**Requirements:**
- macOS with Xcode 15+
- iOS device OR iOS Simulator
- Backend still running

### 4.0: VERIFY NO BarqNet FOLDER EXISTS (DO THIS FIRST!)

**🚨 CRITICAL: Check for BarqNet folder BEFORE building!**

```bash
# Navigate to iOS folder
cd ~/Desktop/ChameleonVpn/workvpn-ios

# Check if BarqNet folder exists (it SHOULD NOT!)
ls -la | grep BarqNet

# If you see "BarqNet" in the output, STOP and run this fix:
rm -rf BarqNet BarqNet.xcodeproj BarqNet.xcworkspace
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Verify only correct folders exist:
ls -la

# You should ONLY see these folders:
# - WorkVPN
# - WorkVPNTunnelExtension
# - Pods
# - WorkVPN.xcworkspace
# - WorkVPN.xcodeproj

# If you see BarqNet, delete the iOS folder and get a fresh copy:
cd ~/Desktop/ChameleonVpn
rm -rf workvpn-ios
git checkout workvpn-ios
cd workvpn-ios
```

**✅ Expected:** No BarqNet folder exists, only WorkVPN folders

**If you had to fix the BarqNet folder issue, see Issue 9 for complete cleanup steps.**

---

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

### Issue 9: iOS Build Errors - Color Not Found ⚠️ MOST COMMON ISSUE

**Error:** `Type 'Color' has no member 'cyanBlue'` or similar color errors

**Cause:** You created or renamed a folder to `BarqNet` inside `workvpn-ios/`, breaking Xcode file references

**🚨 CRITICAL: THIS IS THE MOST COMMON MISTAKE!**

If you see these errors:
```
Type 'Color?' has no member 'cyanBlue'
Type 'Color' has no member 'grayLight'
Type 'Color' has no member 'darkBgSecondary'
```

**Or if you see error paths like:**
```
/Users/wolf/Desktop/ChameleonVpn/workvpn-ios/BarqNet/BarqNet/Views/VPNStatusView.swift
```

**The BarqNet folder shouldn't exist! Stop and follow the fix below exactly.**

**Step 1: Verify the Problem**

```bash
# Check if you have a BarqNet folder (you shouldn't!)
ls -la ~/Desktop/ChameleonVpn/workvpn-ios/ | grep BarqNet

# If you see "BarqNet" in the output, you have this issue
# The only folders should be: WorkVPN, WorkVPNTunnelExtension, Pods
```

**Step 2: Complete Fix**

```bash
# 1. Navigate to iOS folder
cd ~/Desktop/ChameleonVpn/workvpn-ios

# 2. Delete BarqNet folder and any BarqNet Xcode files
rm -rf BarqNet
rm -rf BarqNet.xcodeproj
rm -rf BarqNet.xcworkspace

# 3. Delete the iOS folder completely to get a clean state
cd ~/Desktop/ChameleonVpn
rm -rf workvpn-ios

# 4. Get fresh copy from GitHub
git checkout workvpn-ios

# 5. Clean DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 6. Install dependencies
cd workvpn-ios
pod deintegrate
pod install

# 7. Open the CORRECT workspace
open WorkVPN.xcworkspace
```

**Step 3: In Xcode**

1. Build the **WorkVPN** target (NOT BarqNet)
2. The app will show **"BarqNet"** branding in the UI automatically
3. All folder names stay as **WorkVPN** in the code

**⚠️ WHAT NOT TO DO:**
- ❌ DO NOT rename `WorkVPN` folder to `BarqNet`
- ❌ DO NOT create a `BarqNet` folder
- ❌ DO NOT use Xcode's "Rename Project" feature
- ❌ DO NOT open `WorkVPN.xcodeproj` (use `.xcworkspace` instead)

**✅ WHAT TO DO:**
- ✅ Keep all folder names as `WorkVPN` (internal code structure)
- ✅ Always open `WorkVPN.xcworkspace` (with CocoaPods)
- ✅ Build and run the `WorkVPN` target
- ✅ The app displays "BarqNet" automatically in the UI - no renaming needed!

---

### Issue 10: iOS Xcode Duplicate File Errors

**Error:** `Multiple commands produce Info.plist` or `PacketTunnelProvider.stringsdata`

**Cause:** Stale DerivedData from previous builds

**Solution:**

```bash
# Clean DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# In Xcode
# 1. Product > Clean Build Folder (Cmd+Shift+K)
# 2. Restart Xcode
# 3. Build again (Cmd+B)
```

---

### Issue 11: Backend Migration Errors - Missing Tables

**Error:** `pq: relation "users" does not exist` or `column "display_order" does not exist`

**Cause:** Database migrations not run, or run in wrong order

**Solution - Fresh Database Setup:**

```bash
# Windows PowerShell
$env:PGPASSWORD = "postgres"

# 1. Drop and recreate database
dropdb -U postgres barqnet
createdb -U postgres barqnet

# 2. Run ALL migrations in order (CRITICAL!)
cd barqnet-backend/migrations
psql -U postgres -d barqnet -f 001_initial_schema.sql
psql -U postgres -d barqnet -f 002_add_phone_auth.sql
psql -U postgres -d barqnet -f 003_add_statistics.sql
psql -U postgres -d barqnet -f 004_add_locations.sql

# 3. Verify all migrations applied
psql -U postgres -d barqnet -c "SELECT version, applied_at FROM schema_migrations ORDER BY version;"

# Expected: 4 rows showing all migrations
```

**macOS/Linux:**

```bash
# 1. Drop and recreate database
sudo -u postgres dropdb barqnet
sudo -u postgres createdb barqnet

# 2. Run ALL migrations in order
cd barqnet-backend/migrations
sudo -u postgres psql -d barqnet -f 001_initial_schema.sql
sudo -u postgres psql -d barqnet -f 002_add_phone_auth.sql
sudo -u postgres psql -d barqnet -f 003_add_statistics.sql
sudo -u postgres psql -d barqnet -f 004_add_locations.sql

# 3. Verify
sudo -u postgres psql -d barqnet -c "SELECT version, applied_at FROM schema_migrations ORDER BY version;"
```

**What the 4 SQL files do:**
- `001_initial_schema.sql` - Base tables (users, servers, audit_logs)
- `002_add_phone_auth.sql` - Phone authentication & OTP
- `003_add_statistics.sql` - VPN connection statistics
- `004_add_locations.sql` - Geographic server locations

**⚠️ MUST run in order:** 001 → 002 → 003 → 004

---

### Issue 12: SQL Migration Files - Where Are They?

**Question:** "Where are the SQL files? I only see some migrations."

**Answer:**

All **4 SQL migration files** are in: `barqnet-backend/migrations/`

```bash
# List migrations
ls -la barqnet-backend/migrations/*.sql

# You should see:
# 001_initial_schema.sql      ← BASE (MUST RUN FIRST!)
# 002_add_phone_auth.sql      ← Phone auth
# 003_add_statistics.sql      ← Statistics
# 004_add_locations.sql       ← Locations
```

**Full documentation:** See `barqnet-backend/migrations/QUICKSTART.md`

**Quick verification:**

```bash
# Count SQL files (should be 4)
ls barqnet-backend/migrations/*.sql | wc -l
```

---

### Issue 13: PostgreSQL IMMUTABLE Function Error

**Error:** `ERROR: functions in index predicate must be marked IMMUTABLE` during migration 002

**Cause:** Migration 002 had CURRENT_TIMESTAMP in an index WHERE clause (line 102)

**Solution:**

This is already fixed in the latest code! Just pull the update:

```bash
# Pull latest fixes
cd ~/ChameleonVpn
git pull origin main

# Then re-run the migration
# (See Issue 11 for fresh database setup)
```

**What was fixed:**
- Removed `CURRENT_TIMESTAMP` from index predicate
- Index now only filters on `verified = false`
- Still efficient, but PostgreSQL-compliant

**Fixed in commit:** `05ddb4e`

---

### Issue 14: Migrations Don't Show in schema_migrations Table

**Error:** Only 1 row shows when checking schema_migrations, but all 4 migrations ran successfully

**Cause:** Migrations 002, 003, 004 were missing INSERT statements to record themselves

**How to verify the issue:**

```bash
# Check how many migrations are tracked
sudo -u postgres psql -d barqnet -c "SELECT version FROM schema_migrations ORDER BY version;"

# If you only see 001_initial_schema, you have this issue
```

**Solution - Already Fixed in Latest Code:**

The migrations are now fixed, but if you already ran them, just add the missing records manually:

```bash
# Pull latest fixes
cd ~/ChameleonVpn
git pull origin main

# Add missing migration records (safe - uses ON CONFLICT DO NOTHING)
sudo -u postgres psql -d barqnet <<EOF
INSERT INTO schema_migrations (version) VALUES ('002_add_phone_auth') ON CONFLICT (version) DO NOTHING;
INSERT INTO schema_migrations (version) VALUES ('003_add_statistics') ON CONFLICT (version) DO NOTHING;
INSERT INTO schema_migrations (version) VALUES ('004_add_locations') ON CONFLICT (version) DO NOTHING;
EOF

# Verify all 4 migrations are now tracked
sudo -u postgres psql -d barqnet -c "SELECT version, applied_at FROM schema_migrations ORDER BY version;"
```

**Expected output:**
```
      version       |         applied_at
--------------------+----------------------------
 001_initial_schema | 2025-10-28 08:24:01.049605
 002_add_phone_auth | 2025-10-28 08:30:xx.xxxxxx
 003_add_statistics | 2025-10-28 08:30:xx.xxxxxx
 004_add_locations  | 2025-10-28 08:30:xx.xxxxxx
(4 rows)
```

**Why this matters:**
- Tracks which migrations have been applied
- Prevents accidentally re-running migrations
- Standard database migration best practice

**Fixed in commit:** `5fac6d5`

---

### Issue 15: Backend Database Connection Error - Wrong User

**Error:** `pq: password authentication failed for user "vpnmanager"`

**Cause:** Backend expects database user "vpnmanager" and database "vpnmanager" by default, but migrations created database "barqnet"

**How to check default configuration:**

The backend uses these defaults if environment variables are not set:
- Database: `vpnmanager` (not `barqnet`)
- User: `vpnmanager` (not `postgres`)
- Password: (empty - must be set)

**Solution - Set Environment Variables (RECOMMENDED):**

```bash
# Set environment variables to match your database
export DB_USER="postgres"
export DB_PASSWORD="your_postgres_password"
export DB_NAME="barqnet"
export DB_HOST="localhost"
export DB_SSLMODE="disable"

# Run backend WITHOUT sudo (backend doesn't need root)
cd ~/ChameleonVpn/barqnet-backend
./management
```

**⚠️ CRITICAL: DO NOT USE sudo**

```bash
# ❌ WRONG - This will NOT work:
sudo ./management

# Why? sudo creates a new shell and doesn't preserve environment variables!
```

**If you MUST use sudo (not recommended):**

```bash
# Option 1: Use sudo -E to preserve environment
sudo -E ./management

# Option 2: Set variables inline with sudo
sudo DB_USER="postgres" DB_PASSWORD="postgres" DB_NAME="barqnet" DB_HOST="localhost" DB_SSLMODE="disable" ./management
```

**For persistent configuration (Ubuntu/Linux):**

```bash
# Create environment file
sudo mkdir -p /etc/barqnet
sudo nano /etc/barqnet/management.env

# Add these lines:
export DB_USER="postgres"
export DB_PASSWORD="your_postgres_password"
export DB_NAME="barqnet"
export DB_HOST="localhost"
export DB_SSLMODE="disable"
export JWT_SECRET="change-this-in-production"
export PORT="8080"

# Save and exit (Ctrl+X, Y, Enter)

# Load environment and run
source /etc/barqnet/management.env
cd ~/ChameleonVpn/barqnet-backend
./management
```

**Alternative - Create vpnmanager database:**

If you prefer to match the backend's defaults:

```bash
# Create vpnmanager database and user
sudo -u postgres psql <<EOF
CREATE DATABASE vpnmanager;
CREATE USER vpnmanager WITH PASSWORD 'vpnmanager123';
GRANT ALL PRIVILEGES ON DATABASE vpnmanager TO vpnmanager;
\c vpnmanager
GRANT ALL PRIVILEGES ON SCHEMA public TO vpnmanager;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO vpnmanager;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO vpnmanager;
EOF

# Run migrations on vpnmanager database
cd ~/ChameleonVpn/barqnet-backend/migrations
sudo -u postgres psql -d vpnmanager -f 001_initial_schema.sql
sudo -u postgres psql -d vpnmanager -f 002_add_phone_auth.sql
sudo -u postgres psql -d vpnmanager -f 003_add_statistics.sql
sudo -u postgres psql -d vpnmanager -f 004_add_locations.sql

# Set password and run
export DB_PASSWORD="vpnmanager123"
cd ~/ChameleonVpn/barqnet-backend
./management
```

**Expected output when successful:**

```
Management server started with ID: management-server
API server running on port 8080
Database: localhost:5432/barqnet
```

**Test the backend:**

```bash
# In a new terminal
curl http://localhost:8080/api/health

# Expected response:
{"status":"healthy","timestamp":1234567890}
```

**Windows (PowerShell):**

```powershell
# Set environment variables
$env:DB_USER = "postgres"
$env:DB_PASSWORD = "postgres"
$env:DB_NAME = "barqnet"
$env:DB_HOST = "localhost"
$env:DB_SSLMODE = "disable"

# Run backend
cd barqnet-backend
.\management.exe
```

---

### Issue 16: Backend Still Shows "vpnmanager" Error After Setting Variables

**Error:** `pq: password authentication failed for user "vpnmanager"` even after setting environment variables

**Cause:** Using `sudo` to run the backend, which creates a new shell session without your environment variables

**How to identify:**

```bash
# You set variables like this:
export DB_USER="postgres"
export DB_PASSWORD="postgres"
export DB_NAME="barqnet"

# But then ran:
sudo ./management  # ❌ WRONG!
```

**Solution:**

The backend **DOES NOT need sudo**. Just run it normally:

```bash
# Set environment variables
export DB_USER="postgres"
export DB_PASSWORD="postgres"
export DB_NAME="barqnet"
export DB_HOST="localhost"
export DB_SSLMODE="disable"

# Run WITHOUT sudo
./management
```

**Why sudo doesn't work:**
- `sudo` creates a new shell session with root privileges
- Your user's environment variables don't transfer to root's session
- The backend reads environment variables at startup
- Without variables, it falls back to defaults (vpnmanager/vpnmanager)
- **The backend doesn't need root privileges anyway!**

**If you absolutely must use sudo:**

```bash
# Option 1: Use sudo -E (preserve Environment)
export DB_USER="postgres"
export DB_PASSWORD="postgres"
export DB_NAME="barqnet"
sudo -E ./management

# Option 2: Set variables inline
sudo DB_USER="postgres" DB_PASSWORD="postgres" DB_NAME="barqnet" DB_HOST="localhost" DB_SSLMODE="disable" ./management
```

**Quick test to verify environment variables are set:**

```bash
# Check if variables are set in your current shell
echo $DB_USER
echo $DB_NAME

# Expected output:
# postgres
# barqnet
```

**If variables are empty, re-export them before running the backend.**

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

## 🚀 PRODUCTION DEPLOYMENT (Ubuntu Servers)

After testing on Windows, you're ready to deploy to production Ubuntu servers for **actual VPN functionality**.

### Why Ubuntu for Production?

**Windows is great for testing, but Ubuntu is required for production because:**
- ✅ OpenVPN works best on Linux
- ✅ Better performance and stability
- ✅ Industry standard for VPN servers
- ✅ Lower cost (cloud VPS pricing)

### What You Need

**Servers:**
1. **Management Server** (1 server)
   - Ubuntu 20.04 LTS or newer
   - 2GB RAM, 2 CPU cores
   - 20GB storage
   - Static IP or domain name
   - **Cost:** ~$12/month (DigitalOcean, AWS EC2, Linode)

2. **VPN Servers** (multiple locations)
   - Ubuntu 20.04 LTS or newer
   - 1-2GB RAM, 1-2 CPU cores
   - 10GB storage
   - Public static IP address
   - **Cost:** ~$6-12/month each

**Recommended VPN Server Locations:**
- US-East (New York/Virginia)
- EU-West (London/Ireland)
- Asia-Pacific (Singapore/Tokyo)

**Total Cost:** ~$30-50/month for 3-location VPN service

---

### 🎯 EASY DEPLOYMENT: One-Command Setup

We have **automated deployment scripts** that do everything for you!

#### Step 1: Deploy Management Server (5-10 minutes)

```bash
# 1. SSH into your Ubuntu server
ssh user@your-management-server-ip

# 2. Clone the repository
git clone https://github.com/LenoreWoW/ChameleonVpn.git
cd ChameleonVpn/deployment

# 3. Run the automated deployment script
sudo ./ubuntu-deploy-management.sh
```

**The script automatically:**
- ✅ Installs PostgreSQL 14
- ✅ Installs Go 1.21
- ✅ Creates secure database with random passwords
- ✅ Builds Management API
- ✅ Runs database migrations
- ✅ Creates systemd service (auto-starts on boot)
- ✅ Configures firewall
- ✅ Starts the service

**Expected output:**
```
═══════════════════════════════════════════════════════════════
[SUCCESS] BarqNet Management Server Deployment Complete!
═══════════════════════════════════════════════════════════════

🔐 Credentials (SAVE THESE!):
   - Database: barqnet
   - DB User: barqnet
   - DB Password: <randomly-generated-secure-password>
```

**IMPORTANT:** Save the database password! You'll need it for VPN servers.

```bash
# 4. Verify it's working
curl http://localhost:8080/api/health

# Expected: {"status":"healthy","timestamp":...}
```

---

#### Step 2: Deploy VPN Server(s) (10-15 minutes each)

Repeat this for each VPN server location (US, EU, Asia, etc.)

```bash
# 1. SSH into your Ubuntu VPN server
ssh user@your-vpn-server-ip

# 2. Clone the repository
git clone https://github.com/LenoreWoW/ChameleonVpn.git
cd ChameleonVpn/deployment

# 3. Run the automated deployment script
sudo ./ubuntu-deploy-endnode.sh
```

**The script will ask you for:**
- **Server ID:** Unique name (e.g., `us-east-1`, `eu-west-1`)
- **Management Server URL:** Your Management Server (e.g., `http://192.168.1.100:8080`)
- **API Key:** Shared secret (create a strong password)
- **Database Host:** Management Server IP
- **Database Password:** From Management Server deployment
- **Server Location:** Display name (e.g., `US-East`, `EU-West`)

**The script automatically:**
- ✅ Installs OpenVPN + Easy-RSA
- ✅ Sets up complete PKI (Certificate Authority)
- ✅ Generates server certificates and keys
- ✅ Configures OpenVPN with security best practices
- ✅ Enables IP forwarding and NAT
- ✅ Builds End-Node API
- ✅ Creates systemd services (auto-start)
- ✅ Configures firewall
- ✅ Registers with Management Server
- ✅ Starts all services

**Expected output:**
```
═══════════════════════════════════════════════════════════════
[SUCCESS] BarqNet End-Node VPN Server Deployment Complete!
═══════════════════════════════════════════════════════════════

📍 Installation Details:
   - Server ID: us-east-1
   - Location: US-East
   - Public IP: 1.2.3.4
   - VPN Port: 1194
```

```bash
# 4. Verify it's working
curl http://localhost:8081/health

# Expected: {"status":"healthy","server_id":"us-east-1"...}
```

---

#### Step 3: Configure Production Settings

**On Management Server:**

```bash
# 1. Edit configuration
sudo nano /etc/barqnet/management-config.env

# 2. Add Twilio credentials for real SMS/OTP
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+1234567890

# 3. Remove development OTP bypass
# Comment out or remove this line:
# ENABLE_OTP_CONSOLE=true

# 4. Restart service
sudo systemctl restart barqnet-management
```

**Sign up for Twilio:**
- Go to https://www.twilio.com/
- Sign up for free trial ($15 credit)
- Get your Account SID, Auth Token, and phone number
- Add to configuration above

---

#### Step 4: Update Client Apps

Update all client apps to use your production server:

**Desktop Client:**
```bash
# Edit .env file
nano workvpn-desktop/.env

# Change to your domain or IP
API_BASE_URL=https://yourdomain.com
# or
API_BASE_URL=http://YOUR_SERVER_IP:8080
```

**iOS Client:**
```swift
// Edit WorkVPN/Config/Config.swift
static let apiBaseURL = "https://yourdomain.com"
```

**Android Client:**
```kotlin
// Edit app/src/main/java/com/barqnet/android/network/ApiConfig.kt
const val BASE_URL = "https://yourdomain.com"
```

**Rebuild and redistribute clients to users.**

---

#### Step 5: (Optional) Set Up SSL/HTTPS

For production, use HTTPS with a real domain:

```bash
# On Management Server
sudo apt install -y nginx certbot python3-certbot-nginx

# Configure nginx
sudo nano /etc/nginx/sites-available/barqnet
```

Add:
```nginx
server {
    listen 80;
    server_name yourdomain.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

```bash
# Enable and get SSL certificate
sudo ln -s /etc/nginx/sites-available/barqnet /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo certbot --nginx -d yourdomain.com
```

---

### 📊 Verify Production Deployment

**Check all services are running:**

```bash
# On Management Server
sudo systemctl status barqnet-management
curl http://localhost:8080/api/health

# On each VPN Server
sudo systemctl status openvpn@server
sudo systemctl status barqnet-endnode
curl http://localhost:8081/health
```

**Test full flow:**
1. Open Desktop/iOS/Android app
2. Register with real phone number
3. Receive SMS with OTP code
4. Login successfully
5. See VPN server locations
6. Connect to VPN
7. Verify IP changed (visit whatismyip.com)

**✅ If all works, you're in production!**

---

### 🔧 Production Management

**Service Commands:**

```bash
# Start/Stop/Restart
sudo systemctl start barqnet-management
sudo systemctl stop barqnet-management
sudo systemctl restart barqnet-management

# View logs
sudo journalctl -u barqnet-management -f
sudo journalctl -u openvpn@server -f

# Check VPN connections
sudo cat /var/log/openvpn/openvpn-status.log
```

**Daily Backups:**

```bash
# On Management Server, add to crontab
sudo crontab -e

# Add daily backup at 2 AM
0 2 * * * /usr/bin/pg_dump -U barqnet barqnet | gzip > /backup/barqnet-$(date +\%Y\%m\%d).sql.gz
```

---

### 📚 Complete Production Documentation

For full deployment details, see:
- **`UBUNTU_DEPLOYMENT_GUIDE.md`** - Complete production deployment guide
- **`DEPLOYMENT_ARCHITECTURE.md`** - System architecture
- **`deployment/ubuntu-deploy-management.sh`** - Management Server script
- **`deployment/ubuntu-deploy-endnode.sh`** - VPN Server script

---

### 💰 Cost Breakdown (Example)

**Monthly costs for 3-location VPN service:**

| Component | Provider | Specs | Cost/Month |
|-----------|----------|-------|------------|
| Management Server | DigitalOcean | 2GB RAM, 2 CPU | $12 |
| VPN Server (US-East) | DigitalOcean | 1GB RAM, 1 CPU | $6 |
| VPN Server (EU-West) | DigitalOcean | 1GB RAM, 1 CPU | $6 |
| VPN Server (Asia) | DigitalOcean | 1GB RAM, 1 CPU | $6 |
| Domain Name | Namecheap | .com domain | $1 |
| Twilio SMS | Twilio | ~1000 SMS/month | $10 |
| **TOTAL** | | | **$41/month** |

**Scale up as needed:**
- Add more VPN servers for more locations
- Increase server size for more users
- Typical pricing: $6-12 per location

---

### ⚡ Quick Start Summary

**Testing (Windows):**
1. Run backend on Windows (30 min)
2. Test Desktop client (30 min)
3. Test iOS client if macOS (45 min)
4. Test Android client (45 min)

**Production (Ubuntu):**
1. Deploy Management Server on Ubuntu (10 min)
2. Deploy VPN Server(s) on Ubuntu (15 min each)
3. Configure Twilio for SMS (5 min)
4. Update client apps (10 min)
5. Test end-to-end (15 min)

**Total: 3-4 hours from zero to production!**

---

**Questions?** Check the troubleshooting section or contact us with specific error messages.

**For production deployment help, see:** `UBUNTU_DEPLOYMENT_GUIDE.md`
