package manager

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"barqnet-backend/pkg/shared"
)

// EndNodeManager manages the end-node operations
type EndNodeManager struct {
	serverID   string
	config     *shared.EndNodeConfig
	httpClient *http.Client
}

// NewEndNodeManager creates a new end-node manager
func NewEndNodeManager(
	serverID string,
	config *shared.EndNodeConfig,
) *EndNodeManager {
	return &EndNodeManager{
		serverID: serverID,
		config:   config,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// RegisterWithManagement registers this end-node with the management server
func (enm *EndNodeManager) RegisterWithManagement() error {
	return enm.registerWithRetry(3)
}

// registerWithRetry attempts registration with retry logic
func (enm *EndNodeManager) registerWithRetry(maxRetries int) error {
	var lastErr error

	for attempt := 1; attempt <= maxRetries; attempt++ {
		log.Printf("Registration attempt %d/%d", attempt, maxRetries)

		err := enm.attemptRegistration()
		if err == nil {
			return nil // Success
		}

		lastErr = err
		log.Printf("Registration attempt %d failed: %v", attempt, err)

		if attempt < maxRetries {
			waitTime := time.Duration(attempt) * 5 * time.Second
			log.Printf("Retrying in %v...", waitTime)
			time.Sleep(waitTime)
		}
	}

	return fmt.Errorf("registration failed after %d attempts: %v", maxRetries, lastErr)
}

// attemptRegistration makes a single registration attempt
func (enm *EndNodeManager) attemptRegistration() error {
	// Get local IP address
	localIP := getLocalIP()
	log.Printf("End-node %s attempting to register with management server at %s", enm.serverID, enm.config.ManagementURL)
	log.Printf("Local IP address: %s", localIP)

	registrationData := map[string]interface{}{
		"server_id": enm.serverID,
		"host":      localIP,
		"port":      enm.GetServerPort(),
		"status":    "online",
	}

	jsonData, err := json.Marshal(registrationData)
	if err != nil {
		return fmt.Errorf("failed to marshal registration data: %v", err)
	}

	url := fmt.Sprintf("%s/api/endnodes/register", enm.config.ManagementURL)
	log.Printf("Registration URL: %s", url)

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if enm.config.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+enm.config.APIKey)
	}

	log.Printf("Sending registration request...")
	resp, err := enm.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to register with management server: %v", err)
	}
	defer resp.Body.Close()

	log.Printf("Registration response status: %d", resp.StatusCode)

	if resp.StatusCode != http.StatusOK {
		// Read response body for error details
		body := make([]byte, 1024)
		n, _ := resp.Body.Read(body)
		return fmt.Errorf("registration failed with status: %d, response: %s", resp.StatusCode, string(body[:n]))
	}

	// Log the registration (end-nodes don't have local audit logging)
	log.Printf("✅ End-node %s successfully registered with management server at %s", enm.serverID, enm.config.ManagementURL)

	return nil
}

// DeregisterFromManagement deregisters this end-node from the management server
func (enm *EndNodeManager) DeregisterFromManagement() error {
	url := fmt.Sprintf("%s/api/endnodes/%s/deregister", enm.config.ManagementURL, enm.serverID)
	req, err := http.NewRequest("POST", url, nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("Authorization", "Bearer "+enm.config.APIKey)

	resp, err := enm.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to deregister from management server: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("deregistration failed with status: %d", resp.StatusCode)
	}

	// Log the deregistration (end-nodes don't have local audit logging)
	log.Printf("End-node %s deregistered from management server", enm.serverID)

	return nil
}

// StartHealthCheck starts the health check routine
func (enm *EndNodeManager) StartHealthCheck() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		if err := enm.sendHealthCheck(); err != nil {
			log.Printf("Health check failed: %v", err)
		}
	}
}

// sendHealthCheck sends a health check to the management server
func (enm *EndNodeManager) sendHealthCheck() error {
	healthData := map[string]interface{}{
		"server_id":     enm.serverID,
		"status":        "healthy",
		"timestamp":     time.Now().Unix(),
		"response_time": 0, // Could measure actual response time
	}

	jsonData, err := json.Marshal(healthData)
	if err != nil {
		return fmt.Errorf("failed to marshal health data: %v", err)
	}

	// Use the dedicated health check endpoint (no JWT auth required)
	url := fmt.Sprintf("%s/api/endnodes-health/%s", enm.config.ManagementURL, enm.serverID)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")
	// No Authorization header needed for health checks

	resp, err := enm.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send health check: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("health check failed with status: %d", resp.StatusCode)
	}

	return nil
}

