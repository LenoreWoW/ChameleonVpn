# End-to-End Testing Guide
## Testing Management Server → VPN Server → End Node → iOS/Android Clients

**Date:** November 16, 2025
**Purpose:** Verify complete system integration

---

## 🎯 Testing Architecture

```
iOS/Android Clients
        ↓
    (OpenVPN)
        ↓
Management Server (Port 8080)
        ↓
    VPN Server (Port 8081)
        ↓
    End Node (Port 8082)
```

---

## Step 1: Start Backend Services

### Terminal 1 - Management Server

```bash
cd ~/ChameleonVpn/barqnet-backend

# Fix dependencies first (if not done):
go mod tidy

# Build:
go build -o management ./apps/management

# Run:
./management

# Should see:
# Server starting on port 8080...
# Database connected
# ✓ Management server ready
```

### Terminal 2 - VPN Server

```bash
cd ~/ChameleonVpn/barqnet-backend

# Build:
go build -o vpn ./apps/vpn

# Run:
./vpn

# Should see:
# VPN server starting on port 8081...
# Connected to management server
# OpenVPN daemon started
# ✓ VPN server ready
```

### Terminal 3 - End Node

```bash
cd ~/ChameleonVpn/barqnet-backend

# Build:
go build -o end-node ./apps/end-node

# Run:
./end-node

# Should see:
# End node starting on port 8082...
# Connected to management server
# Node ID: node-xxxx-xxxx-xxxx
# ✓ End node ready
```

---

## Step 2: Verify Backend Health

### Test Management API:

```bash
# Health check:
curl http://localhost:8080/health

# Expected:
{"status":"healthy","database":"connected"}
```

### Test VPN Server:

```bash
# Status:
curl http://localhost:8081/status

# Expected:
{"status":"running","connected_clients":0}
```

### Test End Node:

```bash
# Status:
curl http://localhost:8082/status

# Expected:
{"status":"active","load":0.0}
```

---

## Step 3: Create Test User (Management Server)

### Register a test user:

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+97450000001",
    "password": "TestPass123!"
  }'

# Expected:
{"user_id":"xxx","message":"User registered"}
```

### Request OTP:

```bash
curl -X POST http://localhost:8080/api/auth/request-otp \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+97450000001"
  }'

# Expected:
{"message":"OTP sent"}

# Check server logs for OTP code (development mode):
# [OTP] Code for +97450000001: 123456
```

### Verify OTP and Login:

```bash
# Verify OTP:
curl -X POST http://localhost:8080/api/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+97450000001",
    "otp_code": "123456"
  }'

# Expected:
{"token":"eyJhbGc...","user_id":"xxx"}

# Save the token for next requests:
TOKEN="eyJhbGc..."
```

---

## Step 4: Request VPN Configuration

### Get VPN config from management server:

```bash
curl -X POST http://localhost:8080/api/vpn/config \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"

# Expected (sample):
{
  "config": "client\ndev tun\nproto udp\nremote vpn.server.com 1194\n...",
  "server_address": "vpn.server.com",
  "protocol": "udp",
  "port": 1194
}

# Save this config to a file:
curl -X POST http://localhost:8080/api/vpn/config \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  | jq -r '.config' > test-config.ovpn
```

---

## Step 5: Test iOS App

### Build iOS app (if not built):

```bash
cd ~/ChameleonVpn/workvpn-ios

# Install dependencies:
pod install

# Open in Xcode:
open WorkVPN.xcworkspace
```

### In Xcode:

1. Select simulator or device
2. Build and Run (⌘R)
3. Grant VPN permission when prompted
4. Import the `test-config.ovpn` file
5. Tap "Connect"

### Expected Behavior:

```
✅ Status: Connecting...
✅ Status: Authenticating...
✅ Status: Connected
✅ IP Address: 10.8.0.x (VPN IP)
✅ Traffic stats updating
```

### Verify in Server Logs (Terminal 2):

```
[VPN Server] New connection from iOS client
[VPN Server] Authentication successful
[VPN Server] Client assigned IP: 10.8.0.6
[VPN Server] ✓ Client connected
```

---

## Step 6: Test Android App

### Setup Android SDK (if not done):

```bash
cd ~/ChameleonVpn/workvpn-android

# Create local.properties:
echo "sdk.dir=/Users/YOUR_USERNAME/Library/Android/sdk" > local.properties

# Build:
./gradlew assembleDebug

