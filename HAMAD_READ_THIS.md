# BarqNet - Testing Guide for Hamad

**Last Updated:** November 23, 2025
**Status:** Ready for Testing

**READ THIS FIRST:** This guide assumes you're starting fresh. Follow EVERY step exactly as written.

---

## 🚀 START HERE - Complete Step-by-Step Instructions

### Where Are You Right Now?

Open a terminal and type this command to see where you are:
```bash
pwd
```

You should see something like:
```
/home/osrv2
```

### Step 1: Go to the Project Directory

Type this command EXACTLY:
```bash
cd ~/ChameleonVpn
```

Press Enter.

**Verify you're in the right place:**
```bash
pwd
```

You should see:
```
/home/osrv2/ChameleonVpn
```

**List what's in this directory:**
```bash
ls
```

You should see:
```
barqnet-backend/
workvpn-desktop/
workvpn-ios/
workvpn-android/
HAMAD_READ_THIS.md
setup-ios.sh
... other files ...
```

✅ **If you see these folders, you're in the right place!**

❌ **If you DON'T see these folders:**
```bash
# You're in the wrong place. Start over:
cd ~
cd ChameleonVpn
ls
```

---

## Prerequisites (Do These First!)

Before testing ANY platform, you MUST do these steps.

### 1. Check if PostgreSQL is Running

Type this command:
```bash
psql -U postgres -c "SELECT version();"
```

**If you see version info:**
```
PostgreSQL 14.x ...
```
✅ **PostgreSQL is running! Skip to step 2.**

**If you see an error:**
```
psql: error: connection to server failed
```
❌ **PostgreSQL is NOT running. Start it:**

**On Linux (your server osrv2):**
```bash
sudo systemctl start postgresql
```

Type your password when asked.

**Verify it's running:**
```bash
sudo systemctl status postgresql
```

You should see:
```
Active: active (running)
```

Press `q` to exit.

### 2. Check if Database Exists

Type this command:
```bash
psql -U postgres -l | grep barqnet
```

**If you see:**
```
barqnet | postgres | ...
```
✅ **Database exists! Skip to Backend Setup.**

**If you see nothing (no output):**
❌ **Database doesn't exist. Create it:**

```bash
createdb -U postgres barqnet
```

**Verify it was created:**
```bash
psql -U postgres -l | grep barqnet
```

You should NOW see:
```
barqnet | postgres | ...
```

✅ **Database created successfully!**

---

## Backend Setup (THE MOST IMPORTANT PART!)

**⚠️  WARNING: The backend MUST be running for ANY app to work!**

Follow these steps EXACTLY in order.

### Step 1: Open a New Terminal Window

You need a SEPARATE terminal that will run the backend.

**Important:** Keep this terminal open while testing. Don't close it!

### Step 2: Navigate to the Backend Directory

In your NEW terminal, type:
```bash
cd ~/ChameleonVpn/barqnet-backend/apps/management
```

**Verify you're in the right place:**
```bash
pwd
```

You should see:
```
/home/osrv2/ChameleonVpn/barqnet-backend/apps/management
```

**List files:**
```bash
ls
```

You should see:
```
main.go
.env.example
... other files ...
```

### Step 3: Check if .env File Exists

Type:
```bash
ls .env
```

**If you see:**
```
.env
```
✅ **File exists! Skip to Step 4.**

**If you see:**
```
ls: cannot access '.env': No such file or directory
```
❌ **File doesn't exist. Create it:**

```bash
cp .env.example .env
```

**Verify it was created:**
```bash
ls .env
```

You should NOW see:
```
.env
```

### Step 4: Start the Backend Server

Type this command:
```bash
go run main.go
```

**Wait 5-10 seconds. You should see:**
```
========================================
BarqNet Management Server - Starting...
========================================
[ENV] ✅ Loaded configuration from .env file
[DB] ✅ Connected to PostgreSQL successfully
[OTP] ✅ Resend email service initialized
[API] 🚀 Management API server starting on :8080
```

✅ **SUCCESS! The backend is running!**

**⚠️  IMPORTANT:**
- **DO NOT close this terminal!**
- **Keep it running in the background!**
- **Leave it alone while you test!**

**If you see errors instead:**

**Error: "Database connection failed"**
```bash
# Go back and make sure PostgreSQL is running:
sudo systemctl status postgresql
```

**Error: "Port 8080 already in use"**
```bash
# Kill the process using port 8080:
lsof -ti:8080 | xargs kill -9
# Then try again:
go run main.go
```

