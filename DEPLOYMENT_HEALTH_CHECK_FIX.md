# Health Check Fix - Production Deployment Guide

**Issue:** End-node health checks failing with 401 Unauthorized
**Fix:** Created dedicated unauthenticated health check endpoint
**Priority:** HIGH - Affects service monitoring
**Date:** 2025-12-04

---

## 🎯 Overview

### What Was Fixed
- Created new endpoint `/api/endnodes-health/{serverID}` for end-node health submissions
- This endpoint does NOT require JWT authentication (health checks should be unauthenticated)
- Updated end-node to use the new endpoint
- Removed unnecessary Authorization header from health check requests

### Why This Fix is Important
- Health checks are critical for service monitoring
- 401 errors prevent proper health monitoring of end-nodes
- Follows industry best practice: health checks should be lightweight and unauthenticated

---

## 📋 Changes Made

### Backend Changes

#### 1. Management Server (`apps/management/api/api.go`)
- **Line 112:** Added route for unauthenticated health check endpoint
- **Lines 530-551:** Added `handleEndNodeHealthSubmission()` handler

#### 2. End-Node (`apps/endnode/manager/manager.go`)
- **Line 177:** Changed health check URL from `/api/endnodes/{serverID}/health` to `/api/endnodes-health/{serverID}`
- **Line 184:** Removed Authorization header (no longer needed)

---

## 🚀 Deployment Steps

### Prerequisites
- Git access to the repository
- SSH access to management and end-node servers
- Sudo privileges on both servers
- Services currently running

### Step 1: Backup Current State

```bash
# On Management Server
ssh user@management-server
sudo systemctl stop vpnmanager-management
sudo cp /opt/barqnet/bin/management /opt/barqnet/bin/management.backup.$(date +%Y%m%d_%H%M%S)

# On End-Node Server(s)
ssh user@endnode-server
sudo systemctl stop vpnmanager-endnode
sudo cp /opt/barqnet/bin/endnode /opt/barqnet/bin/endnode.backup.$(date +%Y%m%d_%H%M%S)
```

### Step 2: Deploy Management Server Update

```bash
# On Management Server
ssh user@192.168.10.217  # Adjust IP as needed

# Navigate to project directory
cd ~/ChameleonVpn/barqnet-backend/apps/management

# Pull latest changes (or upload updated files)
git pull origin main  # or: git fetch && git checkout <commit-hash>

# Verify changes
git log -1 --stat  # Should show changes to api/api.go

# Build
go build -o management .

# Run tests if available
go test ./...

# Install new binary
sudo cp management /opt/barqnet/bin/management
sudo chown barqnet:barqnet /opt/barqnet/bin/management
sudo chmod 755 /opt/barqnet/bin/management

# Start service
sudo systemctl start vpnmanager-management

# Verify service started successfully
sudo systemctl status vpnmanager-management
sudo journalctl -u vpnmanager-management -n 50 --no-pager

# Test health endpoint
curl http://localhost:8080/health
```

**Expected Output:**
```json
{"status":"healthy","timestamp":1733277600,"version":"1.0.0","serverID":"management-server"}
```

### Step 3: Deploy End-Node Update(s)

Repeat for each end-node server:

```bash
# On End-Node Server
ssh user@192.168.10.248  # Adjust IP for each end-node

# Navigate to project directory
cd ~/ChameleonVpn/barqnet-backend/apps/endnode

# Pull latest changes
git pull origin main

# Verify changes
git log -1 --stat  # Should show changes to manager/manager.go

# Build
go build -o endnode .

# Run tests if available
go test ./...

# Install new binary
sudo cp endnode /opt/barqnet/bin/endnode
sudo chown barqnet:barqnet /opt/barqnet/bin/endnode
sudo chmod 755 /opt/barqnet/bin/endnode

# Start service
sudo systemctl start vpnmanager-endnode

# Verify service started successfully
sudo systemctl status vpnmanager-endnode
sudo journalctl -u vpnmanager-endnode -n 50 --no-pager
```

### Step 4: Verify Health Checks Working

```bash
# On End-Node Server - Monitor logs
sudo journalctl -u vpnmanager-endnode -f

# You should see (every 30 seconds):
# - No more "health check failed with status: 401" errors
# - Successful health check submissions

# On Management Server - Monitor logs
sudo journalctl -u vpnmanager-management -f | grep -i health

# You should see:
# - "Health check received from end-node: server-1"
# - HTTP 200 responses for /api/endnodes-health/ requests
```

---

## ✅ Testing Checklist

### Pre-Deployment Tests (Development Environment)

