-- =====================================================
-- Migration: 004_add_locations
-- Description: Add geographic server locations and mapping
-- Created: 2025-10-26
-- =====================================================

-- ============== MIGRATION UP ==============

-- Create server_locations table for geographic location data
CREATE TABLE IF NOT EXISTS server_locations (
    location_id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    country VARCHAR(100) NOT NULL,
    country_code CHAR(2) NOT NULL, -- ISO 3166-1 alpha-2
    city VARCHAR(100) NOT NULL,
    region VARCHAR(100), -- State/Province
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    timezone VARCHAR(50),
    data_center VARCHAR(255), -- e.g., 'AWS us-east-1', 'Azure West US'
    flag_emoji CHAR(4), -- Country flag emoji
    display_order INTEGER DEFAULT 0,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for server_locations
CREATE INDEX IF NOT EXISTS idx_locations_country ON server_locations(country);
CREATE INDEX IF NOT EXISTS idx_locations_country_code ON server_locations(country_code);
CREATE INDEX IF NOT EXISTS idx_locations_enabled ON server_locations(enabled);
CREATE INDEX IF NOT EXISTS idx_locations_display_order ON server_locations(display_order);

-- Create unique constraint on country + city combination
CREATE UNIQUE INDEX IF NOT EXISTS idx_locations_country_city ON server_locations(country_code, city);

-- Add location_id column to servers table (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'servers' AND column_name = 'location_id'
    ) THEN
        ALTER TABLE servers ADD COLUMN location_id INTEGER;
    END IF;
END $$;

-- Add foreign key constraint to servers table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_servers_location'
    ) THEN
        ALTER TABLE servers
        ADD CONSTRAINT fk_servers_location
        FOREIGN KEY (location_id)
        REFERENCES server_locations(location_id)
        ON DELETE SET NULL;
    END IF;
END $$;

-- Create index on servers.location_id
CREATE INDEX IF NOT EXISTS idx_servers_location_id ON servers(location_id);

-- Insert sample locations (idempotent)
INSERT INTO server_locations (name, country, country_code, city, region, latitude, longitude, timezone, data_center, flag_emoji, display_order, enabled)
VALUES
    ('US East - New York', 'United States', 'US', 'New York', 'New York', 40.7128, -74.0060, 'America/New_York', 'AWS us-east-1', '🇺🇸', 1, true),
    ('US East - Virginia', 'United States', 'US', 'Ashburn', 'Virginia', 39.0438, -77.4874, 'America/New_York', 'AWS us-east-1', '🇺🇸', 2, true),
    ('US West - California', 'United States', 'US', 'San Francisco', 'California', 37.7749, -122.4194, 'America/Los_Angeles', 'AWS us-west-1', '🇺🇸', 3, true),
    ('US West - Oregon', 'United States', 'US', 'Portland', 'Oregon', 45.5152, -122.6784, 'America/Los_Angeles', 'AWS us-west-2', '🇺🇸', 4, true),
    ('Europe - London', 'United Kingdom', 'GB', 'London', 'England', 51.5074, -0.1278, 'Europe/London', 'AWS eu-west-2', '🇬🇧', 5, true),
    ('Europe - Frankfurt', 'Germany', 'DE', 'Frankfurt', 'Hesse', 50.1109, 8.6821, 'Europe/Berlin', 'AWS eu-central-1', '🇩🇪', 6, true),
    ('Europe - Paris', 'France', 'FR', 'Paris', 'Île-de-France', 48.8566, 2.3522, 'Europe/Paris', 'AWS eu-west-3', '🇫🇷', 7, true),
    ('Europe - Amsterdam', 'Netherlands', 'NL', 'Amsterdam', 'North Holland', 52.3676, 4.9041, 'Europe/Amsterdam', 'AWS eu-west-1', '🇳🇱', 8, true),
    ('Asia - Tokyo', 'Japan', 'JP', 'Tokyo', 'Kanto', 35.6762, 139.6503, 'Asia/Tokyo', 'AWS ap-northeast-1', '🇯🇵', 9, true),
    ('Asia - Singapore', 'Singapore', 'SG', 'Singapore', 'Central', 1.3521, 103.8198, 'Asia/Singapore', 'AWS ap-southeast-1', '🇸🇬', 10, true),
    ('Asia - Mumbai', 'India', 'IN', 'Mumbai', 'Maharashtra', 19.0760, 72.8777, 'Asia/Kolkata', 'AWS ap-south-1', '🇮🇳', 11, true),
    ('Asia - Seoul', 'South Korea', 'KR', 'Seoul', 'Seoul Capital Area', 37.5665, 126.9780, 'Asia/Seoul', 'AWS ap-northeast-2', '🇰🇷', 12, true),
    ('Australia - Sydney', 'Australia', 'AU', 'Sydney', 'New South Wales', -33.8688, 151.2093, 'Australia/Sydney', 'AWS ap-southeast-2', '🇦🇺', 13, true),
    ('Canada - Toronto', 'Canada', 'CA', 'Toronto', 'Ontario', 43.6532, -79.3832, 'America/Toronto', 'AWS ca-central-1', '🇨🇦', 14, true),
    ('South America - São Paulo', 'Brazil', 'BR', 'São Paulo', 'São Paulo', -23.5505, -46.6333, 'America/Sao_Paulo', 'AWS sa-east-1', '🇧🇷', 15, true)
