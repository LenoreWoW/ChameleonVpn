# Database Migrations

This directory contains PostgreSQL migration scripts for the BarqNet project.

## Overview

Migrations are versioned SQL scripts that modify the database schema in a controlled, trackable manner. Each migration is applied only once and tracked in the `schema_migrations` table.

## Migration Files

### 002_add_phone_auth.sql
**Purpose**: Add phone-based authentication support

**Changes**:
- Adds `phone_number` column to users table (VARCHAR(20), UNIQUE)
- Adds `password_hash` column for bcrypt password storage
- Adds `created_via` column to track user creation method
- Adds `last_login` timestamp tracking
- Creates `user_sessions` table for JWT token management
- Creates `otp_attempts` table for rate limiting OTP requests
- Includes comprehensive indexes for performance

**Tables Created**:
- `user_sessions` - Tracks active JWT sessions with device info
- `otp_attempts` - Rate limiting and tracking for OTP send/verify

---

### 003_add_statistics.sql
**Purpose**: Add VPN usage statistics and connection tracking

**Changes**:
- Creates `vpn_statistics` table for historical bandwidth/usage data
- Creates `vpn_connections` table for real-time connection tracking
- Adds views for analytics: `v_active_connections`, `v_user_statistics`, `v_server_statistics`

**Tables Created**:
- `vpn_statistics` - Historical session data (bytes in/out, duration, timestamps)
- `vpn_connections` - Real-time connection status and metadata

**Views Created**:
- `v_active_connections` - Currently active VPN sessions
- `v_user_statistics` - Per-user usage aggregations
- `v_server_statistics` - Per-server usage aggregations

---

### 004_add_locations.sql
**Purpose**: Add geographic server locations

**Changes**:
- Creates `server_locations` table with geographic data
- Adds `location_id` foreign key to servers table
- Inserts 15 sample global locations (US, Europe, Asia, etc.)
- Creates views and functions for location-based queries

**Tables Created**:
- `server_locations` - Geographic location data with lat/long coordinates

**Sample Locations**:
- US East (New York, Virginia)
- US West (California, Oregon)
- Europe (London, Frankfurt, Paris, Amsterdam)
- Asia (Tokyo, Singapore, Mumbai, Seoul)
- Australia (Sydney)
- Canada (Toronto)
- South America (São Paulo)

**Functions Created**:
- `get_nearest_location(lat, lon, limit)` - Finds nearest locations using Haversine formula

**Views Created**:
- `v_servers_with_locations` - Servers with full location details
- `v_location_statistics` - Per-location usage and server counts

---

## Usage

### Running Migrations Programmatically

```go
package main

import (
    "log"
    "path/filepath"
    "yourproject/pkg/shared"
)

func main() {
    // Create database connection
    cfg := &shared.DatabaseConfig{
        Host:     "localhost",
        Port:     5432,
        User:     "postgres",
        Password: "yourpassword",
        DBName:   "chameleonvpn",
        SSLMode:  "disable",
    }

    db, err := shared.NewDatabase(cfg)
    if err != nil {
        log.Fatalf("Failed to connect to database: %v", err)
    }
    defer db.Close()

    // Run migrations
    migrationsPath := filepath.Join(".", "migrations")
    if err := db.RunMigrations(migrationsPath); err != nil {
        log.Fatalf("Failed to run migrations: %v", err)
    }

    log.Println("Migrations completed successfully")

    // Check migration status
    status, err := db.GetMigrationStatus()
    if err != nil {
        log.Fatalf("Failed to get migration status: %v", err)
    }

    for _, migration := range status {
        log.Printf("Migration %d (%s) applied at %v",
            migration["version"],
            migration["name"],
            migration["applied_at"])
    }
}
```

### Running Migrations Manually

If you prefer to run migrations manually using `psql`:

```bash
# Connect to your database
psql -h localhost -U postgres -d barqnet

# Run each migration in order
\i migrations/002_add_phone_auth.sql
\i migrations/003_add_statistics.sql
\i migrations/004_add_locations.sql
```

### Checking Migration Status

```sql
-- View all applied migrations
SELECT * FROM schema_migrations ORDER BY version;

-- Check if a specific migration is applied
SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version = 2);
```

---

## Migration Features

### Idempotency
All migrations are designed to be **idempotent** - they can be run multiple times safely without causing errors or duplicate data:

