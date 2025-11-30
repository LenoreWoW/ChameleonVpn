# BarqNet - Complete Testing Guide

**Last Updated:** November 30, 2025
**Status:** 🚀 NEW: iOS Quick Testing Bypass Added! + Authentication Fixes

---

## 🚨 CRITICAL: New Features & Fixes (November 30, 2025)

**Recent updates:**
1. ✅ **Database Migrations** - Automatic migration system verified and working
2. ✅ **iOS Testing Bypass** - Quick login/signup buttons in DEBUG mode (saves ~60 sec per test!)
3. ✅ **Redis Authentication** - Password now required for production
4. ✅ **Audit Logging** - Database schema fixed, dual logging enabled
5. ✅ **Rate Limiting** - Properly validates credentials

**YOU MUST complete Step 0A before running the backend!**

---

## Step 0A: Configure Redis & Database (REQUIRED - Do This First!)

### 1. Start PostgreSQL
```bash
sudo systemctl start postgresql
# OR on macOS:
brew services start postgresql
```

### 2. Create BarqNet Database & User

**Option A: Quick Setup (Recommended)**
```bash
cd ~/ChameleonVpn/barqnet-backend
sudo -u postgres psql <<EOF
CREATE USER barqnet WITH PASSWORD 'barqnet123';
CREATE DATABASE barqnet OWNER barqnet;
GRANT ALL PRIVILEGES ON DATABASE barqnet TO barqnet;
GRANT ALL PRIVILEGES ON SCHEMA public TO barqnet;
EOF
```

**Option B: Manual Migration (If automatic fails)**
```bash
# First, create user and database with Option A above
# Then run migrations manually:
cd ~/ChameleonVpn/barqnet-backend/migrations
for f in *.sql; do sudo -u postgres psql -d barqnet -f "$f"; done
cd ..
```

**Verify Database:**
```bash
psql -U barqnet -d barqnet -c "\dt"
# Should show: users, servers, audit_log, etc.
```

**Note:** User: `barqnet`, Password: `barqnet123` (matches .env defaults)

### 3. Configure Redis Password

**Check if Redis is running:**
```bash
redis-cli ping
```

**Generate a strong password:**
```bash
openssl rand -base64 32
```

**Copy the output, then edit Redis config:**
```bash
# Linux:
sudo nano /etc/redis/redis.conf

# macOS (Homebrew):
nano /opt/homebrew/etc/redis.conf
```

**Find and uncomment/add this line:**
```
requirepass YOUR_GENERATED_PASSWORD_HERE
```

**Restart Redis:**
```bash
# Linux:
sudo systemctl restart redis

# macOS:
brew services restart redis
```

**Test Redis with password:**
```bash
redis-cli -a YOUR_PASSWORD ping
# Should return: PONG
```

### 4. Update Backend .env File

```bash
cd ~/ChameleonVpn/barqnet-backend
nano .env
```

**Update these lines:**
```bash
# Database (matches user created in Step 2)
DB_HOST=localhost
DB_PORT=5432
DB_USER=barqnet
DB_PASSWORD=barqnet123
DB_NAME=barqnet
DB_SSLMODE=disable

# Redis
REDIS_PASSWORD=YOUR_GENERATED_PASSWORD_HERE

# Audit Logging
AUDIT_LOG_DIR=/var/log/vpnmanager
AUDIT_FILE_ENABLED=true
AUDIT_DB_ENABLED=true

# Environment
ENVIRONMENT=development  # Use 'production' when deploying
```

**Save and exit (Ctrl+X, Y, Enter)**

### 5. Create Audit Log Directory

```bash
sudo mkdir -p /var/log/vpnmanager
sudo chown $USER:$USER /var/log/vpnmanager
sudo chmod 750 /var/log/vpnmanager
```

**✅ Step 0A Complete! Now proceed to Step 0B.**

---

## Step 0B: Install Prerequisites (First Time Only!)

**Run this ONCE before anything else:**

```bash
cd ~/ChameleonVpn
./setup-prereqs.sh
```

This script will automatically:
- ✅ Check and install PostgreSQL
- ✅ Check and install Go (Golang)
- ✅ Check and install Node.js/npm
- ✅ Check and install CocoaPods (iOS)
- ✅ Check and install Java (Android)
- ✅ Create the BarqNet database (if not already done)
- ✅ Create .env files from templates

**If everything is already installed, it just confirms and exits.**

---

## Quick Start - 3 Steps

### 1. Start Backend (Required!)

```bash
cd ~/ChameleonVpn/barqnet-backend/apps/management
go run main.go
```

**Keep this terminal running!** Don't close it.

You should see these success messages:
```
[ENV] ✅ Loaded configuration from .env file
[ENV] ✅ Environment validation PASSED
[DB] ✅ Database migrations completed successfully
[RATE-LIMIT] ✅ Successfully connected to Redis at localhost:6379
[RATE-LIMIT] Rate limiting is ENABLED
[AUDIT] ✅ File logging enabled: /var/log/vpnmanager
[AUDIT] ✅ Database logging enabled
Management server started with ID: management-server
API server running on port 8080
```

