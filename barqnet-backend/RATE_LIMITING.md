# Rate Limiting Documentation

## Overview

ChameleonVPN backend implements production-ready, Redis-based rate limiting to prevent abuse and ensure fair API usage. The system uses a sliding window algorithm with Redis for distributed rate limiting across multiple server instances.

## Features

- **Redis-backed**: Distributed rate limiting using Redis for multi-instance deployments
- **Graceful degradation**: If Redis is unavailable, the system logs warnings and allows requests (degraded mode)
- **Multiple rate limit types**: Different limits for OTP, login, registration, and general API access
- **Standards-compliant**: Returns HTTP 429 status code with standard rate limit headers
- **Configurable**: All limits configurable via environment variables
- **Production-ready**: Includes proper error handling, logging, and monitoring

## Architecture

### Components

1. **RateLimiter** (`pkg/shared/rate_limit.go`)
   - Manages Redis connection
   - Implements sliding window algorithm
   - Provides rate limit checking and tracking

2. **Rate Limit Middleware** (`apps/management/api/api.go`)
   - Applied to all API endpoints
   - Adds rate limit headers to responses
   - Returns 429 when limits exceeded

3. **Endpoint-specific Rate Limiting** (`apps/management/api/auth.go`)
   - OTP endpoints: Limited per phone number
   - Login endpoints: Limited per phone number
   - Registration endpoints: Limited per IP address

## Rate Limit Types

### 1. OTP Send Rate Limit

**Type**: `RateLimitOTP`
**Key**: Phone number
**Default**: 5 requests per hour
**Purpose**: Prevent OTP spam and SMS service abuse

```go
// Environment variables
RATE_LIMIT_OTP_MAX=5
RATE_LIMIT_OTP_WINDOW_MINUTES=60
```

**Endpoints affected**:
- `POST /v1/auth/send-otp`

### 2. Login Rate Limit

**Type**: `RateLimitLogin`
**Key**: Phone number
**Default**: 10 attempts per hour
**Purpose**: Prevent brute force password attacks

```go
// Environment variables
RATE_LIMIT_LOGIN_MAX=10
RATE_LIMIT_LOGIN_WINDOW_MINUTES=60
```

**Endpoints affected**:
- `POST /v1/auth/login`

### 3. Registration Rate Limit

**Type**: `RateLimitRegister`
**Key**: IP address
**Default**: 3 registrations per hour
**Purpose**: Prevent mass account creation

```go
// Environment variables
RATE_LIMIT_REGISTER_MAX=3
RATE_LIMIT_REGISTER_WINDOW_MINUTES=60
```

**Endpoints affected**:
- `POST /v1/auth/register`

### 4. General API Rate Limit

**Type**: `RateLimitAPI`
**Key**: IP address
**Default**: 100 requests per minute
**Purpose**: Prevent API abuse and DDoS

```go
// Environment variables
RATE_LIMIT_API_MAX=100
RATE_LIMIT_API_WINDOW_SECONDS=60
```

**Endpoints affected**:
- All API endpoints (middleware level)

## Configuration

### Required: Redis Setup

Rate limiting requires a Redis instance. Install and start Redis:

```bash
# On Ubuntu/Debian
sudo apt-get install redis-server
sudo systemctl start redis
sudo systemctl enable redis

# On macOS (Homebrew)
brew install redis
brew services start redis

# Using Docker
docker run -d --name redis -p 6379:6379 redis:7-alpine
```

### Environment Variables

Create a `.env` file based on `.env.example`:

```bash
# Copy example file
cp .env.example .env

# Edit with your values
nano .env
```

**Redis Configuration**:

```env
# Enable/disable rate limiting
RATE_LIMIT_ENABLED=true

# Redis connection
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=          # Optional, leave empty if no password
REDIS_DB=0               # Redis database number (0-15)
```

**Rate Limit Configuration**:

```env
# OTP limits
RATE_LIMIT_OTP_MAX=5
RATE_LIMIT_OTP_WINDOW_MINUTES=60

# Login limits
RATE_LIMIT_LOGIN_MAX=10
RATE_LIMIT_LOGIN_WINDOW_MINUTES=60

# Registration limits
RATE_LIMIT_REGISTER_MAX=3
RATE_LIMIT_REGISTER_WINDOW_MINUTES=60

# General API limits
RATE_LIMIT_API_MAX=100
RATE_LIMIT_API_WINDOW_SECONDS=60
```

## Usage

### Starting the Server

The rate limiter is automatically initialized when the server starts:

```bash
cd barqnet-backend
go run apps/management/main.go
```

**Expected log output**:
```
[RATE-LIMIT] Successfully connected to Redis at localhost:6379
[RATE-LIMIT] Rate limiting is ENABLED
```

