package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"barqnet-backend/pkg/shared"
)

// handleVPNStatus handles VPN connection status updates
// POST /vpn/status
func (api *ManagementAPI) handleVPNStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Validate JWT token (placeholder - implement actual JWT validation)
	username, err := api.validateJWTToken(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req struct {
		Status    string `json:"status"` // connected, disconnected, connecting, error
		ServerID  string `json:"server_id"`
		IPAddress string `json:"ip_address,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Validate status
	validStatuses := map[string]bool{
		"connected":    true,
		"disconnected": true,
		"connecting":   true,
		"error":        true,
	}
	if !validStatuses[req.Status] {
		http.Error(w, "Invalid status. Must be one of: connected, disconnected, connecting, error", http.StatusBadRequest)
		return
	}

	// Update connection status in database
	if err := api.updateConnectionStatus(username, req.Status, req.ServerID, req.IPAddress); err != nil {
		http.Error(w, fmt.Sprintf("Failed to update connection status: %v", err), http.StatusInternalServerError)
		return
	}

	// Log the status update
	api.logAudit(
		"VPN_STATUS_UPDATE",
		username,
		fmt.Sprintf("VPN status updated to %s on server %s", req.Status, req.ServerID),
		req.IPAddress,
	)

	response := shared.APIResponse{
		Success:   true,
		Message:   fmt.Sprintf("Connection status updated to %s", req.Status),
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleVPNStats handles VPN usage statistics upload
// POST /vpn/stats
func (api *ManagementAPI) handleVPNStats(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Validate JWT token
	username, err := api.validateJWTToken(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req struct {
		ServerID string `json:"server_id"`
		BytesIn  int64  `json:"bytes_in"`
		BytesOut int64  `json:"bytes_out"`
		Duration int    `json:"duration_seconds"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Validate input
	if req.BytesIn < 0 || req.BytesOut < 0 || req.Duration < 0 {
		http.Error(w, "Invalid statistics values", http.StatusBadRequest)
		return
	}

	// Store statistics in database
	if err := api.storeVPNStatistics(username, req.ServerID, req.BytesIn, req.BytesOut, req.Duration); err != nil {
		http.Error(w, fmt.Sprintf("Failed to store statistics: %v", err), http.StatusInternalServerError)
		return
	}

	// Log the statistics update
	api.logAudit(
		"VPN_STATS_UPLOADED",
		username,
		fmt.Sprintf("Statistics uploaded - bytes_in=%d, bytes_out=%d, duration=%ds", req.BytesIn, req.BytesOut, req.Duration),
		r.RemoteAddr,
	)

	response := shared.APIResponse{
		Success:   true,
		Message:   "Statistics uploaded successfully",
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleGetUserStats handles retrieving user statistics
// GET /vpn/stats/{username}
func (api *ManagementAPI) handleGetUserStats(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Validate JWT token
	authenticatedUser, err := api.validateJWTToken(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Extract username from URL path
	username := strings.TrimPrefix(r.URL.Path, "/vpn/stats/")
	if username == "" {
		http.Error(w, "Username required", http.StatusBadRequest)
		return
	}

	// Users can only access their own stats unless they're admin
	if username != authenticatedUser && !api.isAdmin(authenticatedUser) {
		http.Error(w, "Forbidden - you can only access your own statistics", http.StatusForbidden)
		return
	}

	// Get user statistics from database
	stats, err := api.getUserStatistics(username)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to retrieve statistics: %v", err), http.StatusInternalServerError)
		return
	}

	// Get connection history
	connections, err := api.getConnectionHistory(username)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to retrieve connection history: %v", err), http.StatusInternalServerError)
		return
	}

	// Log the access
	api.logAudit(
		"VPN_STATS_ACCESSED",
		authenticatedUser,
		fmt.Sprintf("Statistics accessed for user %s", username),
		r.RemoteAddr,
	)

	responseData := map[string]interface{}{
		"summary":     stats,
		"connections": connections,
	}

	response := shared.APIResponse{
		Success:   true,
		Message:   "Statistics retrieved successfully",
		Data:      responseData,
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// updateConnectionStatus updates the VPN connection status in the database
// Uses UPSERT pattern to prevent infinite row growth
func (api *ManagementAPI) updateConnectionStatus(username, status, serverID, ipAddress string) error {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	// UPSERT: Insert new or update existing connection state
	// Prevents database from growing infinitely with duplicate rows
	query := `
		INSERT INTO vpn_connections (username, status, server_id, ip_address, connected_at, disconnected_at, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $7)
		ON CONFLICT (username, server_id)
		DO UPDATE SET
			status = EXCLUDED.status,
			ip_address = EXCLUDED.ip_address,
			connected_at = EXCLUDED.connected_at,
			disconnected_at = EXCLUDED.disconnected_at,
			updated_at = EXCLUDED.updated_at
	`

	var connectedAt, disconnectedAt interface{}
	now := time.Now()

	if status == "connected" {
		connectedAt = now
		disconnectedAt = nil
	} else if status == "disconnected" {
		connectedAt = nil
		disconnectedAt = now
	}

	_, err := conn.Exec(query, username, status, serverID, ipAddress, connectedAt, disconnectedAt, now)
	return err
}

// storeVPNStatistics stores VPN usage statistics in the database
func (api *ManagementAPI) storeVPNStatistics(username, serverID string, bytesIn, bytesOut int64, duration int) error {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	query := `
		INSERT INTO vpn_statistics (username, server_id, bytes_in, bytes_out, duration_seconds, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`

	_, err := conn.Exec(query, username, serverID, bytesIn, bytesOut, duration, time.Now())
	return err
}

// getUserStatistics retrieves aggregated statistics for a user
func (api *ManagementAPI) getUserStatistics(username string) (*shared.UserStatisticsSummary, error) {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	query := `
		SELECT
			COALESCE(SUM(bytes_in), 0) as total_bytes_in,
			COALESCE(SUM(bytes_out), 0) as total_bytes_out,
			COALESCE(SUM(duration_seconds), 0) as total_duration,
			COUNT(*) as connection_count
		FROM vpn_statistics
		WHERE username = $1
	`

	var stats shared.UserStatisticsSummary
	stats.Username = username

	err := conn.QueryRow(query, username).Scan(
		&stats.TotalBytesIn,
		&stats.TotalBytesOut,
		&stats.TotalDuration,
		&stats.ConnectionCount,
	)

	if err != nil {
		return nil, err
	}

	// Get last connection time
	lastConnQuery := `
		SELECT created_at
		FROM vpn_connections
		WHERE username = $1 AND status = 'connected'
		ORDER BY created_at DESC
		LIMIT 1
	`

	var lastConn time.Time
	if err := conn.QueryRow(lastConnQuery, username).Scan(&lastConn); err == nil {
		stats.LastConnection = lastConn
	}

	return &stats, nil
}

// getConnectionHistory retrieves recent connection history for a user
func (api *ManagementAPI) getConnectionHistory(username string) ([]shared.VPNConnectionStatus, error) {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	query := `
		SELECT id, username, status, server_id, connected_at, disconnected_at, ip_address, created_at
		FROM vpn_connections
		WHERE username = $1
		ORDER BY created_at DESC
		LIMIT 50
	`

	rows, err := conn.Query(query, username)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var connections []shared.VPNConnectionStatus
	for rows.Next() {
		var conn shared.VPNConnectionStatus
		var connectedAt, disconnectedAt, ipAddress interface{}

		err := rows.Scan(
			&conn.ID,
			&conn.Username,
			&conn.Status,
			&conn.ServerID,
			&connectedAt,
			&disconnectedAt,
			&ipAddress,
			&conn.CreatedAt,
		)

		if err != nil {
			return nil, err
		}

		// Handle nullable fields
		if connectedAt != nil {
			conn.ConnectedAt = connectedAt.(time.Time)
		}
		if disconnectedAt != nil {
			conn.DisconnectedAt = disconnectedAt.(time.Time)
		}
		if ipAddress != nil {
			conn.IPAddress = ipAddress.(string)
		}

		connections = append(connections, conn)
	}

	return connections, rows.Err()
}

// validateJWTToken validates the JWT token and returns the username
// Uses actual JWT validation with signature verification
func (api *ManagementAPI) validateJWTToken(r *http.Request) (string, error) {
	// Get token from Authorization header
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return "", fmt.Errorf("missing authorization header")
	}

	// Extract token from "Bearer <token>" format
	parts := strings.Split(authHeader, " ")
	if len(parts) != 2 || parts[0] != "Bearer" {
		return "", fmt.Errorf("invalid authorization header format")
	}

	token := parts[1]

	// Validate JWT token using shared validation function
	claims, err := shared.ValidateJWT(token)
	if err != nil {
		return "", fmt.Errorf("invalid or expired token: %v", err)
	}

	// Return email from validated claims
	return claims.Email, nil
}

// isAdmin checks if a user has admin privileges by querying the database
func (api *ManagementAPI) isAdmin(email string) bool {
	db := api.manager.GetDB()
	conn := db.GetConnection()
	
	// Check role from users table
	query := `SELECT COALESCE(role, 'user') FROM users WHERE email = $1`
	
	var role string
	err := conn.QueryRow(query, email).Scan(&role)
	if err != nil {
		// If user not found or error, check environment for superadmins
		superAdmins := strings.Split(os.Getenv("SUPER_ADMINS"), ",")
		for _, admin := range superAdmins {
			if strings.TrimSpace(admin) == email {
				return true
			}
		}
		return false
	}
	
	// Admin or superadmin roles have admin access
	return role == "admin" || role == "superadmin"
}

// isAdminOrModerator checks if a user has admin or moderator privileges
func (api *ManagementAPI) isAdminOrModerator(email string) bool {
	db := api.manager.GetDB()
	conn := db.GetConnection()
	
	query := `SELECT COALESCE(role, 'user') FROM users WHERE email = $1`
	
	var role string
	err := conn.QueryRow(query, email).Scan(&role)
	if err != nil {
		return false
	}
	
	return role == "admin" || role == "superadmin" || role == "moderator"
}
