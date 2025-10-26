package manager

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"vpnmanager/pkg/shared"
)

// ManagementManager manages the management server operations
type ManagementManager struct {
	serverID      string
	config        *shared.ManagementConfig
	userManager   *shared.UserManager
	serverManager *shared.ServerManager
	auditManager  *shared.AuditManager
	httpClient    *http.Client
}

// NewManagementManager creates a new management manager
func NewManagementManager(
	serverID string,
	config *shared.ManagementConfig,
	userManager *shared.UserManager,
	serverManager *shared.ServerManager,
	auditManager *shared.AuditManager,
) *ManagementManager {
	return &ManagementManager{
		serverID:      serverID,
		config:        config,
		userManager:   userManager,
		serverManager: serverManager,
		auditManager:  auditManager,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// StartEndNodeMonitoring starts monitoring end-node servers
func (mm *ManagementManager) StartEndNodeMonitoring() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		if err := mm.checkEndNodeHealth(); err != nil {
			log.Printf("End-node health check failed: %v", err)
		}
	}
}

// checkEndNodeHealth checks the health of all end-node servers
func (mm *ManagementManager) checkEndNodeHealth() error {
	endNodes, err := mm.serverManager.ListEndNodes()
	if err != nil {
		return fmt.Errorf("failed to list end-nodes: %v", err)
	}

	for _, endNode := range endNodes {
		if err := mm.checkSingleEndNode(endNode); err != nil {
			log.Printf("Health check failed for end-node %s: %v", endNode.Name, err)
		}
	}

	return nil
}

// checkSingleEndNode checks the health of a single end-node
func (mm *ManagementManager) checkSingleEndNode(endNode shared.Server) error {
	url := fmt.Sprintf("http://%s:%d/health", endNode.Host, endNode.Port)

	start := time.Now()
	resp, err := mm.httpClient.Get(url)
	responseTime := int(time.Since(start).Milliseconds())

	status := "healthy"

	if err != nil {
		status = "unhealthy"
	} else {
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			status = "unhealthy"
		}
	}

	// Log health status to database
	mm.auditManager.LogAction(
		"HEALTH_CHECK",
		endNode.Name,
		fmt.Sprintf("end-node health check - status=%s response_time=%dms", status, responseTime),
		"",
		mm.serverID,
	)

	return nil
}

// StartUserSyncCoordination starts coordinating user sync across end-nodes
func (mm *ManagementManager) StartUserSyncCoordination() {
	ticker := time.NewTicker(60 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		if err := mm.coordinateUserSync(); err != nil {
			log.Printf("User sync coordination failed: %v", err)
		}
	}
}

// coordinateUserSync coordinates user synchronization across all end-nodes
func (mm *ManagementManager) coordinateUserSync() error {
	// Get all users from all end-nodes
	allUsers, err := mm.userManager.ListUsers()
	if err != nil {
		return fmt.Errorf("failed to list all users: %v", err)
	}

	// Get all end-nodes
	endNodes, err := mm.serverManager.ListEndNodes()
	if err != nil {
		return fmt.Errorf("failed to list end-nodes: %v", err)
	}

	// Sync users to each end-node
	for _, endNode := range endNodes {
		if err := mm.syncUsersToEndNode(endNode, allUsers); err != nil {
			log.Printf("Failed to sync users to end-node %s: %v", endNode.Name, err)
		}
	}

	return nil
}

// syncUsersToEndNode syncs users to a specific end-node
func (mm *ManagementManager) syncUsersToEndNode(endNode shared.Server, users []shared.User) error {
	// Filter users that belong to this end-node or need to be synced
	var usersToSync []shared.User
	for _, user := range users {
		if user.ServerID == endNode.Name || !user.Synced {
			usersToSync = append(usersToSync, user)
		}
	}

	// Send sync request to end-node
	for _, user := range usersToSync {
		if err := mm.syncUserToEndNode(endNode, user); err != nil {
			log.Printf("Failed to sync user %s to end-node %s: %v", user.Username, endNode.Name, err)
		}
	}

	return nil
}