**If Redis is unavailable**:
```
[RATE-LIMIT] WARNING: Failed to connect to Redis: connection refused
[RATE-LIMIT] Rate limiting will operate in DEGRADED mode (allow all requests)
```

### Disabling Rate Limiting

To completely disable rate limiting:

```env
RATE_LIMIT_ENABLED=false
```

Or via environment variable:

```bash
RATE_LIMIT_ENABLED=false go run apps/management/main.go
```

## API Response Headers

When rate limiting is active, responses include these headers:

```http
X-RateLimit-Limit: 100           # Maximum requests allowed
X-RateLimit-Remaining: 95        # Requests remaining in window
X-RateLimit-Reset: 1699564800    # Unix timestamp when limit resets
```

When rate limit is exceeded (HTTP 429):

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1699564800
Retry-After: 45                   # Seconds until retry is allowed
```

## Error Responses

### Rate Limit Exceeded

**Status Code**: `429 Too Many Requests`

**Response Body**:
```json
{
  "success": false,
  "message": "Too many OTP requests. Please try again in 3600 seconds."
}
```

**Headers**:
```http
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 5
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1699564800
Retry-After: 3600
```

## Monitoring and Logging

### Log Format

Rate limiting events are logged with the prefix `[RATE-LIMIT]`:

**Allowed request**:
```
[RATE-LIMIT] ALLOWED: otp - key=+1234567890 count=3/5 remaining=2 reset=2023-11-09T15:30:00Z
```

**Blocked request**:
```
[RATE-LIMIT] BLOCKED: login - key=+1234567890 count=10/10 reset=2023-11-09T15:30:00Z
```

**Redis issues**:
```
[RATE-LIMIT] WARNING: Redis unavailable, allowing request (degraded mode): connection refused
```

### Audit Logging

Rate limit violations are also logged to the audit system:

```sql
SELECT * FROM audit_log
WHERE action IN ('OTP_RATE_LIMIT_EXCEEDED', 'LOGIN_RATE_LIMIT_EXCEEDED',
                 'REGISTER_RATE_LIMIT_EXCEEDED', 'RATE_LIMIT_EXCEEDED');
```

## Testing

### Manual Testing

**Test OTP rate limit**:
```bash
# Send 6 OTP requests (5 should succeed, 6th should fail)
for i in {1..6}; do
  curl -X POST http://localhost:8080/v1/auth/send-otp \
    -H "Content-Type: application/json" \
    -d '{"phone_number": "+1234567890"}' \
    -i
  echo "Request $i completed"
done
```

**Test general API rate limit**:
```bash
# Send 101 requests (100 should succeed, 101st should fail)
for i in {1..101}; do
  curl -X GET http://localhost:8080/health -i
done
```

### Checking Rate Limit Status

Use Redis CLI to inspect current limits:

```bash
# Connect to Redis
redis-cli

# View all rate limit keys
KEYS ratelimit:*

# Check specific limit
GET ratelimit:otp:+1234567890
TTL ratelimit:otp:+1234567890

# Reset a specific limit (admin only)
DEL ratelimit:otp:+1234567890
```

### Integration Testing

```go
// Example test
func TestRateLimiting(t *testing.T) {
    rateLimiter, err := shared.NewRateLimiter()
    require.NoError(t, err)
    defer rateLimiter.Close()

    phoneNumber := "+1234567890"

    // Should allow first 5 requests
    for i := 0; i < 5; i++ {
        allowed, _, _, err := rateLimiter.Allow(shared.RateLimitOTP, phoneNumber)
        assert.NoError(t, err)
        assert.True(t, allowed)
    }

    // Should block 6th request
    allowed, _, _, err := rateLimiter.Allow(shared.RateLimitOTP, phoneNumber)
    assert.NoError(t, err)
    assert.False(t, allowed)
}
```

## Production Deployment

### Redis High Availability

For production, use Redis in a highly available configuration:

**Option 1: Redis Sentinel**
```bash
# Master-slave replication with automatic failover
redis-sentinel /etc/redis/sentinel.conf
```

**Option 2: Redis Cluster**
```bash
# Distributed Redis cluster
redis-server /etc/redis/cluster-node-1.conf
```

**Option 3: Managed Redis**
- AWS ElastiCache
- Azure Cache for Redis
- Google Cloud Memorystore
- Redis Enterprise Cloud

### Configuration for Production

```env
# Production Redis (example: AWS ElastiCache)
REDIS_HOST=your-cluster.cache.amazonaws.com
REDIS_PORT=6379
REDIS_PASSWORD=your_secure_password
REDIS_DB=0

# Enable rate limiting
RATE_LIMIT_ENABLED=true

# Stricter limits for production
RATE_LIMIT_OTP_MAX=3
RATE_LIMIT_OTP_WINDOW_MINUTES=60

RATE_LIMIT_LOGIN_MAX=5
RATE_LIMIT_LOGIN_WINDOW_MINUTES=60

