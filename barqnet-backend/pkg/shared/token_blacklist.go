package shared

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"fmt"
	"log"
	"time"
)

// TokenBlacklist handles token revocation and blacklist checking
type TokenBlacklist struct {
	db *sql.DB
}

// NewTokenBlacklist creates a new token blacklist handler
func NewTokenBlacklist(db *sql.DB) *TokenBlacklist {
	return &TokenBlacklist{db: db}
}

// RevokeToken adds a token to the blacklist
// tokenString: The JWT refresh token to revoke (will be hashed before storage)
// userID: The user ID who owns the token
// phoneNumber: The user's phone number (for audit purposes)
// reason: Reason for revocation (e.g., "logout", "password_change", "security_incident")
// revokedBy: Who initiated the revocation ("user", "admin", "security", "system")
// ipAddress: IP address of the revocation request (optional)
// userAgent: User agent string of the revocation request (optional)
func (tb *TokenBlacklist) RevokeToken(
	tokenString string,
	userID int,
	phoneNumber string,
	expiresAt time.Time,
	reason string,
	revokedBy string,
	ipAddress string,
	userAgent string,
) error {
	if tokenString == "" {
		return fmt.Errorf("token cannot be empty")
	}

	// Hash the token using SHA-256 (never store plaintext tokens)
	tokenHash := HashToken(tokenString)

	// Check if token is already blacklisted (idempotent operation)
	var existingID int
	err := tb.db.QueryRow("SELECT id FROM token_blacklist WHERE token_hash = $1", tokenHash).Scan(&existingID)
	if err == nil {
		// Token already blacklisted, return success (idempotent)
		log.Printf("[TOKEN_BLACKLIST] Token already revoked (id=%d), skipping", existingID)
		return nil
	} else if err != sql.ErrNoRows {
		return fmt.Errorf("failed to check existing blacklist entry: %v", err)
	}

	// Validate revoked_by field
	validRevokedBy := map[string]bool{"user": true, "admin": true, "security": true, "system": true}
	if !validRevokedBy[revokedBy] {
		revokedBy = "user" // Default to user
	}

	// Convert empty strings to NULL for database
	var ipAddrSQL, userAgentSQL interface{}
	if ipAddress != "" {
		ipAddrSQL = ipAddress
	}
	if userAgent != "" {
		userAgentSQL = userAgent
	}

	// Insert token into blacklist
	query := `
		INSERT INTO token_blacklist (
			token_hash,
			user_id,
			phone_number,
			revoked_at,
			expires_at,
			revoked_by,
			reason,
			ip_address,
			user_agent
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id
	`

	var blacklistID int
	err = tb.db.QueryRow(
		query,
		tokenHash,
		userID,
		phoneNumber,
		time.Now(),
		expiresAt,
		revokedBy,
		reason,
		ipAddrSQL,
		userAgentSQL,
	).Scan(&blacklistID)

	if err != nil {
		return fmt.Errorf("failed to insert token into blacklist: %v", err)
	}

	log.Printf("[TOKEN_BLACKLIST] Token revoked (id=%d, user_id=%d, reason=%s, revoked_by=%s)",
		blacklistID, userID, reason, revokedBy)

	return nil
}

// IsTokenBlacklisted checks if a token is in the blacklist
// Returns true if the token is blacklisted, false otherwise
func (tb *TokenBlacklist) IsTokenBlacklisted(tokenString string) (bool, error) {
	if tokenString == "" {
		return false, fmt.Errorf("token cannot be empty")
	}

	// Hash the token
	tokenHash := HashToken(tokenString)

	// Check if token exists in blacklist and is not expired
	var blacklistID int
	query := `
		SELECT id
		FROM token_blacklist
		WHERE token_hash = $1
		  AND expires_at > $2
		LIMIT 1
	`

	err := tb.db.QueryRow(query, tokenHash, time.Now()).Scan(&blacklistID)
	if err == sql.ErrNoRows {
		// Token not found in blacklist
		return false, nil
	} else if err != nil {
		// Database error
		return false, fmt.Errorf("failed to check blacklist: %v", err)
	}

	// Token is blacklisted
	return true, nil
}

// RevokeAllUserTokens revokes all tokens for a specific user
// This is used for security incidents or when a user changes their password
// Note: This marks the user's session as revoked. Individual tokens are blacklisted as they're used.
func (tb *TokenBlacklist) RevokeAllUserTokens(
	userID int,
	phoneNumber string,
	reason string,
	revokedBy string,
	ipAddress string,
) (int, error) {
	// This is a placeholder - in practice, we can't revoke all tokens unless we track them
	// The best approach is to add a "revoked_after" timestamp to the user record
	// and check it during token validation

	// For now, we'll just log the event
	log.Printf("[TOKEN_BLACKLIST] Request to revoke all tokens for user_id=%d, reason=%s", userID, reason)

	// TODO: Implement user-level revocation timestamp
	// This would require adding a "tokens_revoked_after" column to users table
	// and checking it during JWT validation

	return 0, fmt.Errorf("bulk revocation not yet implemented - revoke tokens individually")
}

