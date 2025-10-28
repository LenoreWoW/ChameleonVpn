-- =====================================================
-- Migration: 003_add_statistics
-- Description: Add VPN usage statistics and connection tracking
-- Created: 2025-10-26
-- =====================================================

-- ============== MIGRATION UP ==============

-- Create vpn_statistics table for tracking bandwidth and usage
CREATE TABLE IF NOT EXISTS vpn_statistics (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL,
    server_id VARCHAR(255) NOT NULL,
    bytes_in BIGINT DEFAULT 0,
    bytes_out BIGINT DEFAULT 0,
    duration_seconds INTEGER DEFAULT 0,
    connection_id INTEGER, -- Foreign key to vpn_connections
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    session_type VARCHAR(50) DEFAULT 'vpn', -- 'vpn', 'api', 'web'
    client_version VARCHAR(50),
    protocol VARCHAR(10) DEFAULT 'udp', -- 'udp' or 'tcp'
    encryption VARCHAR(50) DEFAULT 'AES-256-GCM',
    CONSTRAINT fk_vpn_stats_user
        FOREIGN KEY (username)
        REFERENCES users(username)
        ON DELETE CASCADE
);

-- Create indexes for vpn_statistics
CREATE INDEX IF NOT EXISTS idx_vpn_stats_username ON vpn_statistics(username);
CREATE INDEX IF NOT EXISTS idx_vpn_stats_server_id ON vpn_statistics(server_id);
CREATE INDEX IF NOT EXISTS idx_vpn_stats_started_at ON vpn_statistics(started_at);
CREATE INDEX IF NOT EXISTS idx_vpn_stats_ended_at ON vpn_statistics(ended_at);
CREATE INDEX IF NOT EXISTS idx_vpn_stats_duration ON vpn_statistics(duration_seconds);
CREATE INDEX IF NOT EXISTS idx_vpn_stats_connection_id ON vpn_statistics(connection_id);

-- Create composite index for user analytics
CREATE INDEX IF NOT EXISTS idx_vpn_stats_user_date ON vpn_statistics(username, started_at DESC);

-- Create composite index for server analytics
CREATE INDEX IF NOT EXISTS idx_vpn_stats_server_date ON vpn_statistics(server_id, started_at DESC);

-- Create vpn_connections table for real-time connection tracking
CREATE TABLE IF NOT EXISTS vpn_connections (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL,
    server_id VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'connecting', -- 'connecting', 'connected', 'disconnected', 'error'
    client_ip INET,
    virtual_ip INET, -- VPN-assigned IP address
    public_ip INET, -- Client's public IP
    connected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    disconnected_at TIMESTAMP,
    duration_seconds INTEGER, -- Calculated on disconnect
    disconnect_reason VARCHAR(255),
    bytes_received BIGINT DEFAULT 0,
    bytes_sent BIGINT DEFAULT 0,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    device_name VARCHAR(255),
    device_type VARCHAR(50), -- 'windows', 'macos', 'linux', 'ios', 'android'
    app_version VARCHAR(50),
    CONSTRAINT fk_vpn_conn_user
        FOREIGN KEY (username)
        REFERENCES users(username)
        ON DELETE CASCADE
);

-- Create indexes for vpn_connections
CREATE INDEX IF NOT EXISTS idx_vpn_conn_username ON vpn_connections(username);
CREATE INDEX IF NOT EXISTS idx_vpn_conn_server_id ON vpn_connections(server_id);
CREATE INDEX IF NOT EXISTS idx_vpn_conn_status ON vpn_connections(status);
CREATE INDEX IF NOT EXISTS idx_vpn_conn_connected_at ON vpn_connections(connected_at);
CREATE INDEX IF NOT EXISTS idx_vpn_conn_disconnected_at ON vpn_connections(disconnected_at);
CREATE INDEX IF NOT EXISTS idx_vpn_conn_last_activity ON vpn_connections(last_activity);

-- Create composite index for active connections
CREATE INDEX IF NOT EXISTS idx_vpn_conn_active ON vpn_connections(status, connected_at DESC)
WHERE status IN ('connecting', 'connected');

-- Create composite index for user connection history
CREATE INDEX IF NOT EXISTS idx_vpn_conn_user_history ON vpn_connections(username, connected_at DESC);

