# Rate Limiting Quick Start Guide

## Installation Steps

### 1. Install Dependencies

```bash
cd barqnet-backend
go mod tidy
```

This will download:
- `github.com/go-redis/redis/v8` v8.11.5
- Required transitive dependencies

### 2. Install and Start Redis

**Ubuntu/Debian**:
```bash
sudo apt-get update
sudo apt-get install redis-server
sudo systemctl start redis
sudo systemctl enable redis
```

**macOS (Homebrew)**:
```bash
brew install redis
brew services start redis
```

**Docker**:
```bash
docker run -d --name redis -p 6379:6379 redis:7-alpine
```

**Verify Redis is running**:
```bash
redis-cli ping
# Should return: PONG
```

### 3. Configure Environment Variables

```bash
# Create .env file from example
cp .env.example .env

# Edit configuration
nano .env
```

**Minimal configuration**:
```env
# Database
DB_HOST=localhost
DB_PASSWORD=your_password
DB_NAME=vpnmanager

# Rate Limiting
RATE_LIMIT_ENABLED=true
REDIS_HOST=localhost
REDIS_PORT=6379
```

### 4. Start the Server

```bash
# From barqnet-backend directory
go run apps/management/main.go
```

**Expected output**:
```
[RATE-LIMIT] Successfully connected to Redis at localhost:6379
[RATE-LIMIT] Rate limiting is ENABLED
Management server started with ID: management-server
API server running on port 8080
```

## Quick Test

### Test OTP Rate Limit (5 per hour)

```bash
# This should succeed 5 times, fail on 6th
for i in {1..6}; do
  echo "Request $i:"
  curl -X POST http://localhost:8080/v1/auth/send-otp \
    -H "Content-Type: application/json" \
    -d '{"phone_number": "+1234567890"}' \
    -i | grep -E "HTTP|X-RateLimit"
  echo ""
done
```

### Test General API Rate Limit (100 per minute)

```bash
# Health check endpoint - should succeed 100 times, fail on 101st
for i in {1..101}; do
  curl -s -o /dev/null -w "Request $i: %{http_code}\n" http://localhost:8080/health
done
```

## Rate Limits Summary

| Endpoint | Limit | Window | Key |
|----------|-------|--------|-----|
| OTP Send | 5 requests | 1 hour | Phone number |
| Login | 10 attempts | 1 hour | Phone number |
| Register | 3 registrations | 1 hour | IP address |
| General API | 100 requests | 1 minute | IP address |

## Response Headers

**Successful request**:
```http
HTTP/1.1 200 OK
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1699564800
```

**Rate limited request**:
```http
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 5
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1699568400
Retry-After: 3600
```

## Common Issues

### Redis Connection Failed

**Symptom**:
```
[RATE-LIMIT] WARNING: Failed to connect to Redis: connection refused
[RATE-LIMIT] Rate limiting will operate in DEGRADED mode
```

**Solution**:
```bash
# Check if Redis is running
redis-cli ping

# Start Redis if not running
sudo systemctl start redis

# Check Redis logs
sudo journalctl -u redis -n 50
```

### Rate Limits Not Working

**Checks**:
1. Verify Redis is running: `redis-cli ping`
2. Check `RATE_LIMIT_ENABLED=true` in .env
3. Restart server after .env changes
4. Check logs for `[RATE-LIMIT]` messages

### Adjusting Limits

Edit `.env` file:
```env
# More permissive
RATE_LIMIT_OTP_MAX=10
RATE_LIMIT_LOGIN_MAX=20
RATE_LIMIT_API_MAX=200

# More restrictive (production)
RATE_LIMIT_OTP_MAX=3
RATE_LIMIT_LOGIN_MAX=5
RATE_LIMIT_API_MAX=50
```

Restart server for changes to take effect.

## Monitoring

### Check Redis Keys

```bash
redis-cli

# List all rate limit keys
KEYS ratelimit:*

# Check specific limit
GET ratelimit:otp:+1234567890
TTL ratelimit:otp:+1234567890

# Reset a limit (admin operation)
DEL ratelimit:otp:+1234567890
```

### Check Audit Logs

```sql
SELECT * FROM audit_log
WHERE action LIKE '%RATE_LIMIT%'
ORDER BY timestamp DESC
LIMIT 20;
```

## Disabling Rate Limiting

For development or testing:

```env
RATE_LIMIT_ENABLED=false
```

Or via command line:
```bash
RATE_LIMIT_ENABLED=false go run apps/management/main.go
```

## Production Checklist

- [ ] Redis is running in high availability mode (Sentinel/Cluster)
- [ ] Redis has authentication enabled (`REDIS_PASSWORD`)
- [ ] Rate limits are configured appropriately for your use case
- [ ] Monitoring is set up for 429 responses
- [ ] Logs are aggregated and searchable
- [ ] Backup Redis regularly
- [ ] Test failover scenarios

## Next Steps

1. Review full documentation: `RATE_LIMITING.md`
2. Configure production Redis deployment
3. Set up monitoring and alerting
4. Test rate limits in staging environment
5. Adjust limits based on actual usage patterns

## Support

For detailed information, see:
- Full documentation: `RATE_LIMITING.md`
- Configuration: `.env.example`
- Code: `pkg/shared/rate_limit.go`

For issues:
1. Check logs: `grep "RATE-LIMIT" <logfile>`
2. Check Redis: `redis-cli info`
3. Review audit logs in database
