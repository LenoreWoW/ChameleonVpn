-- =====================================================
-- Migration: 008_fix_audit_log_schema
-- Description: Add missing audit columns for backward compatibility
-- Created: 2025-11-30
-- =====================================================

-- ============== MIGRATION UP ==============

-- Add missing columns to audit_log table
ALTER TABLE audit_log ADD COLUMN IF NOT EXISTS server_id VARCHAR(255);
ALTER TABLE audit_log ADD COLUMN IF NOT EXISTS username VARCHAR(255);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_audit_log_server_id ON audit_log(server_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_username ON audit_log(username);

-- Add comments to document the columns
COMMENT ON COLUMN audit_log.server_id IS 'Server/node that generated this audit event';
COMMENT ON COLUMN audit_log.username IS 'Denormalized username for quick queries (also stored as user_id FK)';

-- Create view for backward compatibility with old queries
CREATE OR REPLACE VIEW audit_log_with_username AS
SELECT
    a.id,
    a.created_at as timestamp,
    a.action,
    COALESCE(a.username, u.username) as username,
    a.details,
    a.ip_address,
    a.server_id,
    a.user_id,
    a.resource_type,
    a.resource_id,
    a.user_agent,
    a.status
FROM audit_log a
LEFT JOIN users u ON a.user_id = u.id;

COMMENT ON VIEW audit_log_with_username IS 'Backward-compatible view that resolves usernames from user_id FK';

-- ============== ROLLBACK DOWN ==============

/*
-- To rollback this migration, run the following SQL:

-- Drop view
DROP VIEW IF EXISTS audit_log_with_username;

-- Drop indexes
DROP INDEX IF EXISTS idx_audit_log_username;
DROP INDEX IF EXISTS idx_audit_log_server_id;

-- Drop columns (WARNING: This will lose data in these columns)
ALTER TABLE audit_log DROP COLUMN IF EXISTS username;
ALTER TABLE audit_log DROP COLUMN IF EXISTS server_id;

*/