**⚠️ If you see these warnings instead:**
```
[RATE-LIMIT] ⚠️ CRITICAL: Redis authentication failed
[RATE-LIMIT] Rate limiting will operate in DEGRADED mode
```
**→ Go back to Step 0A and fix your Redis password!**

### 2. Test iOS

Open a NEW terminal:
```bash
cd ~/ChameleonVpn
./setup-ios.sh
```

The script will:
- Install dependencies
- Fix Xcode 16 compatibility
- Build and launch app

### 3. Test Desktop

Open a NEW terminal:
```bash
cd ~/ChameleonVpn/workvpn-desktop
npm start
```

---

## iOS Testing Steps

When the app launches:

1. **Enter email:** `hamad@test.com`
2. **Tap Continue**
3. **Check backend terminal** for OTP code:
   ```
   [OTP] DEBUG: Code for hamad@test.com = 123456
   ```
4. **Enter the 6-digit code**
5. **Create password:** `Test123!`
6. **Confirm password:** `Test123!`

✅ You should see the main VPN screen

**Test Settings:**
- Tap gear icon ⚙️ (top right)
- Settings should open
- Close modal

**Test Logout:**
- Tap logout icon (top left)
- Should return to login screen

**Test Login:**
- Email: `hamad@test.com`
- Password: `Test123!`
- Should login without OTP

---

## 🚀 NEW: iOS Quick Testing Bypass (DEBUG Mode Only!)

**No more email waiting!** In DEBUG builds, you can now bypass email/OTP entry for instant testing.

### Option 1: One-Tap Quick Login (Fastest!)

When the app launches:

1. **Tap "Already have an account? Sign In"**
2. **Look for the yellow ⚡ "Quick Test Login" button**
3. **Tap it**
4. ✅ **Instantly logged in!** (No typing needed)

**Test Credentials Auto-Filled:**
- Email: `test@barqnet.local`
- Password: `Test1234`

### Option 2: Quick Signup Flow

1. **Launch app → Look for yellow ⚡ "Use Test Email" button**
2. **Tap it** → Auto-fills email and proceeds to OTP
3. **Look for yellow ⚡ "Use Test OTP" button**
4. **Tap it** → Auto-fills OTP code `123456`
5. **Create password manually**
6. ✅ **Account created!**

### How to Create More Test Accounts

```bash
cd ~/ChameleonVpn/barqnet-backend
go run scripts/create_test_user.go \
  -email "mytest@test.local" \
  -username "myuser" \
  -password "MyPass123" \
  -force
```

Then update iOS test config in `workvpn-ios/WorkVPN/Config/TestingConfig.swift`

### Important Notes

- ⚡ **Yellow buttons only appear in DEBUG builds**
- 🔒 **Automatically disabled in Release/Production**
- 📖 **Full guide:** `workvpn-ios/TESTING_GUIDE.md`
- 🎯 **Saves ~60 seconds per test cycle**

### Visual Indicators

All testing buttons have:
- **Yellow color** with lightning bolt ⚡
- **Dashed yellow border**
- **Semi-transparent background**

Easy to spot and won't appear in production!

---

## Desktop Testing Steps

Follow the same flow as iOS:

1. Enter email: `hamad2@test.com`
2. Get OTP from backend logs
3. Enter OTP
4. Create password
5. Test settings
6. Test logout/login

---

## Android Testing

```bash
cd ~/ChameleonVpn/workvpn-android
./gradlew installDebug
```

Follow same testing flow as iOS/Desktop.

---

## Prerequisites (First Time Only)

### PostgreSQL Setup

**Check if running:**
```bash
psql -U postgres -c "SELECT version();"
```

**If not running:**
```bash
sudo systemctl start postgresql
```

**Create database user and database (same as Step 0A):**
```bash
cd ~/ChameleonVpn/barqnet-backend
sudo -u postgres psql <<EOF
CREATE USER barqnet WITH PASSWORD 'barqnet123';
CREATE DATABASE barqnet OWNER barqnet;
GRANT ALL PRIVILEGES ON DATABASE barqnet TO barqnet;
GRANT ALL PRIVILEGES ON SCHEMA public TO barqnet;
EOF
```

### Backend .env File

**Check if exists:**
```bash
cd ~/ChameleonVpn/barqnet-backend/apps/management
ls .env
```

**If missing:**
```bash
cp .env.example .env
```

---

## Endnode Setup (Optional)

The endnode is for VPN traffic handling. Management server is for authentication.

**Create .env:**
```bash
cd ~/ChameleonVpn/barqnet-backend/apps/endnode
cp .env.example .env
nano .env
```

**Set these 3 variables:**

1. **JWT_SECRET** - Copy from management server:
   ```bash
   cd ~/ChameleonVpn/barqnet-backend/apps/management
   cat .env | grep JWT_SECRET
   ```

2. **API_KEY** - Generate random:
   ```bash
   openssl rand -hex 32
   ```

3. **MANAGEMENT_URL** - If same server:
   ```bash
   MANAGEMENT_URL=http://localhost:8080
   ```

**Save and run:**
```bash
go build -o endnode main.go
./endnode -server-id server-1
```