-- Add foreign key constraint to vpn_statistics if both tables exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_vpn_stats_connection'
    ) THEN
        ALTER TABLE vpn_statistics
        ADD CONSTRAINT fk_vpn_stats_connection
        FOREIGN KEY (connection_id)
        REFERENCES vpn_connections(id)
        ON DELETE SET NULL;
    END IF;
END $$;

-- Create view for active connections summary
CREATE OR REPLACE VIEW v_active_connections AS
SELECT
    vc.id,
    vc.username,
    vc.server_id,
    vc.status,
    vc.virtual_ip,
    vc.connected_at,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - vc.connected_at))::INTEGER as duration_seconds,
    vc.bytes_received,
    vc.bytes_sent,
    vc.device_type,
    vc.last_activity,
    u.phone_number,
    u.created_via
FROM vpn_connections vc
JOIN users u ON vc.username = u.username
WHERE vc.status IN ('connecting', 'connected')
ORDER BY vc.connected_at DESC;

-- Create view for user statistics summary
CREATE OR REPLACE VIEW v_user_statistics AS
SELECT
    username,
    COUNT(*) as total_sessions,
    SUM(bytes_in) as total_bytes_in,
    SUM(bytes_out) as total_bytes_out,
    SUM(bytes_in + bytes_out) as total_bandwidth,
    SUM(duration_seconds) as total_duration_seconds,
    AVG(duration_seconds) as avg_duration_seconds,
    MAX(started_at) as last_session,
    MIN(started_at) as first_session
FROM vpn_statistics
WHERE ended_at IS NOT NULL
GROUP BY username;

-- Create view for server statistics summary
CREATE OR REPLACE VIEW v_server_statistics AS
SELECT
    server_id,
    COUNT(*) as total_sessions,
    COUNT(DISTINCT username) as unique_users,
    SUM(bytes_in) as total_bytes_in,
    SUM(bytes_out) as total_bytes_out,
    SUM(bytes_in + bytes_out) as total_bandwidth,
    SUM(duration_seconds) as total_duration_seconds,
    AVG(duration_seconds) as avg_duration_seconds,
    MAX(started_at) as last_session
FROM vpn_statistics
WHERE ended_at IS NOT NULL
GROUP BY server_id;

-- Add comments to document the tables
COMMENT ON TABLE vpn_statistics IS 'Historical VPN usage statistics for bandwidth and duration tracking';
COMMENT ON TABLE vpn_connections IS 'Real-time VPN connection tracking with status and metadata';
COMMENT ON VIEW v_active_connections IS 'View of currently active VPN connections with user details';
COMMENT ON VIEW v_user_statistics IS 'Aggregated statistics per user for analytics';
COMMENT ON VIEW v_server_statistics IS 'Aggregated statistics per server for capacity planning';

COMMENT ON COLUMN vpn_statistics.bytes_in IS 'Bytes received by client from VPN server';
COMMENT ON COLUMN vpn_statistics.bytes_out IS 'Bytes sent by client to VPN server';
COMMENT ON COLUMN vpn_statistics.duration_seconds IS 'Total connection duration in seconds';
COMMENT ON COLUMN vpn_connections.virtual_ip IS 'VPN-assigned private IP address (e.g., 10.8.0.x)';
COMMENT ON COLUMN vpn_connections.public_ip IS 'Client public IP address';
COMMENT ON COLUMN vpn_connections.status IS 'Current connection status: connecting, connected, disconnected, error';

-- Record this migration as applied
INSERT INTO schema_migrations (version) VALUES ('003_add_statistics')
ON CONFLICT (version) DO NOTHING;

-- ============== ROLLBACK DOWN ==============

/*
-- To rollback this migration, run the following SQL:

-- Drop views
DROP VIEW IF EXISTS v_server_statistics;
DROP VIEW IF EXISTS v_user_statistics;
DROP VIEW IF EXISTS v_active_connections;

-- Drop foreign key constraint
ALTER TABLE vpn_statistics DROP CONSTRAINT IF EXISTS fk_vpn_stats_connection;

-- Drop tables
DROP TABLE IF EXISTS vpn_statistics CASCADE;
DROP TABLE IF EXISTS vpn_connections CASCADE;

*/
