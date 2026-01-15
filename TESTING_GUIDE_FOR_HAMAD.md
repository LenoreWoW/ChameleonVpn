# Testing Guide - Health Check Fix & iOS Configuration

**Prepared for:** Hamad
**Date:** 2025-12-04
**Priority:** HIGH
**Estimated Testing Time:** 30-45 minutes

---

## 🎯 What You're Testing

### Backend Changes
- ✅ End-node health check no longer returns 401 errors
- ✅ New unauthenticated health check endpoint works
- ✅ End-nodes can successfully report their health status

### iOS App Changes
- ✅ Proper environment configuration using `.xcconfig` files
- ✅ No more hardcoded server IPs
- ✅ Easy switching between development/staging/production environments
- ✅ App connects to management server successfully

---

## 📋 Prerequisites

Before you start testing, ensure you have:

- [ ] SSH access to management server (192.168.10.217)
- [ ] SSH access to end-node server (192.168.10.248)
- [ ] Mac with Xcode installed
- [ ] Git access to the repository
- [ ] Basic familiarity with terminal commands

---

## 🔧 Part 1: Backend Testing (20 minutes)

### Step 1.1: Deploy Management Server Update

```bash
# SSH to management server
ssh user@192.168.10.217

# Navigate to project
cd ~/ChameleonVpn/barqnet-backend/apps/management

# Pull latest changes
git pull origin main

# Check what changed
git log -1 --stat
# Should show: apps/management/api/api.go changed

# Build
go build -o management .

# Backup current binary
sudo cp /opt/barqnet/bin/management /opt/barqnet/bin/management.backup

# Install new binary
sudo cp management /opt/barqnet/bin/management
sudo chown barqnet:barqnet /opt/barqnet/bin/management

# Restart service
sudo systemctl restart vpnmanager-management

# Verify it started
sudo systemctl status vpnmanager-management
```

**✅ Test 1.1: Management Server Health Check**

```bash
curl http://localhost:8085/health
```

**Expected Output:**
```json
{"status":"healthy","timestamp":1733277600,"version":"1.0.0","serverID":"management-server"}
```

**❌ If it fails:**
- Check logs: `sudo journalctl -u vpnmanager-management -n 50`
- Check if port is in use: `sudo netstat -tlnp | grep 8085`
- Restore backup: `sudo cp /opt/barqnet/bin/management.backup /opt/barqnet/bin/management && sudo systemctl restart vpnmanager-management`

---

### Step 1.2: Deploy End-Node Update

```bash
# SSH to end-node server
ssh user@192.168.10.248

# Navigate to project
cd ~/ChameleonVpn/barqnet-backend/apps/endnode

# Pull latest changes
git pull origin main

# Check what changed
git log -1 --stat
# Should show: apps/endnode/manager/manager.go changed

# Build
go build -o endnode .

# Backup current binary
sudo cp /opt/barqnet/bin/endnode /opt/barqnet/bin/endnode.backup

# Install new binary
sudo cp endnode /opt/barqnet/bin/endnode
sudo chown barqnet:barqnet /opt/barqnet/bin/endnode

# Restart service
sudo systemctl restart vpnmanager-endnode

# Verify it started
sudo systemctl status vpnmanager-endnode
```

**✅ Test 1.2: End-Node Health Check (Local)**

```bash
curl http://localhost:8081/health
```

**Expected Output:**
```json
{"status":"healthy","timestamp":1733277600,"version":"1.0.0","serverID":"endnode-server"}
```

---

### Step 1.3: Monitor Health Check Integration

**✅ Test 1.3A: Monitor End-Node Logs (NO 401 Errors)**

```bash
# On end-node server
sudo journalctl -u vpnmanager-endnode -f | grep -i health
```

**Expected Output (every 30 seconds):**
```
Dec 04 10:00:00 endnode: Health check sent to management server
Dec 04 10:00:30 endnode: Health check sent to management server
Dec 04 10:01:00 endnode: Health check sent to management server
```

