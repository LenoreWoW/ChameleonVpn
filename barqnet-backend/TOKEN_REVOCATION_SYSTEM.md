# Token Revocation/Blacklist System

## Overview

The token revocation system provides secure logout functionality by maintaining a blacklist of revoked JWT refresh tokens. This is a **production-recommended** security feature that prevents compromised or stolen tokens from being reused after logout.

## Architecture

### Components

1. **Database Table**: `token_blacklist` - Stores SHA-256 hashes of revoked tokens
2. **Blacklist Package**: `pkg/shared/token_blacklist.go` - Token revocation logic
3. **JWT Validation**: `pkg/shared/jwt.go` - Enhanced JWT validation with blacklist checking
4. **Revocation Endpoints**: `apps/management/api/auth.go` - HTTP handlers for token revocation
5. **Cleanup Job**: `cmd/token-cleanup/main.go` - Periodic cleanup of expired entries

### Security Design

- **Never stores plaintext tokens** - Only SHA-256 hashes are stored
- **Automatic expiry cleanup** - Expired entries are automatically removed
- **Audit logging** - All revocations are logged for security monitoring
- **Indexed queries** - Fast blacklist lookups with proper database indexes
- **Statistics tracking** - Real-time monitoring of revocation patterns

## Database Schema

### token_blacklist Table

```sql
CREATE TABLE token_blacklist (
    id SERIAL PRIMARY KEY,
    token_hash CHAR(64) NOT NULL UNIQUE,     -- SHA-256 hash of token
    user_id INTEGER NOT NULL,                -- Owner of the token
    phone_number VARCHAR(20),                -- Denormalized for queries
    revoked_at TIMESTAMP NOT NULL,           -- When token was revoked
    expires_at TIMESTAMP NOT NULL,           -- Original token expiry
    revoked_by VARCHAR(50),                  -- 'user', 'admin', 'security', 'system'
    reason VARCHAR(255),                     -- Revocation reason
    ip_address INET,                         -- Request IP
    user_agent TEXT,                         -- Request user agent
    device_info TEXT,                        -- Optional device info
    session_id VARCHAR(255)                  -- Optional session tracking
);
```

### Indexes

- `idx_blacklist_token_hash` - Primary lookup (unique)
- `idx_blacklist_expires_at` - Cleanup queries (partial index on active entries)
- `idx_blacklist_user_id` - User queries
- `idx_blacklist_phone_number` - Audit queries
- `idx_blacklist_revoked_at` - Analytics queries
- `idx_blacklist_reason` - Pattern analysis
- `idx_blacklist_ip_address` - Security monitoring

### Views

- `v_active_blacklist` - Shows only non-expired entries
- `v_blacklist_statistics` - Real-time statistics

### Functions

- `cleanup_expired_blacklist_entries()` - Remove expired tokens
- `revoke_all_user_tokens()` - Emergency bulk revocation
- `update_revocation_stats()` - Automatic statistics tracking

## API Endpoints

### 1. Revoke Single Token

**Endpoint**: `POST /v1/auth/revoke`

**Description**: Revoke a single refresh token (normal logout)

**Request Body**:
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "reason": "logout"  // Optional: "logout", "password_change", etc.
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "message": "Token revoked successfully",
  "data": {
    "revoked_at": 1699200000,
    "reason": "logout"
  }
}
```

**Error Responses**:
- `400 Bad Request` - Invalid JSON or missing refresh_token
- `401 Unauthorized` - Invalid or expired refresh token
- `500 Internal Server Error` - Database error

**Usage Example**:
```bash
curl -X POST http://localhost:8080/v1/auth/revoke \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "your_refresh_token_here",
    "reason": "logout"
  }'
```

### 2. Revoke All User Tokens

**Endpoint**: `POST /v1/auth/revoke-all`

**Description**: Revoke all tokens for a user (emergency logout from all devices)

**Headers**:
- `Authorization: Bearer <access_token>` - Required

**Request Body**:
```json
{
  "password": "user_password",  // Required for security
  "reason": "device_lost"       // Optional: security incident description
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "message": "All tokens marked for revocation. Please login again on all devices.",
  "data": {
    "revoked_at": 1699200000,
    "reason": "device_lost",
    "note": "Please change your password if you suspect compromise."
  }
}
```

**Error Responses**:
- `400 Bad Request` - Missing password
- `401 Unauthorized` - Invalid password or access token
- `500 Internal Server Error` - Database error

**Usage Example**:
```bash
curl -X POST http://localhost:8080/v1/auth/revoke-all \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_access_token_here" \
  -d '{
    "password": "MySecureP@ssw0rd",
    "reason": "device_lost"
  }'
```

### 3. Token Refresh (Updated)

**Endpoint**: `POST /v1/auth/refresh`

**Description**: Refresh access token (now checks blacklist)

**Request Body**:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs..."  // Refresh token
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "message": "Tokens refreshed successfully",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
    "expiresIn": 86400
  }
}
```

