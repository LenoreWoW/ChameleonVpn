# Security Bug Fix - Deployment Guide
## User Stays Connected After Deletion

**Bug ID:** SECURITY-001
**Severity:** 🔴 CRITICAL
**Status:** ✅ FIX READY FOR DEPLOYMENT
**Date:** October 26, 2025

---

## Quick Summary

**Problem:** Deleted VPN users remain connected indefinitely.

**Root Cause:** OpenVPN not configured to check Certificate Revocation List (CRL).

**Fix:** Enable CRL verification + improve disconnection logic.

**Deployment Time:** 15-30 minutes per end-node server.

**Downtime:** ~30-60 seconds per end-node.

---

## Pre-Deployment Checklist

Before starting deployment, verify:

- [ ] **Backup current OpenVPN configuration**
  ```bash
  cp /etc/openvpn/server.conf /etc/openvpn/server.conf.backup.$(date +%Y%m%d)
  ```

- [ ] **Access to all end-node servers** (SSH, root/sudo)

- [ ] **Maintenance window scheduled** (optional, but recommended)

- [ ] **Rollback plan understood** (see section below)

- [ ] **Testing environment available** (highly recommended)

---

## Deployment Phases

### Phase 1: Emergency Hotfix (Deploy IMMEDIATELY)
**Time:** 5 minutes
**Downtime:** 30 seconds
**Risk:** Very Low

This enables CRL verification. Deploy to **all end-node servers**.

```bash
# 1. SSH to end-node server
ssh root@endnode-server

# 2. Verify CRL file exists
ls -lh /etc/openvpn/crl.pem

# 3. Add CRL verification to OpenVPN config
echo "" >> /etc/openvpn/server.conf
echo "# Certificate Revocation List - CRITICAL SECURITY" >> /etc/openvpn/server.conf
echo "crl-verify /etc/openvpn/crl.pem" >> /etc/openvpn/server.conf

# 4. Verify configuration syntax
openvpn --config /etc/openvpn/server.conf --test-crypto

# 5. Restart OpenVPN service
systemctl restart openvpn@server

# 6. Verify service is running
systemctl status openvpn@server

# 7. Verify CRL is being used
journalctl -u openvpn@server --since "1 minute ago" | grep -i crl

# 8. Test: Try to connect with a revoked certificate (should fail)
```

**Expected Results:**
- OpenVPN service restarts successfully
- Logs show "CRL" messages
- Revoked certificates are rejected on connection attempt
- **Existing revoked users stay connected until they reconnect**

**If anything goes wrong:**
```bash
# Restore backup
cp /etc/openvpn/server.conf.backup.$(date +%Y%m%d) /etc/openvpn/server.conf
systemctl restart openvpn@server
```

---

### Phase 2: Management Interface (Deploy within 24 hours)
**Time:** 10 minutes
**Downtime:** 30 seconds
**Risk:** Low

This enables immediate user disconnection via management interface.

```bash
# 1. Add management interface to OpenVPN config
cat >> /etc/openvpn/server.conf <<'EOF'

# Management Interface for remote control
management /var/run/openvpn/server.sock unix
management-client-auth
management-log-cache 300
EOF

# 2. Create directory for management socket (if needed)
mkdir -p /var/run/openvpn
chmod 755 /var/run/openvpn

# 3. Restart OpenVPN
systemctl restart openvpn@server

# 4. Verify management socket exists
ls -lh /var/run/openvpn/server.sock

# 5. Test management interface
echo 'status' | nc -U /var/run/openvpn/server.sock

# Expected output: List of connected users
```

**Expected Results:**
- Management socket created at `/var/run/openvpn/server.sock`
- `status` command shows connected users
- Can now disconnect users with `kill <username>` command

---

### Phase 3: Deploy Scripts (Deploy within 1 week)
**Time:** 15 minutes
**Downtime:** None
**Risk:** Very Low

Install helper scripts for automation.

