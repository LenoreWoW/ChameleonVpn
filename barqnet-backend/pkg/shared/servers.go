package shared

import (
	"database/sql"
	"time"
)

// ServerManager handles server operations
type ServerManager struct {
	db *DB
}

// NewServerManager creates a new server manager
func NewServerManager(db *DB) *ServerManager {
	return &ServerManager{db: db}
}

// AddServer adds a new server to the database
func (sm *ServerManager) AddServer(name, host string, port int, username, password, serverType, managementURL string) error {
	query := `
		INSERT INTO servers (name, host, port, username, password, server_type, management_url, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT (name) DO UPDATE SET
			host = EXCLUDED.host,
			port = EXCLUDED.port,
			username = EXCLUDED.username,
			password = EXCLUDED.password,
			server_type = EXCLUDED.server_type,
			management_url = EXCLUDED.management_url
	`
	
	_, err := sm.db.conn.Exec(query, name, host, port, username, password, serverType, managementURL, time.Now())
	return err
}

// GetServer retrieves a server by name
func (sm *ServerManager) GetServer(name string) (*Server, error) {
	query := `
		SELECT id, name, host, port, username, password, enabled, last_sync, server_type, management_url, created_at
		FROM servers WHERE name = $1
	`
	
	var server Server
	var lastSync sql.NullTime
	
	err := sm.db.conn.QueryRow(query, name).Scan(
		&server.ID, &server.Name, &server.Host, &server.Port, &server.Username,
		&server.Password, &server.Enabled, &lastSync, &server.ServerType,
		&server.ManagementURL, &server.CreatedAt,
	)
	
	if err != nil {
		return nil, err
	}
	
	if lastSync.Valid {
		server.LastSync = lastSync.Time
	}
	
	return &server, nil
}

// ListServers returns all servers
func (sm *ServerManager) ListServers() ([]Server, error) {
	query := `
		SELECT id, name, host, port, username, password, enabled, last_sync, server_type, management_url, created_at
		FROM servers ORDER BY name
	`
	
	rows, err := sm.db.conn.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var servers []Server
	for rows.Next() {
		var server Server
		var lastSync sql.NullTime
		
		err := rows.Scan(
			&server.ID, &server.Name, &server.Host, &server.Port, &server.Username,
			&server.Password, &server.Enabled, &lastSync, &server.ServerType,
			&server.ManagementURL, &server.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		
		if lastSync.Valid {
			server.LastSync = lastSync.Time
		}
		
		servers = append(servers, server)
	}
	
	return servers, rows.Err()
}

// ListEndNodes returns all end-node servers
func (sm *ServerManager) ListEndNodes() ([]Server, error) {
	query := `
		SELECT id, name, host, port, username, password, enabled, last_sync, server_type, management_url, created_at
		FROM servers WHERE server_type = 'endnode' AND enabled = true ORDER BY name
	`
	
	rows, err := sm.db.conn.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var servers []Server
	for rows.Next() {
		var server Server
		var lastSync sql.NullTime
		
		err := rows.Scan(
			&server.ID, &server.Name, &server.Host, &server.Port, &server.Username,
			&server.Password, &server.Enabled, &lastSync, &server.ServerType,
			&server.ManagementURL, &server.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		
		if lastSync.Valid {
			server.LastSync = lastSync.Time
		}
		
		servers = append(servers, server)
	}
	
	return servers, rows.Err()
}

// UpdateServerLastSync updates the last sync time for a server
func (sm *ServerManager) UpdateServerLastSync(name string) error {
	query := `UPDATE servers SET last_sync = $1 WHERE name = $2`
	_, err := sm.db.conn.Exec(query, time.Now(), name)
	return err
}

// EnableServer enables a server
func (sm *ServerManager) EnableServer(name string) error {
	query := `UPDATE servers SET enabled = true WHERE name = $1`
	_, err := sm.db.conn.Exec(query, name)
	return err
}

// DisableServer disables a server
func (sm *ServerManager) DisableServer(name string) error {
	query := `UPDATE servers SET enabled = false WHERE name = $1`
	_, err := sm.db.conn.Exec(query, name)
	return err
}

// RemoveServer removes a server
func (sm *ServerManager) RemoveServer(name string) error {
	query := `DELETE FROM servers WHERE name = $1`
	_, err := sm.db.conn.Exec(query, name)
	return err
}

// ServerExists checks if a server exists
func (sm *ServerManager) ServerExists(name string) (bool, error) {
	query := `SELECT COUNT(*) FROM servers WHERE name = $1`
	var count int
	err := sm.db.conn.QueryRow(query, name).Scan(&count)
	return count > 0, err
}