RATE_LIMIT_REGISTER_MAX=2
RATE_LIMIT_REGISTER_WINDOW_MINUTES=120

RATE_LIMIT_API_MAX=60
RATE_LIMIT_API_WINDOW_SECONDS=60
```

### Monitoring in Production

**Metrics to monitor**:
- Rate limit hit rate (429 responses)
- Redis connection health
- Redis memory usage
- Rate limit key count
- Average response times

**Recommended tools**:
- Prometheus + Grafana for metrics
- ELK Stack for log aggregation
- Redis monitoring tools (redis-stat, RedisInsight)

### Scaling Considerations

1. **Horizontal Scaling**: Rate limiting works across multiple backend instances sharing the same Redis
2. **Redis Performance**: Single Redis instance can handle 100k+ ops/sec
3. **Connection Pooling**: Built-in connection pooling (10 connections, 2 idle)
4. **Timeouts**: 5s dial, 3s read/write timeouts to prevent blocking

## Troubleshooting

### Issue: "Failed to connect to Redis"

**Cause**: Redis is not running or not accessible

**Solution**:
```bash
# Check if Redis is running
redis-cli ping
# Should return: PONG

# Start Redis if not running
sudo systemctl start redis

# Check Redis logs
sudo journalctl -u redis -n 50
```

### Issue: Rate limits not working

**Checks**:
1. Verify `RATE_LIMIT_ENABLED=true`
2. Check Redis connection: `redis-cli ping`
3. Check server logs for `[RATE-LIMIT]` messages
4. Verify environment variables are loaded

### Issue: Too restrictive limits

**Solution**: Adjust limits in `.env`:
```env
RATE_LIMIT_API_MAX=200  # Increase from 100
```

Restart the server for changes to take effect.

### Issue: Memory usage growing in Redis

**Cause**: Rate limit keys accumulating

**Solution**: Rate limit keys have automatic TTL (expiry), but you can also:
```bash
# Clean up old rate limit keys (admin task)
redis-cli --scan --pattern "ratelimit:*" | xargs redis-cli del
```

## API Reference

### RateLimiter Methods

```go
// Check if request is allowed
allowed, remaining, resetTime, err := rateLimiter.Allow(
    shared.RateLimitOTP,  // Rate limit type
    "+1234567890",         // Key (phone number or IP)
)

// Get current status without incrementing
count, remaining, resetTime, err := rateLimiter.GetStatus(
    shared.RateLimitOTP,
    "+1234567890",
)

// Reset rate limit for a key (admin only)
err := rateLimiter.Reset(
    shared.RateLimitOTP,
    "+1234567890",
)

// Check if rate limiting is enabled
enabled := rateLimiter.IsEnabled()

// Close Redis connection
rateLimiter.Close()
```

## Security Considerations

1. **IP Spoofing**: Rate limiting by IP can be bypassed with proxies. Consider additional authentication-based limits.

2. **Distributed Attacks**: Attackers can use multiple IPs. Monitor for patterns and implement additional security layers.

3. **Phone Number Validation**: Always validate phone numbers before rate limiting to prevent bypass via malformed inputs.

4. **Redis Security**:
   - Use password authentication (`REDIS_PASSWORD`)
   - Enable Redis TLS in production
   - Restrict network access to Redis

5. **Graceful Degradation**: The system allows requests if Redis is down. Monitor Redis health to detect issues.

## Best Practices

1. **Start Conservative**: Begin with strict limits and relax based on legitimate usage patterns
2. **Monitor 429 Responses**: High 429 rates may indicate legitimate users being blocked
3. **Whitelist IPs**: Consider whitelisting known good IPs (office, monitoring)
4. **User Communication**: Provide clear error messages with retry times
5. **Logging**: Log all rate limit violations for security analysis
6. **Testing**: Test rate limits in staging before production deployment

## Future Enhancements

Potential improvements for future versions:

- [ ] Per-user rate limits (in addition to IP-based)
- [ ] Dynamic rate limiting based on load
- [ ] Rate limit whitelisting/blacklisting
- [ ] Prometheus metrics export
- [ ] Admin API for rate limit management
- [ ] Geolocation-based rate limits
- [ ] CAPTCHA integration for exceeded limits

## Support

For issues or questions about rate limiting:

1. Check logs: `grep "RATE-LIMIT" /var/log/vpnmanager/`
2. Review this documentation
3. Check Redis status: `redis-cli info`
4. Review audit logs: `SELECT * FROM audit_log WHERE action LIKE '%RATE_LIMIT%'`

## References

- [Redis Documentation](https://redis.io/documentation)
- [RFC 6585 - Additional HTTP Status Codes](https://tools.ietf.org/html/rfc6585)
- [IETF Rate Limiting Headers](https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/)
- [go-redis Client Documentation](https://redis.uptrace.dev/)