// createOVPNOnEndNode creates an OVPN file on a specific end-node
func (mm *ManagementManager) createOVPNOnEndNode(endNode shared.Server, user shared.User) error {
	// Use placeholder certificates - end-nodes will generate real certificates
	certData := struct {
		CA   string
		Cert string
		Key  string
		TA   string
	}{
		CA:   "-----BEGIN CERTIFICATE-----\n[CA Certificate Content]\n-----END CERTIFICATE-----",
		Cert: "-----BEGIN CERTIFICATE-----\n[Client Certificate Content]\n-----END CERTIFICATE-----",
		Key:  "-----BEGIN PRIVATE KEY-----\n[Client Private Key Content]\n-----END PRIVATE KEY-----",
		TA:   "-----BEGIN OpenVPN Static key V1-----\n[TLS Auth Key Content]\n-----END OpenVPN Static key V1-----",
	}

	// Prepare request data
	requestData := map[string]interface{}{
		"username":   user.Username,
		"port":       user.Port,
		"protocol":   user.Protocol,
		"server_id":  endNode.Name,
		"server_ip":  endNode.Host,
		"cert_data": certData,
	}

	jsonData, err := json.Marshal(requestData)
	if err != nil {
		return fmt.Errorf("failed to marshal request data: %v", err)
	}

	url := fmt.Sprintf("http://%s:%d/api/ovpn/create", endNode.Host, endNode.Port)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := mm.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to create OVPN on end-node: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("OVPN creation on end-node failed with status: %d", resp.StatusCode)
	}

	log.Printf("✅ OVPN file created successfully for user %s on end-node %s", user.Username, endNode.Name)
	return nil
}


// syncUserToEndNode syncs a single user to an end-node
func (mm *ManagementManager) syncUserToEndNode(endNode shared.Server, user shared.User) error {
	// Only sync to the target end-node
	if user.ServerID != endNode.Name {
		return nil // Skip if user doesn't belong to this end-node
	}

	userData := map[string]interface{}{
		"username":   user.Username,
		"ovpn_path":  fmt.Sprintf("/var/lib/vpnmanager/clients/%s.ovpn", user.Username),
		"checksum":   user.Checksum,
		"port":       user.Port,
		"protocol":   user.Protocol,
		"server_id":  user.ServerID,
		"created_by": user.CreatedBy,
	}

	jsonData, err := json.Marshal(userData)
	if err != nil {
		return fmt.Errorf("failed to marshal user data: %v", err)
	}

	url := fmt.Sprintf("http://%s:%d/api/users", endNode.Host, endNode.Port)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := mm.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to create user on end-node: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("user creation on end-node failed with status: %d", resp.StatusCode)
	}

	log.Printf("✅ User %s created successfully on end-node %s", user.Username, endNode.Name)
	return nil
}

// CreateUser creates a new user and syncs to all end-nodes
func (mm *ManagementManager) CreateUser(username, ovpnPath, checksum, targetServerID string, port int, protocol string) error {
	// Add user to database
	if err := mm.userManager.AddUser(username, ovpnPath, checksum, targetServerID, "management", port, protocol); err != nil {
		return fmt.Errorf("failed to add user to database: %v", err)
	}

	// Log the action
	mm.auditManager.LogAction(
		"USER_CREATED",
		username,
		fmt.Sprintf("user created via management server for server %s", targetServerID),
		"",
		mm.serverID,
	)

	// Sync to all end-nodes
	if err := mm.syncUserToAllEndNodes(username); err != nil {
		log.Printf("Warning: Failed to sync user %s to all end-nodes: %v", username, err)
	}

	return nil
}

// DeleteUser deletes a user and syncs to all end-nodes
func (mm *ManagementManager) DeleteUser(username string) error {
	// Delete user from database
	if err := mm.userManager.DeleteUser(username); err != nil {
		return fmt.Errorf("failed to delete user from database: %v", err)
	}

	// Log the action
	mm.auditManager.LogAction(
		"USER_DELETED",
		username,
		"user deleted via management server",
		"",
		mm.serverID,
	)

	// Sync deletion to all end-nodes
	if err := mm.syncUserDeletionToAllEndNodes(username); err != nil {
		log.Printf("Warning: Failed to sync user deletion %s to all end-nodes: %v", username, err)
	}

	return nil
}

// ListUsers lists all users
func (mm *ManagementManager) ListUsers() ([]shared.User, error) {
	return mm.userManager.ListUsers()
}

// ListEndNodes lists all end-node servers
func (mm *ManagementManager) ListEndNodes() ([]shared.Server, error) {
	return mm.serverManager.ListEndNodes()
}

// RegisterEndNode registers a new end-node server and syncs existing users
func (mm *ManagementManager) RegisterEndNode(serverID, host, status string, port int) error {
	// Add the end-node to the database
	if err := mm.serverManager.AddServer(serverID, host, port, "", "", "endnode", ""); err != nil {
		return fmt.Errorf("failed to add end-node to database: %v", err)
	}

	// Log the registration
	mm.auditManager.LogAction(
		"ENDNODE_REGISTERED",
		serverID,
		fmt.Sprintf("end-node registered - host=%s port=%d status=%s", host, port, status),
		"",
		mm.serverID,
	)

	// Sync all existing users to the new end-node
	if err := mm.syncAllUsersToNewEndNode(serverID, host, port); err != nil {
		log.Printf("Warning: Failed to sync existing users to new end-node %s: %v", serverID, err)
	}

	return nil
}