```bash
# 1. Create scripts directory
mkdir -p /opt/vpnmanager/scripts
chmod 755 /opt/vpnmanager/scripts

# 2. Copy scripts from repository
cd /tmp
git clone https://github.com/LenoreWoW/ChameleonVpn.git
# Or download from go-hello-main repository

# 3. Install disconnect script
cp scripts/disconnect-user.sh /opt/vpnmanager/scripts/
chmod +x /opt/vpnmanager/scripts/disconnect-user.sh

# 4. Install client lifecycle scripts
cp scripts/client-connect.sh /opt/vpnmanager/scripts/
cp scripts/client-disconnect.sh /opt/vpnmanager/scripts/
chmod +x /opt/vpnmanager/scripts/client-*.sh

# 5. Install CRL refresh script
cp scripts/refresh-crl.sh /opt/vpnmanager/scripts/
chmod +x /opt/vpnmanager/scripts/refresh-crl.sh

# 6. Create log directory
mkdir -p /var/log/vpnmanager
chmod 755 /var/log/vpnmanager

# 7. Add scripts to OpenVPN config
cat >> /etc/openvpn/server.conf <<'EOF'

# Client lifecycle scripts
script-security 2
client-connect /opt/vpnmanager/scripts/client-connect.sh
client-disconnect /opt/vpnmanager/scripts/client-disconnect.sh
setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF

# 8. Reload OpenVPN (no disconnection)
pkill -SIGUSR1 openvpn

# 9. Verify scripts are working
tail -f /var/log/vpnmanager/connections.log
# Connect a test user and verify log entry appears

# 10. Test disconnect script
/opt/vpnmanager/scripts/disconnect-user.sh <test_username>
```

**Expected Results:**
- Scripts installed in `/opt/vpnmanager/scripts/`
- Connection/disconnection logged to `/var/log/vpnmanager/connections.log`
- Disconnect script successfully terminates user connections

---

### Phase 4: Code Update (Deploy within 1 week)
**Time:** 10 minutes per end-node
**Downtime:** ~10 seconds (service restart)
**Risk:** Medium

Update the end-node API code with improved deletion logic.

```bash
# 1. SSH to build machine (or end-node if building locally)
cd /Users/hassanalsahli/Desktop/go-hello-main

# 2. Verify code changes
git status

# 3. Build new binary
go build -o bin/endnode ./apps/endnode/main.go

# 4. Test binary (dry run)
./bin/endnode --version  # or similar test

# 5. Copy to end-node server
scp bin/endnode root@endnode-server:/opt/vpnmanager/bin/endnode.new

# 6. On end-node server:
ssh root@endnode-server

# 7. Stop current service
systemctl stop vpnmanager-endnode

# 8. Backup current binary
mv /opt/vpnmanager/bin/endnode /opt/vpnmanager/bin/endnode.backup.$(date +%Y%m%d)

# 9. Install new binary
mv /opt/vpnmanager/bin/endnode.new /opt/vpnmanager/bin/endnode
chmod +x /opt/vpnmanager/bin/endnode

# 10. Start service
systemctl start vpnmanager-endnode

# 11. Verify service is running
systemctl status vpnmanager-endnode

# 12. Check API health
curl http://localhost:8080/health

# 13. Test deletion flow
curl -X DELETE http://localhost:8080/api/ovpn/delete/testuser
# Verify logs show improved disconnection logic
```

**Expected Results:**
- New binary running successfully
- Health check returns OK
- User deletion triggers management interface disconnect
- Logs show improved disconnection attempts

**Rollback if needed:**
```bash
systemctl stop vpnmanager-endnode
mv /opt/vpnmanager/bin/endnode.backup.$(date +%Y%m%d) /opt/vpnmanager/bin/endnode
systemctl start vpnmanager-endnode
```

---

### Phase 5: Automation (Deploy within 2 weeks)
**Time:** 10 minutes
**Downtime:** None
**Risk:** Very Low

Set up automatic CRL refresh via cron.

```bash
# 1. Create cron job file
cat > /etc/cron.d/vpnmanager-crl <<'EOF'
# Refresh CRL every 15 minutes to catch revocations quickly
# This ensures deleted users are blocked within 15 minutes maximum
*/15 * * * * root /opt/vpnmanager/scripts/refresh-crl.sh >/dev/null 2>&1
EOF

# 2. Set proper permissions
chmod 644 /etc/cron.d/vpnmanager-crl

# 3. Verify cron job is registered
crontab -l  # or: systemctl restart cron

# 4. Test CRL refresh script manually
/opt/vpnmanager/scripts/refresh-crl.sh

# 5. Verify CRL log
tail -20 /var/log/vpnmanager/crl.log

# 6. Wait 15 minutes and verify cron executed
tail -20 /var/log/vpnmanager/crl.log
# Should show new entry approximately every 15 minutes
```

**Expected Results:**
- Cron job runs every 15 minutes
- CRL refreshed automatically
- OpenVPN signaled to reload CRL
- Logs show regular CRL updates

---

## Verification & Testing

### Test Scenario 1: Immediate Disconnection