**Error: "Environment variables missing"**
```bash
# Make sure .env file exists:
ls .env
# If it doesn't, create it:
cp .env.example .env
```

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

## Now Choose What to Test

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

## iOS Testing (macOS/Xcode Only)

**Note:** iOS testing requires macOS with Xcode installed.

### Step 1: Open a NEW Terminal (Not the Backend One!)

The backend should still be running in another terminal. Don't close it!

Open a fresh terminal window.

### Step 2: Go to Project Root

Type:
```bash
cd ~/ChameleonVpn
```

**Verify:**
```bash
pwd
```

Should show:
```
/home/wolf/ChameleonVpn
```

Or on macOS:
```
/Users/wolf/Desktop/ChameleonVpn
```

### Step 3: Run the Automated Setup Script

Type this EXACT command:
```bash
./setup-ios.sh
```

**What will happen:**
1. Script checks CocoaPods is installed
2. Installs iOS dependencies (OpenVPN library)
3. Applies Xcode 16 compatibility fixes automatically
4. Opens Xcode workspace
5. (If Xcode installed) Builds and runs app on Simulator

**Wait for the script to finish.** It may take 2-5 minutes.

**You'll see output like:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🚀 BarqNet iOS - Automated Setup & Run Script
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/6] Checking project structure...
✓ Project structure verified

[2/6] Checking CocoaPods installation...
✓ CocoaPods already installed (v1.16.2)

[3/6] Installing iOS dependencies...
✓ Dependencies installed successfully

[4/6] Verifying Xcode workspace...
✓ Workspace verified

[5/6] Checking Xcode installation...
✓ Xcode 16.0 found

[6/6] Building and running app...
✓ Build successful!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✅ Setup Complete! App is launching on simulator...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

✅ **If you see this, the app should launch automatically!**

### Step 4: Wait for Xcode to Open

Xcode will open automatically. Wait for it to fully load.

### Step 5: Build in Xcode (If Script Didn't Auto-Build)

If the app didn't launch automatically:

1. **Look at the top of Xcode window**
2. **Click the dropdown** next to "WorkVPN"
3. **Select:** iPhone 15 (or any iPhone Simulator)
4. **Press:** ⌘R (Command + R) or click the Play ▶ button

### Step 6: Wait for Build to Complete

**You'll see** at the top of Xcode:
```
Building WorkVPN...
```

**Wait 1-2 minutes.** First build takes longer.

**When done, you'll see:**
```
Build Succeeded
```

**The iPhone Simulator will open automatically.**

### Manual Steps (If Automated Script Fails)

Only do this if `./setup-ios.sh` didn't work.

**Step 1: Navigate to iOS directory**
```bash
cd ~/ChameleonVpn/workvpn-ios
```

**Step 2: Install dependencies**
```bash
pod install
```

Wait for it to finish. You should see:
```
Pod installation complete!
```

**Step 3: Open workspace**
```bash
open WorkVPN.xcworkspace
```

**Step 4: Build in Xcode**
- Select "WorkVPN" scheme
- Select "iPhone 15 Simulator"
- Press ⌘R

### What to Test in the iOS App

**NOW:** The iPhone Simulator should be open with the BarqNet app running.

### Test 1: Verify App Launched Successfully

**Look at the Simulator screen. You should see:**

1. **Blue gradient background** (dark blue fading to cyan/light blue)
2. **Animated email emoji** 📧 (floating up and down)
3. **"Get Started" title** in cyan/blue color
4. **Subtitle text:** "Enter your email address to create your secure VPN account"
5. **Email input field** (empty white box)
6. **"CONTINUE" button** (blue gradient button)
7. **Link at bottom:** "Already have an account? Sign In"

✅ **If you see ALL of these, Test 1 PASSED!**

❌ **If the app crashed or shows blank screen:**
- Check Xcode console (bottom panel) for errors
- Look for red error messages
- Send screenshot of error

### Test 2: Create a New Account

**Step 1:** Tap the email input field

**Step 2:** Type this email:
```
hamad@test.com
```

**Step 3:** Tap the "CONTINUE" button

**Step 4:** Wait 2-3 seconds. App should show loading spinner.

**Step 5:** **IMPORTANT - Go to your backend terminal!**

Look for this line in the backend logs:
```
[OTP] DEBUG: Code for hamad@test.com = 123456
```

**Write down the 6-digit code!** You'll need it in the next step.

**Step 6:** App should now show OTP verification screen

