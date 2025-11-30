package shared

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"
)

// AuditLogger handles multi-destination audit logging (file + database)
type AuditLogger struct {
	auditDir    string
	fileEnabled bool
	dbEnabled   bool
	auditMgr    *AuditManager
}

// NewAuditLogger creates a new audit logger with file and database backends
func NewAuditLogger(auditDir string, fileEnabled, dbEnabled bool, auditMgr *AuditManager) *AuditLogger {
	logger := &AuditLogger{
		auditDir:    auditDir,
		fileEnabled: fileEnabled,
		dbEnabled:   dbEnabled,
		auditMgr:    auditMgr,
	}

	// Ensure audit directory exists if file logging enabled
	if fileEnabled && auditDir != "" {
		if err := os.MkdirAll(auditDir, 0750); err != nil {
			log.Printf("[AUDIT] WARNING: Could not create audit log directory %s: %v", auditDir, err)
			log.Printf("[AUDIT] File-based logging will be DISABLED, using database only")
			logger.fileEnabled = false
		} else {
			log.Printf("[AUDIT] ✅ File logging enabled: %s", auditDir)
		}
	}

	if dbEnabled && auditMgr != nil {
		log.Printf("[AUDIT] ✅ Database logging enabled")
	}

	return logger
}

// LogAudit logs to both file and database with graceful degradation
func (al *AuditLogger) LogAudit(filename, action, username, details, ipAddress, serverID string) error {
	var fileErr, dbErr error

	// Log to database first (primary)
	if al.dbEnabled && al.auditMgr != nil {
		dbErr = al.auditMgr.LogAction(action, username, details, ipAddress, serverID)
		if dbErr != nil {
			log.Printf("[AUDIT] Database logging failed: %v", dbErr)
		}
	}

	// Log to file (secondary/redundant)
	if al.fileEnabled && al.auditDir != "" {
		fileErr = al.logToFile(filename, action, username, details, ipAddress, serverID)
		if fileErr != nil {
			log.Printf("[AUDIT] File logging failed: %v", fileErr)
		}
	}

	// Return error only if BOTH failed
	if fileErr != nil && dbErr != nil {
		return fmt.Errorf("audit logging completely failed - file: %v, db: %v", fileErr, dbErr)
	}

	// At least one succeeded
	return nil
}

// logToFile writes audit entry to file
func (al *AuditLogger) logToFile(filename, action, username, details, ipAddress, serverID string) error {
	logFile := filepath.Join(al.auditDir, filename)

	timestamp := time.Now().Format("2006-01-02 15:04:05")
	auditEntry := fmt.Sprintf("[%s] action=%s username=%s details=%s ip=%s server=%s\n",
		timestamp, action, username, details, ipAddress, serverID)

	file, err := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0640)
	if err != nil {
		return fmt.Errorf("failed to open audit log file %s: %v", logFile, err)
	}
	defer file.Close()

	if _, err := file.WriteString(auditEntry); err != nil {
		return fmt.Errorf("failed to write to audit log file: %v", err)
	}

	return nil
}