**❌ What you should NOT see:**
```
Health check failed: health check failed with status: 401
```

**✅ Test 1.3B: Monitor Management Server Logs**

```bash
# On management server
sudo journalctl -u vpnmanager-management -f | grep -i health
```

**Expected Output (every 30 seconds):**
```
Dec 04 10:00:00 management: Health check received from end-node: server-1
Dec 04 10:00:00 management: POST /api/endnodes-health/server-1 200
Dec 04 10:00:30 management: Health check received from end-node: server-1
Dec 04 10:00:30 management: POST /api/endnodes-health/server-1 200
```

**✅ Test 1.3C: Manual Health Check Test**

```bash
# On management server, test the new endpoint
curl -X POST http://localhost:8085/api/endnodes-health/test-server \
  -H "Content-Type: application/json" \
  -d '{"server_id":"test-server","status":"healthy","timestamp":1733277600}'
```

**Expected Output:**
```json
{"success":true,"message":"Health status updated successfully","timestamp":1733277600}
```

---

### Step 1.4: Verify Existing Functionality

**✅ Test 1.4A: Authentication Still Works**

```bash
# On management server
curl -X POST http://localhost:8085/v1/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'
```

**Expected:** Should process (even if email fails, endpoint should respond)

**✅ Test 1.4B: Protected Endpoints Still Require Auth**

```bash
curl http://localhost:8085/api/users
```

**Expected Output:**
```json
{"success":false,"message":"Authorization header required"}
```

**✅ Test 1.4C: API Root Endpoint**

```bash
curl http://localhost:8085/api
```

**Expected:** JSON response with endpoints list

---

### Backend Testing Checklist

- [ ] Management server deployed successfully
- [ ] End-node server deployed successfully
- [ ] Management server health check returns 200 OK
- [ ] End-node health check returns 200 OK
- [ ] End-node logs show NO 401 errors (monitor for 2 minutes)
- [ ] Management server logs show health checks being received
- [ ] Manual health check test succeeds
- [ ] Authentication endpoints still work
- [ ] Protected endpoints still require JWT
- [ ] API root endpoint responds

**🎉 If all checks pass, backend is ✅ GOOD TO GO!**

---

## 📱 Part 2: iOS App Testing (25 minutes)

### Step 2.1: Setup Xcode Configuration

```bash
# On your Mac
cd ~/ChameleonVpn/workvpn-ios

# Pull latest changes
git pull origin main

# Verify configuration files exist
ls -la Configuration/
# Should see: Development.xcconfig, Staging.xcconfig, Production.xcconfig
```

**Open Xcode Project:**

1. Open `WorkVPN.xcodeproj` in Xcode
2. Add configuration files to project:
   - Right-click project root → "Add Files to WorkVPN"
   - Navigate to `Configuration` folder
   - Select all `.xcconfig` files
   - ✅ Check "Copy items if needed"
   - Click "Add"

**Configure Build Settings:**

1. Click **WorkVPN** project (blue icon)
2. Go to **Info** tab
3. Expand **Configurations** section
4. Set configurations:
   - **Debug** → `Development.xcconfig`
   - **Release** → `Production.xcconfig`

**Add Info.plist Keys:**

1. Open `Info.plist`
2. Add these keys (Right-click → Add Row):
   ```
   API_BASE_URL = $(API_BASE_URL)
   ENVIRONMENT_NAME = $(ENVIRONMENT_NAME)
   ENABLE_DEBUG_LOGGING = $(ENABLE_DEBUG_LOGGING)
   ENABLE_CERTIFICATE_PINNING = $(ENABLE_CERTIFICATE_PINNING)
   API_TIMEOUT_INTERVAL = $(API_TIMEOUT_INTERVAL)
   ```

**Clean Build:**

1. Product → Clean Build Folder (⌘+Shift+K)
2. Close Xcode
3. Delete Derived Data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. Reopen Xcode

---

### Step 2.2: Test Local Development Environment

