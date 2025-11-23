package shared

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	_ "github.com/lib/pq"
)

// DatabaseConfig holds PostgreSQL connection configuration
type DatabaseConfig struct {
	Host     string
	Port     int
	User     string
	Password string
	DBName   string
	SSLMode  string
}

// DB represents the PostgreSQL database connection
type DB struct {
	conn *sql.DB
	cfg  *DatabaseConfig
}

// NewDatabase creates a new PostgreSQL database connection
func NewDatabase(cfg *DatabaseConfig) (*DB, error) {
	dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.DBName, cfg.SSLMode)

	conn, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %v", err)
	}

	// Test the connection
	if err := conn.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %v", err)
	}

	// Set connection pool settings
	conn.SetMaxOpenConns(25)
	conn.SetMaxIdleConns(5)
	conn.SetConnMaxLifetime(time.Hour)

	db := &DB{
		conn: conn,
		cfg:  cfg,
	}

	// Initialize schema
	// NOTE: Schema initialization is handled by migrations (migrations/*.sql)
	// Commenting out to avoid conflicts with migration-managed schema
	// if err := db.initSchema(); err != nil {
	// 	return nil, fmt.Errorf("failed to initialize schema: %v", err)
	// }

	return db, nil
}

// Close closes the database connection
func (db *DB) Close() error {
	return db.conn.Close()
}

// initSchema initializes the database schema
func (db *DB) initSchema() error {
	schema := `
	-- Users table
	CREATE TABLE IF NOT EXISTS users (
		id SERIAL PRIMARY KEY,
		username VARCHAR(255) UNIQUE NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		expires_at TIMESTAMP,
		active BOOLEAN DEFAULT true,
		ovpn_path TEXT,
		port INTEGER DEFAULT 1194,
		protocol VARCHAR(10) DEFAULT 'udp',
		last_access TIMESTAMP,
		checksum VARCHAR(255),
		synced BOOLEAN DEFAULT false,
		server_id VARCHAR(255) NOT NULL,
		created_by VARCHAR(255) NOT NULL
	);

	-- Servers table
	CREATE TABLE IF NOT EXISTS servers (
		id SERIAL PRIMARY KEY,
		name VARCHAR(255) UNIQUE NOT NULL,
		host VARCHAR(255) NOT NULL,
		port INTEGER DEFAULT 8080,
		username VARCHAR(255),
		password VARCHAR(255),
		enabled BOOLEAN DEFAULT true,
		last_sync TIMESTAMP,
		server_type VARCHAR(50) DEFAULT 'endnode',
		management_url VARCHAR(255),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	-- Audit log table (matches migrations schema)
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

	-- Server health table
	CREATE TABLE IF NOT EXISTS server_health (
		id SERIAL PRIMARY KEY,
		server_id VARCHAR(255) NOT NULL,
		status VARCHAR(50) NOT NULL,
		last_check TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		response_time_ms INTEGER,
		error_message TEXT
	);

	-- Authentication users table
	CREATE TABLE IF NOT EXISTS auth_users (
		id SERIAL PRIMARY KEY,
		phone_number VARCHAR(20) UNIQUE NOT NULL,
		password_hash TEXT NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		last_login TIMESTAMP,
		active BOOLEAN DEFAULT true,
		failed_login_attempts INTEGER DEFAULT 0,
		locked_until TIMESTAMP,
		email VARCHAR(255),
		full_name VARCHAR(255)
	);

	-- VPN connection status table
	CREATE TABLE IF NOT EXISTS vpn_connections (
		id SERIAL PRIMARY KEY,
		username VARCHAR(255) NOT NULL,
		status VARCHAR(50) NOT NULL,
		server_id VARCHAR(255) NOT NULL,
		connected_at TIMESTAMP,
		disconnected_at TIMESTAMP,
		ip_address INET,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	-- VPN statistics table
	CREATE TABLE IF NOT EXISTS vpn_statistics (
		id SERIAL PRIMARY KEY,
		username VARCHAR(255) NOT NULL,
		server_id VARCHAR(255) NOT NULL,
		bytes_in BIGINT DEFAULT 0,
		bytes_out BIGINT DEFAULT 0,
		duration_seconds INTEGER DEFAULT 0,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	-- Server locations table
	CREATE TABLE IF NOT EXISTS server_locations (
		id SERIAL PRIMARY KEY,
		country VARCHAR(255) NOT NULL,
		city VARCHAR(255) NOT NULL,
		country_code VARCHAR(10) NOT NULL,
		latitude DECIMAL(9,6),
		longitude DECIMAL(9,6),
		enabled BOOLEAN DEFAULT true
	);

	-- Link servers to locations
	ALTER TABLE servers ADD COLUMN IF NOT EXISTS location_id INTEGER REFERENCES server_locations(id);

	-- Create indexes
	CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
	CREATE INDEX IF NOT EXISTS idx_users_active ON users(active);
	CREATE INDEX IF NOT EXISTS idx_users_server_id ON users(server_id);
	CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON audit_log(created_at);
	CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action);
	CREATE INDEX IF NOT EXISTS idx_audit_log_status ON audit_log(status);
	CREATE INDEX IF NOT EXISTS idx_audit_log_user_id ON audit_log(user_id);
	CREATE INDEX IF NOT EXISTS idx_audit_log_resource_type ON audit_log(resource_type);
	CREATE INDEX IF NOT EXISTS idx_servers_enabled ON servers(enabled);
	CREATE INDEX IF NOT EXISTS idx_servers_type ON servers(server_type);
	CREATE INDEX IF NOT EXISTS idx_server_health_server_id ON server_health(server_id);
	CREATE INDEX IF NOT EXISTS idx_server_health_last_check ON server_health(last_check);
	CREATE INDEX IF NOT EXISTS idx_vpn_connections_username ON vpn_connections(username);
	CREATE INDEX IF NOT EXISTS idx_vpn_connections_status ON vpn_connections(status);
	CREATE INDEX IF NOT EXISTS idx_vpn_connections_created_at ON vpn_connections(created_at);
	CREATE INDEX IF NOT EXISTS idx_vpn_statistics_username ON vpn_statistics(username);
	CREATE INDEX IF NOT EXISTS idx_vpn_statistics_server_id ON vpn_statistics(server_id);
	CREATE INDEX IF NOT EXISTS idx_vpn_statistics_created_at ON vpn_statistics(created_at);
	CREATE INDEX IF NOT EXISTS idx_server_locations_enabled ON server_locations(enabled);
	CREATE INDEX IF NOT EXISTS idx_auth_users_phone_number ON auth_users(phone_number);
	CREATE INDEX IF NOT EXISTS idx_auth_users_active ON auth_users(active);
	CREATE INDEX IF NOT EXISTS idx_auth_users_created_at ON auth_users(created_at);
	`

	_, err := db.conn.Exec(schema)
	return err
}

