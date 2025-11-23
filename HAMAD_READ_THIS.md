# BarqNet - Complete Testing Guide

**Last Updated:** November 23, 2025
**Status:** Ready for Testing

---

## Quick Start - 3 Steps

### 1. Start Backend (Required!)

```bash
cd ~/ChameleonVpn/barqnet-backend/apps/management
go run main.go
```

**Keep this terminal running!** Don't close it.

You should see:
```
[ENV] ✅ Loaded configuration from .env file
[DB] ✅ Connected to PostgreSQL successfully
[API] 🚀 Management API server starting on :8080
```

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

**Create database:**
```bash
createdb -U postgres barqnet
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

### "Port 8080 already in use"
```bash
lsof -ti:8080 | xargs kill -9
```

### "Database connection failed"
```bash
sudo systemctl start postgresql
createdb -U postgres barqnet
```

### iOS Simulator warnings (AlertService, CA Event)
These are normal - ignore them.

### "Cannot find module" (Desktop)
```bash
cd ~/ChameleonVpn/workvpn-desktop
rm -rf node_modules package-lock.json
npm install
```

---

## What Success Looks Like

**Backend:**
- ✅ Starts on port 8080
- ✅ Shows OTP codes in logs

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

```
[ ] Backend running on port 8080
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