You should see:
- "Verify Your Email" title
- Your email address displayed
- 6 empty boxes for the OTP code
- "VERIFY" button
- "Didn't receive code? Resend" link

**Step 7:** Enter the 6-digit OTP code from backend logs

Type each digit. The boxes will auto-advance.

**Step 8:** Tap "VERIFY" button

**Step 9:** Wait 2-3 seconds

**Step 10:** App should show "Create Password" screen

You should see:
- "Create Password" title
- Password input field
- "Confirm Password" input field
- "CREATE ACCOUNT" button

**Step 11:** Enter a password

Type:
```
Test123!
```

**Step 12:** Confirm the password

Type again:
```
Test123!
```

**Step 13:** Tap "CREATE ACCOUNT" button

**Step 14:** Wait 2-3 seconds

✅ **SUCCESS!** You should now see the main VPN screen!

### Test 3: Verify Main Screen

You should see:
- "BarqNet" title at top
- **Gear icon** ⚙️ in top right corner
- **Logout icon** 🚪 in top left corner
- Message: "No VPN Configuration" or "Import .ovpn configuration file"

**⚠️  THIS IS NORMAL!** VPN server configuration isn't implemented yet. This is expected!

**Test the settings:**

**Step 1:** Tap the gear icon (⚙️) in top right

**Step 2:** Settings modal should slide up from bottom

You should see:
- Your email address
- Account information
- "Delete Account" option (in red)

**Step 3:** Tap outside the modal or close button

Modal should close.

✅ **Test 3 PASSED!**

### Test 4: Test Logout

**Step 1:** Tap the logout icon (🚪) in top left corner

**Step 2:** App should return to login screen

You should see:
- "Welcome Back" title
- Email input field
- Password input field
- "SIGN IN" button
- "Don't have an account? Sign Up" link

✅ **Logout works!**

### Test 5: Test Login

**Step 1:** Enter email:
```
hamad@test.com
```

**Step 2:** Enter password:
```
Test123!
```

**Step 3:** Tap "SIGN IN" button

**Step 4:** Wait 2-3 seconds

**Step 5:** You should be logged in and see the main VPN screen again

**No OTP required this time!** That's correct - password login doesn't need OTP.

✅ **Login works!**

---

### iOS Testing Complete!

**If ALL 5 tests passed:**
✅ iOS app is working perfectly!

**If ANY test failed:**
❌ Send screenshot of the error
❌ Check Xcode console for red error messages
❌ Check backend terminal for error logs

---

## Desktop Testing

**Note:** Desktop app runs on macOS, Windows, or Linux.

### Step 1: Open a NEW Terminal

Backend should still be running. Don't close it!

Open a fresh terminal.

### Step 2: Navigate to Desktop Directory

Type:
```bash
cd ~/ChameleonVpn/workvpn-desktop
```

**Verify:**
```bash
pwd
```

Should show:
```
/home/osrv2/ChameleonVpn/workvpn-desktop
```

Or on macOS:
```
/Users/wolf/Desktop/ChameleonVpn/workvpn-desktop
```

**List files:**
```bash
ls
```

You should see:
```
package.json
src/
node_modules/ (maybe)
...
```

### Step 3: Install Dependencies (First Time Only)

**Skip this if you've already done it before.**

Type:
```bash
npm install
```

**Wait 1-2 minutes.** You'll see lots of package names scrolling by.

**When done, you should see:**
```
added XXX packages in XXs
```

✅ **Dependencies installed!**

**If you see errors:**
```bash
# Delete node_modules and try again:
rm -rf node_modules package-lock.json
npm install
```

### Step 4: Run the Desktop App

Type:
```bash
npm start
```

**Wait 10-20 seconds.**

**You should see:**
```
> workvpn-desktop@1.0.0 start
> electron .

[Electron app starting...]
```

**A window will open!** This is the BarqNet desktop app.

✅ **If the app window opens, SUCCESS!**

### Step 5: Test the Desktop App

**The desktop app uses the SAME testing flow as iOS.**

Follow these steps IN THE APP WINDOW:

**Test 1: Create Account**
1. Enter email: `hamad2@test.com` (different from iOS test)
2. Click "CONTINUE"
3. Check backend terminal for OTP:
   ```
   [OTP] DEBUG: Code for hamad2@test.com = 654321
   ```
4. Enter the 6-digit code
5. Create password: `Test123!`
6. Confirm password: `Test123!`

