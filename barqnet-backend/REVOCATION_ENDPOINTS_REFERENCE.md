# Token Revocation Endpoints - Quick Reference

## Endpoint Summary

| Endpoint | Method | Auth Required | Purpose |
|----------|--------|---------------|---------|
| `/v1/auth/revoke` | POST | No | Revoke single refresh token (logout) |
| `/v1/auth/revoke-all` | POST | Yes (Bearer) | Revoke all user tokens (emergency) |
| `/v1/auth/refresh` | POST | No | Refresh tokens (now checks blacklist) |

---

## 1. Revoke Single Token (Normal Logout)

### Endpoint
```
POST /v1/auth/revoke
```

### Request
```bash
curl -X POST http://localhost:8080/v1/auth/revoke \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "reason": "logout"
  }'
```

### Request Body Schema
```json
{
  "refresh_token": "string (required)",
  "reason": "string (optional)"
}
```

**Reason Values**:
- `logout` - Normal user logout (default)
- `password_change` - User changed password
- `device_change` - User switched devices
- `security_concern` - User suspects compromise
- `session_expired` - Session timeout

### Success Response (200 OK)
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

### Error Responses

**400 Bad Request** - Missing or invalid refresh_token
```json
{
  "success": false,
  "message": "refresh_token is required"
}
```

**401 Unauthorized** - Invalid token
```json
{
  "success": false,
  "message": "Invalid refresh token: token has expired"
}
```

**500 Internal Server Error** - Database error
```json
{
  "success": false,
  "message": "Failed to revoke token"
}
```

### Notes
- Token can be revoked multiple times (idempotent operation)
- Already-revoked tokens return success
- Token is hashed with SHA-256 before storage (never stored in plaintext)
- Revocation is logged in audit_log table

---

## 2. Revoke All User Tokens (Emergency Logout)

### Endpoint
```
POST /v1/auth/revoke-all
```

### Request
```bash
curl -X POST http://localhost:8080/v1/auth/revoke-all \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -d '{
    "password": "MySecureP@ssw0rd",
    "reason": "device_lost"
  }'
```

### Headers
- `Authorization: Bearer <access_token>` - **Required**

### Request Body Schema
```json
{
  "password": "string (required)",
  "reason": "string (optional)"
}
```

**Reason Values**:
- `user_requested_revoke_all` - User initiated (default)
- `device_lost` - Lost device
- `device_stolen` - Stolen device
- `account_breach` - Suspected account compromise
- `suspicious_activity` - Unusual activity detected
- `security_audit` - Security review

### Success Response (200 OK)
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

### Error Responses

**400 Bad Request** - Missing password
```json
{
  "success": false,
  "message": "password is required for security verification"
}
```

**401 Unauthorized** - Invalid access token
```json
{
  "success": false,
  "message": "Invalid access token: token has been revoked"
}
```

**401 Unauthorized** - Incorrect password
```json
{
  "success": false,
  "message": "Invalid password"
}
```

**500 Internal Server Error** - Database error
```json
{
  "success": false,
  "message": "Internal server error"
}
```

### Security Notes
- Requires valid access token in Authorization header
- Requires password confirmation to prevent unauthorized revocation
- All revocations are logged with IP address and user agent
- Audit log entry created with action `REVOKE_ALL_TOKENS`
- User should change password after revoke-all if security incident

---

## 3. Refresh Token (Updated with Blacklist Check)

### Endpoint
```
POST /v1/auth/refresh
```

### Request
```bash
curl -X POST http://localhost:8080/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }'
```

### Request Body Schema
```json
{
  "token": "string (required)"
}
```

### Success Response (200 OK)
```json
{
  "success": true,
  "message": "Tokens refreshed successfully",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 86400
  }
}
```

### Error Responses

**401 Unauthorized** - Token is blacklisted (revoked)
```json
{
  "success": false,
  "message": "Invalid refresh token: token has been revoked"
}
```

**401 Unauthorized** - Token is invalid or expired
```json
{
  "success": false,
  "message": "Invalid refresh token: token has expired"
}
```

### What Changed
- Now checks token against blacklist before refreshing
- Revoked tokens are immediately rejected
- Same request/response format as before

---

## Client Integration Examples

### JavaScript/TypeScript

```typescript
// Logout - Revoke single token
async function logout() {
  const refreshToken = localStorage.getItem('refreshToken');

  try {
    const response = await fetch('/v1/auth/revoke', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        refresh_token: refreshToken,
        reason: 'logout'
      })
    });

    if (response.ok) {
      console.log('Token revoked successfully');
    }
  } catch (error) {
    console.error('Revocation failed:', error);
  } finally {
    // Always clear local storage
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
    window.location.href = '/login';
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
    alert('All devices logged out. Please login again.');
    localStorage.clear();
    window.location.href = '/login';
  } else {
    const error = await response.json();
    throw new Error(error.message);
  }
}
```

### Swift (iOS)