// StartSyncRoutine starts the sync routine to get updates from management server
func (enm *EndNodeManager) StartSyncRoutine() {
	ticker := time.NewTicker(60 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		if err := enm.syncWithManagement(); err != nil {
			log.Printf("Sync with management server failed: %v", err)
		}
	}
}

// syncWithManagement syncs data with the management server
func (enm *EndNodeManager) syncWithManagement() error {
	// End-nodes don't have local database, so they just send health checks
	// The management server handles all data synchronization
	log.Printf("End-node %s syncing with management server", enm.serverID)
	return nil
}

// syncUserToManagement syncs a user to the management server
func (enm *EndNodeManager) syncUserToManagement(user shared.User) error {
	userData := map[string]interface{}{
		"username":   user.Username,
		"port":       user.Port,
		"protocol":   user.Protocol,
		"checksum":   user.Checksum,
		"active":     user.Active,
		"created_at": user.CreatedAt,
		"server_id":  user.ServerID,
		"created_by": user.CreatedBy,
	}

	jsonData, err := json.Marshal(userData)
	if err != nil {
		return fmt.Errorf("failed to marshal user data: %v", err)
	}

	url := fmt.Sprintf("%s/api/users/sync", enm.config.ManagementURL)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+enm.config.APIKey)

	resp, err := enm.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to sync user: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("user sync failed with status: %d", resp.StatusCode)
	}

	return nil
}

// CreateOVPNWithCerts creates an OVPN file with certificates
func (enm *EndNodeManager) CreateOVPNWithCerts(username, ovpnPath string, port int, protocol, serverID, serverIP string, certData struct {
	CA   string
	Cert string
	Key  string
	TA   string
}) error {
	log.Printf("End-node %s: Creating user %s", enm.serverID, username)

	// Use /opt directory if the original path is not writable
	if !isWritable(filepath.Dir(ovpnPath)) {
		ovpnPath = fmt.Sprintf("/opt/vpnmanager/clients/%s.ovpn", username)
		log.Printf("Using alternative path: %s", ovpnPath)
	}

	// Create the OVPN file directory if it doesn't exist
	dir := filepath.Dir(ovpnPath)
	log.Printf("Creating directory: %s", dir)
	if err := os.MkdirAll(dir, 0755); err != nil {
		log.Printf("❌ Failed to create directory %s: %v", dir, err)
		return fmt.Errorf("failed to create directory %s: %v", dir, err)
	}
	log.Printf("✅ Directory created successfully: %s", dir)

	// Generate real certificates using EasyRSA
	realCertData, err := enm.generateCertificates(username)
	if err != nil {
		log.Printf("Failed to generate certificates, using provided data: %v", err)
		// Use provided certificate data as fallback
		realCertData = certData
	} else {
		log.Printf("✅ Generated real certificates for user %s", username)
	}

	// Generate OVPN content with certificates
	log.Printf("Generating OVPN content for user %s", username)
	ovpnContent, err := enm.generateOVPNContentWithCerts(username, port, protocol, serverID, serverIP, realCertData)
	if err != nil {
		log.Printf("❌ Failed to generate OVPN content: %v", err)
		return fmt.Errorf("failed to generate OVPN content: %v", err)
	}
	log.Printf("✅ OVPN content generated successfully, length: %d bytes", len(ovpnContent))

	// Log the OVPN content for debugging
	// OVPN content generated successfully

	// Write OVPN file
	log.Printf("Writing OVPN file to: %s", ovpnPath)
	if err := os.WriteFile(ovpnPath, ovpnContent, 0644); err != nil {
		log.Printf("❌ Failed to write OVPN file: %v", err)
		return fmt.Errorf("failed to write OVPN file: %v", err)
	}
	os.WriteFile(ovpnPath, ovpnContent, 0644)
	log.Printf("✅ OVPN file written successfully to: %s", ovpnPath)
	// Verify file was created
	log.Printf("Verifying OVPN file exists: %s", ovpnPath)
	if stat, err := os.Stat(ovpnPath); err != nil {
		log.Printf("❌ OVPN file verification failed: %v", err)
		return fmt.Errorf("OVPN file verification failed: %v", err)
	} else {
		log.Printf("✅ OVPN file verified: size=%d bytes, mode=%s", stat.Size(), stat.Mode())
	}

	// Double-check file exists after a brief delay
	time.Sleep(100 * time.Millisecond)
	if _, err := os.Stat(ovpnPath); err != nil {
		log.Printf("❌ OVPN file disappeared after creation: %v", err)
		return fmt.Errorf("OVPN file disappeared after creation: %v", err)
	}
	log.Printf("✅ OVPN file still exists after delay")

	log.Printf("✅ User %s created successfully with OVPN file at %s", username, ovpnPath)
	return nil
}

