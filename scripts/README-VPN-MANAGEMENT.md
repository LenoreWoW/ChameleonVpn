# BarqNet VPN Management Scripts

This directory contains scripts for managing OpenVPN server operations, specifically for the **CRITICAL SECURITY FIX** addressing the user deletion bug where deleted users remain connected.

## 📋 Overview

These scripts implement the security fix described in `SECURITY_BUG_ANALYSIS_USER_DELETION.md` and `SECURITY_BUG_FIX_DEPLOYMENT.md`.

**Critical Bug Fixed:** When a VPN user is deleted, their certificate is revoked and the CRL is updated, but they remain connected indefinitely because:
1. OpenVPN server doesn't have CRL verification enabled
2. No active session disconnection mechanism
3. Server restart doesn't disconnect clients (they auto-reconnect)

## 🗂️ Files

### 1. `openvpn-server.conf.template`
**Purpose:** Production-ready OpenVPN server configuration with CRL support

**Critical Settings:**
```conf
# CRITICAL: Enable Certificate Revocation List checking
crl-verify /etc/openvpn/crl.pem

# CRITICAL: Enable management interface for immediate disconnection
management /var/run/openvpn/server.sock unix

# Client lifecycle monitoring
client-connect /opt/barqnet/scripts/client-connect.sh
client-disconnect /opt/barqnet/scripts/client-disconnect.sh
```

**Deployment:**
```bash
# Backup existing config
sudo cp /etc/openvpn/server.conf /etc/openvpn/server.conf.backup

# Copy template
sudo cp openvpn-server.conf.template /etc/openvpn/server.conf

# Restart OpenVPN
sudo systemctl restart openvpn@server
```

---

### 2. `disconnect-user.sh`
**Purpose:** Immediately disconnect a VPN user by username

**Usage:**
```bash
sudo ./disconnect-user.sh <username>
```

**How it works:**
1. Validates username format
2. Tries multiple management socket paths
3. Sends disconnect command via management interface
4. Verifies user is no longer connected
5. Logs action to syslog and file

**Example:**
```bash
sudo ./disconnect-user.sh alice
# Output: User 'alice' has been disconnected successfully
```

**Requirements:**
- OpenVPN management interface must be enabled
- `nc` (netcat) must be installed
- Must run as root or with sudo

---

### 3. `client-connect.sh`
**Purpose:** Called by OpenVPN when a client connects

**Security Checks:**
1. **CRL Verification:** Double-checks certificate is not revoked
2. **Username Validation:** Ensures alphanumeric + underscore only
3. **Rate Limiting:** Blocks >5 connections per IP per 60 seconds

**Logs:**
- `/var/log/barqnet/connections.log` - All connections
- `/var/log/barqnet/security.log` - Security events
- Syslog entries for system monitoring

**Deployment:**
```bash
# Copy to OpenVPN scripts directory
sudo mkdir -p /opt/barqnet/scripts
sudo cp client-connect.sh /opt/barqnet/scripts/
sudo chmod +x /opt/barqnet/scripts/client-connect.sh

# Ensure log directory exists
sudo mkdir -p /var/log/barqnet
```

**OpenVPN Configuration Required:**
```conf
script-security 2
client-connect /opt/barqnet/scripts/client-connect.sh
```

---

### 4. `client-disconnect.sh`
**Purpose:** Called by OpenVPN when a client disconnects

**Features:**
- Logs connection duration (human-readable: "2h 15m 30s")
- Logs data transferred (human-readable: "150MB")
- Statistics in parseable format for analytics
- Alerts on suspicious activity:
  - High data transfer (>10GB)
  - Long connections (>24 hours)
- Automatic log rotation (>100MB)
- Cleanup of temporary files

**Logs:**
- `/var/log/barqnet/connections.log` - Human-readable
- `/var/log/barqnet/statistics.log` - Machine-parseable
- `/var/log/barqnet/alerts.log` - Security alerts

**Deployment:**
```bash
sudo cp client-disconnect.sh /opt/barqnet/scripts/
sudo chmod +x /opt/barqnet/scripts/client-disconnect.sh
```

**OpenVPN Configuration Required:**
```conf
client-disconnect /opt/barqnet/scripts/client-disconnect.sh
```

---

### 5. `refresh-crl.sh`
**Purpose:** Automatically refresh Certificate Revocation List every 15 minutes