**Error Responses**:
- `401 Unauthorized` - Token is blacklisted (revoked)
- `401 Unauthorized` - Token is invalid or expired

## Integration Guide

### Step 1: Run Migration

Apply the database migration:

```bash
cd barqnet-backend
psql -U postgres -d barqnet -f migrations/005_add_token_blacklist.sql
```

Or use the migration system:

```go
db, err := shared.NewDatabase(dbConfig)
if err != nil {
    log.Fatal(err)
}
err = db.RunMigrations("./migrations")
```

### Step 2: Update Authentication Handler

The `AuthHandler` now includes blacklist checking automatically:

```go
// Create auth handler (blacklist is initialized internally)
authHandler := api.NewAuthHandler(db, otpService, rateLimiter)

// Register routes
http.HandleFunc("/v1/auth/revoke", authHandler.HandleRevokeToken)
http.HandleFunc("/v1/auth/revoke-all", authHandler.HandleRevokeAllTokens)
http.HandleFunc("/v1/auth/refresh", authHandler.HandleRefresh)  // Now checks blacklist
```

### Step 3: Setup Cleanup Cron Job

Run the cleanup job periodically to remove expired entries:

**Option A: Manual Execution**
```bash
cd barqnet-backend
go run cmd/token-cleanup/main.go
```

**Option B: Systemd Timer** (Linux)
```ini
# /etc/systemd/system/token-cleanup.service
[Unit]
Description=Token Blacklist Cleanup Job
After=network.target

[Service]
Type=oneshot
User=barqnet
WorkingDirectory=/opt/barqnet-backend
Environment="DB_HOST=localhost"
Environment="DB_PORT=5432"
Environment="DB_USER=barqnet"
Environment="DB_NAME=barqnet"
EnvironmentFile=/etc/barqnet/db.env
ExecStart=/opt/barqnet-backend/token-cleanup

# /etc/systemd/system/token-cleanup.timer
[Unit]
Description=Run token cleanup hourly

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:
```bash
sudo systemctl enable token-cleanup.timer
sudo systemctl start token-cleanup.timer
```

**Option C: Cron Job** (Linux/macOS)
```bash
# Edit crontab
crontab -e

# Add entry to run hourly at minute 0
0 * * * * cd /opt/barqnet-backend && ./token-cleanup >> /var/log/token-cleanup.log 2>&1
```

**Option D: Database Scheduled Job** (PostgreSQL)
```sql
-- Using pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule cleanup job to run every hour
SELECT cron.schedule('token-cleanup', '0 * * * *',
  'SELECT * FROM cleanup_expired_blacklist_entries()');
```

### Step 4: Client Integration

**Web/Desktop Client (TypeScript/JavaScript)**:

```typescript
// Logout: Revoke refresh token
async function logout() {
  try {
    const refreshToken = localStorage.getItem('refreshToken');

    await fetch('/v1/auth/revoke', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        refresh_token: refreshToken,
        reason: 'logout'
      })
    });

    // Clear local storage regardless of API response
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');

    // Redirect to login
    window.location.href = '/login';
  } catch (error) {
    console.error('Logout error:', error);
    // Still clear tokens locally
    localStorage.clear();
  }
}

