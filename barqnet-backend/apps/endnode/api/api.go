package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"vpnmanager/apps/endnode/manager"
	"vpnmanager/pkg/shared"
)

// EndNodeAPI handles API requests for the end-node
type EndNodeAPI struct {
	manager *manager.EndNodeManager
}

// NewEndNodeAPI creates a new end-node API
func NewEndNodeAPI(manager *manager.EndNodeManager) *EndNodeAPI {
	return &EndNodeAPI{manager: manager}
}

// Start starts the API server
func (api *EndNodeAPI) Start(port int) error {
	mux := http.NewServeMux()

	// Health check endpoint
	mux.HandleFunc("/health", api.handleHealth)

	// User management endpoints (removed - users managed by management server)
	// mux.HandleFunc("/api/users", api.handleUsers)
	// mux.HandleFunc("/api/users/", api.handleUserByID)

	// Management server communication endpoints
	mux.HandleFunc("/api/sync/users", api.handleSyncUsers)

	// OVPN creation endpoint (called by management server)
	mux.HandleFunc("/api/ovpn/create", api.handleCreateOVPN)

	// OVPN delete endpoint (must be before /api/ovpn/ to avoid route conflicts)
	mux.HandleFunc("/api/ovpn/delete/", api.handleDeleteOVPN)

	// OVPN download endpoints
	mux.HandleFunc("/api/ovpn/", api.handleDownloadOVPN)

	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", port),
		Handler:      api.middleware(mux),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
	}

	return server.ListenAndServe()
}

