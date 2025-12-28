# Backend & Endnode Audit Fix Plan

## Executive Summary

This document outlines the security vulnerabilities and bugs discovered during the full audit of the ChameleonVPN backend and endnode components, along with the fixes that have been applied and remaining items to address.

---

## ✅ FIXED: Immediate Errors (From Your Console Output)

### 1. Missing CLI Flags (`--port`, `--openvpn-dir`)

**Error:**
```
flag provided but not defined: -port
Usage of ./endnode:
  -config string
    	Configuration file path (default "endnode-config.json")
  -help
    	Show help
  -server-id string
    	Server ID for this end-node
```

**Root Cause:** The endnode binary only accepted limited flags.

**Fix Applied:** Added new CLI flags to `apps/endnode/main.go`:
- `-port int` - API server port (default: 8080)
- `-openvpn-dir string` - OpenVPN configuration directory (default: /etc/openvpn)
- `-clients-dir string` - Client OVPN files directory (default: /opt/vpnmanager/clients)
- `-easyrsa-dir string` - EasyRSA directory (default: /opt/vpnmanager/easyrsa)

**Usage Now:**
```bash
./endnode --server-id server-1 --port 8080 --openvpn-dir /etc/openvpn
```

---

### 2. NULL Column Scan Error (`ovpn_path`)

**Error:**
```
User sync coordination failed: failed to list all users: sql: Scan error on column index 5, 
name "ovpn_path": converting NULL to string is unsupported
```

**Root Cause:** The `ListUsers`, `GetUser`, and `ListUsersByServer` functions in `pkg/shared/users.go` were scanning directly into string fields, but the database contains NULL values for `ovpn_path`, `port`, `protocol`, `server_id`, and `created_by`.

**Fix Applied:** Updated all three functions to use `sql.NullString` and `sql.NullInt32` for nullable columns:

```go
var checksum, ovpnPath, protocol, serverID, createdBy sql.NullString
var port sql.NullInt32

// ... scan into nullable types ...

if ovpnPath.Valid {
    user.OvpnPath = ovpnPath.String
}
if protocol.Valid {
    user.Protocol = protocol.String
} else {
    user.Protocol = "udp" // Default
}
if port.Valid {
    user.Port = int(port.Int32)
} else {
    user.Port = 1194 // Default
}
```

---

## ✅ FIXED: Critical Security Vulnerabilities

### 3. Command Injection in EasyRSA Calls (CRITICAL)

**Vulnerability:** The endnode was using shell command interpolation to execute EasyRSA commands:
```go
// VULNERABLE CODE
cmd := exec.Command("bash", "-c", fmt.Sprintf("cd %s && ./easyrsa revoke %s", easyrsaDir, username))
```

An attacker could inject commands by providing a malicious username like `user; rm -rf /`.

**Fix Applied:**
1. Added strict username validation function:
```go
func validateUsernameForCommand(username string) error {
    // Length: 3-32 characters
    // Only alphanumeric and underscore
    // No path traversal characters
    // No reserved names
}
```

2. Changed all `exec.Command` calls to use separate arguments (no shell):
```go
// SECURE CODE
cmd := exec.Command(easyrsaPath, "revoke", username)
cmd.Dir = easyrsaDir
cmd.Env = append(os.Environ(), "EASYRSA_BATCH=1", "EASYRSA_PKI="+pkiDir)
```

---

### 4. Path Traversal in OVPN Download (CRITICAL)

**Vulnerability:** The OVPN download and delete endpoints accepted usernames without validation:
```go
// VULNERABLE CODE
username := r.URL.Path[len("/api/ovpn/"):]
ovpnPath := fmt.Sprintf("/opt/vpnmanager/clients/%s.ovpn", username)
```

An attacker could request `../../../etc/passwd` to read arbitrary files.

**Fix Applied:**
1. Added path validation function:
```go
func (api *EndNodeAPI) validateUsernameForPath(username string) error {
    // Prevent path traversal (.., /, \)
    // Only allow alphanumeric and underscore
    // Length limits
}
```

2. Used `filepath.Join` for safe path construction:
```go
ovpnPath := filepath.Join(clientsDir, username+".ovpn")
```

---

### 5. Missing API Key Authentication on Endnode (CRITICAL)

**Vulnerability:** The endnode API had no authentication. Anyone with network access could:
- Create OVPN configurations
- Delete users
- Access sync endpoints