**✅ Test 2.2A: Start Local Management Server**

```bash
# On your Mac
cd ~/ChameleonVpn/barqnet-backend/apps/management

# Edit start-local-management.sh and set DB_PASSWORD
# Then run:
./start-local-management.sh
```

**Expected Output:**
```
🚀 Starting local management server for iOS development...
📦 Building management server...
▶️  Starting server on http://127.0.0.1:8085
[Management server startup logs...]
```

**✅ Test 2.2B: Verify Local Server**

```bash
# In a new terminal
curl http://127.0.0.1:8085/health
```

**Expected:**
```json
{"status":"healthy","timestamp":1733277600,"version":"1.0.0","serverID":"management-server"}
```

**✅ Test 2.2C: Build and Run iOS App (Development)**

1. In Xcode, select **WorkVPN** scheme
2. Select iOS Simulator (e.g., iPhone 15 Pro)
3. Build and Run (⌘+R)
4. **Watch Console Output** in Xcode

**Expected Console Output:**
```
[APIClient] ═══════════════════════════════════════
[APIClient] Environment: Development
[APIClient] Base URL: http://127.0.0.1:8085
[APIClient] Debug Logging: Enabled
[APIClient] Certificate Pinning: Disabled
[APIClient] ═══════════════════════════════════════
[APIClient] Request timeout: 30.0s
[APIClient] Certificate pinning disabled for this environment
[APIClient] Initialization complete
```

**✅ Test 2.2D: Test API Connectivity**

1. App should launch successfully (not hang!)
2. Try to register/login
3. Check console for API requests
4. Should see network requests to `http://127.0.0.1:8085`

---

### Step 2.3: Test Staging Environment (Network Server)

**Configure Staging:**

1. Open `Configuration/Staging.xcconfig`
2. Update IP to management server:
   ```
   API_BASE_URL = http:/$()/192.168.10.217:8080
   ```
3. Save file

**Create Staging Scheme (First Time Only):**

1. Product → Scheme → Manage Schemes
2. Click **+** (bottom left)
3. Name: **WorkVPN (Staging)**
4. Click **OK**
5. Select project → **Info** tab → **Configurations**
6. Duplicate **Release** configuration → Rename to **Staging**
7. Set **Staging** to use `Staging.xcconfig`
8. Edit **WorkVPN (Staging)** scheme:
   - Set all build configurations to **Staging**

**✅ Test 2.3A: Build and Run (Staging)**

1. Select **WorkVPN (Staging)** scheme
2. Clean Build Folder (⌘+Shift+K)
3. Build and Run (⌘+R)
4. **Watch Console Output**

**Expected Console Output:**
```
[APIClient] ═══════════════════════════════════════
[APIClient] Environment: Staging
[APIClient] Base URL: http://192.168.10.217:8080
[APIClient] Debug Logging: Enabled
[APIClient] Certificate Pinning: Disabled
[APIClient] ═══════════════════════════════════════
```

**✅ Test 2.3B: Verify Network Connectivity**

Before testing app, verify server is reachable:

```bash
# From your Mac
ping 192.168.10.217
curl http://192.168.10.217:8080/health
```

**If curl fails:**
- Check firewall on server: `sudo ufw allow 8080/tcp`
- Check server is running: `sudo systemctl status vpnmanager-management`
- Check server is listening: `sudo netstat -tlnp | grep 8080`

**✅ Test 2.3C: Test App with Network Server**

1. App should launch successfully
2. Try to register/login
3. Should connect to network server (not localhost)
4. Check console for API requests to `192.168.10.217:8080`

---

### iOS Testing Checklist

#### Configuration Setup
- [ ] `.xcconfig` files added to Xcode project
- [ ] Info.plist updated with configuration keys
- [ ] APIClient.swift reads from Info.plist (check console logs)
- [ ] Build configurations assigned correctly
- [ ] Staging scheme created (optional but recommended)