```swift
// Logout - Revoke single token
func logout(refreshToken: String) async throws {
    let url = URL(string: "\(baseURL)/v1/auth/revoke")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = ["refresh_token": refreshToken, "reason": "logout"]
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw AuthError.revocationFailed
    }

    // Clear keychain
    KeychainHelper.deleteToken(key: "accessToken")
    KeychainHelper.deleteToken(key: "refreshToken")
}

// Emergency logout from all devices
func logoutAllDevices(accessToken: String, password: String) async throws {
    let url = URL(string: "\(baseURL)/v1/auth/revoke-all")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let body = ["password": password, "reason": "device_lost"]
    request.httpBody = try JSONEncoder().encode(body)

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw AuthError.revocationFailed
    }

    // Clear keychain
    KeychainHelper.deleteAll()
}
```

### Kotlin (Android)

```kotlin
// Logout - Revoke single token
suspend fun logout(refreshToken: String) {
    val request = RevokeTokenRequest(
        refreshToken = refreshToken,
        reason = "logout"
    )

    try {
        apiService.revokeToken(request)
        secureStorage.clear()
        navigationController.navigateToLogin()
    } catch (e: Exception) {
        Log.e(TAG, "Logout error", e)
        // Clear tokens anyway
        secureStorage.clear()
    }
}

// Emergency logout from all devices
suspend fun logoutAllDevices(accessToken: String, password: String) {
    val request = RevokeAllTokensRequest(
        password = password,
        reason = "user_requested_security_logout"
    )

    try {
        val response = apiService.revokeAllTokens(
            authorization = "Bearer $accessToken",
            request = request
        )

        Toast.makeText(context, "All devices logged out", Toast.LENGTH_LONG).show()
        secureStorage.clear()
        navigationController.navigateToLogin()
    } catch (e: HttpException) {
        if (e.code() == 401) {
            throw InvalidPasswordException()
        }
        throw e
    }
}
```

---

## Testing

### Using curl

```bash
# 1. Register/Login to get tokens
TOKENS=$(curl -s -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+1234567890", "password": "TestPassword123"}')

ACCESS_TOKEN=$(echo $TOKENS | jq -r '.data.accessToken')
REFRESH_TOKEN=$(echo $TOKENS | jq -r '.data.refreshToken')

# 2. Revoke refresh token
curl -X POST http://localhost:8080/v1/auth/revoke \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\": \"$REFRESH_TOKEN\", \"reason\": \"test\"}"

# 3. Try to use revoked token (should fail)
curl -X POST http://localhost:8080/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$REFRESH_TOKEN\"}"

# 4. Revoke all tokens
curl -X POST http://localhost:8080/v1/auth/revoke-all \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{"password": "TestPassword123", "reason": "test"}'
```

### Using the test script

```bash
chmod +x test-token-revocation.sh
./test-token-revocation.sh
```

---

## Database Queries

### Check blacklist entries
```sql
-- View active blacklist entries
SELECT * FROM v_active_blacklist LIMIT 10;

-- View all blacklist entries for a user
SELECT * FROM token_blacklist
WHERE phone_number = '+1234567890'
ORDER BY revoked_at DESC;

-- View blacklist statistics
SELECT * FROM v_blacklist_statistics;

-- View daily revocation stats
SELECT * FROM token_revocation_stats
ORDER BY stat_date DESC LIMIT 7;
```

### Manual cleanup
```sql
-- Run cleanup function
SELECT * FROM cleanup_expired_blacklist_entries();
```

---

## Security Considerations

1. **Token Hashing**: Tokens are hashed with SHA-256 before storage (never plaintext)
2. **Password Confirmation**: Revoke-all requires password to prevent unauthorized revocation
3. **Audit Logging**: All revocations logged with IP, user agent, and reason
4. **Idempotent**: Revoking same token multiple times is safe (returns success)
5. **Automatic Cleanup**: Expired entries removed automatically by cleanup job
6. **Rate Limiting**: Consider adding rate limits to prevent abuse

---

## Monitoring

### Key Metrics
- Total revocations per day
- Revocations by reason
- Users with multiple revocations (potential abuse)
- Average time between login and revocation
- Failed revoke-all attempts (wrong password)

### Alerts
- Unusual spike in revocations
- Same user revoking tokens repeatedly
- High rate of failed password attempts on revoke-all
- Blacklist table size exceeding threshold

### Logs to Monitor
```bash
# View revocation logs
grep "TOKEN_REVOKED\|TOKEN_REVOKE_ALL" /var/log/barqnet-backend.log

# View audit events
psql -U postgres -d barqnet -c "
SELECT * FROM audit_log
WHERE action IN ('TOKEN_REVOKED', 'REVOKE_ALL_TOKENS', 'REVOKE_ALL_FAILED')
ORDER BY timestamp DESC LIMIT 50;
"
```

---

## Support

For implementation questions or issues:
- Documentation: `/barqnet-backend/TOKEN_REVOCATION_SYSTEM.md`
- Test Script: `/barqnet-backend/test-token-revocation.sh`
- Migration: `/barqnet-backend/migrations/005_add_token_blacklist.sql`