// handleHealth handles health check requests
func (api *EndNodeAPI) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	response := shared.HealthCheck{
		Status:    "healthy",
		Timestamp: time.Now().Unix(),
		Version:   "1.0.0",
		ServerID:  "endnode-server", // TODO: Get from manager
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleUsers handles user list requests
func (api *EndNodeAPI) handleUsers(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		api.handleListUsers(w, r)
	case "POST":
		api.handleCreateUser(w, r)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// handleListUsers handles listing users
func (api *EndNodeAPI) handleListUsers(w http.ResponseWriter, r *http.Request) {
	users, err := api.manager.ListUsers()
	if err != nil {
		http.Error(w, "Failed to list users", http.StatusInternalServerError)
		return
	}

	response := shared.APIResponse{
		Success:   true,
		Message:   "Users retrieved successfully",
		Data:      users,
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleCreateUser handles user creation
func (api *EndNodeAPI) handleCreateUser(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username string `json:"username"`
		OvpnPath string `json:"ovpn_path"`
		Checksum string `json:"checksum"`
		Port     int    `json:"port"`
		Protocol string `json:"protocol"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// End-nodes no longer create users directly - this endpoint is disabled
	http.Error(w, "User creation is now handled by management server", http.StatusMethodNotAllowed)
	return
}

// handleUserByID handles individual user operations
func (api *EndNodeAPI) handleUserByID(w http.ResponseWriter, r *http.Request) {
	// Extract username from URL path
	username := r.URL.Path[len("/api/users/"):]
	if username == "" {
		http.Error(w, "Username required", http.StatusBadRequest)
		return
	}

	switch r.Method {
	case "GET":
		api.handleGetUser(w, r, username)
	case "DELETE":
		api.handleDeleteUser(w, r, username)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// handleGetUser handles getting a specific user
func (api *EndNodeAPI) handleGetUser(w http.ResponseWriter, r *http.Request, username string) {
	users, err := api.manager.ListUsers()
	if err != nil {
		http.Error(w, "Failed to list users", http.StatusInternalServerError)
		return
	}

	var user *shared.User
	for _, u := range users {
		if u.Username == username {
			user = &u
			break
		}
	}

	if user == nil {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	response := shared.APIResponse{
		Success:   true,
		Message:   "User retrieved successfully",
		Data:      user,
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleDeleteUser handles user deletion
func (api *EndNodeAPI) handleDeleteUser(w http.ResponseWriter, r *http.Request, username string) {
	if err := api.manager.DeleteUser(username); err != nil {
		http.Error(w, fmt.Sprintf("Failed to delete user: %v", err), http.StatusInternalServerError)
		return
	}

	response := shared.APIResponse{
		Success:   true,
		Message:   "User deleted successfully",
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleSyncUsers handles user sync from management server
func (api *EndNodeAPI) handleSyncUsers(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var syncRequest shared.SyncRequest
	if err := json.NewDecoder(r.Body).Decode(&syncRequest); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Process the sync request
	switch syncRequest.Action {
	case "CREATE":
		api.handleSyncCreateUser(w, r, syncRequest)
	case "UPDATE":
		api.handleSyncUpdateUser(w, r, syncRequest)
	case "DELETE":
		api.handleSyncDeleteUser(w, r, syncRequest)
	default:
		http.Error(w, "Unknown sync action", http.StatusBadRequest)
		return
	}
}

// handleSyncCreateUser handles syncing user creation
func (api *EndNodeAPI) handleSyncCreateUser(w http.ResponseWriter, r *http.Request, syncRequest shared.SyncRequest) {
	// End-nodes no longer handle user sync directly - this functionality is disabled
	http.Error(w, "User sync is now handled by management server", http.StatusMethodNotAllowed)
	return
}

// handleSyncUpdateUser handles syncing user updates
func (api *EndNodeAPI) handleSyncUpdateUser(w http.ResponseWriter, r *http.Request, syncRequest shared.SyncRequest) {
	// End-nodes no longer handle user sync directly - this functionality is disabled
	http.Error(w, "User sync is now handled by management server", http.StatusMethodNotAllowed)
	return
}

// handleSyncDeleteUser handles syncing user deletion
func (api *EndNodeAPI) handleSyncDeleteUser(w http.ResponseWriter, r *http.Request, syncRequest shared.SyncRequest) {
	// End-nodes no longer handle user sync directly - this functionality is disabled
	http.Error(w, "User sync is now handled by management server", http.StatusMethodNotAllowed)
	return
}

// handleCreateOVPN handles OVPN file creation requests from management server
func (api *EndNodeAPI) handleCreateOVPN(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Username string `json:"username"`
		Port     int    `json:"port"`
		Protocol string `json:"protocol"`
		ServerID string `json:"server_id"`
		ServerIP string `json:"server_ip"`
		CertData struct {
			CA   string `json:"ca"`
			Cert string `json:"cert"`
			Key  string `json:"key"`
			TA   string `json:"ta"`
		} `json:"cert_data"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Validate and sanitize input
	if err := api.validateOVPNInput(req.Username, req.Port, req.Protocol, req.ServerID, req.ServerIP); err != nil {
		http.Error(w, fmt.Sprintf("Invalid input: %v", err), http.StatusBadRequest)
		return
	}

	// Validate certificate data
	if err := api.validateCertData(req.CertData); err != nil {
		http.Error(w, fmt.Sprintf("Invalid certificate data: %v", err), http.StatusBadRequest)
		return
	}

	// Create OVPN file with certificates
	ovpnPath := fmt.Sprintf("/opt/vpnmanager/clients/%s.ovpn", req.Username)
	certData := struct {
		CA   string
		Cert string
		Key  string
		TA   string
	}{
		CA:   req.CertData.CA,
		Cert: req.CertData.Cert,
		Key:  req.CertData.Key,
		TA:   req.CertData.TA,
	}
	if err := api.manager.CreateOVPNWithCerts(req.Username, ovpnPath, req.Port, req.Protocol, req.ServerID, req.ServerIP, certData); err != nil {
		http.Error(w, fmt.Sprintf("Failed to create OVPN file: %v", err), http.StatusInternalServerError)
		return
	}

	// Log successful OVPN creation
	api.logAudit("ovpn_created", req.Username, fmt.Sprintf("OVPN file created for user %s on server %s", req.Username, req.ServerID), r.RemoteAddr)

	response := shared.APIResponse{
		Success:   true,
		Message:   fmt.Sprintf("OVPN file created for user %s", req.Username),
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// validateOVPNInput validates OVPN creation input
func (api *EndNodeAPI) validateOVPNInput(username string, port int, protocol, serverID, serverIP string) error {
	// Validate username
	if err := api.validateUsername(username); err != nil {
		return err
	}

	// Validate port
	if port < 1 || port > 65535 {
		return fmt.Errorf("port must be between 1 and 65535")
	}

	// Validate protocol
	if protocol != "udp" && protocol != "tcp" {
		return fmt.Errorf("protocol must be 'udp' or 'tcp'")
	}

	// Validate server ID
	if len(serverID) < 1 || len(serverID) > 64 {
		return fmt.Errorf("server ID must be 1-64 characters")
	}

	// Validate server IP
	if serverIP == "" {
		return fmt.Errorf("server IP is required")
	}

	return nil
}

// validateUsername validates username for security
func (api *EndNodeAPI) validateUsername(username string) error {
	// Length check
	if len(username) < 3 || len(username) > 32 {
		return fmt.Errorf("username must be 3-32 characters")
	}
	
	// Character validation (alphanumeric and underscore only)
	matched, _ := regexp.MatchString("^[a-zA-Z0-9_]+$", username)
	if !matched {
		return fmt.Errorf("username must contain only alphanumeric characters and underscores")
	}
	
	// Reserved names
	reserved := []string{"admin", "root", "system", "vpnmanager", "postgres", "nobody"}
	for _, reserved := range reserved {
		if strings.EqualFold(username, reserved) {
			return fmt.Errorf("username '%s' is reserved", username)
		}
	}
	
	return nil
}

// validateCertData validates certificate data
func (api *EndNodeAPI) validateCertData(certData struct {
	CA   string `json:"ca"`
	Cert string `json:"cert"`
	Key  string `json:"key"`
	TA   string `json:"ta"`
}) error {
	// Validate CA certificate
	if !strings.Contains(certData.CA, "BEGIN CERTIFICATE") || !strings.Contains(certData.CA, "END CERTIFICATE") {
		return fmt.Errorf("invalid CA certificate format")
	}

	// Validate client certificate
	if !strings.Contains(certData.Cert, "BEGIN CERTIFICATE") || !strings.Contains(certData.Cert, "END CERTIFICATE") {
		return fmt.Errorf("invalid client certificate format")
	}

	// Validate private key
	if !strings.Contains(certData.Key, "BEGIN PRIVATE KEY") || !strings.Contains(certData.Key, "END PRIVATE KEY") {
		return fmt.Errorf("invalid private key format")
	}

	// Validate TLS auth key
	if !strings.Contains(certData.TA, "BEGIN OpenVPN Static key V1") || !strings.Contains(certData.TA, "END OpenVPN Static key V1") {
		return fmt.Errorf("invalid TLS auth key format")
	}

	return nil
}

// handleDownloadOVPN handles OVPN file download requests
func (api *EndNodeAPI) handleDownloadOVPN(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract username from URL path: /api/ovpn/{username}
	username := r.URL.Path[len("/api/ovpn/"):]
	if username == "" {
		http.Error(w, "Username required", http.StatusBadRequest)
		return
	}

	// Check if OVPN file exists in /opt/vpnmanager/clients/
	ovpnPath := fmt.Sprintf("/opt/vpnmanager/clients/%s.ovpn", username)

	// Check if file exists
	if _, err := os.Stat(ovpnPath); os.IsNotExist(err) {
		http.Error(w, "User does not exist", http.StatusNotFound)
		return
	}

	// Read the OVPN file
	ovpnContent, err := os.ReadFile(ovpnPath)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to read OVPN file: %v", err), http.StatusInternalServerError)
		return
	}

	// Set headers for file download
	filename := fmt.Sprintf("%s.ovpn", username)
	w.Header().Set("Content-Type", "application/x-openvpn-profile")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", filename))
	w.Header().Set("Content-Length", fmt.Sprintf("%d", len(ovpnContent)))

	// Write the OVPN content
	w.Write(ovpnContent)
}

// handleDeleteOVPN handles OVPN file deletion requests
func (api *EndNodeAPI) handleDeleteOVPN(w http.ResponseWriter, r *http.Request) {
	if r.Method != "DELETE" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract username from URL path: /api/ovpn/delete/{username}
	username := r.URL.Path[len("/api/ovpn/delete/"):]
	if username == "" {
		http.Error(w, "Username required", http.StatusBadRequest)
		return
	}

	// Check if OVPN file exists in /opt/vpnmanager/clients/
	ovpnPath := fmt.Sprintf("/opt/vpnmanager/clients/%s.ovpn", username)

	// Log the deletion attempt
	fmt.Printf("Attempting to delete OVPN file: %s\n", ovpnPath)

	// Check if file exists
	fileInfo, err := os.Stat(ovpnPath)
	if os.IsNotExist(err) {
		fmt.Printf("File does not exist: %s\n", ovpnPath)
		http.Error(w, "User does not exist", http.StatusNotFound)
		return
	}
	if err != nil {
		fmt.Printf("Error checking file: %v\n", err)
		http.Error(w, fmt.Sprintf("Error checking file: %v", err), http.StatusInternalServerError)
		return
	}

	fmt.Printf("File exists, size: %d bytes\n", fileInfo.Size())

	// Delete the OVPN file
	err = os.Remove(ovpnPath)
	if err != nil {
		fmt.Printf("Failed to delete file: %v\n", err)
		http.Error(w, fmt.Sprintf("Failed to delete OVPN file: %v", err), http.StatusInternalServerError)
		return
	}

	fmt.Printf("Successfully deleted file: %s\n", ovpnPath)

	// Remove certificate files from EasyRSA to allow recreation
	fmt.Printf("Removing certificate files for user: %s\n", username)

	// Remove certificate files
	certFiles := []string{
		fmt.Sprintf("/opt/vpnmanager/easyrsa/pki/issued/%s.crt", username),
		fmt.Sprintf("/opt/vpnmanager/easyrsa/pki/private/%s.key", username),
		fmt.Sprintf("/opt/vpnmanager/easyrsa/pki/reqs/%s.req", username),
	}

	for _, file := range certFiles {
		if err := os.Remove(file); err != nil {
			if !os.IsNotExist(err) {
				fmt.Printf("Failed to remove file %s: %v\n", file, err)
			}
		} else {
			fmt.Printf("Removed file: %s\n", file)
		}
	}

	// Also revoke the certificate to update CRL (in case it was already signed)
	fmt.Printf("Revoking certificate for user: %s\n", username)
	revokeCmd := exec.Command("/opt/vpnmanager/easyrsa/easyrsa", "revoke", username)
	revokeCmd.Dir = "/opt/vpnmanager/easyrsa"
	revokeCmd.Env = append(os.Environ(), "EASYRSA_BATCH=1", "EASYRSA_PKI=/opt/vpnmanager/easyrsa/pki")

	revokeOutput, revokeErr := revokeCmd.CombinedOutput()
	if revokeErr != nil {
		fmt.Printf("Revoke failed (expected if cert was already removed): %v, output: %s\n", revokeErr, string(revokeOutput))
	} else {
		fmt.Printf("Certificate revoked successfully: %s\n", string(revokeOutput))
	}

	// Update CRL
	fmt.Printf("Updating Certificate Revocation List...\n")
	crlCmd := exec.Command("/opt/vpnmanager/easyrsa/easyrsa", "gen-crl")
	crlCmd.Dir = "/opt/vpnmanager/easyrsa"
	crlCmd.Env = append(os.Environ(), "EASYRSA_BATCH=1", "EASYRSA_PKI=/opt/vpnmanager/easyrsa/pki")

	crlOutput, crlErr := crlCmd.CombinedOutput()
	if crlErr != nil {
		fmt.Printf("Failed to update CRL: %v, output: %s\n", crlErr, string(crlOutput))
	} else {
		fmt.Printf("CRL updated successfully: %s\n", string(crlOutput))

		// Copy CRL to OpenVPN directory
		copyCmd := exec.Command("cp", "/opt/vpnmanager/easyrsa/pki/crl.pem", "/etc/openvpn/crl.pem")
		copyErr := copyCmd.Run()
		if copyErr != nil {
			fmt.Printf("Failed to copy CRL to OpenVPN directory: %v\n", copyErr)
		} else {
			fmt.Printf("CRL copied to OpenVPN directory\n")
		}
	}

	// Disconnect active OpenVPN sessions for this user
	fmt.Printf("Disconnecting active sessions for user: %s\n", username)

	// Signal OpenVPN to reload CRL (SIGUSR1 does not disconnect active clients, just reloads config)
	fmt.Printf("Signaling OpenVPN to reload CRL...\n")
	reloadCmd := exec.Command("pkill", "-SIGUSR1", "openvpn")
	reloadErr := reloadCmd.Run()
	if reloadErr != nil {
		fmt.Printf("Failed to signal OpenVPN to reload CRL: %v\n", reloadErr)
	} else {
		fmt.Printf("OpenVPN signaled to reload CRL successfully\n")
	}

	// Use management interface to disconnect user immediately
	// Try multiple possible socket paths
	socketPaths := []string{
		"/var/run/openvpn/server.sock",
		"/var/run/openvpn-server/server.sock",
		"/run/openvpn/server.sock",
	}

	disconnected := false
	for _, socketPath := range socketPaths {
		// Check if socket exists
		if _, err := os.Stat(socketPath); os.IsNotExist(err) {
			continue
		}

		fmt.Printf("Attempting disconnect via management socket: %s\n", socketPath)
		disconnectCmd := exec.Command("bash", "-c",
			fmt.Sprintf("echo 'kill %s' | nc -U %s", username, socketPath))
		disconnectOutput, disconnectErr := disconnectCmd.CombinedOutput()

		if disconnectErr != nil {
			fmt.Printf("Management interface disconnect failed: %v\n", disconnectErr)
			continue
		}

		// Check if the kill command was successful
		outputStr := string(disconnectOutput)
		if strings.Contains(outputStr, "SUCCESS") || strings.Contains(outputStr, "killed") {
			fmt.Printf("User session disconnected successfully via management interface\n")
			fmt.Printf("Output: %s\n", outputStr)
			disconnected = true
			break
		} else {
			fmt.Printf("Disconnect command sent but uncertain result: %s\n", outputStr)
		}
	}

	if !disconnected {
		fmt.Printf("WARNING: Could not disconnect via management interface\n")
		fmt.Printf("User will be rejected on next connection attempt due to CRL\n")
		fmt.Printf("IMPORTANT: Ensure OpenVPN server.conf has 'crl-verify /etc/openvpn/crl.pem'\n")

		// Try using helper script if available
		disconnectScript := "/opt/vpnmanager/scripts/disconnect-user.sh"
		if _, err := os.Stat(disconnectScript); err == nil {
			fmt.Printf("Attempting disconnect via helper script\n")
			scriptCmd := exec.Command(disconnectScript, username)
			scriptOutput, scriptErr := scriptCmd.CombinedOutput()
			if scriptErr != nil {
				fmt.Printf("Helper script failed: %v\n", scriptErr)
			} else {
				fmt.Printf("Helper script output: %s\n", string(scriptOutput))
			}
		}
	}

	// Wait a moment for disconnect to process
	time.Sleep(1 * time.Second)

	// Verify user is disconnected by checking management interface status
	for _, socketPath := range socketPaths {
		if _, err := os.Stat(socketPath); os.IsNotExist(err) {
			continue
		}

		statusCmd := exec.Command("bash", "-c",
			fmt.Sprintf("echo 'status' | nc -U %s | grep -i '%s'", socketPath, username))
		statusOutput, _ := statusCmd.CombinedOutput()

		if len(statusOutput) > 0 {
			fmt.Printf("WARNING: User %s still appears in OpenVPN status:\n%s\n",
				username, string(statusOutput))
			fmt.Printf("User may still be connected - will be blocked on next authentication\n")
		} else {
			fmt.Printf("Verified: User %s is no longer in active connections list\n", username)
		}
		break
	}

	// Log audit event for disconnection
	api.logAudit("user_disconnected", username,
		fmt.Sprintf("User %s deleted and disconnected from VPN", username),
		r.RemoteAddr)

	// Return success response
	response := shared.APIResponse{
		Success:   true,
		Message:   fmt.Sprintf("OVPN file deleted and certificate revoked for user %s", username),
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// generateOVPNContent generates OVPN configuration content for a user on this end-node
func (api *EndNodeAPI) generateOVPNContent(user *shared.User) ([]byte, error) {
	// Get server information from manager
	serverID := api.manager.GetServerID()
	serverHost := api.manager.GetServerHost()
	serverPort := api.manager.GetServerPort()

	// Create OVPN configuration content
	ovpnConfig := fmt.Sprintf(`# OpenVPN Configuration for %s on %s
# Generated by VPN Manager End-Node
# Server: %s (%s:%d)
# User: %s
# Port: %d
# Protocol: %s

# Client configuration
client
dev tun
proto %s
remote %s %d
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-CBC
verb 3

# Authentication
auth-user-pass
auth-nocache

# SSL/TLS settings
tls-client
remote-cert-tls server

# Connection settings
connect-retry-max 5
connect-retry 5
connect-timeout 10

# Compression
comp-lzo

# Logging
log-append /var/log/openvpn/%s.log

# Security
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384:TLS-ECDHE-RSA-WITH-AES-256-CBC-SHA

# Keepalive
keepalive 10 60
ping-timer-rem
ping-exit 60

# Route settings (if needed)
# route 0.0.0.0 0.0.0.0

# DNS settings
# dhcp-option DNS 8.8.8.8
# dhcp-option DNS 8.8.4.4

# Scripts
# script-security 2
# up /etc/openvpn/up.sh
# down /etc/openvpn/down.sh

# Additional settings
# mute-replay-warnings
# replay-window 64
# mute 20

# Certificate and key placeholders
# <ca>
# [CA certificate content would go here]
# </ca>
# <cert>
# [Client certificate content would go here]
# </cert>
# <key>
# [Client private key content would go here]
# </key>
# <tls-auth>
# [TLS auth key content would go here]
# </tls-auth>
`,
		user.Username,
		serverID,
		serverID,
		serverHost,
		serverPort,
		user.Username,
		user.Port,
		user.Protocol,
		user.Protocol,
		serverHost,
		user.Port,
		user.Username,
	)

	return []byte(ovpnConfig), nil
}

// middleware adds common middleware to all requests
func (api *EndNodeAPI) middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Add security headers
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		w.Header().Set("Content-Security-Policy", "default-src 'self'")
		
		// Add CORS headers (restrict in production)
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-API-Key")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		// Rate limiting
		if !api.checkRateLimit(r.RemoteAddr) {
			http.Error(w, "Rate limit exceeded", http.StatusTooManyRequests)
			return
		}

		// Input validation and sanitization
		if err := api.validateRequest(r); err != nil {
			http.Error(w, fmt.Sprintf("Invalid request: %v", err), http.StatusBadRequest)
			return
		}

		// Log the request with security context
		api.logSecurityEvent(r)

		next.ServeHTTP(w, r)
	})
}

// checkRateLimit implements rate limiting
func (api *EndNodeAPI) checkRateLimit(ip string) bool {
	// Simple in-memory rate limiting (use Redis in production)
	// This is a basic implementation - consider using a proper rate limiter
	return true // Placeholder - implement proper rate limiting
}

// validateRequest validates and sanitizes incoming requests
func (api *EndNodeAPI) validateRequest(r *http.Request) error {
	// Validate request size
	if r.ContentLength > 10*1024*1024 { // 10MB limit
		return fmt.Errorf("request too large")
	}

	// Validate headers
	if r.Header.Get("Content-Type") != "" && 
	   !strings.Contains(r.Header.Get("Content-Type"), "application/json") &&
	   !strings.Contains(r.Header.Get("Content-Type"), "multipart/form-data") {
		return fmt.Errorf("invalid content type")
	}

	return nil
}

// logSecurityEvent logs security-related events
func (api *EndNodeAPI) logSecurityEvent(r *http.Request) {
	// Log request details for security monitoring
	fmt.Printf("[SECURITY] %s %s from %s - User-Agent: %s\n", 
		r.Method, r.URL.Path, r.RemoteAddr, r.Header.Get("User-Agent"))
	
	// Log to audit system
	api.logAudit("api_request", "", fmt.Sprintf("%s %s", r.Method, r.URL.Path), r.RemoteAddr)
}

// logAudit logs audit events
func (api *EndNodeAPI) logAudit(action, username, details, ipAddress string) {
	// Log to local file for end-node audit trail
	logFile := "/var/log/vpnmanager/endnode-audit.log"
	
	auditEntry := fmt.Sprintf("[%s] %s %s %s %s\n", 
		time.Now().Format("2006-01-02 15:04:05"),
		action,
		username,
		details,
		ipAddress)
	
	// Append to audit log file
	if file, err := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0640); err == nil {
		file.WriteString(auditEntry)
		file.Close()
	}
}

// isWritable checks if a directory is writable
func isWritable(path string) bool {
	// Try to create a temporary file in the directory
	testFile := filepath.Join(path, ".write_test")
	file, err := os.Create(testFile)
	if err != nil {
		return false
	}
	file.Close()
	os.Remove(testFile)
	return true
}