#### Development Environment
- [ ] Local management server starts successfully
- [ ] Local server health check responds
- [ ] iOS app builds without errors
- [ ] Console shows "Environment: Development"
- [ ] Console shows "Base URL: http://127.0.0.1:8085"
- [ ] App launches without hanging
- [ ] App can make API requests to localhost

#### Staging Environment
- [ ] Staging.xcconfig configured with server IP
- [ ] iOS app builds with Staging scheme
- [ ] Console shows "Environment: Staging"
- [ ] Console shows correct network server URL
- [ ] Network server is reachable from Mac
- [ ] App launches without hanging
- [ ] App can make API requests to network server

#### Functional Tests
- [ ] Registration flow works
- [ ] Login flow works
- [ ] Error handling works (try invalid credentials)
- [ ] No crashes or freezes
- [ ] Console logs are clear and helpful

**🎉 If all checks pass, iOS app is ✅ GOOD TO GO!**

---

## 🐛 Common Issues & Solutions

### Backend Issues

**Issue:** End-node still shows 401 errors

**Solution:**
```bash
# Verify new binary is running
ps aux | grep endnode
ls -la /opt/barqnet/bin/endnode  # Check timestamp

# Force restart
sudo systemctl stop vpnmanager-endnode
sudo killall endnode
sudo systemctl start vpnmanager-endnode
```

**Issue:** Management server won't start

**Solution:**
```bash
# Check logs
sudo journalctl -u vpnmanager-management -n 100

# Common causes:
# - Database connection failed
# - Port already in use
# - Missing environment variables

# Test database connection
psql -h localhost -U barqnet -d barqnet -c "SELECT 1;"
```

### iOS Issues

**Issue:** App still hangs on launch

**Solution:**
1. Clean build folder (⌘+Shift+K)
2. Delete derived data
3. Check console for actual error (not just hang)
4. Verify server is reachable: `curl http://SERVER_IP:8080/health`

**Issue:** Configuration not loading

**Solution:**
1. Verify `.xcconfig` files in project navigator
2. Check Project Settings → Info → Configurations
3. Clean build and retry
4. Check Info.plist has configuration keys

**Issue:** Wrong environment shown in console

**Solution:**
1. Verify correct scheme selected
2. Check scheme uses correct configuration
3. Clean build folder
4. Rebuild

---

## 📊 Success Criteria

### Backend Success
✅ **Zero** 401 errors in end-node logs for 5 minutes
✅ Health checks successfully received by management server
✅ Existing functionality (auth, users) still works

### iOS Success
✅ App launches without hanging
✅ Correct environment shown in console logs
✅ API requests reach correct server
✅ Can switch between environments easily
✅ No hardcoded IPs in code

---

## 📝 Test Report Template

After testing, please provide this information:

```
# Test Report

**Tester:** Hamad
**Date:** [Date]
**Duration:** [Time spent testing]

## Backend Testing
- Management Server Deployment: ✅ / ❌
- End-Node Deployment: ✅ / ❌
- Health Checks Working: ✅ / ❌
- No 401 Errors: ✅ / ❌
- Existing Features Work: ✅ / ❌

**Issues Found:**
[List any issues]

## iOS Testing
- Configuration Setup: ✅ / ❌
- Development Environment: ✅ / ❌
- Staging Environment: ✅ / ❌
- App Functionality: ✅ / ❌
- No Hanging/Crashes: ✅ / ❌

**Issues Found:**
[List any issues]

## Overall Result
✅ PASS - Ready for production
⚠️ PASS with minor issues - [List issues]
❌ FAIL - [Describe problems]

## Notes
[Any additional observations or feedback]
```

---

## 🆘 Need Help?

If you encounter issues during testing:

1. Check the troubleshooting sections above
2. Look at the console/log output for clues
3. Verify all prerequisites are met
4. Try the rollback procedure if needed
5. Contact the development team with specific error messages

---

**Thank you for testing! Your feedback is crucial for ensuring quality.**

---

**Prepared by:** Development Team
**Last Updated:** 2025-12-04
