package shared

import (
	"database/sql"
	"time"
)

// UserManager handles user operations
type UserManager struct {
	db *DB
}

// NewUserManager creates a new user manager
func NewUserManager(db *DB) *UserManager {
	return &UserManager{db: db}
}

// AddUser adds a new user to the database
func (um *UserManager) AddUser(username, ovpnPath, checksum, serverID, createdBy string, port int, protocol string) error {
	query := `
		INSERT INTO users (username, ovpn_path, checksum, server_id, created_by, port, protocol, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT (username) DO UPDATE SET
			ovpn_path = EXCLUDED.ovpn_path,
			checksum = EXCLUDED.checksum,
			server_id = EXCLUDED.server_id,
			port = EXCLUDED.port,
			protocol = EXCLUDED.protocol,
			synced = false
	`
	
	_, err := um.db.conn.Exec(query, username, ovpnPath, checksum, serverID, createdBy, port, protocol, time.Now())
	return err
}

// GetUser retrieves a user by username
func (um *UserManager) GetUser(username string) (*User, error) {
	query := `
		SELECT id, username, created_at, expires_at, active, ovpn_path, port, protocol, 
		       last_access, checksum, synced, server_id, created_by
		FROM users WHERE username = $1
	`
	
	var user User
	var expiresAt, lastAccess sql.NullTime
	var checksum, ovpnPath, protocol, serverID, createdBy sql.NullString
	var port sql.NullInt32
	
	err := um.db.conn.QueryRow(query, username).Scan(
		&user.ID, &user.Username, &user.CreatedAt, &expiresAt, &user.Active,
		&ovpnPath, &port, &protocol, &lastAccess, &checksum,
		&user.Synced, &serverID, &createdBy,
	)
	
	if err != nil {
		return nil, err
	}
	
	if expiresAt.Valid {
		user.ExpiresAt = expiresAt.Time
	}
	if lastAccess.Valid {
		user.LastAccess = lastAccess.Time
	}
	if checksum.Valid {
		user.Checksum = checksum.String
	}
	if ovpnPath.Valid {
		user.OvpnPath = ovpnPath.String
	}
	if protocol.Valid {
		user.Protocol = protocol.String
	} else {
		user.Protocol = "udp" // Default
	}
	if port.Valid {
		user.Port = int(port.Int32)
	} else {
		user.Port = 1194 // Default
	}
	if serverID.Valid {
		user.ServerID = serverID.String
	}
	if createdBy.Valid {
		user.CreatedBy = createdBy.String
	}
	
	return &user, nil
}

// ListUsers returns all users
func (um *UserManager) ListUsers() ([]User, error) {
	query := `
		SELECT id, username, created_at, expires_at, active, ovpn_path, port, protocol,
		       last_access, checksum, synced, server_id, created_by
		FROM users ORDER BY created_at DESC
	`
	
	rows, err := um.db.conn.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var users []User
	for rows.Next() {
		var user User
		var expiresAt, lastAccess sql.NullTime
		var checksum, ovpnPath, protocol, serverID, createdBy sql.NullString
		var port sql.NullInt32
		
		err := rows.Scan(
			&user.ID, &user.Username, &user.CreatedAt, &expiresAt, &user.Active,
			&ovpnPath, &port, &protocol, &lastAccess, &checksum,
			&user.Synced, &serverID, &createdBy,
		)
		if err != nil {
			return nil, err
		}
		
		if expiresAt.Valid {
			user.ExpiresAt = expiresAt.Time
		}
		if lastAccess.Valid {
			user.LastAccess = lastAccess.Time
		}
		if checksum.Valid {
			user.Checksum = checksum.String
		}
		if ovpnPath.Valid {
			user.OvpnPath = ovpnPath.String
		}
		if protocol.Valid {
			user.Protocol = protocol.String
		} else {
			user.Protocol = "udp" // Default
		}
		if port.Valid {
			user.Port = int(port.Int32)
		} else {
			user.Port = 1194 // Default
		}
		if serverID.Valid {
			user.ServerID = serverID.String
		}
		if createdBy.Valid {
			user.CreatedBy = createdBy.String
		}
		
		users = append(users, user)
	}
	
	return users, rows.Err()
}

// ListUsersByServer returns users for a specific server
func (um *UserManager) ListUsersByServer(targetServerID string) ([]User, error) {
	query := `
		SELECT id, username, created_at, expires_at, active, ovpn_path, port, protocol,
		       last_access, checksum, synced, server_id, created_by
		FROM users WHERE server_id = $1 ORDER BY created_at DESC
	`
	
	rows, err := um.db.conn.Query(query, targetServerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	var users []User
	for rows.Next() {
		var user User
		var expiresAt, lastAccess sql.NullTime
		var checksum, ovpnPath, protocol, serverID, createdBy sql.NullString
		var port sql.NullInt32
		
		err := rows.Scan(
			&user.ID, &user.Username, &user.CreatedAt, &expiresAt, &user.Active,
			&ovpnPath, &port, &protocol, &lastAccess, &checksum,
			&user.Synced, &serverID, &createdBy,
		)
		if err != nil {
			return nil, err
		}
		
		if expiresAt.Valid {
			user.ExpiresAt = expiresAt.Time
		}
		if lastAccess.Valid {
			user.LastAccess = lastAccess.Time
		}
		if checksum.Valid {
			user.Checksum = checksum.String
		}
		if ovpnPath.Valid {
			user.OvpnPath = ovpnPath.String
		}
		if protocol.Valid {
			user.Protocol = protocol.String
		} else {
			user.Protocol = "udp" // Default
		}
		if port.Valid {
			user.Port = int(port.Int32)
		} else {
			user.Port = 1194 // Default
		}
		if serverID.Valid {
			user.ServerID = serverID.String
		}
		if createdBy.Valid {
			user.CreatedBy = createdBy.String
		}
		
		users = append(users, user)
	}
	
	return users, rows.Err()
}

// UpdateUser updates user information
func (um *UserManager) UpdateUser(username, ovpnPath, checksum string, port int, protocol string) error {
	query := `
		UPDATE users SET ovpn_path = $1, checksum = $2, port = $3, protocol = $4, 
		                synced = false, last_access = $5
		WHERE username = $6
	`
	
	_, err := um.db.conn.Exec(query, ovpnPath, checksum, port, protocol, time.Now(), username)
	return err
}

// DeactivateUser deactivates a user
func (um *UserManager) DeactivateUser(username string) error {
	query := `UPDATE users SET active = false, synced = false WHERE username = $1`
	_, err := um.db.conn.Exec(query, username)
	return err
}

// DeleteUser deletes a user
func (um *UserManager) DeleteUser(username string) error {
	query := `DELETE FROM users WHERE username = $1`
	_, err := um.db.conn.Exec(query, username)
	return err
}

// UserExists checks if a user exists
func (um *UserManager) UserExists(username string) (bool, error) {
	query := `SELECT COUNT(*) FROM users WHERE username = $1`
	var count int
	err := um.db.conn.QueryRow(query, username).Scan(&count)
	return count > 0, err
}

// MarkUserSynced marks a user as synced
func (um *UserManager) MarkUserSynced(username string) error {
	query := `UPDATE users SET synced = true WHERE username = $1`
	_, err := um.db.conn.Exec(query, username)
	return err
}

// GetDB returns the database connection
func (um *UserManager) GetDB() *DB {
	return um.db
}