**Test 2: Verify Main Screen**
- You should see "No VPN Configuration"
- Settings button should be visible
- Window should be resizable (try dragging corners)

**Test 3: Test Logout & Login**
1. Click logout
2. Login with: `hamad2@test.com` / `Test123!`

✅ **If all tests pass, Desktop app works!**

**Desktop-Specific Things to Check:**
- ✅ Window can be resized (drag corners)
- ✅ All buttons are visible (no cut-off UI)
- ✅ Can scroll if content is too long
- ✅ Settings modal opens and closes

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

## Endnode Server Setup (Optional - For VPN Traffic)

**Note:** You saw the endnode errors on osrv2. Here's how to fix them.

### What is Endnode?

**Management Server** = Authentication, users, database (what you already started)
**Endnode Server** = VPN traffic handling (what you're trying to start now)

**Important:** Endnode does NOT need database credentials! It only talks to Management API.

### Step 1: Go to Endnode Directory

Type:
```bash
cd ~/ChameleonVpn/barqnet-backend/apps/endnode
```

**Verify:**
```bash
pwd
```

Should show:
```
/home/osrv2/ChameleonVpn/barqnet-backend/apps/endnode
```

### Step 2: Create .env File

**Why isn't .env in git?**
- `.env` contains SECRETS (passwords, API keys)
- NEVER commit secrets to git (security risk!)
- Only `.env.example` is in git (template with fake values)

**Create .env from the example:**
```bash
cp .env.example .env
```

**Verify it was created:**
```bash
ls .env
```

You should see:
```
.env
```

### Step 3: Edit .env File

Open the file:
```bash
nano .env
```

**You need to set these 3 variables:**

**1. JWT_SECRET** (MUST match Management Server)

Go to your Management Server terminal and find this line:
```
[ENV] ✅ VALID: JWT_SECRET = yo**************************re
```

Or check the Management .env file:
```bash
# In another terminal:
cd ~/ChameleonVpn/barqnet-backend/apps/management
cat .env | grep JWT_SECRET
```

Copy that EXACT value.

In the endnode .env, set:
```bash
JWT_SECRET=<paste the value here>
```

**2. API_KEY** (Create a strong random key)

Generate a random key:
```bash
openssl rand -hex 32
```

Copy the output and set in .env:
```bash
API_KEY=<paste the random key here>
```

**3. MANAGEMENT_URL** (Where is Management Server?)

If Management is running on the same server (osrv2):
```bash
MANAGEMENT_URL=http://localhost:8080
```

If Management is on a different server:
```bash
MANAGEMENT_URL=http://<management-server-ip>:8080
```

**Save and exit nano:**
- Press `Ctrl+X`
- Press `Y` to confirm
- Press `Enter` to save

### Step 4: Build Endnode

Type:
```bash
go build -o endnode main.go
```

Wait 10-20 seconds.

You should see:
```
(no output means success)
```

**Verify binary was created:**
```bash
ls endnode
```

You should see:
```
endnode
```

### Step 5: Run Endnode

Type:
```bash
./endnode -server-id server-1
```

**You should see:**
```
========================================
BarqNet Endnode Server - Starting...
========================================
[ENV] ✅ Loaded configuration from .env file
[ENV] Validating endnode environment variables...
[ENV] Note: Endnodes use Management API, no direct database access needed
[ENV] ✅ VALID: JWT_SECRET = yo**************************re
[ENV] ✅ VALID: API_KEY = a9**********6f
[ENV] ✅ VALID: MANAGEMENT_URL = http://localhost:8080
[ENV] ============================================================
[ENV] ✅ Endnode environment validation PASSED
[ENV] ============================================================
End-node mode: No direct database connection needed
Communication with management server via API only
✅ API server is ready
✅ Successfully registered with management server
🚀 Endnode server 'server-1' started successfully
```

✅ **If you see this, Endnode is running!**

**Important:** Like the Management server, keep this terminal running!

### What You Fixed

**Before (with database errors):**
```
[ENV] ❌ MISSING: DB_HOST
[ENV] ❌ MISSING: DB_PORT
[ENV] ❌ MISSING: DB_USER
[ENV] ❌ MISSING: DB_PASSWORD
[ENV] ❌ MISSING: DB_NAME
```

**After (only needs 3 variables):**
```
[ENV] ✅ VALID: JWT_SECRET
[ENV] ✅ VALID: API_KEY
[ENV] ✅ VALID: MANAGEMENT_URL
```

**This is correct!** Endnode doesn't need database - it uses Management API only.

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