**Process:**
1. Generate new CRL with `easyrsa gen-crl`
2. Validate CRL with `openssl crl`
3. Backup current CRL
4. Copy new CRL to `/etc/openvpn/crl.pem`
5. Signal OpenVPN to reload (SIGUSR1)
6. Verify reload in logs
7. Log statistics (revoked count, file size, etc.)

**Deployment:**
```bash
# Copy script
sudo cp refresh-crl.sh /opt/barqnet/scripts/
sudo chmod +x /opt/barqnet/scripts/refresh-crl.sh

# Test run
sudo /opt/barqnet/scripts/refresh-crl.sh

# Add to cron (every 15 minutes)
sudo crontab -e
# Add this line:
*/15 * * * * /opt/barqnet/scripts/refresh-crl.sh
```

**Why Every 15 Minutes?**
- Ensures revoked certificates are blocked quickly
- Balances security vs. system load
- Standard practice for VPN CRL refresh

**Logs:**
- `/var/log/barqnet/crl.log` - CRL refresh history
- Syslog entries for monitoring

---

## 🚀 Quick Deployment Guide

### Phase 1: Enable CRL Verification (IMMEDIATE - CRITICAL)
```bash
# Edit OpenVPN config
sudo nano /etc/openvpn/server.conf

# Add this line:
crl-verify /etc/openvpn/crl.pem

# Restart OpenVPN
sudo systemctl restart openvpn@server
```

**Downtime:** ~30 seconds
**Impact:** Revoked certificates immediately blocked

---

### Phase 2: Enable Management Interface (24 hours)
```bash
# Edit OpenVPN config
sudo nano /etc/openvpn/server.conf

# Add these lines:
management /var/run/openvpn/server.sock unix
management-client-auth
management-log-cache 300

# Restart OpenVPN
sudo systemctl restart openvpn@server
```

**Downtime:** ~30 seconds
**Impact:** Enables immediate user disconnection

---

### Phase 3: Deploy Scripts (1 week)
```bash
# Create directory structure
sudo mkdir -p /opt/barqnet/scripts
sudo mkdir -p /var/log/barqnet

# Copy all scripts
sudo cp disconnect-user.sh /opt/barqnet/scripts/
sudo cp client-connect.sh /opt/barqnet/scripts/
sudo cp client-disconnect.sh /opt/barqnet/scripts/
sudo cp refresh-crl.sh /opt/barqnet/scripts/

# Make executable
sudo chmod +x /opt/barqnet/scripts/*.sh

# Test disconnect script
sudo /opt/barqnet/scripts/disconnect-user.sh testuser

# Add lifecycle scripts to OpenVPN config
sudo nano /etc/openvpn/server.conf
# Add:
script-security 2
client-connect /opt/barqnet/scripts/client-connect.sh
client-disconnect /opt/barqnet/scripts/client-disconnect.sh

# Restart OpenVPN
sudo systemctl restart openvpn@server
```

**Downtime:** None (except final restart: ~30s)
**Impact:** Connection monitoring and security checks enabled

---

### Phase 4: Automation (2 weeks)
```bash
# Set up CRL auto-refresh
sudo crontab -e
# Add:
*/15 * * * * /opt/barqnet/scripts/refresh-crl.sh

# Test cron job
sudo /opt/barqnet/scripts/refresh-crl.sh

# Check logs
sudo tail -f /var/log/barqnet/crl.log
```

**Downtime:** None
**Impact:** Automatic CRL updates every 15 minutes

---

## 🧪 Testing

### Test 1: Immediate Disconnection
```bash
# 1. Create test user
sudo /opt/barqnet/easyrsa/easyrsa build-client-full testuser nopass

# 2. Connect test user (from client machine)
# Connect via OpenVPN client

# 3. Delete test user
# Via management API: DELETE /api/v1/users/testuser

# 4. Verify disconnection
echo 'status' | sudo nc -U /var/run/openvpn/server.sock | grep testuser
# Should return: empty (user not connected)

# 5. Expected result
# User disconnected within 2 seconds
```

---