// Emergency logout from all devices
async function logoutAllDevices(password: string) {
  const accessToken = localStorage.getItem('accessToken');

  const response = await fetch('/v1/auth/revoke-all', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`
    },
    body: JSON.stringify({
      password: password,
      reason: 'user_requested_security_logout'
    })
  });

  if (response.ok) {
    localStorage.clear();
    window.location.href = '/login';
  } else {
    const error = await response.json();
    throw new Error(error.message);
  }
}
```

**iOS Client (Swift)**:

```swift
func logout(refreshToken: String, reason: String = "logout") async throws {
    let url = URL(string: "\(baseURL)/v1/auth/revoke")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = ["refresh_token": refreshToken, "reason": reason]
    request.httpBody = try JSONEncoder().encode(body)

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw AuthError.logoutFailed
    }

    // Clear keychain
    KeychainHelper.deleteToken(key: "accessToken")
    KeychainHelper.deleteToken(key: "refreshToken")
}
```

**Android Client (Kotlin)**:

```kotlin
suspend fun logout(refreshToken: String, reason: String = "logout") {
    val request = RevokeTokenRequest(
        refreshToken = refreshToken,
        reason = reason
    )

    try {
        val response = apiService.revokeToken(request)

        // Clear stored tokens
        secureStorage.clear()

        // Navigate to login
        navigationController.navigateToLogin()
    } catch (e: Exception) {
        Log.e(TAG, "Logout error", e)
        // Clear tokens anyway for security
        secureStorage.clear()
    }
}
```

## Monitoring & Analytics

### Check Blacklist Statistics

```sql
-- View current statistics
SELECT * FROM v_blacklist_statistics;

-- View daily revocation stats
SELECT * FROM token_revocation_stats ORDER BY stat_date DESC LIMIT 30;

-- View active blacklist entries
SELECT * FROM v_active_blacklist LIMIT 100;

-- Find users with most revocations
SELECT
    phone_number,
    COUNT(*) as revocation_count,
    MAX(revoked_at) as last_revocation
FROM token_blacklist
WHERE revoked_at > NOW() - INTERVAL '7 days'
GROUP BY phone_number
ORDER BY revocation_count DESC
LIMIT 10;
```

### Application Monitoring

```go
// Get blacklist statistics via API
blacklist := shared.NewTokenBlacklist(db)
stats, err := blacklist.GetBlacklistStats()
if err != nil {
    log.Printf("Failed to get stats: %v", err)
} else {
    log.Printf("Blacklist stats: %+v", stats)
}
```

## Performance Considerations

### Database Performance

- **Indexed Lookups**: Token hash lookup is O(1) with unique index
- **Automatic Cleanup**: Expired entries removed to prevent table bloat
- **Partial Indexes**: Only active entries indexed for faster queries
- **Connection Pooling**: Reuse database connections

### Scalability

**Current Implementation** (Single Database):
- Supports 100K+ blacklist entries efficiently
- Sub-millisecond blacklist checks
- Suitable for most production deployments

**High-Scale Options** (1M+ active users):

1. **Redis Cache Layer**:
   ```go
   // Check Redis first, fallback to PostgreSQL
   isBlacklisted := redis.Exists("blacklist:" + tokenHash)
   if !isBlacklisted {
       isBlacklisted = db.IsBlacklisted(tokenHash)
   }
   ```

2. **Bloom Filter**:
   ```go
   // Fast probabilistic check (no false negatives)
   if !bloomFilter.MightContain(tokenHash) {
       return false  // Definitely not blacklisted
   }
   // Check database for confirmation
   return db.IsBlacklisted(tokenHash)
   ```

3. **Database Sharding**:
   - Partition by user_id or token_hash prefix
   - Distribute load across multiple databases

## Security Best Practices

1. **Token Rotation**: Generate new refresh token on each refresh
2. **Short-lived Access Tokens**: 15-60 minute expiry recommended
3. **Longer Refresh Tokens**: 7-30 days expiry
4. **Password Changes**: Revoke all tokens when password changes
5. **Suspicious Activity**: Use revoke-all for security incidents
6. **Audit Logging**: Monitor revocation patterns for anomalies
7. **Rate Limiting**: Limit revocation requests to prevent abuse

## Troubleshooting

### Token Still Valid After Revocation

**Problem**: Revoked token still works

**Solutions**:
1. Check if blacklist validation is enabled:
   ```go
   claims, err := shared.ValidateJWTWithBlacklist(token, blacklist)
   ```

2. Verify token hash matches:
   ```sql
   SELECT token_hash FROM token_blacklist
   WHERE user_id = ? ORDER BY revoked_at DESC LIMIT 1;
   ```

3. Check database connectivity

### Cleanup Job Not Running

**Problem**: Expired entries accumulating

**Solutions**:
1. Verify cron job is active:
   ```bash
   systemctl status token-cleanup.timer
   ```

2. Check cleanup logs:
   ```bash
   journalctl -u token-cleanup
   ```

3. Run manual cleanup:
   ```bash
   go run cmd/token-cleanup/main.go --verbose
   ```

### Performance Degradation

**Problem**: Slow token validation

**Solutions**:
1. Check index usage:
   ```sql
   EXPLAIN ANALYZE
   SELECT id FROM token_blacklist
   WHERE token_hash = 'hash' AND expires_at > NOW();
   ```

2. Monitor table size:
   ```sql
   SELECT
       pg_size_pretty(pg_total_relation_size('token_blacklist')) as total_size,
       COUNT(*) as row_count,
       COUNT(*) FILTER (WHERE expires_at < NOW()) as expired_count
   FROM token_blacklist;
   ```

3. Optimize cleanup frequency (run more often)

## Future Enhancements

1. **User-Level Revocation Timestamp**: Track when all tokens were invalidated per user
2. **Device Fingerprinting**: Track and revoke by device
3. **Geographic Anomaly Detection**: Auto-revoke on suspicious location changes
4. **Token Usage Analytics**: Track token usage patterns
5. **Redis Integration**: Faster blacklist checks for high-traffic systems
6. **Revocation Webhooks**: Notify clients of revocations in real-time

## References

- JWT Best Practices: https://tools.ietf.org/html/rfc8725
- Token Revocation: https://tools.ietf.org/html/rfc7009
- OWASP JWT Security: https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html

## Support

For issues or questions:
1. Check logs: `journalctl -u barqnet-backend`
2. Review audit logs: `SELECT * FROM audit_log WHERE action LIKE 'TOKEN_%'`
3. Contact: backend-team@barqnet.com