- Use `IF NOT EXISTS` for table/column creation
- Use `DO $$ BEGIN ... END $$` blocks for conditional DDL
- Use `ON CONFLICT DO NOTHING` for data inserts
- Check for existing constraints before adding them

### Transaction Safety
- Each migration runs in a transaction
- If any part fails, the entire migration is rolled back
- The `schema_migrations` table is only updated on successful completion

### Rollback Support
Each migration file includes a commented rollback section that can be used to reverse the migration if needed:

```sql
-- ============== ROLLBACK DOWN ==============

/*
-- To rollback this migration, run the following SQL:
DROP TABLE IF EXISTS new_table CASCADE;
ALTER TABLE existing_table DROP COLUMN IF EXISTS new_column;
*/
```

To rollback a migration:
1. Copy the rollback SQL from the migration file
2. Run it in your database
3. Delete the entry from `schema_migrations`

---

## Migration Naming Convention

Migrations follow the pattern: `{version}_{description}.sql`

- **Version**: 3-digit zero-padded number (e.g., 002, 003, 004)
- **Description**: Snake_case description (e.g., add_phone_auth, add_statistics)

Examples:
- `002_add_phone_auth.sql`
- `003_add_statistics.sql`
- `004_add_locations.sql`

---

## Creating New Migrations

When creating a new migration:

1. **Increment the version number**
   ```bash
   # Find the latest version
   ls migrations/ | grep -E '^[0-9]+' | sort -n | tail -1

   # Create new migration (next version)
   touch migrations/005_your_migration_name.sql
   ```

2. **Use the migration template**
   ```sql
   -- =====================================================
   -- Migration: 005_your_migration_name
   -- Description: Brief description of changes
   -- Created: YYYY-MM-DD
   -- =====================================================

   -- ============== MIGRATION UP ==============

   -- Your DDL/DML statements here
   CREATE TABLE IF NOT EXISTS ...;

   -- ============== ROLLBACK DOWN ==============

   /*
   -- To rollback this migration, run the following SQL:
   DROP TABLE IF EXISTS ...;
   */
   ```

3. **Make it idempotent**
   - Use `IF NOT EXISTS` checks
   - Use `DO $$ BEGIN ... END $$` blocks for conditional logic
   - Test running the migration multiple times

4. **Test thoroughly**
   ```bash
   # Test in a development database
   psql -h localhost -U postgres -d test_db -f migrations/005_your_migration.sql

   # Test idempotency by running again
   psql -h localhost -U postgres -d test_db -f migrations/005_your_migration.sql

   # Test rollback
   psql -h localhost -U postgres -d test_db -c "/* paste rollback SQL */"
   ```

---

## Database Schema Tracking

The migration system creates a `schema_migrations` table:

```sql
CREATE TABLE schema_migrations (
    version INTEGER PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    checksum VARCHAR(64)
);
```

This table tracks:
- **version**: Migration version number
- **name**: Migration name/description
- **applied_at**: When the migration was applied
- **checksum**: Reserved for future integrity checking

---

## Best Practices

1. **Never modify existing migrations** that have been applied to production
2. **Always create a new migration** for schema changes
3. **Test migrations** in development before applying to production
4. **Keep migrations small and focused** - one logical change per migration
5. **Include rollback scripts** for all migrations
6. **Document breaking changes** in migration comments
7. **Use transactions** to ensure atomicity
8. **Make migrations idempotent** for safety

---

## Troubleshooting

### Migration Failed Mid-Way

If a migration fails:

1. Check the error message for the specific issue
2. The transaction will have rolled back - no partial changes applied
3. Fix the migration SQL and run again
4. If needed, manually check the `schema_migrations` table

### Migration Already Applied

The system automatically skips already-applied migrations based on the `schema_migrations` table.

### Force Re-run a Migration

```sql
-- Remove migration record (use with caution!)
DELETE FROM schema_migrations WHERE version = 2;

-- Then run migrations again
```

### Check Database State

```sql
-- List all tables
\dt

-- Describe a table
\d users

-- View applied migrations
SELECT * FROM schema_migrations ORDER BY version;

-- Check for specific features
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'phone_number';
```

---

## Compatibility

- **PostgreSQL**: 12.0 or higher recommended
- **Go**: 1.16 or higher for the migration runner
- **Dependencies**: github.com/lib/pq (PostgreSQL driver)

---

## Support

For issues or questions:
1. Check migration logs for error details
2. Verify database permissions
3. Ensure PostgreSQL version compatibility
4. Review migration SQL for syntax errors
5. Test in a development environment first