// GetConnection returns the underlying database connection
func (db *DB) GetConnection() *sql.DB {
	return db.conn
}

// Migration represents a database migration
type Migration struct {
	Version int
	Name    string
	SQL     string
}

// RunMigrations executes all pending database migrations from the migrations directory
// migrations should be located in the "migrations" directory relative to the project root
func (db *DB) RunMigrations(migrationsPath string) error {
	// Create migrations tracking table if it doesn't exist
	if err := db.createMigrationsTable(); err != nil {
		return fmt.Errorf("failed to create migrations table: %v", err)
	}

	// Get list of applied migrations
	appliedMigrations, err := db.getAppliedMigrations()
	if err != nil {
		return fmt.Errorf("failed to get applied migrations: %v", err)
	}

	// Read migration files from directory
	migrations, err := db.readMigrationFiles(migrationsPath)
	if err != nil {
		return fmt.Errorf("failed to read migration files: %v", err)
	}

	// Apply pending migrations
	for _, migration := range migrations {
		if _, applied := appliedMigrations[migration.Version]; applied {
			log.Printf("Migration %03d_%s already applied, skipping", migration.Version, migration.Name)
			continue
		}

		log.Printf("Applying migration %03d_%s...", migration.Version, migration.Name)
		if err := db.applyMigration(migration); err != nil {
			return fmt.Errorf("failed to apply migration %03d_%s: %v", migration.Version, migration.Name, err)
		}
		log.Printf("Successfully applied migration %03d_%s", migration.Version, migration.Name)
	}

	log.Printf("All migrations completed successfully")
	return nil
}

// createMigrationsTable creates the schema_migrations table for tracking applied migrations
// Note: Uses VARCHAR for version to match existing migration files (e.g., '001_initial_schema')
func (db *DB) createMigrationsTable() error {
	schema := `
	CREATE TABLE IF NOT EXISTS schema_migrations (
		id SERIAL PRIMARY KEY,
		version INTEGER NOT NULL UNIQUE,
		name VARCHAR(255) NOT NULL,
		applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		checksum VARCHAR(64) -- For future integrity checking
	);
	CREATE INDEX IF NOT EXISTS idx_migrations_version ON schema_migrations(version);
	CREATE INDEX IF NOT EXISTS idx_migrations_applied_at ON schema_migrations(applied_at);
	`
	_, err := db.conn.Exec(schema)
	return err
}