# Install to device/emulator:
./gradlew installDebug
```

### In Android App:

1. Launch app
2. Grant VPN permission
3. Import `test-config.ovpn`
4. Tap "Connect"

### Expected Behavior:

```
✅ Status: Connecting...
✅ Status: Connected
✅ Traffic encrypted
✅ Stats showing real data
```

---

## Step 7: Test VPN Connectivity

### On iOS/Android (while connected):

```bash
# Test internet connectivity:
# Open Safari/Chrome
# Visit: https://ipinfo.io

# Should show VPN server IP, not your real IP
```

### Test DNS leak protection:

```
# Visit: https://dnsleaktest.com
# Run standard test

# Should show VPN server DNS, not ISP DNS
```

### Test traffic routing:

```
# Visit various websites
# Check server logs - should see traffic

[VPN Server] Traffic from 10.8.0.6 → 8.8.8.8:53 (DNS)
[VPN Server] Traffic from 10.8.0.6 → 142.250.80.46:443 (HTTPS)
```

---

## Step 8: Test End Node Integration

### Send request through end node:

```bash
# From iOS/Android while connected to VPN:
# Make HTTP request to test endpoint

curl -X GET "http://api.example.com/test" \
  -H "X-End-Node-Route: true"

# Should route through end node
```

### Verify in End Node Logs (Terminal 3):

```
[End Node] Received request from VPN client 10.8.0.6
[End Node] Routing to api.example.com
[End Node] Response: 200 OK
[End Node] Traffic: 1.2KB
```

---

## Step 9: Test Disconnection

### On iOS/Android:

1. Tap "Disconnect"

### Expected Behavior:

```
✅ Status: Disconnecting...
✅ Status: Disconnected
✅ Traffic stats reset
✅ IP returns to real IP
```

### Verify in Server Logs:

```
[VPN Server] Client 10.8.0.6 disconnecting
[VPN Server] Connection closed gracefully
[VPN Server] ✓ Client cleanup complete
```

---

## 🧪 Automated Testing Script

### Create test script:

```bash
#!/bin/bash
# test-e2e.sh

echo "=== BarqNet E2E Test ==="

echo "[1/5] Testing Management Server..."
curl -s http://localhost:8080/health | jq '.'

echo "[2/5] Testing VPN Server..."
curl -s http://localhost:8081/status | jq '.'

echo "[3/5] Testing End Node..."
curl -s http://localhost:8082/status | jq '.'

echo "[4/5] Creating test user..."
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"phone_number":"+97450000099","password":"Test123!"}' \
  | jq -r '.token')

echo "[5/5] Getting VPN config..."
curl -s -X POST http://localhost:8080/api/vpn/config \
  -H "Authorization: Bearer $TOKEN" \
  | jq -r '.config' > auto-test-config.ovpn

echo "✅ Backend tests passed!"
echo "📁 Config saved to: auto-test-config.ovpn"
echo ""
echo "Next: Import config to iOS/Android and test connection"
```

### Run:

```bash
chmod +x test-e2e.sh
./test-e2e.sh
```

---

## 📊 Expected Results Summary

| Component | Expected Status |
|-----------|----------------|
| Management Server | ✅ Running on :8080 |
| VPN Server | ✅ Running on :8081 |
| End Node | ✅ Running on :8082 |
| iOS App | ✅ Builds and connects |
| Android App | ✅ Builds and connects |
| VPN Encryption | ✅ Real OpenVPN encryption |
| Traffic Routing | ✅ Through VPN tunnel |
| DNS Protection | ✅ No leaks |
| Authentication | ✅ JWT tokens work |
| End Node | ✅ Routes traffic |

---

## 🐛 Troubleshooting

### iOS won't connect:

```bash
# Check server logs for errors
# Verify .ovpn config is valid:
cat test-config.ovpn | grep "remote"

# Should show correct server address
```

### Android SDK error:

```bash
# Fix local.properties:
echo "sdk.dir=$HOME/Library/Android/sdk" > local.properties
```

### Backend dependency errors:

```bash
cd ~/ChameleonVpn/barqnet-backend
go mod tidy
```

### Database connection failed:

```bash
# Check database is running:
psql -U vpnmanager -d vpnmanager -h localhost

# Update .env with correct credentials
```

---

## ✅ Success Criteria

You know everything works when:

- ✅ All 3 backend services start without errors
- ✅ Health endpoints return success
- ✅ iOS app connects and shows "Connected"
- ✅ Android app connects and shows encrypted traffic
- ✅ Real IP is hidden (check ipinfo.io)
- ✅ DNS is not leaking (check dnsleaktest.com)
- ✅ Traffic goes through VPN tunnel (check server logs)
- ✅ Disconnection works cleanly

---

**Need Help?**

Check logs in all 3 terminals - errors will show the issue!