### Test 2: CRL Blocking
```bash
# 1. Revoke certificate
cd /opt/barqnet/easyrsa
./easyrsa revoke testuser

# 2. Generate CRL
./easyrsa gen-crl

# 3. Copy CRL
sudo cp pki/crl.pem /etc/openvpn/crl.pem

# 4. Signal OpenVPN to reload
sudo pkill -SIGUSR1 openvpn

# 5. Attempt connection (should fail)
# Try connecting with revoked certificate
# Expected: Connection rejected immediately
```

---

### Test 3: Management Interface
```bash
# Test socket exists
ls -la /var/run/openvpn/server.sock

# Test status command
echo 'status' | sudo nc -U /var/run/openvpn/server.sock

# Test disconnect command
echo 'kill testuser' | sudo nc -U /var/run/openvpn/server.sock
```

---

## 📊 Monitoring

### Check Active Connections
```bash
echo 'status' | sudo nc -U /var/run/openvpn/server.sock
```

### Check CRL Status
```bash
sudo openssl crl -in /etc/openvpn/crl.pem -noout -text
```

### View Connection Logs
```bash
sudo tail -f /var/log/barqnet/connections.log
```

### View Security Alerts
```bash
sudo tail -f /var/log/barqnet/alerts.log
```

### Check CRL Refresh
```bash
sudo tail -f /var/log/barqnet/crl.log
```

---

## 🔧 Troubleshooting

### Issue: Management socket not found
**Problem:** `/var/run/openvpn/server.sock` doesn't exist

**Solution:**
1. Check OpenVPN config has management interface enabled
2. Restart OpenVPN: `sudo systemctl restart openvpn@server`
3. Check logs: `sudo journalctl -u openvpn@server -n 50`

---

### Issue: CRL verification not working
**Problem:** Revoked certificates still accepted

**Solution:**
1. Verify `crl-verify` directive in `/etc/openvpn/server.conf`
2. Check CRL file exists: `ls -la /etc/openvpn/crl.pem`
3. Validate CRL: `openssl crl -in /etc/openvpn/crl.pem -noout -text`
4. Restart OpenVPN: `sudo systemctl restart openvpn@server`

---

### Issue: Scripts not executing
**Problem:** Client connect/disconnect scripts not running

**Solution:**
1. Check `script-security 2` in OpenVPN config
2. Verify scripts are executable: `sudo chmod +x /opt/barqnet/scripts/*.sh`
3. Check script paths in config match actual locations
4. Check logs: `sudo tail -f /var/log/openvpn/openvpn.log`

---

### Issue: Disconnect command fails
**Problem:** `disconnect-user.sh` returns error

**Solution:**
1. Run with sudo: `sudo ./disconnect-user.sh username`
2. Check user is actually connected first
3. Verify management interface is enabled
4. Try manual disconnect: `echo 'kill username' | sudo nc -U /var/run/openvpn/server.sock`

---

## 📚 References

- [OpenVPN Management Interface](https://openvpn.net/community-resources/management-interface/)
- [OpenVPN CRL Verification](https://openvpn.net/community-resources/reference-manual-for-openvpn-2-6/#certificate-revocation-list-crl-options)
- [EasyRSA Documentation](https://easy-rsa.readthedocs.io/)
- BarqNet Security Docs:
  - `SECURITY_BUG_ANALYSIS_USER_DELETION.md`
  - `SECURITY_BUG_FIX_DEPLOYMENT.md`

---

## ⚠️ Security Notes

1. **CRITICAL:** Always enable `crl-verify` in production
2. **NEVER** skip certificate verification in production
3. **ALWAYS** test in staging before deploying to production
4. **MONITOR** connection logs for suspicious activity
5. **ROTATE** logs regularly to prevent disk space issues
6. **BACKUP** CRL before regenerating
7. **AUDIT** all user deletions and disconnections

---

## 🔒 Compliance

These scripts help maintain compliance with:
- **SOC 2:** Access control and audit logging
- **ISO 27001:** Information security management
- **GDPR:** Right to be forgotten (immediate access revocation)
- **PCI-DSS:** Strong access control measures

---

## 📞 Support

For issues or questions:
1. Review `SECURITY_BUG_FIX_DEPLOYMENT.md` for detailed deployment guide
2. Check `SECURITY_BUG_ANALYSIS_USER_DELETION.md` for technical details
3. Review OpenVPN logs: `sudo journalctl -u openvpn@server`
4. Test scripts manually before automating

---

**Last Updated:** October 26, 2025
**Version:** 1.0
**Status:** Production Ready