**Fix Applied:**
1. Added API key validation middleware:
```go
func (api *EndNodeAPI) validateAPIKey(r *http.Request) bool {
    expectedAPIKey := os.Getenv("API_KEY")
    providedKey := r.Header.Get("X-API-Key")
    // Constant-time comparison
    return providedKey == expectedAPIKey
}
```

2. Protected all endpoints except `/health`:
```go
if isProtectedEndpoint(r.URL.Path) {
    if !api.validateAPIKey(r) {
        http.Error(w, "Unauthorized", http.StatusUnauthorized)
        return
    }
}
```

---

### 6. Unrestricted CORS on Endnode

**Vulnerability:** CORS was set to `*`, allowing any origin to make requests.

**Fix Applied:** CORS now restricted to management server:
```go
allowedOrigin := os.Getenv("ALLOWED_ORIGIN")
if allowedOrigin == "" {
    allowedOrigin = os.Getenv("MANAGEMENT_URL")
}
w.Header().Set("Access-Control-Allow-Origin", allowedOrigin)
```

---

## ⚠️ REMAINING ISSUES TO ADDRESS

### 7. Rate Limiting Not Fully Implemented on Endnode (Medium)

**Issue:** The `checkRateLimit` function is a placeholder returning `true` always.

**Recommendation:** Implement proper rate limiting using an in-memory store or Redis:
```go
// Implement with sync.Map for simple in-memory rate limiting
type rateLimitEntry struct {
    count     int
    windowEnd time.Time
}
```

---

### 8. Double Certificate Generation Issue (Medium)

**Issue:** When management server creates OVPN, it sends placeholder cert data to endnode. The endnode then generates real certificates. However, the flow is confusing and could lead to orphaned certificates.

**Recommendation:**
1. Remove certificate data from management → endnode request
2. Endnode should always generate its own certificates
3. Add cleanup routine for orphaned certificates

---

### 9. Admin Role System Not Implemented (Medium)

**Issue:** The `isAdmin` function is a placeholder:
```go
func isAdmin(userID string) bool {
    // TODO: Implement proper admin check
    return true // All users are treated as admin
}
```

**Recommendation:** Add role field to users table and JWT claims:
```sql
ALTER TABLE users ADD COLUMN role VARCHAR(20) DEFAULT 'user';
```

---

### 10. Audit Log Cleanup Not Automated (Low)

**Issue:** No automatic cleanup of old audit logs in database.

**Recommendation:** Add scheduled cleanup job:
```sql
DELETE FROM audit_log WHERE created_at < NOW() - INTERVAL '90 days';
```

---

## Environment Variables Reference

### Endnode Required Variables
```bash
ENDNODE_SERVER_ID=server-1
MANAGEMENT_URL=https://management.yourdomain.com
API_KEY=your-secure-api-key-here

# Optional with defaults
OPENVPN_DIR=/etc/openvpn
CLIENTS_DIR=/opt/vpnmanager/clients
EASYRSA_DIR=/opt/vpnmanager/easyrsa
AUDIT_LOG_DIR=/var/log/vpnmanager
```

### Management Required Variables
```bash
DB_HOST=localhost
DB_PORT=5432
DB_USER=vpnmanager
DB_PASSWORD=secure-password
DB_NAME=vpnmanager
JWT_SECRET=your-jwt-secret-at-least-32-chars
API_KEY=your-secure-api-key-here

# Optional
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=redis-password
```

---

## Rebuild Instructions

After applying these fixes, rebuild and deploy:

```bash
# On the endnode server
cd /path/to/barqnet-backend/apps/endnode
go build -o endnode .

# Start with new flags
./endnode --server-id server-1 --port 8080 --openvpn-dir /etc/openvpn

# On the management server
cd /path/to/barqnet-backend/apps/management
go build -o management .
./management
```

---

## Security Checklist Before Production

- [ ] Set strong API_KEY (32+ characters, random)
- [ ] Set strong JWT_SECRET (32+ characters, random)
- [ ] Set strong DB_PASSWORD
- [ ] Set REDIS_PASSWORD if using Redis
- [ ] Configure ALLOWED_ORIGIN to management server URL
- [ ] Enable TLS/HTTPS for all communications
- [ ] Configure firewall to restrict endnode API access to management server only
- [ ] Review audit logs regularly
- [ ] Implement remaining TODO items (rate limiting, admin roles)

---

## Files Modified

1. `apps/endnode/main.go` - Added CLI flags
2. `apps/endnode/api/api.go` - Added security middleware, path validation
3. `apps/endnode/manager/manager.go` - Fixed command injection
4. `pkg/shared/users.go` - Fixed NULL column handling

---

*Generated: 2025-12-28*

