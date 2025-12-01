# Migration 005 Fix - Schema Migrations Table Upgrade

**Date:** December 1, 2025
**Issue:** Migration 005 fails with "column 'name' of relation 'schema_migrations' does not exist"
**Status:** ✅ FIXED

---

## Problem

When running migrations on Hamad's machine:
```
2025/12/01 05:29:29 Applying migration 005_add_token_blacklist...
2025/12/01 05:29:29 Failed to run database migrations: failed to apply migration 005_add_token_blacklist:
failed to record migration: pq: column "name" of relation "schema_migrations" does not exist
```

### Root Cause

The `schema_migrations` table was created with an old structure on Hamad's machine:

**Old structure:**
```sql
CREATE TABLE schema_migrations (
    id SERIAL PRIMARY KEY,
    version INTEGER NOT NULL UNIQUE,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**New structure (required by migration system):**
```sql
CREATE TABLE schema_migrations (
    id SERIAL PRIMARY KEY,
    version INTEGER NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,          -- ❌ MISSING
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    checksum VARCHAR(64)                  -- ❌ MISSING
);
```

The migration system's `applyMigration()` function tries to INSERT with:
```go
INSERT INTO schema_migrations (version, name) VALUES ($1, $2)
```

This fails because the `name` column doesn't exist on tables created with the old structure.

### Why `CREATE TABLE IF NOT EXISTS` Doesn't Help

The original `createMigrationsTable()` function used:
```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    ...
);
```

**Problem:** `IF NOT EXISTS` only checks if the TABLE exists, not if it has the correct COLUMNS. If the table already exists with the old structure, PostgreSQL skips the entire CREATE statement, leaving the table unchanged.

---

## Solution

Updated `createMigrationsTable()` to handle table schema upgrades:

**File:** `barqnet-backend/pkg/shared/database.go`
**Lines:** 263-311

### Changes Made

**Step 1: Create table with basic structure**
```go
createTableSQL := `
CREATE TABLE IF NOT EXISTS schema_migrations (
    id SERIAL PRIMARY KEY,
    version INTEGER NOT NULL UNIQUE,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
`
```

**Step 2: Add missing columns if table exists**
```go
alterTableSQL := `
DO $$
BEGIN
    -- Add name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'schema_migrations' AND column_name = 'name'
    ) THEN
        ALTER TABLE schema_migrations ADD COLUMN name VARCHAR(255);
    END IF;

    -- Add checksum column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'schema_migrations' AND column_name = 'checksum'
    ) THEN
        ALTER TABLE schema_migrations ADD COLUMN checksum VARCHAR(64);
    END IF;
END $$;
`
```

**Step 3: Create indexes**
```go
indexSQL := `
CREATE INDEX IF NOT EXISTS idx_migrations_version ON schema_migrations(version);
CREATE INDEX IF NOT EXISTS idx_migrations_applied_at ON schema_migrations(applied_at);
`
```

### How This Fixes It

1. **New installations:** Table created with basic structure, then columns added → Full structure
2. **Old installations:** Table already exists → Skip CREATE → Columns added via ALTER → Upgraded structure
3. **Already upgraded:** Table exists with columns → Skip CREATE → Skip ALTER (IF NOT EXISTS) → No changes

**Result:** Every environment gets the correct structure, regardless of previous state.

---

## Testing

### Test 1: Fresh Database (New Installation)

```bash
# Drop and recreate database
psql -U postgres -c "DROP DATABASE IF EXISTS vpnmanager"
psql -U postgres -c "CREATE DATABASE vpnmanager OWNER vpnmanager"