// getAppliedMigrations returns a map of already applied migration versions
func (db *DB) getAppliedMigrations() (map[int]bool, error) {
	rows, err := db.conn.Query("SELECT version FROM schema_migrations ORDER BY version")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	applied := make(map[int]bool)
	for rows.Next() {
		var version int
		if err := rows.Scan(&version); err != nil {
			return nil, err
		}
		applied[version] = true
	}
	return applied, rows.Err()
}

// readMigrationFiles reads and parses migration files from the specified directory
func (db *DB) readMigrationFiles(migrationsPath string) ([]Migration, error) {
	files, err := os.ReadDir(migrationsPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read migrations directory: %v", err)
	}

	var migrations []Migration
	for _, file := range files {
		if file.IsDir() || !strings.HasSuffix(file.Name(), ".sql") {
			continue
		}

		// Parse migration filename (format: 002_add_phone_auth.sql)
		parts := strings.SplitN(file.Name(), "_", 2)
		if len(parts) < 2 {
			log.Printf("Skipping invalid migration filename: %s", file.Name())
			continue
		}

		var version int
		if _, err := fmt.Sscanf(parts[0], "%d", &version); err != nil {
			log.Printf("Skipping migration with invalid version: %s", file.Name())
			continue
		}

		name := strings.TrimSuffix(parts[1], ".sql")

		// Read SQL content
		sqlPath := filepath.Join(migrationsPath, file.Name())
		content, err := os.ReadFile(sqlPath)
		if err != nil {
			return nil, fmt.Errorf("failed to read migration file %s: %v", file.Name(), err)
		}

		// Extract only the "MIGRATION UP" section (ignore rollback)
		sqlContent := string(content)
		sqlContent = db.extractUpMigration(sqlContent)

		migrations = append(migrations, Migration{
			Version: version,
			Name:    name,
			SQL:     sqlContent,
		})
	}

	// Sort migrations by version
	sort.Slice(migrations, func(i, j int) bool {
		return migrations[i].Version < migrations[j].Version
	})

	return migrations, nil
}

// extractUpMigration extracts the UP migration SQL, excluding rollback section
// Also removes schema_migrations table creation and INSERT statements since those are handled by the migration system
func (db *DB) extractUpMigration(content string) string {
	// Remove commented rollback section (everything after "ROLLBACK DOWN")
	if idx := strings.Index(content, "-- ============== ROLLBACK DOWN =============="); idx != -1 {
		content = content[:idx]
	}
	if idx := strings.Index(content, "/*"); idx != -1 {
		content = content[:idx]
	}

	// Remove schema_migrations table creation (handled by migration system)
	lines := strings.Split(content, "\n")
	var filtered []string
	skipUntilSemicolon := false

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)

		// Skip schema_migrations table creation
		if strings.Contains(trimmed, "CREATE TABLE") && strings.Contains(trimmed, "schema_migrations") {
			skipUntilSemicolon = true
			continue
		}

		// Skip INSERT into schema_migrations
		if strings.Contains(trimmed, "INSERT INTO schema_migrations") {
			skipUntilSemicolon = true
			continue
		}

		if skipUntilSemicolon {
			if strings.Contains(trimmed, ";") {
				skipUntilSemicolon = false
			}
			continue
		}

		filtered = append(filtered, line)
	}

	return strings.TrimSpace(strings.Join(filtered, "\n"))
}

// applyMigration applies a single migration within a transaction
func (db *DB) applyMigration(migration Migration) error {
	// Start transaction
	tx, err := db.conn.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %v", err)
	}
	defer tx.Rollback() // Rollback if not committed

	// Execute migration SQL
	if _, err := tx.Exec(migration.SQL); err != nil {
		return fmt.Errorf("failed to execute migration SQL: %v", err)
	}

	// Record migration in schema_migrations table
	_, err = tx.Exec(
		"INSERT INTO schema_migrations (version, name) VALUES ($1, $2)",
		migration.Version,
		migration.Name,
	)
	if err != nil {
		return fmt.Errorf("failed to record migration: %v", err)
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit migration: %v", err)
	}

	return nil
}

// GetMigrationStatus returns the current migration status
func (db *DB) GetMigrationStatus() ([]map[string]interface{}, error) {
	rows, err := db.conn.Query(`
		SELECT version, name, applied_at
		FROM schema_migrations
		ORDER BY version DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var migrations []map[string]interface{}
	for rows.Next() {
		var version int
		var name string
		var appliedAt time.Time

		if err := rows.Scan(&version, &name, &appliedAt); err != nil {
			return nil, err
		}

		migrations = append(migrations, map[string]interface{}{
			"version":    version,
			"name":       name,
			"applied_at": appliedAt,
		})
	}

	return migrations, rows.Err()
}
