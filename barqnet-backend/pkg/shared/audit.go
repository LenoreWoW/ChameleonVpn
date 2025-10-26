package shared

import (
	"time"
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
	query := `
		INSERT INTO audit_log (action, username, details, ip_address, server_id, timestamp)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	
	_, err := am.db.conn.Exec(query, action, username, details, ipAddress, serverID, time.Now())
	return err
}

// ListAuditLog returns audit log entries
func (am *AuditManager) ListAuditLog(limit int) ([]AuditLog, error) {
	query := `
		SELECT id, timestamp, action, username, details, ip_address, server_id
		FROM audit_log ORDER BY timestamp DESC LIMIT $1
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
		SELECT id, timestamp, action, username, details, ip_address, server_id
		FROM audit_log WHERE server_id = $1 ORDER BY timestamp DESC LIMIT $2
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
		SELECT id, timestamp, action, username, details, ip_address, server_id
		FROM audit_log WHERE username = $1 ORDER BY timestamp DESC LIMIT $2
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