- [ ] Management server compiles without errors
- [ ] End-node compiles without errors
- [ ] Unit tests pass (if available)
- [ ] Verify new endpoint exists: `curl http://localhost:8080/api/endnodes-health/test-server`
- [ ] Verify old endpoint still requires auth: `curl http://localhost:8080/api/endnodes/test-server/health`

### Post-Deployment Tests (Production Environment)

#### Management Server Tests
- [ ] Service starts successfully
- [ ] Health endpoint responds: `curl http://localhost:8080/health`
- [ ] New health check endpoint accessible: `curl -X POST http://localhost:8080/api/endnodes-health/server-1 -H "Content-Type: application/json" -d '{"status":"healthy"}'`
- [ ] API root endpoint responds: `curl http://localhost:8080/api`
- [ ] Authenticated endpoints still require JWT: `curl http://localhost:8080/api/users` (should return 401)

#### End-Node Tests
- [ ] Service starts successfully
- [ ] End-node health endpoint responds: `curl http://localhost:8080/health`
- [ ] No 401 errors in logs for health checks
- [ ] Health check logs show successful submissions every 30 seconds
- [ ] End-node appears healthy in management server logs

#### Integration Tests
- [ ] End-node successfully registers with management server
- [ ] Health checks flow from end-node → management server
- [ ] Management server receives and logs health checks
- [ ] No authentication errors in either service logs
- [ ] Existing functionality (user creation, OVPN generation) still works

---

## 🔄 Rollback Procedure

If issues occur after deployment:

```bash
# On Management Server
sudo systemctl stop vpnmanager-management
sudo cp /opt/barqnet/bin/management.backup.YYYYMMDD_HHMMSS /opt/barqnet/bin/management
sudo systemctl start vpnmanager-management
sudo systemctl status vpnmanager-management

# On End-Node Server(s)
sudo systemctl stop vpnmanager-endnode
sudo cp /opt/barqnet/bin/endnode.backup.YYYYMMDD_HHMMSS /opt/barqnet/bin/endnode
sudo systemctl start vpnmanager-endnode
sudo systemctl status vpnmanager-endnode
```

---

## 🐛 Troubleshooting

### Issue: Management server won't start after update

**Check:**
```bash
sudo journalctl -u vpnmanager-management -n 100 --no-pager
```

**Common causes:**
- Database connection issues
- Port 8080 already in use
- Missing environment variables
- Permission issues on binary

**Solution:**
```bash
# Check if port is in use
sudo netstat -tlnp | grep 8080

# Check environment variables
sudo systemctl cat vpnmanager-management | grep Environment

# Check binary permissions
ls -l /opt/barqnet/bin/management
```

### Issue: End-node still shows 401 errors

**Check:**
```bash
# Verify new binary is running
ps aux | grep endnode
sudo systemctl status vpnmanager-endnode

# Check binary version (should be recent)
ls -l /opt/barqnet/bin/endnode
stat /opt/barqnet/bin/endnode
```

**Solution:**
```bash
# Force restart with new binary
sudo systemctl stop vpnmanager-endnode
sudo killall endnode  # Force kill if needed
sudo systemctl start vpnmanager-endnode
```

### Issue: Health checks not being received by management server

**Check:**
```bash
# On management server
sudo journalctl -u vpnmanager-management -f | grep -i "health\|endnode"

# Check if endpoint is registered
curl -v http://localhost:8080/api/endnodes-health/server-1
```

**Solution:**
- Verify management server was updated and restarted
- Check network connectivity between servers
- Verify MANAGEMENT_URL in end-node configuration

---

## 📊 Success Metrics

After deployment, verify these metrics:

1. **Health Check Success Rate:** 100% (no 401 errors)
2. **Health Check Frequency:** Every 30 seconds per end-node
3. **Response Time:** < 100ms for health check endpoint
4. **Error Rate:** 0% for `/api/endnodes-health/` endpoint

**Monitor for 1 hour after deployment to ensure stability.**

---

## 📝 Notes

- This fix follows REST API best practices for health check endpoints
- Health checks should never require authentication (industry standard)
- The old authenticated endpoint (`/api/endnodes/{id}/health`) is still available for backward compatibility but not used
- Future enhancement: Add health check metrics dashboard

---

## 👤 Contact

**Deployed by:** [Your Name]
**Date:** [Deployment Date]
**Tested by:** Hamad
**Approved by:** [Approver Name]

---

## 🔗 Related Documentation

- `QUICK_FIXES.md` - Quick reference for this fix
- `API_DOCUMENTATION.md` - Full API documentation
- `DEPLOYMENT.md` - General deployment procedures