// CleanupExpiredEntries removes expired tokens from the blacklist
// This should be called periodically (e.g., via cron job) to keep the table size manageable
// Returns the number of entries deleted
func (tb *TokenBlacklist) CleanupExpiredEntries() (int64, error) {
	// Call the database function that handles cleanup
	var deletedCount int64
	var oldestDeleted, newestDeleted sql.NullTime

	err := tb.db.QueryRow(`
		SELECT * FROM cleanup_expired_blacklist_entries()
	`).Scan(&deletedCount, &oldestDeleted, &newestDeleted)

	if err != nil {
		return 0, fmt.Errorf("failed to cleanup expired entries: %v", err)
	}

	if deletedCount > 0 {
		log.Printf("[TOKEN_BLACKLIST] Cleanup completed: deleted %d expired entries", deletedCount)
		if oldestDeleted.Valid && newestDeleted.Valid {
			log.Printf("[TOKEN_BLACKLIST] Deleted range: %s to %s",
				oldestDeleted.Time.Format(time.RFC3339),
				newestDeleted.Time.Format(time.RFC3339))
		}
	} else {
		log.Printf("[TOKEN_BLACKLIST] Cleanup completed: no expired entries found")
	}

	return deletedCount, nil
}

// GetBlacklistStats returns statistics about the token blacklist
func (tb *TokenBlacklist) GetBlacklistStats() (map[string]interface{}, error) {
	var stats struct {
		TotalEntries       int
		ActiveEntries      int
		ExpiredEntries     int
		AffectedUsers      int
		UserRevocations    int
		AdminRevocations   int
		SecurityRevocations int
		SystemRevocations  int
		OldestRevocation   sql.NullTime
		LatestRevocation   sql.NullTime
		AvgHoursUntilExpiry sql.NullFloat64
	}

	query := `SELECT * FROM v_blacklist_statistics`

	err := tb.db.QueryRow(query).Scan(
		&stats.TotalEntries,
		&stats.ActiveEntries,
		&stats.ExpiredEntries,
		&stats.AffectedUsers,
		&stats.UserRevocations,
		&stats.AdminRevocations,
		&stats.SecurityRevocations,
		&stats.SystemRevocations,
		&stats.OldestRevocation,
		&stats.LatestRevocation,
		&stats.AvgHoursUntilExpiry,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to get blacklist stats: %v", err)
	}

	result := map[string]interface{}{
		"total_entries":        stats.TotalEntries,
		"active_entries":       stats.ActiveEntries,
		"expired_entries":      stats.ExpiredEntries,
		"affected_users":       stats.AffectedUsers,
		"user_revocations":     stats.UserRevocations,
		"admin_revocations":    stats.AdminRevocations,
		"security_revocations": stats.SecurityRevocations,
		"system_revocations":   stats.SystemRevocations,
	}

	if stats.OldestRevocation.Valid {
		result["oldest_revocation"] = stats.OldestRevocation.Time
	}
	if stats.LatestRevocation.Valid {
		result["latest_revocation"] = stats.LatestRevocation.Time
	}
	if stats.AvgHoursUntilExpiry.Valid {
		result["avg_hours_until_expiry"] = stats.AvgHoursUntilExpiry.Float64
	}

	return result, nil
}

// GetUserBlacklistedTokens returns all blacklisted tokens for a user
func (tb *TokenBlacklist) GetUserBlacklistedTokens(userID int) ([]map[string]interface{}, error) {
	query := `
		SELECT
			id,
			revoked_at,
			expires_at,
			revoked_by,
			reason,
			ip_address
		FROM token_blacklist
		WHERE user_id = $1
		  AND expires_at > $2
		ORDER BY revoked_at DESC
		LIMIT 100
	`

	rows, err := tb.db.Query(query, userID, time.Now())
	if err != nil {
		return nil, fmt.Errorf("failed to get user blacklisted tokens: %v", err)
	}
	defer rows.Close()

	var tokens []map[string]interface{}
	for rows.Next() {
		var (
			id           int
			revokedAt    time.Time
			expiresAt    time.Time
			revokedBy    string
			reason       sql.NullString
			ipAddress    sql.NullString
		)

		if err := rows.Scan(&id, &revokedAt, &expiresAt, &revokedBy, &reason, &ipAddress); err != nil {
			return nil, fmt.Errorf("failed to scan row: %v", err)
		}

		token := map[string]interface{}{
			"id":         id,
			"revoked_at": revokedAt,
			"expires_at": expiresAt,
			"revoked_by": revokedBy,
		}

		if reason.Valid {
			token["reason"] = reason.String
		}
		if ipAddress.Valid {
			token["ip_address"] = ipAddress.String
		}

		tokens = append(tokens, token)
	}

	return tokens, rows.Err()
}

// HashToken creates a SHA-256 hash of the token
// This is used to securely store token references without keeping the plaintext
func HashToken(tokenString string) string {
	hash := sha256.Sum256([]byte(tokenString))
	return hex.EncodeToString(hash[:])
}