ON CONFLICT (name) DO NOTHING;

-- Create view for servers with location details
CREATE OR REPLACE VIEW v_servers_with_locations AS
SELECT
    s.id,
    s.name as server_name,
    s.host,
    s.port,
    s.enabled as server_enabled,
    s.server_type,
    s.last_sync,
    l.location_id,
    l.name as location_name,
    l.country,
    l.country_code,
    l.city,
    l.region,
    l.latitude,
    l.longitude,
    l.timezone,
    l.data_center,
    l.flag_emoji,
    l.enabled as location_enabled
FROM servers s
LEFT JOIN server_locations l ON s.location_id = l.location_id
ORDER BY l.display_order, s.name;

-- Create view for location statistics
CREATE OR REPLACE VIEW v_location_statistics AS
SELECT
    l.location_id,
    l.name as location_name,
    l.country,
    l.country_code,
    l.city,
    l.flag_emoji,
    COUNT(DISTINCT s.id) as total_servers,
    COUNT(DISTINCT s.id) FILTER (WHERE s.enabled = true) as active_servers,
    COUNT(DISTINCT u.username) as total_users,
    COUNT(DISTINCT vc.id) as active_connections,
    COALESCE(SUM(vs.bytes_in + vs.bytes_out), 0) as total_bandwidth
FROM server_locations l
LEFT JOIN servers s ON l.location_id = s.location_id
LEFT JOIN users u ON s.name = u.server_id
LEFT JOIN vpn_connections vc ON s.name = vc.server_id AND vc.status IN ('connecting', 'connected')
LEFT JOIN vpn_statistics vs ON s.name = vs.server_id
WHERE l.enabled = true
GROUP BY l.location_id, l.name, l.country, l.country_code, l.city, l.flag_emoji
ORDER BY l.display_order;

-- Create function to get nearest location based on coordinates
CREATE OR REPLACE FUNCTION get_nearest_location(
    user_lat DECIMAL(10, 8),
    user_lon DECIMAL(11, 8),
    max_results INTEGER DEFAULT 5
)
RETURNS TABLE (
    location_id INTEGER,
    location_name VARCHAR(255),
    country VARCHAR(100),
    city VARCHAR(100),
    distance_km NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        sl.location_id,
        sl.name,
        sl.country,
        sl.city,
        ROUND(
            6371 * acos(
                cos(radians(user_lat)) *
                cos(radians(sl.latitude)) *
                cos(radians(sl.longitude) - radians(user_lon)) +
                sin(radians(user_lat)) *
                sin(radians(sl.latitude))
            )::numeric,
            2
        ) as distance_km
    FROM server_locations sl
    WHERE sl.enabled = true
        AND sl.latitude IS NOT NULL
        AND sl.longitude IS NOT NULL
    ORDER BY distance_km
    LIMIT max_results;
END;
$$ LANGUAGE plpgsql;

-- Add comments to document the schema
COMMENT ON TABLE server_locations IS 'Geographic locations for VPN servers with coordinates and metadata';
COMMENT ON VIEW v_servers_with_locations IS 'Servers joined with their geographic location details';
COMMENT ON VIEW v_location_statistics IS 'Aggregated statistics per location including server count and bandwidth';
COMMENT ON FUNCTION get_nearest_location IS 'Finds nearest server locations using Haversine formula (great-circle distance)';

COMMENT ON COLUMN server_locations.country_code IS 'ISO 3166-1 alpha-2 country code (e.g., US, GB, JP)';
COMMENT ON COLUMN server_locations.latitude IS 'Latitude in decimal degrees (-90 to 90)';
COMMENT ON COLUMN server_locations.longitude IS 'Longitude in decimal degrees (-180 to 180)';
COMMENT ON COLUMN server_locations.flag_emoji IS 'Unicode flag emoji for the country';
COMMENT ON COLUMN server_locations.display_order IS 'Display order for UI sorting (lower numbers first)';
COMMENT ON COLUMN servers.location_id IS 'Foreign key to server_locations table';

-- ============== ROLLBACK DOWN ==============

/*
-- To rollback this migration, run the following SQL:

-- Drop function
DROP FUNCTION IF EXISTS get_nearest_location(DECIMAL, DECIMAL, INTEGER);

-- Drop views
DROP VIEW IF EXISTS v_location_statistics;
DROP VIEW IF EXISTS v_servers_with_locations;

-- Remove foreign key constraint
ALTER TABLE servers DROP CONSTRAINT IF EXISTS fk_servers_location;

-- Remove location_id column from servers
ALTER TABLE servers DROP COLUMN IF EXISTS location_id;

-- Drop server_locations table
DROP TABLE IF EXISTS server_locations CASCADE;

*/
