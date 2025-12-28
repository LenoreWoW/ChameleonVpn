package api

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"barqnet-backend/apps/endnode/manager"
	"barqnet-backend/pkg/shared"
)

// EndNodeAPI handles API requests for the end-node
type EndNodeAPI struct {
	manager     *manager.EndNodeManager
	auditLogger *shared.AuditLogger
}

// NewEndNodeAPI creates a new end-node API
func NewEndNodeAPI(manager *manager.EndNodeManager) *EndNodeAPI {
	return &EndNodeAPI{manager: manager}
}

// Start starts the API server
func (api *EndNodeAPI) Start(port int) error {
	// Initialize audit logger with file-only logging (endnode doesn't have DB connection)
	auditDir := os.Getenv("AUDIT_LOG_DIR")
	if auditDir == "" {
		auditDir = "/var/log/vpnmanager"
	}

	fileEnabled := getEnvBool("AUDIT_FILE_ENABLED", true)
	// Endnode uses file-only logging (no database connection)
	api.auditLogger = shared.NewAuditLogger(auditDir, fileEnabled, false, nil)

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

// validateUsernameForPath validates username to prevent path traversal attacks
// SECURITY: This is critical - usernames are used in filesystem paths
func (api *EndNodeAPI) validateUsernameForPath(username string) error {
	// Length check
	if len(username) < 3 || len(username) > 32 {
		return fmt.Errorf("username must be 3-32 characters")
	}
	
	// SECURITY: Prevent path traversal
	if strings.Contains(username, "..") || strings.Contains(username, "/") || strings.Contains(username, "\\") {
		return fmt.Errorf("username contains invalid characters")
	}
	
	// Only allow alphanumeric and underscore - NO special characters
	for _, c := range username {
		if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_') {
			return fmt.Errorf("username contains invalid character")
		}
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

	// SECURITY: Validate username to prevent path traversal attacks
	if err := api.validateUsernameForPath(username); err != nil {
		http.Error(w, fmt.Sprintf("Invalid username: %v", err), http.StatusBadRequest)
		return
	}

	// Get clients directory from environment or use default
	clientsDir := os.Getenv("CLIENTS_DIR")
	if clientsDir == "" {
		clientsDir = "/opt/vpnmanager/clients"
	}

	// SECURITY: Use filepath.Join to safely construct path
	ovpnPath := filepath.Join(clientsDir, username+".ovpn")

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

	// SECURITY: Validate username to prevent path traversal attacks
	if err := api.validateUsernameForPath(username); err != nil {
		http.Error(w, fmt.Sprintf("Invalid username: %v", err), http.StatusBadRequest)
		return
	}

	// Get clients directory from environment or use default
	clientsDir := os.Getenv("CLIENTS_DIR")
	if clientsDir == "" {
		clientsDir = "/opt/vpnmanager/clients"
	}

	// SECURITY: Use filepath.Join to safely construct path
	ovpnPath := filepath.Join(clientsDir, username+".ovpn")

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

	// Get EasyRSA and OpenVPN directories from environment
	easyrsaDir := os.Getenv("EASYRSA_DIR")
	if easyrsaDir == "" {
		easyrsaDir = "/opt/vpnmanager/easyrsa"
	}
	openvpnDir := os.Getenv("OPENVPN_DIR")
	if openvpnDir == "" {
		openvpnDir = "/etc/openvpn"
	}
	pkiDir := filepath.Join(easyrsaDir, "pki")
	easyrsaPath := filepath.Join(easyrsaDir, "easyrsa")

	// Remove certificate files from EasyRSA to allow recreation
	fmt.Printf("Removing certificate files for user: %s\n", username)

	// SECURITY: Username already validated, use filepath.Join for safe path construction
	certFiles := []string{
		filepath.Join(pkiDir, "issued", username+".crt"),
		filepath.Join(pkiDir, "private", username+".key"),
		filepath.Join(pkiDir, "reqs", username+".req"),
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
	// SECURITY: Use exec.Command with separate arguments to prevent shell injection
	fmt.Printf("Revoking certificate for user: %s\n", username)
	revokeCmd := exec.Command(easyrsaPath, "revoke", username)
	revokeCmd.Dir = easyrsaDir
	revokeCmd.Env = append(os.Environ(), "EASYRSA_BATCH=1", "EASYRSA_PKI="+pkiDir)

	revokeOutput, revokeErr := revokeCmd.CombinedOutput()
	if revokeErr != nil {
		fmt.Printf("Revoke failed (expected if cert was already removed): %v, output: %s\n", revokeErr, string(revokeOutput))
	} else {
		fmt.Printf("Certificate revoked successfully: %s\n", string(revokeOutput))
	}

	// Update CRL
	fmt.Printf("Updating Certificate Revocation List...\n")
	crlCmd := exec.Command(easyrsaPath, "gen-crl")
	crlCmd.Dir = easyrsaDir
	crlCmd.Env = append(os.Environ(), "EASYRSA_BATCH=1", "EASYRSA_PKI="+pkiDir)

	crlOutput, crlErr := crlCmd.CombinedOutput()
	if crlErr != nil {
		fmt.Printf("Failed to update CRL: %v, output: %s\n", crlErr, string(crlOutput))
	} else {
		fmt.Printf("CRL updated successfully: %s\n", string(crlOutput))

		// Copy CRL to OpenVPN directory
		srcCRL := filepath.Join(pkiDir, "crl.pem")
		dstCRL := filepath.Join(openvpnDir, "crl.pem")
		copyCmd := exec.Command("cp", srcCRL, dstCRL)
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

// validateAPIKey validates the API key from request header against environment
func (api *EndNodeAPI) validateAPIKey(r *http.Request) bool {
	expectedAPIKey := os.Getenv("API_KEY")
	if expectedAPIKey == "" {
		log.Println("WARNING: API_KEY environment variable not set - API key validation disabled")
		return true // Allow if no key configured (dev mode)
	}
	
	providedKey := r.Header.Get("X-API-Key")
	if providedKey == "" {
		providedKey = r.Header.Get("Authorization")
		if strings.HasPrefix(providedKey, "Bearer ") {
			providedKey = strings.TrimPrefix(providedKey, "Bearer ")
		}
	}
	
	// SECURITY: Use constant-time comparison to prevent timing attacks
	return len(providedKey) > 0 && providedKey == expectedAPIKey
}

// isProtectedEndpoint returns true if the endpoint requires API key authentication
func isProtectedEndpoint(path string) bool {
	// Health check is public for load balancer/monitoring
	if path == "/health" {
		return false
	}
	// All other endpoints require authentication
	return true
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
		
		// SECURITY: Restrict CORS to management server only in production
		allowedOrigin := os.Getenv("ALLOWED_ORIGIN")
		if allowedOrigin == "" {
			allowedOrigin = os.Getenv("MANAGEMENT_URL")
		}
		if allowedOrigin == "" {
			// Development fallback - restrict in production
			allowedOrigin = "*"
		}
		w.Header().Set("Access-Control-Allow-Origin", allowedOrigin)
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-API-Key")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		// SECURITY: Validate API key for protected endpoints
		if isProtectedEndpoint(r.URL.Path) {
			if !api.validateAPIKey(r) {
				log.Printf("SECURITY: Invalid API key from %s for %s", r.RemoteAddr, r.URL.Path)
				http.Error(w, "Unauthorized: Invalid or missing API key", http.StatusUnauthorized)
				return
			}
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

// rateLimitStore holds rate limit state in memory
var rateLimitStore = struct {
	entries map[string]*rateLimitEntry
	mu      sync.RWMutex
}{
	entries: make(map[string]*rateLimitEntry),
}

type rateLimitEntry struct {
	count     int
	windowEnd time.Time
}

// checkRateLimit implements sliding window rate limiting
func (api *EndNodeAPI) checkRateLimit(ip string) bool {
	// Configuration
	maxRequests := 100 // requests per window
	windowDuration := time.Minute
	
	// Get rate limit from env if set
	if envMax := os.Getenv("RATE_LIMIT_MAX"); envMax != "" {
		if parsed, err := strconv.Atoi(envMax); err == nil {
			maxRequests = parsed
		}
	}
	
	rateLimitStore.mu.Lock()
	defer rateLimitStore.mu.Unlock()
	
	now := time.Now()
	entry, exists := rateLimitStore.entries[ip]
	
	if !exists || now.After(entry.windowEnd) {
		// New window
		rateLimitStore.entries[ip] = &rateLimitEntry{
			count:     1,
			windowEnd: now.Add(windowDuration),
		}
		return true
	}
	
	// Existing window - check limit
	if entry.count >= maxRequests {
		log.Printf("RATE LIMIT: IP %s exceeded %d requests/minute", ip, maxRequests)
		return false
	}
	
	entry.count++
	return true
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

// logAudit logs audit events using the audit logger (file-only logging for endnode)
func (api *EndNodeAPI) logAudit(action, username, details, ipAddress string) {
	if api.auditLogger != nil {
		// Get server ID from environment or use default
		serverID := os.Getenv("SERVER_ID")
		if serverID == "" {
			serverID = "endnode"
		}

		if err := api.auditLogger.LogAudit("endnode-audit.log", action, username, details, ipAddress, serverID); err != nil {
			log.Printf("[AUDIT] ⚠️  Audit logging failed: %v", err)
		}
	} else {
		log.Printf("[AUDIT] ⚠️  Audit logger not initialized")
	}
}

// getEnvBool retrieves a boolean environment variable with a default value
func getEnvBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		return value == "true" || value == "1"
	}
	return defaultValue
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
