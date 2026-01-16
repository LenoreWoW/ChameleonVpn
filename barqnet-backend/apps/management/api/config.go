package api

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
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

	// Get username from query parameter (can be email or username)
	identifier := r.URL.Query().Get("username")
	if identifier == "" {
		// If no username specified, use authenticated user (email from JWT)
		identifier = authenticatedUser
	}

	// Users can only get their own config unless they're admin
	if identifier != authenticatedUser && !api.isAdmin(authenticatedUser) {
		http.Error(w, "Forbidden - you can only access your own configuration", http.StatusForbidden)
		return
	}

	// Get user information (try by email first, then by username)
	user, err := api.getUserByEmail(identifier)
	if err != nil {
		// Fallback to username lookup
		user, err = api.getUserByUsername(identifier)
		if err != nil {
			http.Error(w, fmt.Sprintf("User not found: %v", err), http.StatusNotFound)
			return
		}
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
	ovpnContent, err := api.getOVPNContent(user.Username, bestServer.Name)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to retrieve OVPN configuration: %v", err), http.StatusInternalServerError)
		return
	}

	// Get server recommendations
	recommendations, err := api.getServerRecommendations(user.Username, bestServer.Name)
	if err != nil {
		// Log error but continue
		fmt.Printf("Failed to get server recommendations: %v\n", err)
		recommendations = []string{}
	}

	// Build configuration response
	config := shared.VPNConfigResponse{
		Username:           user.Username,
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
		user.Username,
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

// getUserByEmail retrieves a user by email from the database
func (api *ManagementAPI) getUserByEmail(email string) (*shared.User, error) {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	query := `
		SELECT id, username, created_at, expires_at, active, ovpn_path, port, protocol,
		       last_access, checksum, synced, server_id, created_by
		FROM users
		WHERE email = $1
	`

	var user shared.User
	var expiresAt, lastAccess sql.NullTime
	var checksum, ovpnPath, protocol sql.NullString
	var port sql.NullInt32

	err := conn.QueryRow(query, email).Scan(
		&user.ID,
		&user.Username,
		&user.CreatedAt,
		&expiresAt,
		&user.Active,
		&ovpnPath,
		&port,
		&protocol,
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
	if ovpnPath.Valid {
		user.OvpnPath = ovpnPath.String
	}
	if port.Valid {
		user.Port = int(port.Int32)
	} else {
		user.Port = 1194 // Default
	}
	if protocol.Valid {
		user.Protocol = protocol.String
	} else {
		user.Protocol = "udp" // Default
	}

	return &user, nil
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
	var checksum, ovpnPath, protocol sql.NullString
	var port sql.NullInt32

	err := conn.QueryRow(query, username).Scan(
		&user.ID,
		&user.Username,
		&user.CreatedAt,
		&expiresAt,
		&user.Active,
		&ovpnPath,
		&port,
		&protocol,
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
	if ovpnPath.Valid {
		user.OvpnPath = ovpnPath.String
	}
	if port.Valid {
		user.Port = int(port.Int32)
	} else {
		user.Port = 1194 // Default
	}
	if protocol.Valid {
		user.Protocol = protocol.String
	} else {
		user.Protocol = "udp" // Default
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
		SELECT s.id, s.name, s.host, s.port, s.enabled,
		       s.last_sync, s.server_type, s.created_at,
		       COUNT(u.id) as user_count
		FROM servers s
		LEFT JOIN users u ON s.name = u.server_id AND u.active = true
		WHERE s.enabled = true
		GROUP BY s.id, s.name, s.host, s.port, s.enabled,
		         s.last_sync, s.server_type, s.created_at
		ORDER BY user_count ASC, s.created_at DESC
		LIMIT 1
	`

	var server shared.Server
	var userCount int
	var lastSync sql.NullTime
	var serverType sql.NullString

	err := conn.QueryRow(query).Scan(
		&server.ID,
		&server.Name,
		&server.Host,
		&server.Port,
		&server.Enabled,
		&lastSync,
		&serverType,
		&server.CreatedAt,
		&userCount,
	)

	if err != nil {
		return nil, fmt.Errorf("no available servers found: %v", err)
	}

	if lastSync.Valid {
		server.LastSync = lastSync.Time
	}
	if serverType.Valid {
		server.ServerType = serverType.String
	}

	return &server, nil
}

// getServerByID retrieves a server by its ID/name
func (api *ManagementAPI) getServerByID(serverID string) (*shared.Server, error) {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	query := `
		SELECT id, name, host, port, enabled,
		       last_sync, server_type, created_at
		FROM servers
		WHERE name = $1
	`

	var server shared.Server
	var lastSync sql.NullTime
	var serverType sql.NullString

	err := conn.QueryRow(query, serverID).Scan(
		&server.ID,
		&server.Name,
		&server.Host,
		&server.Port,
		&server.Enabled,
		&lastSync,
		&serverType,
		&server.CreatedAt,
	)

	if err != nil {
		return nil, err
	}

	if lastSync.Valid {
		server.LastSync = lastSync.Time
	}
	if serverType.Valid {
		server.ServerType = serverType.String
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

	// Try to download OVPN file from the end-node
	url := fmt.Sprintf("http://%s:%d/api/ovpn/%s", server.Host, server.Port, username)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		// Fall back to template
		return api.generateOVPNTemplate(username, server), nil
	}

	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	resp, err := client.Do(req)
	if err != nil {
		// End-node not reachable, generate template config
		fmt.Printf("[VPN] End-node not reachable, generating template config for %s\n", username)
		return api.generateOVPNTemplate(username, server), nil
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		// OVPN file doesn't exist - create it automatically
		fmt.Printf("[VPN] OVPN file not found for %s, creating it now...\n", username)

		if createErr := api.createOVPNFileOnEndNode(username, server); createErr != nil {
			fmt.Printf("[VPN] Failed to create OVPN file: %v, falling back to template\n", createErr)
			return api.generateOVPNTemplate(username, server), nil
		}

		// Retry fetching the OVPN file after creation
		resp2, err := client.Do(req)
		if err != nil || resp2.StatusCode != http.StatusOK {
			fmt.Printf("[VPN] Failed to fetch OVPN after creation, falling back to template\n")
			if resp2 != nil {
				resp2.Body.Close()
			}
			return api.generateOVPNTemplate(username, server), nil
		}
		defer resp2.Body.Close()

		body, err := io.ReadAll(resp2.Body)
		if err != nil {
			return api.generateOVPNTemplate(username, server), nil
		}

		fmt.Printf("[VPN] Successfully created and fetched OVPN file for %s\n", username)
		return string(body), nil
	}

	if resp.StatusCode != http.StatusOK {
		// Other error - fall back to template
		return api.generateOVPNTemplate(username, server), nil
	}

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return api.generateOVPNTemplate(username, server), nil
	}

	return string(body), nil
}

// createOVPNFileOnEndNode creates an OVPN file for a user on the specified end-node
func (api *ManagementAPI) createOVPNFileOnEndNode(username string, server *shared.Server) error {
	// Prepare the request payload for OVPN creation with all required fields
	// End-node will generate certificates automatically if cert_data is empty
	payload := map[string]interface{}{
		"username":  username,
		"port":      1194,        // Default OpenVPN port
		"protocol":  "udp",       // Default protocol
		"server_id": server.Name,
		"server_ip": server.Host, // Use server host as IP
		"cert_data": map[string]string{
			"ca":   "", // Empty - end-node will generate
			"cert": "",
			"key":  "",
			"ta":   "",
		},
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal payload: %v", err)
	}

	// Call the endnode's /api/ovpn/create endpoint
	url := fmt.Sprintf("http://%s:%d/api/ovpn/create", server.Host, server.Port)

	req, err := http.NewRequest("POST", url, strings.NewReader(string(payloadBytes)))
	if err != nil {
		return fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{
		Timeout: 30 * time.Second, // Longer timeout for file creation
	}

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to call endnode: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("endnode returned error %d: %s", resp.StatusCode, string(body))
	}

	return nil
}

// generateOVPNTemplate creates a basic OVPN configuration template
func (api *ManagementAPI) generateOVPNTemplate(username string, server *shared.Server) string {
	return fmt.Sprintf(`# BarqNet VPN Configuration
# Generated for user: %s
# Server: %s (%s:%d)

client
dev tun
proto udp
remote %s %d
resolv-retry infinite
nobind
persist-key
persist-tun

# Security settings
cipher AES-256-GCM
auth SHA256
key-direction 1
tls-version-min 1.2

# Note: This is a template configuration
# Full certificates will be provided by the VPN server

<ca>
# CA certificate will be inserted here
</ca>

<cert>
# Client certificate for %s will be inserted here
</cert>

<key>
# Client private key will be inserted here
</key>
`, username, server.Name, server.Host, server.Port, server.Host, server.Port, username)
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