// syncAllUsersToNewEndNode syncs all existing users to a newly registered end-node
func (mm *ManagementManager) syncAllUsersToNewEndNode(serverID, host string, port int) error {
	log.Printf("Syncing all existing users to new end-node %s (%s:%d)", serverID, host, port)
	
	// Get all existing users from the database
	users, err := mm.userManager.ListUsers()
	if err != nil {
		return fmt.Errorf("failed to list existing users: %v", err)
	}
	
	if len(users) == 0 {
		log.Printf("No existing users to sync to new end-node %s", serverID)
		return nil
	}
	
	log.Printf("Found %d existing users to sync to new end-node %s", len(users), serverID)
	
	// Create a temporary end-node object for the new end-node
	newEndNode := shared.Server{
		Name: serverID,
		Host: host,
		Port: port,
	}
	
	// Sync each user to the new end-node
	for _, user := range users {
		if err := mm.createOVPNOnEndNode(newEndNode, user); err != nil {
			log.Printf("Failed to sync user %s to new end-node %s: %v", user.Username, serverID, err)
		} else {
			log.Printf("✅ User %s synced to new end-node %s", user.Username, serverID)
		}
	}
	
	log.Printf("✅ All existing users synced to new end-node %s", serverID)
	return nil
}

// syncUserToAllEndNodes syncs a user to all end-nodes
func (mm *ManagementManager) syncUserToAllEndNodes(username string) error {
	user, err := mm.userManager.GetUser(username)
	if err != nil {
		return fmt.Errorf("failed to get user: %v", err)
	}

	endNodes, err := mm.serverManager.ListEndNodes()
	if err != nil {
		return fmt.Errorf("failed to list end-nodes: %v", err)
	}

	for _, endNode := range endNodes {
		if err := mm.createOVPNOnEndNode(endNode, *user); err != nil {
			log.Printf("Failed to create OVPN for user %s on end-node %s: %v", username, endNode.Name, err)
		}
	}

	return nil
}

// syncUserDeletionToAllEndNodes syncs user deletion to all end-nodes
func (mm *ManagementManager) syncUserDeletionToAllEndNodes(username string) error {
	endNodes, err := mm.serverManager.ListEndNodes()
	if err != nil {
		return fmt.Errorf("failed to list end-nodes: %v", err)
	}

	for _, endNode := range endNodes {
		if err := mm.syncUserDeletionToEndNode(endNode, username); err != nil {
			log.Printf("Failed to sync user deletion %s to end-node %s: %v", username, endNode.Name, err)
		}
	}

	return nil
}

// syncUserDeletionToEndNode syncs user deletion to a specific end-node
func (mm *ManagementManager) syncUserDeletionToEndNode(endNode shared.Server, username string) error {
	url := fmt.Sprintf("http://%s:%d/api/users/%s", endNode.Host, endNode.Port, username)
	req, err := http.NewRequest("DELETE", url, nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := mm.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to delete user on end-node: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("user deletion on end-node failed with status: %d", resp.StatusCode)
	}

	log.Printf("✅ User %s deleted successfully from end-node %s", username, endNode.Name)
	return nil
}

// GetAuditLog retrieves audit log entries
func (mm *ManagementManager) GetAuditLog(limit int) ([]shared.AuditLog, error) {
	return mm.auditManager.ListAuditLog(limit)
}

// GetAuditLogByServer retrieves audit log entries for a specific server
func (mm *ManagementManager) GetAuditLogByServer(serverID string, limit int) ([]shared.AuditLog, error) {
	return mm.auditManager.ListAuditLogByServer(serverID, limit)
}

// GetAuditLogByUser retrieves audit log entries for a specific user
func (mm *ManagementManager) GetAuditLogByUser(username string, limit int) ([]shared.AuditLog, error) {
	return mm.auditManager.ListAuditLogByUser(username, limit)
}

// RemoveEndNode removes an end-node from the system
func (mm *ManagementManager) RemoveEndNode(serverID string) error {
	// Remove the end-node from the database
	if err := mm.serverManager.RemoveServer(serverID); err != nil {
		return fmt.Errorf("failed to remove end-node from database: %v", err)
	}

	// Log the removal
	mm.auditManager.LogAction(
		"ENDNODE_REMOVED",
		serverID,
		fmt.Sprintf("end-node '%s' removed from system", serverID),
		"",
		mm.serverID,
	)

	return nil
}

// GetDB returns the database connection for use by API handlers
func (mm *ManagementManager) GetDB() *shared.DB {
	return mm.userManager.GetDB()
}
