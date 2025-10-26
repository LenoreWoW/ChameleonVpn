# Migration Quick Start Guide

## TL;DR - Fast Setup

### Option 1: Using the CLI Tool (Recommended)

```bash
# Navigate to project root
cd /Users/hassanalsahli/Desktop/ChameleonVpn/barqnet-backend

# Run migrations
go run migrations/run_migrations.go \
  -host localhost \
  -port 5432 \
  -user postgres \
  -password yourpassword \
  -dbname barqnet

# Check status
go run migrations/run_migrations.go \
  -host localhost \
  -port 5432 \
  -user postgres \
  -password yourpassword \
  -dbname barqnet \
  -status
```

### Option 2: Using psql

```bash
# Connect to database
psql -h localhost -U postgres -d barqnet

# Run migrations in order
\i migrations/002_add_phone_auth.sql
\i migrations/003_add_statistics.sql
\i migrations/004_add_locations.sql

# Verify
SELECT * FROM schema_migrations ORDER BY version;
\q
```

### Option 3: Programmatically in Go

```go
package main

import (
    "log"
    "yourproject/pkg/shared"
)

func main() {
    cfg := &shared.DatabaseConfig{
        Host:     "localhost",
        Port:     5432,
        User:     "postgres",
        Password: "yourpassword",
        DBName:   "barqnet",
        SSLMode:  "disable",
    }

    db, err := shared.NewDatabase(cfg)
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()

    // Run all migrations
    if err := db.RunMigrations("./migrations"); err != nil {
        log.Fatal(err)
    }

    log.Println("Migrations completed!")
}
```

---

## What Gets Created

After running migrations, you'll have:

### New Authentication Features
- Phone number login support
- Password hashing for phone users
- JWT session tracking
- OTP verification with rate limiting

### New Statistics & Monitoring
- Real-time VPN connection tracking
- Historical bandwidth usage data
- Per-user and per-server analytics views
- Active connection monitoring

### New Geographic Features
- 15 pre-populated global server locations
- Location-to-server mapping
- Distance calculation function
- Location-based server selection

---

## Verification Checklist

After running migrations, verify everything:

```sql
-- Connect to database
psql -U postgres -d barqnet

-- 1. Check migrations applied
SELECT version, name, applied_at FROM schema_migrations ORDER BY version;
-- Expected: 3 rows (versions 2, 3, 4)

-- 2. Verify new columns on users table
\d users
-- Expected: phone_number, password_hash, created_via, last_login

-- 3. Verify new tables exist
\dt
-- Expected: user_sessions, otp_attempts, vpn_statistics, vpn_connections, server_locations

-- 4. Verify views created
\dv
-- Expected: v_active_connections, v_user_statistics, v_server_statistics,
--           v_servers_with_locations, v_location_statistics

-- 5. Verify sample locations inserted
SELECT COUNT(*) FROM server_locations;
-- Expected: 15

-- 6. Check indexes
\di
-- Expected: 30+ indexes including idx_users_phone_number, idx_sessions_*, idx_otp_*, etc.

-- 7. Test function
SELECT * FROM get_nearest_location(40.7128, -74.0060, 5);
-- Expected: 5 nearest locations to New York
```

---

## Common Issues & Solutions

### Issue: "password authentication failed"
```bash
# Solution: Check your PostgreSQL password
psql -U postgres -d barqnet
# Enter correct password when prompted
```

### Issue: "database does not exist"
```bash
# Solution: Create the database first
createdb -U postgres barqnet
```

### Issue: "migrations directory not found"
```bash
# Solution: Ensure you're in the correct directory
cd /Users/hassanalsahli/Desktop/ChameleonVpn/barqnet-backend
ls migrations/  # Should show .sql files
```

### Issue: "permission denied"
```bash
# Solution: Grant necessary permissions
psql -U postgres -d barqnet
GRANT ALL PRIVILEGES ON DATABASE barqnet TO your_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO your_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO your_user;
```

### Issue: "column already exists"
**This is normal!** Migrations are idempotent. The message means:
- Migration was partially applied before, or
- You're running migrations on a database that already has some changes

**Solution**: Migrations will skip existing items safely.

---

## Testing Your Setup

### 1. Test Phone Authentication

```sql
-- Insert a test user with phone number
INSERT INTO users (username, phone_number, password_hash, created_via, server_id, created_by)
VALUES ('testuser', '+1234567890', '$2a$10$...', 'phone', 'server1', 'admin');

-- Verify
SELECT username, phone_number, created_via FROM users WHERE phone_number = '+1234567890';
```

### 2. Test Session Tracking

```sql
-- Create a test session
INSERT INTO user_sessions (user_id, token_hash, device_info, expires_at)
SELECT id, 'test_token_hash', 'iPhone 13', NOW() + INTERVAL '24 hours'
FROM users WHERE username = 'testuser';

-- View active sessions
SELECT * FROM v_active_connections;
```

### 3. Test OTP System

