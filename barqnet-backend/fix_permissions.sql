-- Fix PostgreSQL permissions for barqnet database
-- Run this as postgres superuser: psql -U postgres -d barqnet -f fix_permissions.sql

-- Grant all privileges on database to barqnet user
GRANT ALL PRIVILEGES ON DATABASE barqnet TO barqnet;

-- Grant usage and create on schema public
GRANT USAGE ON SCHEMA public TO barqnet;
GRANT CREATE ON SCHEMA public TO barqnet;

-- Grant all privileges on all existing tables
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO barqnet;

-- Grant all privileges on all sequences (for auto-increment IDs)
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO barqnet;

-- Grant all privileges on all functions
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO barqnet;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO barqnet;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO barqnet;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO barqnet;

-- Make barqnet user the owner of the database (optional but recommended)
ALTER DATABASE barqnet OWNER TO barqnet;

-- Display confirmation
SELECT 'Permissions fixed successfully!' AS status;
SELECT 'User: barqnet now has full privileges on database: barqnet' AS info;