```bash
# 1. Create test user
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "target_server_id": "test-node",
    "port": 1194,
    "protocol": "udp"
  }'

# 2. Connect with test user
# (use OpenVPN client with downloaded testuser.ovpn file)

# 3. Verify user is connected
echo 'status' | nc -U /var/run/openvpn/server.sock | grep testuser

# 4. Delete user while connected
curl -X DELETE http://localhost:8080/api/users/testuser

# 5. Immediately check if still connected (should be disconnected within 2 seconds)
echo 'status' | nc -U /var/run/openvpn/server.sock | grep testuser
# Expected: No output (user disconnected)

# 6. Check logs
tail -20 /var/log/vpnmanager/connections.log
# Expected: DISCONNECTED entry for testuser

# 7. Try to reconnect with same certificate
# Expected: Connection rejected with "Certificate revoked" error
```

**Success Criteria:**
- ✅ User disconnected within 2 seconds of deletion
- ✅ Cannot reconnect (CRL rejection)
- ✅ Disconnection logged

---

### Test Scenario 2: CRL Verification Active

```bash
# 1. Manually revoke a test certificate
cd /opt/vpnmanager/easyrsa
./easyrsa revoke testuser2
./easyrsa gen-crl
cp pki/crl.pem /etc/openvpn/crl.pem

# 2. Signal OpenVPN to reload
pkill -SIGUSR1 openvpn

# 3. Verify CRL contains revoked cert
openssl crl -in /etc/openvpn/crl.pem -noout -text | grep testuser2

# 4. Try to connect with revoked certificate
# Expected: Immediate rejection at connection time

# 5. Check OpenVPN logs
journalctl -u openvpn@server -n 50 | grep -i crl
# Expected: CRL verification messages, rejection logged
```

**Success Criteria:**
- ✅ Revoked certificate appears in CRL
- ✅ Connection rejected immediately
- ✅ Logs show CRL rejection

---

### Test Scenario 3: Management Interface

```bash
# 1. List connected users
echo 'status' | nc -U /var/run/openvpn/server.sock

# 2. Disconnect specific user
/opt/vpnmanager/scripts/disconnect-user.sh alice

# 3. Verify user disconnected
echo 'status' | nc -U /var/run/openvpn/server.sock | grep alice
# Expected: No output

# 4. Check script logs
cat /var/log/vpnmanager/disconnections.log
# Expected: Successful disconnection entry
```

**Success Criteria:**
- ✅ Management interface responds to commands
- ✅ User disconnected successfully
- ✅ Logs show successful operation

---

## Monitoring & Alerting

### Key Metrics to Monitor

```bash
# 1. Number of CRL rejections (should increase after deletions)
journalctl -u openvpn@server --since today | grep -i "crl" | wc -l

# 2. Failed disconnect attempts (should be zero or very low)
grep "FAILED" /var/log/vpnmanager/disconnections.log | tail -10

# 3. Time to disconnect (should be < 2 seconds)
# Parse connection logs to measure disconnect time after deletion

# 4. Active connections
echo 'status' | nc -U /var/run/openvpn/server.sock | grep "^CLIENT_LIST" | wc -l

# 5. CRL update frequency
stat -c %y /etc/openvpn/crl.pem
# Should update every 15 minutes

# 6. Revoked certificates count
openssl crl -in /etc/openvpn/crl.pem -noout -text | grep -c "Serial Number:"
```

### Set Up Alerts (Optional)

Create `/opt/vpnmanager/scripts/check-security.sh`:
```bash
#!/bin/bash
# Security monitoring script - run every 5 minutes via cron

# Alert if CRL not updated in last hour
CRL_AGE=$(stat -c %Y /etc/openvpn/crl.pem)
NOW=$(date +%s)
AGE=$((NOW - CRL_AGE))

if [ $AGE -gt 3600 ]; then
    echo "ALERT: CRL not updated in last hour" | logger -t vpnmanager-alert
    # Send email/Slack notification here
fi

# Alert if management interface not responding
if ! echo 'status' | nc -U /var/run/openvpn/server.sock >/dev/null 2>&1; then
    echo "ALERT: Management interface not responding" | logger -t vpnmanager-alert
fi
```

Run via cron:
```cron
*/5 * * * * root /opt/vpnmanager/scripts/check-security.sh
```

---

## Rollback Plan

### If Phase 1 (CRL verification) causes issues:

```bash
# Remove crl-verify line from config
sudo sed -i '/crl-verify/d' /etc/openvpn/server.conf

# Restart OpenVPN
systemctl restart openvpn@server
```

### If Phase 2 (Management interface) causes issues:

```bash
# Remove management lines from config
sudo sed -i '/management/d' /etc/openvpn/server.conf

# Restart OpenVPN
systemctl restart openvpn@server
```

### If Phase 4 (Code update) causes issues:

```bash
# Restore old binary
systemctl stop vpnmanager-endnode
cp /opt/vpnmanager/bin/endnode.backup.$(date +%Y%m%d) /opt/vpnmanager/bin/endnode
systemctl start vpnmanager-endnode
```

### Complete Rollback (Emergency):

```bash
# Restore backup configuration
cp /etc/openvpn/server.conf.backup.$(date +%Y%m%d) /etc/openvpn/server.conf
systemctl restart openvpn@server

# Restore old endnode binary
systemctl stop vpnmanager-endnode
mv /opt/vpnmanager/bin/endnode.backup.$(date +%Y%m%d) /opt/vpnmanager/bin/endnode
systemctl start vpnmanager-endnode

# Verify services running
systemctl status openvpn@server
systemctl status vpnmanager-endnode
```

---

## Post-Deployment Checklist

After completing all phases, verify:

- [ ] **CRL verification active:** `grep "crl-verify" /etc/openvpn/server.conf`
- [ ] **Management interface working:** `echo 'status' | nc -U /var/run/openvpn/server.sock`
- [ ] **Scripts installed:** `ls -lh /opt/vpnmanager/scripts/`
- [ ] **Scripts executable:** `file /opt/vpnmanager/scripts/*.sh`
- [ ] **Code updated:** `./bin/endnode --version` (if version info available)
- [ ] **CRL cron active:** `grep vpnmanager-crl /etc/cron.d/vpnmanager-crl`
- [ ] **Logs being written:** `ls -lh /var/log/vpnmanager/`
- [ ] **Test scenarios pass:** All 3 test scenarios successful
- [ ] **Monitoring configured:** Security checks running
- [ ] **Documentation updated:** This guide followed and verified

---

## Troubleshooting

### Issue: OpenVPN fails to start after adding crl-verify

**Cause:** CRL file doesn't exist or is invalid

**Solution:**
```bash
# Generate CRL if missing
cd /opt/vpnmanager/easyrsa
./easyrsa gen-crl
cp pki/crl.pem /etc/openvpn/crl.pem
chmod 644 /etc/openvpn/crl.pem

# Verify CRL is valid
openssl crl -in /etc/openvpn/crl.pem -noout -text
```

---

### Issue: Management socket not created

**Cause:** Permission denied or directory doesn't exist

**Solution:**
```bash
# Create directory
mkdir -p /var/run/openvpn
chmod 755 /var/run/openvpn

# Restart OpenVPN
systemctl restart openvpn@server

# Check logs
journalctl -u openvpn@server -n 50 | grep management
```

---

### Issue: Disconnect script fails

**Cause:** Socket path incorrect or nc (netcat) not installed

**Solution:**
```bash
# Install netcat if missing
apt-get install netcat  # Debian/Ubuntu
yum install nmap-ncat   # RHEL/CentOS

# Find correct socket path
find /var/run -name "*.sock" 2>/dev/null | grep openvpn

# Update socket path in script if needed
vim /opt/vpnmanager/scripts/disconnect-user.sh
```

---

## Support & Documentation

**Related Documentation:**
- **Bug Analysis:** `SECURITY_BUG_ANALYSIS_USER_DELETION.md`
- **Code Changes:** See git commit history
- **OpenVPN Documentation:** https://openvpn.net/community-resources/

**Need Help?**
1. Check logs: `/var/log/vpnmanager/` and `journalctl -u openvpn@server`
2. Review this deployment guide
3. Contact backend team with specific error messages

---

## Summary

**Total Deployment Time:** 1-2 hours for all phases
**Critical Phases:** Phase 1 (CRL) and Phase 2 (Management Interface)
**Optional Phases:** Phase 5 (Automation) - recommended but not critical

**Priority Order:**
1. ✅ **Phase 1 (IMMEDIATE):** Enable CRL verification
2. ✅ **Phase 2 (24 hours):** Enable management interface
3. ⏭️ **Phase 3 (1 week):** Install scripts
4. ⏭️ **Phase 4 (1 week):** Update code
5. ⏭️ **Phase 5 (2 weeks):** Automation

**Security Improvement:** Critical vulnerability eliminated after Phase 1 & 2 complete.

---

**Deployment Completed By:** ___________________
**Date:** ___________________
**Verified By:** ___________________
**Sign-off:** ___________________