You should see:
```
[ENV] ✅ Endnode environment validation PASSED
✅ Successfully registered with management server
```

---

## Troubleshooting

### "Redis authentication failed: WRONGPASS"

This means Redis password is not configured correctly.

**Solution:**
```bash
# 1. Check your Redis config
cat /etc/redis/redis.conf | grep requirepass

# 2. Check your .env file
cd ~/ChameleonVpn/barqnet-backend/apps/management
cat .env | grep REDIS_PASSWORD

# 3. Make sure they match!
# Then restart Redis:
sudo systemctl restart redis
```

### "column 'username' does not exist" or Migration Errors

This means the database migrations haven't run or failed.

**Solution Option 1: Automatic (Recommended)**
```bash
# Stop the backend (Ctrl+C)
# Drop and recreate database with user:
sudo -u postgres psql <<EOF
DROP DATABASE IF EXISTS barqnet;
CREATE DATABASE barqnet OWNER barqnet;
GRANT ALL PRIVILEGES ON DATABASE barqnet TO barqnet;
EOF

# Restart backend - migrations will run automatically:
cd ~/ChameleonVpn/barqnet-backend/apps/management
go run main.go
```

**Solution Option 2: Manual Migration**
```bash
# Stop the backend (Ctrl+C)
# Recreate database (same as above)
sudo -u postgres psql <<EOF
DROP DATABASE IF EXISTS barqnet;
CREATE DATABASE barqnet OWNER barqnet;
GRANT ALL PRIVILEGES ON DATABASE barqnet TO barqnet;
EOF

# Run migrations manually:
cd ~/ChameleonVpn/barqnet-backend/migrations
for f in *.sql; do sudo -u postgres psql -d barqnet -f "$f"; done

# Verify migrations:
psql -U barqnet -d barqnet -c "SELECT version, name FROM schema_migrations ORDER BY version;"

# Restart backend:
cd ~/ChameleonVpn/barqnet-backend/apps/management
go run main.go
```

### "Failed to log audit: no such file or directory"

The audit log directory doesn't exist.

**Solution:**
```bash
sudo mkdir -p /var/log/vpnmanager
sudo chown $USER:$USER /var/log/vpnmanager
sudo chmod 750 /var/log/vpnmanager
```

### "Port 8080 already in use"
```bash
lsof -ti:8080 | xargs kill -9
```

### "Database connection failed"
```bash
sudo systemctl start postgresql
# macOS:
brew services start postgresql
```

### iOS Simulator warnings (AlertService, CA Event)
These are normal - ignore them.

### "Cannot find module" (Desktop)
```bash
cd ~/ChameleonVpn/workvpn-desktop
rm -rf node_modules package-lock.json
npm install
```

### Redis not installed?

**Ubuntu/Debian:**
```bash
sudo apt-get install redis-server
sudo systemctl start redis
```

**macOS:**
```bash
brew install redis
brew services start redis
```

---

## What Success Looks Like

**Backend:**
- ✅ Database migrations run successfully
- ✅ Redis authentication succeeds
- ✅ Rate limiting is ENABLED (not degraded mode)
- ✅ Audit logging enabled (file + database)
- ✅ Starts on port 8080
- ✅ Shows OTP codes in logs
- ✅ No "WRONGPASS" errors
- ✅ No "column does not exist" errors

**iOS/Desktop/Android:**
- ✅ App launches
- ✅ Can create account
- ✅ Can enter OTP
- ✅ Can set password
- ✅ Main screen shows "No VPN Configuration" (normal!)
- ✅ Settings open
- ✅ Logout/Login works

---

## Testing Checklist

**Pre-flight Checks:**
```
[ ] Redis is running with password configured
[ ] PostgreSQL is running
[ ] BarqNet database exists
[ ] .env file has REDIS_PASSWORD set
[ ] Audit log directory exists (/var/log/vpnmanager)
```

**Backend Startup:**
```
[ ] Database migrations run successfully
[ ] Redis authentication succeeds
[ ] Rate limiting is ENABLED
[ ] Audit logging enabled (file + database)
[ ] Backend running on port 8080
[ ] No WRONGPASS errors
[ ] No column errors
```

**Client Testing:**
```
[ ] iOS app builds and runs
[ ] Desktop app launches
[ ] Can create account with email
[ ] OTP appears in backend logs
[ ] Can verify OTP
[ ] Can set password
[ ] Main screen appears
[ ] Settings modal works
[ ] Logout works
[ ] Login works
```

---

## Quick Reference

**Backend:**
```bash
cd ~/ChameleonVpn/barqnet-backend/apps/management
go run main.go
```

**iOS:**
```bash
cd ~/ChameleonVpn
./setup-ios.sh
```

**Desktop:**
```bash
cd ~/ChameleonVpn/workvpn-desktop
npm start
```

**Android:**
```bash
cd ~/ChameleonVpn/workvpn-android
./gradlew installDebug
```

**Get OTP:**
Check backend terminal for:
```
[OTP] DEBUG: Code for <email> = 123456
```

---

**That's it! Start with backend, then test each platform. Good luck! 🚀**