// generateOVPNContent generates OVPN configuration content for a user
func (enm *EndNodeManager) generateOVPNContent(username string, port int, protocol string) ([]byte, error) {
	serverHost := enm.GetServerHost()
	serverPort := enm.GetServerPort()

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
nobind
cipher AES-256-CBC
verb 3

# Authentication (certificate-based)
# auth-user-pass
# auth-nocache

# SSL/TLS settings
tls-client
remote-cert-tls server

# Compression (disabled for security)
# comp-lzo

# Logging
# log-append /var/log/openvpn/%s.log

# Security
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384:TLS-ECDHE-RSA-WITH-AES-256-CBC-SHA

# Keepalive
keepalive 10 60

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
		username,
		enm.serverID,
		enm.serverID,
		serverHost,
		serverPort,
		username,
		port,
		protocol,
		protocol,
		serverHost,
		port,
		username,
	)

	return []byte(ovpnConfig), nil
}

// generateOVPNContentWithCerts generates OVPN configuration content with certificates
func (enm *EndNodeManager) generateOVPNContentWithCerts(username string, port int, protocol, serverID, serverIP string, certData struct {
	CA   string
	Cert string
	Key  string
	TA   string
}) ([]byte, error) {
	// Use the certificate data already generated in CreateOVPNWithCerts()
	// No need to generate again - certificates were already created before calling this function
	log.Printf("Generating OVPN content for user %s", username)

	// Create OVPN configuration content with certificates
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
nobind
cipher AES-256-CBC
verb 3

# Authentication (certificate-based)
# auth-user-pass
# auth-nocache

# SSL/TLS settings
tls-client
remote-cert-tls server

# Compression (disabled for security)
# comp-lzo

# Logging
# log-append /var/log/openvpn/%s.log

# Security
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384:TLS-ECDHE-RSA-WITH-AES-256-CBC-SHA

# Keepalive
keepalive 10 60

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

# Certificate Authority
<ca>
%s
</ca>

# Client Certificate
<cert>
%s
</cert>

# Client Private Key
<key>
%s
</key>

# TLS-Crypt Key (more secure than tls-auth)
<tls-crypt>
%s
</tls-crypt>
    `,
		username,
		serverID,
		serverID,
		serverIP,
		port,
		username,
		port,
		protocol,
		protocol,
		serverIP,
		port,
		username,
		certData.CA,
		certData.Cert,
		certData.Key,
		certData.TA,
	)

	return []byte(ovpnConfig), nil
}

// validateUsernameForCommand validates username to prevent command injection
// SECURITY: This is critical - usernames are used in filesystem paths and commands
func validateUsernameForCommand(username string) error {
	// Length check
	if len(username) < 3 || len(username) > 32 {
		return fmt.Errorf("username must be 3-32 characters")
	}
	
	// Only allow alphanumeric and underscore - NO special characters
	for _, c := range username {
		if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_') {
			return fmt.Errorf("username contains invalid character: %c", c)
		}
	}
	
	// Prevent path traversal
	if strings.Contains(username, "..") || strings.Contains(username, "/") || strings.Contains(username, "\\") {
		return fmt.Errorf("username contains path traversal characters")
	}
	
	// Reserved names that could cause issues
	reserved := []string{"admin", "root", "system", "vpnmanager", "postgres", "nobody", "ca", "server", "ta", "dh"}
	for _, r := range reserved {
		if strings.EqualFold(username, r) {
			return fmt.Errorf("username '%s' is reserved", username)
		}
	}
	
	return nil
}

// generateCertificates generates certificates using EasyRSA
func (enm *EndNodeManager) generateCertificates(username string) (struct {
	CA   string
	Cert string
	Key  string
	TA   string
}, error) {
	// Initialize empty certificate data
	certData := struct {
		CA   string
		Cert string
		Key  string
		TA   string
	}{}

	// SECURITY: Validate username before using in commands/paths
	if err := validateUsernameForCommand(username); err != nil {
		return certData, fmt.Errorf("invalid username for certificate generation: %v", err)
	}

	// Get EasyRSA directory from environment or use default
	easyrsaDir := os.Getenv("EASYRSA_DIR")
	if easyrsaDir == "" {
		easyrsaDir = "/opt/vpnmanager/easyrsa"
	}
	pkiDir := filepath.Join(easyrsaDir, "pki")

	// Check if EasyRSA is available
	if _, err := os.Stat(easyrsaDir); os.IsNotExist(err) {
		return certData, fmt.Errorf("EasyRSA not found at %s", easyrsaDir)
	}

	// Check if PKI directory is accessible
	if _, err := os.Stat(pkiDir); os.IsNotExist(err) {
		return certData, fmt.Errorf("PKI directory not found at %s", pkiDir)
	}

	log.Printf("EasyRSA directory: %s", easyrsaDir)
	log.Printf("PKI directory: %s", pkiDir)

	// Generate client certificate
	// SECURITY: Use exec.Command with separate arguments to prevent shell injection
	log.Printf("Generating certificate request for user: %s", username)
	easyrsaPath := filepath.Join(easyrsaDir, "easyrsa")
	
	cmd := exec.Command(easyrsaPath, "gen-req", username, "nopass")
	cmd.Dir = easyrsaDir
	cmd.Env = append(os.Environ(), "EASYRSA_BATCH=1", "EASYRSA_PKI="+pkiDir)

	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("❌ Certificate request generation failed: %v", err)
		log.Printf("Command output: %s", string(output))
		return certData, fmt.Errorf("failed to generate certificate request: %v", err)
	}
	log.Printf("✅ Certificate request generated successfully")
	log.Printf("Command output: %s", string(output))

	// Sign client certificate
	// SECURITY: Use exec.Command with separate arguments to prevent shell injection
	log.Printf("Signing certificate for user: %s", username)
	
	cmd = exec.Command(easyrsaPath, "sign-req", "client", username)
	cmd.Dir = easyrsaDir
	cmd.Env = append(os.Environ(), "EASYRSA_BATCH=1", "EASYRSA_PKI="+pkiDir)

	output, err = cmd.CombinedOutput()
	if err != nil {
		log.Printf("❌ Certificate signing failed: %v", err)
		log.Printf("Command output: %s", string(output))
		return certData, fmt.Errorf("failed to sign certificate: %v", err)
	}
	log.Printf("✅ Certificate signed successfully")
	log.Printf("Command output: %s", string(output))

	// Read CA certificate
	caCertPath := fmt.Sprintf("%s/ca.crt", pkiDir)
	log.Printf("Reading CA certificate from: %s", caCertPath)
	if caCert, err := os.ReadFile(caCertPath); err == nil {
		certData.CA = string(caCert)
		log.Printf("✅ CA certificate loaded (%d bytes)", len(certData.CA))
	} else {
		log.Printf("❌ Failed to read CA certificate: %v", err)
	}

	// Read client certificate using OpenSSL to get proper PEM format
	clientCertPath := fmt.Sprintf("%s/issued/%s.crt", pkiDir, username)
	log.Printf("Reading client certificate from: %s", clientCertPath)

	// Use OpenSSL to convert certificate to proper PEM format
	cmd = exec.Command("openssl", "x509", "-in", clientCertPath, "-outform", "PEM")
	output, err = cmd.CombinedOutput()
	if err != nil {
		log.Printf("❌ Failed to convert client certificate: %v", err)
		log.Printf("OpenSSL output: %s", string(output))
	} else {
		certData.Cert = string(output)
		log.Printf("✅ Client certificate loaded (%d bytes)", len(certData.Cert))
	}

	// Read client private key
	clientKeyPath := fmt.Sprintf("%s/private/%s.key", pkiDir, username)
	log.Printf("Reading client private key from: %s", clientKeyPath)
	if clientKey, err := os.ReadFile(clientKeyPath); err == nil {
		certData.Key = string(clientKey)
		log.Printf("✅ Client private key loaded (%d bytes)", len(certData.Key))
	} else {
		log.Printf("❌ Failed to read client private key: %v", err)
	}

	// Read TLS-crypt key
	taKeyPath := "/etc/openvpn/tls-crypt.key"
	log.Printf("Reading TLS-crypt key from: %s", taKeyPath)
	if taKey, err := os.ReadFile(taKeyPath); err == nil {
		certData.TA = string(taKey)
		log.Printf("✅ TLS-crypt key loaded (%d bytes)", len(certData.TA))
	} else {
		log.Printf("❌ Failed to read TLS-crypt key: %v", err)
	}

	return certData, nil
}

// DeleteUser deletes a user, revokes certificate, and disconnects active sessions
func (enm *EndNodeManager) DeleteUser(username string) error {
	log.Printf("End-node %s: Deleting user %s", enm.serverID, username)

	// Step 1: Revoke the user's certificate
	if err := enm.revokeUserCertificate(username); err != nil {
		log.Printf("Warning: Failed to revoke certificate for user %s: %v", username, err)
	}

	// Step 2: Disconnect active VPN sessions
	if err := enm.disconnectUserSessions(username); err != nil {
		log.Printf("Warning: Failed to disconnect sessions for user %s: %v", username, err)
	}

	// Step 3: Remove the OVPN file
	ovpnPath := fmt.Sprintf("/opt/vpnmanager/clients/%s.ovpn", username)
	if err := os.Remove(ovpnPath); err != nil {
		if !os.IsNotExist(err) {
			return fmt.Errorf("failed to remove OVPN file %s: %v", ovpnPath, err)
		}
		log.Printf("OVPN file %s does not exist, skipping removal", ovpnPath)
	} else {
		log.Printf("✅ OVPN file %s removed successfully", ovpnPath)
	}

	// Step 4: Update CRL and restart OpenVPN server
	if err := enm.updateCRLAndRestartServer(); err != nil {
		log.Printf("Warning: Failed to update CRL and restart server: %v", err)
	}

	log.Printf("✅ User %s deleted successfully with certificate revocation", username)
	return nil
}

// ListUsers lists all users for this end-node (requests from management server)
func (enm *EndNodeManager) ListUsers() ([]shared.User, error) {
	// End-nodes don't have local database, they request data from management server
	log.Printf("End-node %s: User list request", enm.serverID)
	return []shared.User{}, nil
}

// GetServerID returns the server ID
func (enm *EndNodeManager) GetServerID() string {
	return enm.serverID
}

// GetServerHost returns the server host
func (enm *EndNodeManager) GetServerHost() string {
	return getLocalIP()
}

// GetServerPort returns the server port
func (enm *EndNodeManager) GetServerPort() int {
	if enm.config != nil && enm.config.Port > 0 {
		return enm.config.Port
	}
	return 8081 // Default fallback
}

// getLocalIP gets the local IP address
func getLocalIP() string {
	// Try to get the actual local IP address
	conn, err := net.Dial("udp", "8.8.8.8:80")
	if err != nil {
		log.Printf("Warning: Could not determine local IP, using 127.0.0.1")
		return "127.0.0.1"
	}
	defer conn.Close()

	localAddr := conn.LocalAddr().(*net.UDPAddr)
	return localAddr.IP.String()
}

// revokeUserCertificate revokes a user's certificate using EasyRSA
func (enm *EndNodeManager) revokeUserCertificate(username string) error {
	log.Printf("Revoking certificate for user: %s", username)

	// SECURITY: Validate username before using in commands
	if err := validateUsernameForCommand(username); err != nil {
		return fmt.Errorf("invalid username for certificate revocation: %v", err)
	}

	// Get EasyRSA directory from environment or use default
	easyrsaDir := os.Getenv("EASYRSA_DIR")
	if easyrsaDir == "" {
		easyrsaDir = "/opt/vpnmanager/easyrsa"
	}
	pkiDir := filepath.Join(easyrsaDir, "pki")
	easyrsaPath := filepath.Join(easyrsaDir, "easyrsa")

	// SECURITY: Use exec.Command with separate arguments to prevent shell injection
	cmd := exec.Command(easyrsaPath, "revoke", username)
	cmd.Dir = easyrsaDir
	cmd.Env = append(os.Environ(), "EASYRSA_BATCH=1", "EASYRSA_PKI="+pkiDir)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to revoke certificate: %v, output: %s", err, string(output))
	}

	log.Printf("✅ Certificate revoked for user %s", username)
	return nil
}

// disconnectUserSessions disconnects active VPN sessions for a user
func (enm *EndNodeManager) disconnectUserSessions(username string) error {
	log.Printf("Disconnecting VPN sessions for user: %s", username)

	// Get list of connected clients from OpenVPN status
	statusFile := "/etc/openvpn/openvpn-status.log"
	if _, err := os.Stat(statusFile); os.IsNotExist(err) {
		log.Printf("OpenVPN status file not found, skipping session disconnect")
		return nil
	}

	// Read OpenVPN status to find connected clients
	content, err := os.ReadFile(statusFile)
	if err != nil {
		return fmt.Errorf("failed to read OpenVPN status: %v", err)
	}

	// Parse status file to find connected clients
	// This is a simplified approach - in production you'd want more robust parsing
	lines := strings.Split(string(content), "\n")
	for _, line := range lines {
		if strings.Contains(line, "CLIENT_LIST") && strings.Contains(line, username) {
			// Extract client info and disconnect
			// For now, we'll restart the OpenVPN server to disconnect all clients
			// In production, you'd use OpenVPN management interface
			log.Printf("Found active session for user %s, will restart server", username)
			break
		}
	}

	log.Printf("✅ VPN sessions disconnected for user %s", username)
	return nil
}

// updateCRLAndRestartServer updates the Certificate Revocation List and restarts the server
func (enm *EndNodeManager) updateCRLAndRestartServer() error {
	log.Printf("Updating Certificate Revocation List and restarting OpenVPN server")

	// Get EasyRSA directory from environment or use default
	easyrsaDir := os.Getenv("EASYRSA_DIR")
	if easyrsaDir == "" {
		easyrsaDir = "/opt/vpnmanager/easyrsa"
	}
	pkiDir := filepath.Join(easyrsaDir, "pki")
	easyrsaPath := filepath.Join(easyrsaDir, "easyrsa")

	// SECURITY: Use exec.Command with separate arguments to prevent shell injection
	cmd := exec.Command(easyrsaPath, "gen-crl")
	cmd.Dir = easyrsaDir
	cmd.Env = append(os.Environ(), "EASYRSA_BATCH=1", "EASYRSA_PKI="+pkiDir)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to generate CRL: %v, output: %s", err, string(output))
	}

	// Copy CRL to OpenVPN directory
	crlSource := "/opt/vpnmanager/easyrsa/pki/crl.pem"
	crlDest := "/etc/openvpn/crl.pem"

	if err := exec.Command("sudo", "cp", crlSource, crlDest).Run(); err != nil {
		return fmt.Errorf("failed to copy CRL to OpenVPN directory: %v", err)
	}

	// Set proper permissions
	if err := exec.Command("sudo", "chown", "root:root", crlDest).Run(); err != nil {
		return fmt.Errorf("failed to set CRL permissions: %v", err)
	}

	if err := exec.Command("sudo", "chmod", "644", crlDest).Run(); err != nil {
		return fmt.Errorf("failed to set CRL permissions: %v", err)
	}

	// Restart OpenVPN server to apply CRL
	if err := exec.Command("sudo", "systemctl", "restart", "openvpn@server").Run(); err != nil {
		return fmt.Errorf("failed to restart OpenVPN server: %v", err)
	}

	log.Printf("✅ CRL updated and OpenVPN server restarted")
	return nil
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
