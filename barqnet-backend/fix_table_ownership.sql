-- Fix table ownership for barqnet database
-- Run this as postgres superuser: sudo -u postgres psql -d barqnet -f fix_table_ownership.sql

-- Change ownership of all tables to barqnet user
ALTER TABLE IF EXISTS users OWNER TO barqnet;
ALTER TABLE IF EXISTS servers OWNER TO barqnet;
ALTER TABLE IF EXISTS locations OWNER TO barqnet;
ALTER TABLE IF EXISTS vpn_statistics OWNER TO barqnet;
ALTER TABLE IF EXISTS token_blacklist OWNER TO barqnet;
ALTER TABLE IF EXISTS token_blacklist_audit OWNER TO barqnet;

-- Change ownership of all sequences to barqnet user
ALTER SEQUENCE IF EXISTS users_id_seq OWNER TO barqnet;
ALTER SEQUENCE IF EXISTS servers_id_seq OWNER TO barqnet;
ALTER SEQUENCE IF EXISTS locations_id_seq OWNER TO barqnet;
ALTER SEQUENCE IF EXISTS vpn_statistics_id_seq OWNER TO barqnet;
ALTER SEQUENCE IF EXISTS token_blacklist_id_seq OWNER TO barqnet;
ALTER SEQUENCE IF EXISTS token_blacklist_audit_id_seq OWNER TO barqnet;

-- Change ownership of all views to barqnet user
ALTER VIEW IF EXISTS active_tokens OWNER TO barqnet;

-- Grant all privileges to barqnet user (belt and suspenders)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO barqnet;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO barqnet;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO barqnet;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO barqnet;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO barqnet;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO barqnet;

-- Display confirmation
SELECT 'Table ownership fixed!' AS status;
SELECT schemaname, tablename, tableowner FROM pg_tables WHERE schemaname = 'public';
