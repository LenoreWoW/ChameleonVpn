-- Migration: 009_add_user_roles.sql
-- Description: Adds role system for user permissions
-- Date: 2024-12-28

-- ==================== MIGRATION UP ====================

-- Add role column to users table
-- Valid roles: 'user' (default), 'admin', 'moderator', 'superadmin'
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'role'
    ) THEN
        ALTER TABLE users ADD COLUMN role VARCHAR(20) DEFAULT 'user';
    END IF;
END $$;

-- Add index for faster role lookups
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Create admin_audit table for tracking admin actions
CREATE TABLE IF NOT EXISTS admin_audit (
    id SERIAL PRIMARY KEY,
    admin_user_id UUID,
    admin_email VARCHAR(255) NOT NULL,
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(50), -- 'user', 'server', 'config', etc.
    target_id VARCHAR(255),
    details JSONB,
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for admin audit queries
CREATE INDEX IF NOT EXISTS idx_admin_audit_admin_email ON admin_audit(admin_email);
CREATE INDEX IF NOT EXISTS idx_admin_audit_created_at ON admin_audit(created_at);

-- ==================== MIGRATION DOWN ====================
-- To rollback:
-- ALTER TABLE users DROP COLUMN role;
-- DROP TABLE admin_audit;

