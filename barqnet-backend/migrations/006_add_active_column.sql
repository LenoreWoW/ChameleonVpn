-- =====================================================
-- Migration: 006_add_active_column
-- Description: Add 'active' column and align users schema with code expectations
-- Created: 2025-11-15
-- Fix: Resolves "column active does not exist" error
-- =====================================================

-- ============== MIGRATION UP ==============

-- Step 1: Add 'active' column to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT true;

-- Step 2: Migrate existing data from 'status' to 'active'
-- Users with status='active' get active=true, others get active=false
UPDATE users
SET active = (status = 'active')
WHERE active IS NULL;

-- Step 3: Add missing columns that exist in code but not in migration schema
ALTER TABLE users
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS ovpn_path TEXT,
ADD COLUMN IF NOT EXISTS port INTEGER DEFAULT 1194,
ADD COLUMN IF NOT EXISTS protocol VARCHAR(10) DEFAULT 'udp',
ADD COLUMN IF NOT EXISTS last_access TIMESTAMP,
ADD COLUMN IF NOT EXISTS checksum VARCHAR(255),
ADD COLUMN IF NOT EXISTS synced BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);

-- Step 4: Set default values for existing NULL fields
-- Set server_id default for existing NULL values (required by code)
UPDATE users
SET server_id = 'default'
WHERE server_id IS NULL;

-- Set created_by default for existing NULL values (required by code)
UPDATE users
SET created_by = 'migration'
WHERE created_by IS NULL;

-- Step 5: Update columns to match code schema constraints
-- Make server_id NOT NULL (code expects this)
ALTER TABLE users
ALTER COLUMN server_id SET NOT NULL;

-- Make created_by NOT NULL (code expects this)
ALTER TABLE users
ALTER COLUMN created_by SET NOT NULL;

-- Step 6: Create index on active column for efficient queries
CREATE INDEX IF NOT EXISTS idx_users_active ON users(active);

-- Step 7: Create composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_users_active_username ON users(active, username)
WHERE active = true; -- Partial index for active users only

CREATE INDEX IF NOT EXISTS idx_users_server_active ON users(server_id, active);

CREATE INDEX IF NOT EXISTS idx_users_expires_at ON users(expires_at)
WHERE expires_at IS NOT NULL;

-- Step 8: Add comments to document the schema changes
COMMENT ON COLUMN users.active IS 'Whether the user account is active (replaces status column)';
COMMENT ON COLUMN users.expires_at IS 'User account expiration timestamp (NULL = never expires)';
COMMENT ON COLUMN users.ovpn_path IS 'File path to the user OpenVPN configuration file';
COMMENT ON COLUMN users.port IS 'OpenVPN port for this user (default 1194)';
COMMENT ON COLUMN users.protocol IS 'OpenVPN protocol: udp or tcp (default udp)';
COMMENT ON COLUMN users.last_access IS 'Last time user accessed the VPN';
COMMENT ON COLUMN users.checksum IS 'Checksum of the .ovpn file for integrity verification';
COMMENT ON COLUMN users.synced IS 'Whether user data has been synced across servers';
COMMENT ON COLUMN users.created_by IS 'Username or system that created this user account';

-- Step 9: Optional - Remove old 'status' column (uncomment if no longer needed)
-- NOTE: Keeping status column for backward compatibility during transition
-- To fully remove it, uncomment the following lines:
-- DROP INDEX IF EXISTS idx_users_status;
-- ALTER TABLE users DROP COLUMN IF EXISTS status;

-- Step 10: Record this migration as applied
INSERT INTO schema_migrations (version) VALUES ('006_add_active_column')
ON CONFLICT (version) DO NOTHING;

-- ============== ROLLBACK DOWN ==============

/*
-- To rollback this migration, run the following SQL:

-- Restore status column from active (if dropped)
ALTER TABLE users ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'active';
UPDATE users SET status = CASE WHEN active THEN 'active' ELSE 'inactive' END;

-- Drop added indexes
DROP INDEX IF EXISTS idx_users_active;
DROP INDEX IF EXISTS idx_users_active_username;
DROP INDEX IF EXISTS idx_users_server_active;
DROP INDEX IF EXISTS idx_users_expires_at;

-- Remove NOT NULL constraints
ALTER TABLE users ALTER COLUMN server_id DROP NOT NULL;
ALTER TABLE users ALTER COLUMN created_by DROP NOT NULL;

-- Drop added columns
ALTER TABLE users
DROP COLUMN IF EXISTS active,
DROP COLUMN IF EXISTS expires_at,
DROP COLUMN IF EXISTS ovpn_path,
DROP COLUMN IF EXISTS port,
DROP COLUMN IF EXISTS protocol,
DROP COLUMN IF EXISTS last_access,
DROP COLUMN IF EXISTS checksum,
DROP COLUMN IF EXISTS synced,
DROP COLUMN IF EXISTS created_by;

-- Recreate original indexes
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);

-- Remove from migrations tracking
DELETE FROM schema_migrations WHERE version = '006_add_active_column';

*/
