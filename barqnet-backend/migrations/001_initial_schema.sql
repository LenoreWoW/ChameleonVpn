-- =====================================================
-- Migration: 001_initial_schema
-- Description: Initial database schema for BarqNet VPN
-- Created: 2025-10-27
-- =====================================================

-- ============== MIGRATION UP ==============

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255),
    server_id VARCHAR(255),
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes on users table
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_server_id ON users(server_id);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- Create servers table
CREATE TABLE IF NOT EXISTS servers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    host VARCHAR(255) NOT NULL,
    port INTEGER NOT NULL DEFAULT 1194,
    enabled BOOLEAN DEFAULT true,
    server_type VARCHAR(50) DEFAULT 'endnode',
    last_sync TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes on servers table
CREATE INDEX IF NOT EXISTS idx_servers_name ON servers(name);
CREATE INDEX IF NOT EXISTS idx_servers_enabled ON servers(enabled);
CREATE INDEX IF NOT EXISTS idx_servers_type ON servers(server_type);

-- Create audit_log table (singular to match code expectations)
CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(255) NOT NULL,
    resource_type VARCHAR(100),
    resource_id VARCHAR(255),
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    status VARCHAR(50) DEFAULT 'success',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes on audit_log
CREATE INDEX IF NOT EXISTS idx_audit_log_user_id ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_log_resource_type ON audit_log(resource_type);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON audit_log(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_log_status ON audit_log(status);

-- Create schema_migrations table to track applied migrations
CREATE TABLE IF NOT EXISTS schema_migrations (
    id SERIAL PRIMARY KEY,
    version VARCHAR(255) UNIQUE NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert this migration as applied
INSERT INTO schema_migrations (version) VALUES ('001_initial_schema')
ON CONFLICT (version) DO NOTHING;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers to auto-update updated_at
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_servers_updated_at
    BEFORE UPDATE ON servers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add comments to document the schema
COMMENT ON TABLE users IS 'VPN users with authentication and status tracking';
COMMENT ON TABLE servers IS 'VPN server nodes (management and end-nodes)';
COMMENT ON TABLE audit_logs IS 'Audit trail for all system operations';
COMMENT ON TABLE schema_migrations IS 'Tracks which database migrations have been applied';

COMMENT ON COLUMN users.username IS 'Unique username for VPN access';
COMMENT ON COLUMN users.server_id IS 'Associated VPN server (if user-specific)';
COMMENT ON COLUMN users.status IS 'User status: active, suspended, deleted';

COMMENT ON COLUMN servers.name IS 'Unique server identifier';
COMMENT ON COLUMN servers.host IS 'Server hostname or IP address';
COMMENT ON COLUMN servers.port IS 'OpenVPN server port (default 1194)';
COMMENT ON COLUMN servers.server_type IS 'Server type: management or endnode';
COMMENT ON COLUMN servers.last_sync IS 'Last successful sync with management server';

COMMENT ON COLUMN audit_logs.action IS 'Action performed (e.g., user.create, user.delete)';
COMMENT ON COLUMN audit_logs.resource_type IS 'Type of resource affected';
COMMENT ON COLUMN audit_logs.details IS 'Additional details in JSON format';

-- ============== ROLLBACK DOWN ==============

/*
-- To rollback this migration, run the following SQL:

-- Drop triggers
DROP TRIGGER IF EXISTS update_servers_updated_at ON servers;
DROP TRIGGER IF EXISTS update_users_updated_at ON users;

-- Drop function
DROP FUNCTION IF EXISTS update_updated_at_column();

-- Drop tables (in reverse order of dependencies)
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS servers CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS schema_migrations CASCADE;

-- Drop extension
DROP EXTENSION IF EXISTS "uuid-ossp";

*/
