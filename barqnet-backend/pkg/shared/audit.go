package shared

import (
	"database/sql"
	"log"
)

// AuditManager handles audit log operations
type AuditManager struct {
	db *DB
}

// NewAuditManager creates a new audit manager
func NewAuditManager(db *DB) *AuditManager {
	return &AuditManager{db: db}
}

// LogAction logs an action to the audit log
func (am *AuditManager) LogAction(action, username, details, ipAddress, serverID string) error {
	// Resolve username to user_id for referential integrity
	var userID *int
	if username != "" {
		row := am.db.conn.QueryRow("SELECT id FROM users WHERE username = $1", username)
		var id int
		if err := row.Scan(&id); err == nil {
			userID = &id
		} else if err != sql.ErrNoRows {
			log.Printf("[AUDIT] Warning: Could not resolve user_id for username '%s': %v", username, err)
		}
	}

	query := `
		INSERT INTO audit_log
		(user_id, action, username, details, ip_address, server_id, resource_type, status, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
	`

	_, err := am.db.conn.Exec(
		query,
		userID,      // FK to users table
		action,
		username,    // Denormalized for performance
		details,
		ipAddress,
		serverID,
		"general",   // Default resource_type
		"success",   // Default status
	)
	return err
}

// ListAuditLog returns audit log entries
func (am *AuditManager) ListAuditLog(limit int) ([]AuditLog, error) {
	query := `
		SELECT
			id,
			created_at as timestamp,
			action,
			COALESCE(username, (SELECT username FROM users WHERE id = audit_log.user_id)) as username,
			details,
			ip_address,
			COALESCE(server_id, '') as server_id
		FROM audit_log
		ORDER BY created_at DESC
		LIMIT $1
	`

	rows, err := am.db.conn.Query(query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []AuditLog
	for rows.Next() {
		var log AuditLog
		err := rows.Scan(
			&log.ID, &log.Timestamp, &log.Action, &log.Username,
			&log.Details, &log.IPAddress, &log.ServerID,
		)
		if err != nil {
			return nil, err
		}

		logs = append(logs, log)
	}

	return logs, rows.Err()
}

// ListAuditLogByServer returns audit log entries for a specific server
func (am *AuditManager) ListAuditLogByServer(serverID string, limit int) ([]AuditLog, error) {
	query := `
		SELECT
			id,
			created_at as timestamp,
			action,
			COALESCE(username, (SELECT username FROM users WHERE id = audit_log.user_id)) as username,
			details,
			ip_address,
			server_id
		FROM audit_log
		WHERE server_id = $1
		ORDER BY created_at DESC
		LIMIT $2
	`

	rows, err := am.db.conn.Query(query, serverID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []AuditLog
	for rows.Next() {
		var log AuditLog
		err := rows.Scan(
			&log.ID, &log.Timestamp, &log.Action, &log.Username,
			&log.Details, &log.IPAddress, &log.ServerID,
		)
		if err != nil {
			return nil, err
		}

		logs = append(logs, log)
	}

	return logs, rows.Err()
}

// ListAuditLogByUser returns audit log entries for a specific user
func (am *AuditManager) ListAuditLogByUser(username string, limit int) ([]AuditLog, error) {
	query := `
		SELECT
			id,
			created_at as timestamp,
			action,
			username,
			details,
			ip_address,
			server_id
		FROM audit_log
		WHERE username = $1 OR user_id = (SELECT id FROM users WHERE username = $1)
		ORDER BY created_at DESC
		LIMIT $2
	`

	rows, err := am.db.conn.Query(query, username, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []AuditLog
	for rows.Next() {
		var log AuditLog
		err := rows.Scan(
			&log.ID, &log.Timestamp, &log.Action, &log.Username,
			&log.Details, &log.IPAddress, &log.ServerID,
		)
		if err != nil {
			return nil, err
		}

		logs = append(logs, log)
	}

	return logs, rows.Err()
}