```sql
-- Record OTP attempt
INSERT INTO otp_attempts (phone_number, otp_code, attempt_type, expires_at, ip_address)
VALUES ('+1234567890', '123456', 'send', NOW() + INTERVAL '5 minutes', '192.168.1.1');

-- Check recent attempts
SELECT * FROM otp_attempts
WHERE phone_number = '+1234567890'
ORDER BY created_at DESC
LIMIT 5;
```

### 4. Test Statistics

```sql
-- Record a VPN connection
INSERT INTO vpn_connections (username, server_id, status, virtual_ip, device_type)
VALUES ('testuser', 'server1', 'connected', '10.8.0.2', 'macos');

-- Record statistics
INSERT INTO vpn_statistics (username, server_id, bytes_in, bytes_out, duration_seconds, started_at, ended_at)
VALUES ('testuser', 'server1', 1073741824, 2147483648, 3600, NOW() - INTERVAL '1 hour', NOW());

-- View user statistics
SELECT * FROM v_user_statistics WHERE username = 'testuser';
```

### 5. Test Locations

```sql
-- View all locations
SELECT location_id, name, country, city FROM server_locations ORDER BY display_order;

-- Find nearest to New York
SELECT * FROM get_nearest_location(40.7128, -74.0060, 3);

-- Link a server to a location
UPDATE servers
SET location_id = (SELECT location_id FROM server_locations WHERE name = 'US East - New York')
WHERE name = 'server1';

-- View servers with locations
SELECT * FROM v_servers_with_locations;
```

---

## Performance Tips

### For Development
```sql
-- Disable fsync for faster writes (DEVELOPMENT ONLY!)
ALTER SYSTEM SET fsync = off;
SELECT pg_reload_conf();
```

### For Production
```sql
-- Enable connection pooling
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET work_mem = '16MB';
SELECT pg_reload_conf();
```

### Regular Maintenance
```sql
-- Run weekly (add to cron)
VACUUM ANALYZE;
REINDEX DATABASE barqnet;
```

---

## Rollback (If Needed)

### Rollback All Migrations

```sql
-- Rollback 004 (locations)
DROP FUNCTION IF EXISTS get_nearest_location(DECIMAL, DECIMAL, INTEGER);
DROP VIEW IF EXISTS v_location_statistics;
DROP VIEW IF EXISTS v_servers_with_locations;
ALTER TABLE servers DROP CONSTRAINT IF EXISTS fk_servers_location;
ALTER TABLE servers DROP COLUMN IF EXISTS location_id;
DROP TABLE IF EXISTS server_locations CASCADE;
DELETE FROM schema_migrations WHERE version = 4;

-- Rollback 003 (statistics)
DROP VIEW IF EXISTS v_server_statistics;
DROP VIEW IF EXISTS v_user_statistics;
DROP VIEW IF EXISTS v_active_connections;
ALTER TABLE vpn_statistics DROP CONSTRAINT IF EXISTS fk_vpn_stats_connection;
DROP TABLE IF EXISTS vpn_statistics CASCADE;
DROP TABLE IF EXISTS vpn_connections CASCADE;
DELETE FROM schema_migrations WHERE version = 3;

-- Rollback 002 (phone auth)
DROP TABLE IF EXISTS otp_attempts CASCADE;
DROP TABLE IF EXISTS user_sessions CASCADE;
DROP INDEX IF EXISTS idx_users_last_login;
DROP INDEX IF EXISTS idx_users_created_via;
DROP INDEX IF EXISTS idx_users_phone_number;
ALTER TABLE users DROP COLUMN IF EXISTS last_login;
ALTER TABLE users DROP COLUMN IF EXISTS created_via;
ALTER TABLE users DROP COLUMN IF EXISTS password_hash;
ALTER TABLE users DROP COLUMN IF EXISTS phone_number;
DELETE FROM schema_migrations WHERE version = 2;
```

---

## Next Steps

1. **Integrate with API**: Update your Go handlers to use new tables
2. **Add Phone Auth Endpoint**: Implement OTP send/verify logic
3. **Enable Statistics**: Start tracking VPN connections
4. **Use Location Data**: Show users server locations in UI
5. **Set Up Monitoring**: Query statistics views regularly
6. **Schedule Cleanup**: Remove old sessions/OTP attempts
7. **Test Thoroughly**: Use the verification checklist above

---

## Documentation

- **Detailed Guide**: See `README.md`
- **Complete Summary**: See `MIGRATION_SUMMARY.md`
- **Migration Code**: See `002_*.sql`, `003_*.sql`, `004_*.sql`
- **Go Implementation**: See `pkg/shared/database.go`

---

## Support

If migrations fail:
1. Check PostgreSQL logs: `/var/log/postgresql/postgresql-*.log`
2. Verify database connectivity: `psql -U postgres -d barqnet`
3. Check permissions: `\du` in psql
4. Review error message carefully
5. Try manual migration first to identify issue
6. Check migration file syntax

For successful migrations:
- You should see "All migrations completed successfully"
- Check `schema_migrations` table for applied versions
- Verify tables/columns exist using `\d` commands
- Test with sample queries above

---

**Version**: 1.0
**Date**: 2025-10-26
**Compatibility**: PostgreSQL 12+, Go 1.16+
