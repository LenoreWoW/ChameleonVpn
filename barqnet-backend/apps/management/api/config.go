package api

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"barqnet-backend/pkg/shared"
)

// handleVPNConfig handles VPN configuration requests
// GET /vpn/config?username={username}
func (api *ManagementAPI) handleVPNConfig(w http.ResponseWriter, r *http.Request) {
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

	// Get username from query parameter
	username := r.URL.Query().Get("username")
	if username == "" {
		// If no username specified, use authenticated user
		username = authenticatedUser
	}

	// Users can only get their own config unless they're admin
	if username != authenticatedUser && !api.isAdmin(authenticatedUser) {
		http.Error(w, "Forbidden - you can only access your own configuration", http.StatusForbidden)
		return
	}

	// Get user information
	user, err := api.getUserByUsername(username)
	if err != nil {
		http.Error(w, fmt.Sprintf("User not found: %v", err), http.StatusNotFound)
		return
	}

	if !user.Active {
		http.Error(w, "User account is inactive", http.StatusForbidden)
		return
	}

	// Auto-select best server based on load
	bestServer, err := api.selectBestServer(user.ServerID)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to select server: %v", err), http.StatusInternalServerError)
		return
	}

	// Get OVPN file content
	ovpnContent, err := api.getOVPNContent(username, bestServer.Name)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to retrieve OVPN configuration: %v", err), http.StatusInternalServerError)
		return
	}

	// Get server recommendations
	recommendations, err := api.getServerRecommendations(username, bestServer.Name)
	if err != nil {
		// Log error but continue
		fmt.Printf("Failed to get server recommendations: %v\n", err)
		recommendations = []string{}
	}

	// Build configuration response
	config := shared.VPNConfigResponse{
		Username:           username,
		ServerID:           bestServer.Name,
		ServerHost:         bestServer.Host,
		ServerPort:         bestServer.Port,
		Protocol:           user.Protocol,
		OVPNContent:        ovpnContent,
		RecommendedServers: recommendations,
	}

	// Log the access
	api.logAudit(
		"VPN_CONFIG_ACCESSED",
		username,
		fmt.Sprintf("VPN configuration accessed - server: %s", bestServer.Name),
		r.RemoteAddr,
	)

	response := shared.APIResponse{
		Success:   true,
		Message:   "VPN configuration retrieved successfully",
		Data:      config,
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// getUserByUsername retrieves a user by username from the database
func (api *ManagementAPI) getUserByUsername(username string) (*shared.User, error) {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	query := `
		SELECT id, username, created_at, expires_at, active, ovpn_path, port, protocol,
		       last_access, checksum, synced, server_id, created_by
		FROM users
		WHERE username = $1
	`

	var user shared.User
	var expiresAt, lastAccess sql.NullTime
	var checksum sql.NullString

	err := conn.QueryRow(query, username).Scan(
		&user.ID,
		&user.Username,
		&user.CreatedAt,
		&expiresAt,
		&user.Active,
		&user.OvpnPath,
		&user.Port,
		&user.Protocol,
		&lastAccess,
		&checksum,
		&user.Synced,
		&user.ServerID,
		&user.CreatedBy,
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

	return &user, nil
}

// selectBestServer selects the best server based on current load
func (api *ManagementAPI) selectBestServer(preferredServerID string) (*shared.Server, error) {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	// First, try to get the preferred server if it's healthy
	if preferredServerID != "" {
		server, err := api.getServerByID(preferredServerID)
		if err == nil && server.Enabled {
			// Check if server load is acceptable (< 80%)
			userCount, _ := api.getServerUserCount(server.Name)
			loadPercent := float64(userCount) / float64(50) * 100 // Assume max 50 users per server

			if loadPercent < 80 {
				// Server is healthy and not overloaded
				return server, nil
			}
		}
	}

	// If preferred server is not available or overloaded, find the best alternative
	query := `
		SELECT s.id, s.name, s.host, s.port, s.username, s.password, s.enabled,
		       s.last_sync, s.server_type, s.management_url, s.created_at,
		       COUNT(u.id) as user_count
		FROM servers s
		LEFT JOIN users u ON s.name = u.server_id AND u.active = true
		WHERE s.enabled = true AND s.server_type = 'endnode'
		GROUP BY s.id, s.name, s.host, s.port, s.username, s.password, s.enabled,
		         s.last_sync, s.server_type, s.management_url, s.created_at
		ORDER BY user_count ASC, s.created_at DESC
		LIMIT 1
	`

	var server shared.Server
	var userCount int
	var lastSync sql.NullTime
	var username, password, managementURL sql.NullString

	err := conn.QueryRow(query).Scan(
		&server.ID,
		&server.Name,
		&server.Host,
		&server.Port,
		&username,
		&password,
		&server.Enabled,
		&lastSync,
		&server.ServerType,
		&managementURL,
		&server.CreatedAt,
		&userCount,
	)

	if err != nil {
		return nil, fmt.Errorf("no available servers found: %v", err)
	}

	if lastSync.Valid {
		server.LastSync = lastSync.Time
	}
	if username.Valid {
		server.Username = username.String
	}
	if password.Valid {
		server.Password = password.String
	}
	if managementURL.Valid {
		server.ManagementURL = managementURL.String
	}

	return &server, nil
}

// getServerByID retrieves a server by its ID/name
func (api *ManagementAPI) getServerByID(serverID string) (*shared.Server, error) {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	query := `
		SELECT id, name, host, port, username, password, enabled,
		       last_sync, server_type, management_url, created_at
		FROM servers
		WHERE name = $1
	`

	var server shared.Server
	var lastSync sql.NullTime
	var username, password, managementURL sql.NullString

	err := conn.QueryRow(query, serverID).Scan(
		&server.ID,
		&server.Name,
		&server.Host,
		&server.Port,
		&username,
		&password,
		&server.Enabled,
		&lastSync,
		&server.ServerType,
		&managementURL,
		&server.CreatedAt,
	)

	if err != nil {
		return nil, err
	}

	if lastSync.Valid {
		server.LastSync = lastSync.Time
	}
	if username.Valid {
		server.Username = username.String
	}
	if password.Valid {
		server.Password = password.String
	}
	if managementURL.Valid {
		server.ManagementURL = managementURL.String
	}

	return &server, nil
}

// getOVPNContent retrieves the OVPN file content for a user from the end-node
func (api *ManagementAPI) getOVPNContent(username, serverID string) (string, error) {
	// Get the server information
	server, err := api.getServerByID(serverID)
	if err != nil {
		return "", fmt.Errorf("server not found: %v", err)
	}

	// Download OVPN file from the end-node
	url := fmt.Sprintf("http://%s:%d/api/ovpn/%s", server.Host, server.Port, username)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %v", err)
	}

	client := &http.Client{
		Timeout: 30 * time.Second,
	}

	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to download OVPN file: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("OVPN download failed with status: %d", resp.StatusCode)
	}

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read OVPN content: %v", err)
	}

	return string(body), nil
}

// getServerRecommendations returns a list of recommended servers based on load and location
func (api *ManagementAPI) getServerRecommendations(username, currentServerID string) ([]string, error) {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	// Get servers with low load (excluding current server)
	query := `
		SELECT s.name, COUNT(u.id) as user_count
		FROM servers s
		LEFT JOIN users u ON s.name = u.server_id AND u.active = true
		WHERE s.enabled = true AND s.server_type = 'endnode' AND s.name != $1
		GROUP BY s.name
		HAVING COUNT(u.id) < 40
		ORDER BY user_count ASC
		LIMIT 3
	`

	rows, err := conn.Query(query, currentServerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var recommendations []string
	for rows.Next() {
		var serverName string
		var userCount int
		if err := rows.Scan(&serverName, &userCount); err != nil {
			continue
		}
		recommendations = append(recommendations, serverName)
	}

	return recommendations, rows.Err()
}