# Run migrations
cd ~/ChameleonVpn/barqnet-backend/apps/management
go run main.go
```

**Expected output:**
```
[DB] Running database migrations...
Applying migration 001_initial_schema...
Successfully applied migration 001_initial_schema
Applying migration 002_add_phone_auth...
Successfully applied migration 002_add_phone_auth
Applying migration 003_add_statistics...
Successfully applied migration 003_add_statistics
Applying migration 004_add_locations...
Successfully applied migration 004_add_locations
Applying migration 005_add_token_blacklist...
Successfully applied migration 005_add_token_blacklist
Applying migration 006_add_active_column...
Successfully applied migration 006_add_active_column
Applying migration 007_migrate_to_email_auth...
Successfully applied migration 007_migrate_to_email_auth
Applying migration 008_fix_audit_log_schema...
Successfully applied migration 008_fix_audit_log_schema
[DB] ✅ Database migrations completed successfully
```

### Test 2: Old Database (Simulating Hamad's Issue)

```bash
# Create old-style schema_migrations table
psql -U vpnmanager -d vpnmanager -c "
DROP TABLE IF EXISTS schema_migrations CASCADE;
CREATE TABLE schema_migrations (
    id SERIAL PRIMARY KEY,
    version INTEGER NOT NULL UNIQUE,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO schema_migrations (version, applied_at) VALUES
    (1, CURRENT_TIMESTAMP),
    (2, CURRENT_TIMESTAMP),
    (3, CURRENT_TIMESTAMP),
    (4, CURRENT_TIMESTAMP);
"

# Run migrations (should upgrade table and apply 005-008)
cd ~/ChameleonVpn/barqnet-backend/apps/management
go run main.go
```

**Expected output:**
```
[DB] Running database migrations...
Migration 001_initial_schema already applied, skipping
Migration 002_add_phone_auth already applied, skipping
Migration 003_add_statistics already applied, skipping
Migration 004_add_locations already applied, skipping
Applying migration 005_add_token_blacklist...
Successfully applied migration 005_add_token_blacklist
Applying migration 006_add_active_column...
Successfully applied migration 006_add_active_column
Applying migration 007_migrate_to_email_auth...
Successfully applied migration 007_migrate_to_email_auth
Applying migration 008_fix_audit_log_schema...
Successfully applied migration 008_fix_audit_log_schema
[DB] ✅ Database migrations completed successfully
```

### Test 3: Verify Table Structure

```bash
psql -U vpnmanager -d vpnmanager -c "\d schema_migrations"
```

**Expected output:**
```
                       Table "public.schema_migrations"
   Column   |            Type             | Collation | Nullable |      Default
------------+-----------------------------+-----------+----------+-------------------
 id         | integer                     |           | not null | nextval(...)
 version    | integer                     |           | not null |
 applied_at | timestamp without time zone |           |          | CURRENT_TIMESTAMP
 name       | character varying(255)      |           |          |
 checksum   | character varying(64)       |           |          |
Indexes:
    "schema_migrations_pkey" PRIMARY KEY, btree (id)
    "schema_migrations_version_key" UNIQUE CONSTRAINT, btree (version)
    "idx_migrations_version" btree (version)
    "idx_migrations_applied_at" btree (applied_at)
```

---

## For Hamad

**No manual intervention needed!** Just restart the backend:

```bash
cd ~/ChameleonVpn/barqnet-backend/apps/management
go run main.go
```

The migration system will now:
1. Detect the old `schema_migrations` table structure
2. Automatically add the missing `name` and `checksum` columns
3. Continue applying migrations 005-008 successfully

---

## Technical Details

### Why This Approach?

**Option 1 (Rejected):** DROP and recreate schema_migrations
- ❌ Loses migration history
- ❌ Can't tell which migrations were already applied
- ❌ Risk of re-running migrations

**Option 2 (Rejected):** Manual ALTER TABLE instructions
- ❌ Requires user intervention
- ❌ Error-prone
- ❌ Not automated

**Option 3 (Chosen):** Auto-upgrade table structure
- ✅ Fully automated
- ✅ Preserves migration history
- ✅ Idempotent (safe to run multiple times)
- ✅ Works for all scenarios

### Idempotency

The solution is **idempotent** - running it multiple times has the same effect as running it once:

1. First run: Adds columns → Success
2. Second run: Columns exist → Skip ALTER → Success
3. Third run: Columns exist → Skip ALTER → Success

### PostgreSQL Feature Used

**`information_schema.columns`**
- Standard SQL metadata table
- Lists all columns in all tables
- Used to check if column exists before adding

**`DO $$ ... END $$`**
- Anonymous PL/pgSQL block
- Allows IF/THEN/ELSE logic in SQL
- Executes without creating stored procedure

---

## Verification

After running migrations, verify:

```bash
# Check all migrations applied
psql -U vpnmanager -d vpnmanager -c "
SELECT version, name, applied_at
FROM schema_migrations
ORDER BY version;
"
```

**Should show:**
```
 version |         name          |         applied_at
---------+-----------------------+----------------------------
       1 | initial_schema        | 2025-12-01 05:30:15.123456
       2 | add_phone_auth        | 2025-12-01 05:30:15.234567
       3 | add_statistics        | 2025-12-01 05:30:15.345678
       4 | add_locations         | 2025-12-01 05:30:15.456789
       5 | add_token_blacklist   | 2025-12-01 05:30:15.567890
       6 | add_active_column     | 2025-12-01 05:30:15.678901
       7 | migrate_to_email_auth | 2025-12-01 05:30:15.789012
       8 | fix_audit_log_schema  | 2025-12-01 05:30:15.890123
```

---

**Status:** ✅ Fixed and ready for testing
**Last Updated:** December 1, 2025 05:35 UTC
