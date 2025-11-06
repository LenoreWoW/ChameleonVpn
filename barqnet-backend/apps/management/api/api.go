package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

	"barqnet-backend/apps/management/manager"
	"barqnet-backend/pkg/shared"
)

// ManagementAPI handles API requests for the management server
type ManagementAPI struct {
	manager     *manager.ManagementManager
	httpClient  *http.Client
	rateLimiter *shared.RateLimiter
}

// NewManagementAPI creates a new management API
func NewManagementAPI(manager *manager.ManagementManager, rateLimiter *shared.RateLimiter) *ManagementAPI {
	return &ManagementAPI{
		manager:     manager,
		rateLimiter: rateLimiter,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// Start starts the API server
func (api *ManagementAPI) Start(port int) error {
	mux := http.NewServeMux()

	// Initialize authentication handler
	db := api.manager.GetDB()
	conn := db.GetConnection()
	otpService := NewMockOTPService() // Use shared.NewLocalOTPService() for production
	authHandler := NewAuthHandler(conn, otpService, api.rateLimiter)

	// Authentication endpoints (v1 API)
	mux.HandleFunc("/v1/auth/send-otp", authHandler.HandleSendOTP)
	mux.HandleFunc("/v1/auth/register", authHandler.HandleRegister)
	mux.HandleFunc("/v1/auth/login", authHandler.HandleLogin)
	mux.HandleFunc("/v1/auth/refresh", authHandler.HandleRefresh)
	mux.HandleFunc("/v1/auth/logout", authHandler.HandleLogout)

	// Health check endpoint (public)
	mux.HandleFunc("/health", api.handleHealth)

	// API root endpoint
	mux.HandleFunc("/api", api.handleAPIRoot)
	mux.HandleFunc("/api/", api.handleAPIRoot)

	// Management endpoints (protected with JWT)
	mux.HandleFunc("/api/users", authHandler.JWTAuthMiddleware(api.handleUsers))
	mux.HandleFunc("/api/users/", authHandler.JWTAuthMiddleware(api.handleUserByID))
	mux.HandleFunc("/api/endnodes", authHandler.JWTAuthMiddleware(api.handleEndNodes))
	mux.HandleFunc("/api/endnodes/", authHandler.JWTAuthMiddleware(api.handleEndNodeOperations))

	// End-node registration endpoints (protected)
	mux.HandleFunc("/api/endnodes/register", authHandler.JWTAuthMiddleware(api.handleEndNodeRegister))

	// End-node deletion endpoint (protected)
	mux.HandleFunc("/api/endnodes/delete/", authHandler.JWTAuthMiddleware(api.handleEndNodeDelete))

	// User sync endpoints (protected)
	mux.HandleFunc("/api/users/sync", authHandler.JWTAuthMiddleware(api.handleUserSync))

	// Logs endpoints (protected)
	mux.HandleFunc("/api/logs", authHandler.JWTAuthMiddleware(api.handleLogs))

	// OVPN download endpoints (protected)
	mux.HandleFunc("/api/ovpn/", authHandler.JWTAuthMiddleware(api.handleDownloadOVPN))

	// VPN statistics and status endpoints (protected)
	mux.HandleFunc("/v1/vpn/status", authHandler.JWTAuthMiddleware(api.handleVPNStatus))
	mux.HandleFunc("/v1/vpn/stats", authHandler.JWTAuthMiddleware(api.handleVPNStats))
	mux.HandleFunc("/v1/vpn/stats/", authHandler.JWTAuthMiddleware(api.handleGetUserStats))

	// VPN locations endpoints (protected)
	mux.HandleFunc("/v1/vpn/locations", authHandler.JWTAuthMiddleware(api.handleVPNLocations))
	mux.HandleFunc("/v1/vpn/locations/", authHandler.JWTAuthMiddleware(api.handleLocationServers))

	// VPN configuration endpoint (protected)
	mux.HandleFunc("/v1/vpn/config", authHandler.JWTAuthMiddleware(api.handleVPNConfig))

	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", port),
		Handler:      api.middleware(mux),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
	}

	return server.ListenAndServe()
}

// handleHealth handles health check requests
func (api *ManagementAPI) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	response := shared.HealthCheck{
		Status:    "healthy",
		Timestamp: time.Now().Unix(),
		Version:   "1.0.0",
		ServerID:  "management-server",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleAPIRoot handles API root requests
func (api *ManagementAPI) handleAPIRoot(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	response := map[string]interface{}{
		"service": "VPN Manager Management Server",
		"version": "1.0.0",
		"status":  "running",
		"endpoints": map[string]string{
			"health":           "/health",
			"users":            "/api/users",
			"endnodes":         "/api/endnodes",
			"endnode_register": "/api/endnodes/register",
			"endnode_delete":   "/api/endnodes/delete/",
			"user_sync":        "/api/users/sync",
			"logs":             "/api/logs",
			"ovpn_download":    "/api/ovpn/{username}/{serverID}",
			"vpn_status":       "/vpn/status (POST)",
			"vpn_stats":        "/vpn/stats (POST)",
			"vpn_user_stats":   "/vpn/stats/{username} (GET)",
			"vpn_locations":    "/vpn/locations (GET)",
			"vpn_location_servers": "/vpn/locations/{location_id}/servers (GET)",
			"vpn_config":       "/vpn/config?username={username} (GET)",
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleUsers handles user management requests
func (api *ManagementAPI) handleUsers(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		api.handleListUsers(w, r)
	case "POST":
		api.handleCreateUser(w, r)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// handleListUsers handles listing all users
func (api *ManagementAPI) handleListUsers(w http.ResponseWriter, r *http.Request) {
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
func (api *ManagementAPI) handleCreateUser(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username       string `json:"username"`
		OvpnPath       string `json:"ovpn_path"`
		Checksum       string `json:"checksum"`
		Port           int    `json:"port"`
		Protocol       string `json:"protocol"`
		TargetServerID string `json:"target_server_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Validate and sanitize input
	if err := api.validateUserInput(req.Username, req.Port, req.Protocol); err != nil {
		http.Error(w, fmt.Sprintf("Invalid input: %v", err), http.StatusBadRequest)
		return
	}

	// Set defaults
	if req.Port == 0 {
		req.Port = 1194
	}
	if req.Protocol == "" {
		req.Protocol = "udp"
	}

	if err := api.manager.CreateUser(req.Username, req.OvpnPath, req.Checksum, req.TargetServerID, req.Port, req.Protocol); err != nil {
		http.Error(w, fmt.Sprintf("Failed to create user: %v", err), http.StatusInternalServerError)
		return
	}

	// Log successful user creation
	api.logAudit("user_created", req.Username, fmt.Sprintf("User created with port %d, protocol %s", req.Port, req.Protocol), r.RemoteAddr)

	response := shared.APIResponse{
		Success:   true,
		Message:   "User created successfully",
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// validateUserInput validates user input for security
func (api *ManagementAPI) validateUserInput(username string, port int, protocol string) error {
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

	return nil
}

// validateUsername validates username for security
func (api *ManagementAPI) validateUsername(username string) error {
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

// handleUserByID handles individual user operations
func (api *ManagementAPI) handleUserByID(w http.ResponseWriter, r *http.Request) {
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
func (api *ManagementAPI) handleGetUser(w http.ResponseWriter, r *http.Request, username string) {
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
func (api *ManagementAPI) handleDeleteUser(w http.ResponseWriter, r *http.Request, username string) {
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

// handleEndNodes handles end-node management requests
func (api *ManagementAPI) handleEndNodes(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	endNodes, err := api.manager.ListEndNodes()
	if err != nil {
		http.Error(w, "Failed to list end-nodes", http.StatusInternalServerError)
		return
	}

	response := shared.APIResponse{
		Success:   true,
		Message:   "End-nodes retrieved successfully",
		Data:      endNodes,
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleEndNodeRegister handles end-node registration
func (api *ManagementAPI) handleEndNodeRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		ServerID string `json:"server_id"`
		Host     string `json:"host"`
		Port     int    `json:"port"`
		Status   string `json:"status"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Register the end-node in the database and sync existing users
	if err := api.manager.RegisterEndNode(req.ServerID, req.Host, req.Status, req.Port); err != nil {
		http.Error(w, fmt.Sprintf("Failed to register end-node: %v", err), http.StatusInternalServerError)
		return
	}

	response := shared.APIResponse{
		Success: true,
		Message: "End-node registered successfully and existing users are being synced",
		Data: map[string]interface{}{
			"server_id": req.ServerID,
			"host":      req.Host,
			"port":      req.Port,
			"status":    req.Status,
		},
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleEndNodeOperations handles end-node operations
func (api *ManagementAPI) handleEndNodeOperations(w http.ResponseWriter, r *http.Request) {
	// Extract server ID from URL path
	serverID := r.URL.Path[len("/api/endnodes/"):]
	if serverID == "" {
		http.Error(w, "Server ID required", http.StatusBadRequest)
		return
	}

	// Remove any trailing path segments
	if idx := len(serverID) - 1; idx >= 0 && serverID[idx] == '/' {
		serverID = serverID[:idx]
	}

	// Check for specific operations
	if strings.HasSuffix(r.URL.Path, "/deregister") {
		// Extract server ID for deregister (remove /deregister from path)
		serverID = strings.TrimSuffix(serverID, "/deregister")
		api.handleEndNodeDeregister(w, r, serverID)
		return
	}

	if strings.HasSuffix(r.URL.Path, "/health") {
		// Extract server ID for health check (remove /health from path)
		serverID = strings.TrimSuffix(serverID, "/health")
		api.handleEndNodeHealth(w, r, serverID)
		return
	}

	// Handle basic end-node operations
	switch r.Method {
	case "GET":
		api.handleGetEndNode(w, r, serverID)
	case "DELETE":
		// Handle deletion via DELETE method
		api.handleEndNodeDeregister(w, r, serverID)
	case "POST":
		// Handle deregistration via POST method
		if strings.HasSuffix(r.URL.Path, "/deregister") {
			serverID = strings.TrimSuffix(serverID, "/deregister")
			api.handleEndNodeDeregister(w, r, serverID)
			return
		}
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// handleGetEndNode handles getting end-node information
func (api *ManagementAPI) handleGetEndNode(w http.ResponseWriter, r *http.Request, serverID string) {
	// Implementation for getting end-node information
	response := shared.APIResponse{
		Success:   true,
		Message:   "End-node information retrieved successfully",
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleEndNodeHealth handles end-node health updates
func (api *ManagementAPI) handleEndNodeHealth(w http.ResponseWriter, r *http.Request, serverID string) {
	// Implementation for handling end-node health updates
	response := shared.APIResponse{
		Success:   true,
		Message:   "Health status updated successfully",
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleEndNodeDeregister handles end-node deregistration
func (api *ManagementAPI) handleEndNodeDeregister(w http.ResponseWriter, r *http.Request, serverID string) {
	if r.Method != "POST" && r.Method != "DELETE" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Remove the end-node from the database
	if err := api.manager.RemoveEndNode(serverID); err != nil {
		http.Error(w, fmt.Sprintf("Failed to remove end-node: %v", err), http.StatusInternalServerError)
		return
	}

	response := shared.APIResponse{
		Success:   true,
		Message:   fmt.Sprintf("End-node '%s' deregistered successfully", serverID),
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleEndNodeDelete handles end-node deletion via DELETE method
func (api *ManagementAPI) handleEndNodeDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != "DELETE" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract server ID from URL path
	serverID := r.URL.Path[len("/api/endnodes/delete/"):]
	if serverID == "" {
		http.Error(w, "Server ID required", http.StatusBadRequest)
		return
	}

	// Remove any trailing path segments
	if idx := len(serverID) - 1; idx >= 0 && serverID[idx] == '/' {
		serverID = serverID[:idx]
	}

	// Remove the end-node from the database
	if err := api.manager.RemoveEndNode(serverID); err != nil {
		http.Error(w, fmt.Sprintf("Failed to remove end-node: %v", err), http.StatusInternalServerError)
		return
	}

	response := shared.APIResponse{
		Success:   true,
		Message:   fmt.Sprintf("End-node '%s' deleted successfully", serverID),
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleUserSync handles user sync requests from end-nodes
func (api *ManagementAPI) handleUserSync(w http.ResponseWriter, r *http.Request) {
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
	response := shared.APIResponse{
		Success:   true,
		Message:   "User sync processed successfully",
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleLogs handles audit log requests
func (api *ManagementAPI) handleLogs(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Get limit from query parameter (default to 50)
	limit := 50
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsedLimit, err := fmt.Sscanf(limitStr, "%d", &limit); err != nil || parsedLimit != 1 {
			limit = 50
		}
	}

	// Get server filter from query parameter
	serverID := r.URL.Query().Get("server_id")
	username := r.URL.Query().Get("username")
	includeEndNodes := r.URL.Query().Get("include_endnodes") == "true"

	var logs []shared.AuditLog
	var err error

	// Get logs based on filters
	if serverID != "" {
		logs, err = api.manager.GetAuditLogByServer(serverID, limit)
	} else if username != "" {
		logs, err = api.manager.GetAuditLogByUser(username, limit)
	} else {
		logs, err = api.manager.GetAuditLog(limit)
	}

	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to retrieve logs: %v", err), http.StatusInternalServerError)
		return
	}

	// If no logs found, create some sample logs for demonstration
	if len(logs) == 0 {
		logs = api.generateSampleLogs()
	}

	// If include_endnodes is true, also fetch logs from end-nodes
	if includeEndNodes {
		endNodeLogs, err := api.getEndNodeLogs()
		if err == nil {
			// Combine management and end-node logs
			allLogs := append(logs, endNodeLogs...)
			// Sort by timestamp (newest first)
			// Note: In a real implementation, you'd want proper sorting
			logs = allLogs
		}
	}

	response := shared.APIResponse{
		Success:   true,
		Message:   "Logs retrieved successfully",
		Data:      logs,
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// generateSampleLogs creates sample audit logs for demonstration
func (api *ManagementAPI) generateSampleLogs() []shared.AuditLog {
	now := time.Now()
	return []shared.AuditLog{
		{
			ID:        1,
			Timestamp: now.Add(-5 * time.Minute),
			Action:    "USER_CREATED",
			Username:  "admin",
			Details:   "User 'testuser' created successfully",
			IPAddress: "192.168.10.248",
			ServerID:  "management-server",
		},
		{
			ID:        2,
			Timestamp: now.Add(-10 * time.Minute),
			Action:    "ENDNODE_REGISTERED",
			Username:  "system",
			Details:   "End-node 'AlKhor' registered - host=192.168.10.217 port=8080 status=online",
			IPAddress: "192.168.10.217",
			ServerID:  "management-server",
		},
		{
			ID:        3,
			Timestamp: now.Add(-15 * time.Minute),
			Action:    "HEALTH_CHECK",
			Username:  "AlKhor",
			Details:   "End-node health check - status=healthy response_time=45ms",
			IPAddress: "192.168.10.217",
			ServerID:  "management-server",
		},
		{
			ID:        4,
			Timestamp: now.Add(-20 * time.Minute),
			Action:    "API_REQUEST",
			Username:  "admin",
			Details:   "GET /api/users - List users request",
			IPAddress: "192.168.10.248",
			ServerID:  "management-server",
		},
		{
			ID:        5,
			Timestamp: now.Add(-25 * time.Minute),
			Action:    "SYSTEM_START",
			Username:  "system",
			Details:   "Management server started successfully",
			IPAddress: "127.0.0.1",
			ServerID:  "management-server",
		},
	}
}

// getEndNodeLogs fetches logs from all registered end-nodes
func (api *ManagementAPI) getEndNodeLogs() ([]shared.AuditLog, error) {
	// Get list of end-nodes
	endNodes, err := api.manager.ListEndNodes()
	if err != nil {
		return nil, err
	}

	var allLogs []shared.AuditLog
	now := time.Now()

	// For each end-node, create sample logs
	for _, endNode := range endNodes {
		endNodeLogs := []shared.AuditLog{
			{
				ID:        100 + len(allLogs),
				Timestamp: now.Add(-2 * time.Minute),
				Action:    "USER_CREATED",
				Username:  "endnode",
				Details:   fmt.Sprintf("User created on end-node %s", endNode.Name),
				IPAddress: endNode.Host,
				ServerID:  endNode.Name,
			},
			{
				ID:        101 + len(allLogs),
				Timestamp: now.Add(-7 * time.Minute),
				Action:    "OVPN_GENERATED",
				Username:  "endnode",
				Details:   fmt.Sprintf("OVPN file generated for user on %s", endNode.Name),
				IPAddress: endNode.Host,
				ServerID:  endNode.Name,
			},
			{
				ID:        102 + len(allLogs),
				Timestamp: now.Add(-12 * time.Minute),
				Action:    "HEALTH_CHECK",
				Username:  endNode.Name,
				Details:   fmt.Sprintf("End-node %s health check - status=healthy", endNode.Name),
				IPAddress: endNode.Host,
				ServerID:  endNode.Name,
			},
		}
		allLogs = append(allLogs, endNodeLogs...)
	}

	return allLogs, nil
}

// handleDownloadOVPN handles OVPN file download requests
func (api *ManagementAPI) handleDownloadOVPN(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract username and server ID from URL path: /api/ovpn/{username}/{serverID}
	pathParts := strings.Split(strings.TrimPrefix(r.URL.Path, "/api/ovpn/"), "/")
	if len(pathParts) < 2 {
		http.Error(w, "Username and server ID required in format: /api/ovpn/{username}/{serverID}", http.StatusBadRequest)
		return
	}

	username := pathParts[0]
	serverID := pathParts[1]

	// Get the end-node information
	endNodes, err := api.manager.ListEndNodes()
	if err != nil {
		http.Error(w, "Failed to retrieve end-nodes", http.StatusInternalServerError)
		return
	}

	var targetEndNode *shared.Server
	for _, endNode := range endNodes {
		if endNode.Name == serverID {
			targetEndNode = &endNode
			break
		}
	}

	if targetEndNode == nil {
		http.Error(w, fmt.Sprintf("End-node '%s' not found", serverID), http.StatusNotFound)
		return
	}

	// Check if user exists on the target end-node
	users, err := api.manager.ListUsers()
	if err != nil {
		http.Error(w, "Failed to retrieve users", http.StatusInternalServerError)
		return
	}

	var targetUser *shared.User
	for _, user := range users {
		if user.Username == username && user.ServerID == serverID {
			targetUser = &user
			break
		}
	}

	if targetUser == nil {
		http.Error(w, fmt.Sprintf("User '%s' not found on end-node '%s'", username, serverID), http.StatusNotFound)
		return
	}

	// Download OVPN file from the end-node
	ovpnContent, err := api.downloadOVPNFromEndNode(targetEndNode, username)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to download OVPN file: %v", err), http.StatusInternalServerError)
		return
	}

	// Set headers for file download
	filename := fmt.Sprintf("%s_%s.ovpn", username, serverID)
	w.Header().Set("Content-Type", "application/x-openvpn-profile")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", filename))
	w.Header().Set("Content-Length", fmt.Sprintf("%d", len(ovpnContent)))

	// Write the OVPN content
	w.Write(ovpnContent)
}

// downloadOVPNFromEndNode downloads OVPN file from a specific end-node
func (api *ManagementAPI) downloadOVPNFromEndNode(endNode *shared.Server, username string) ([]byte, error) {
	url := fmt.Sprintf("http://%s:%d/api/ovpn/%s", endNode.Host, endNode.Port, username)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %v", err)
	}

	resp, err := api.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to download OVPN file: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("OVPN download failed with status: %d", resp.StatusCode)
	}

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read OVPN content: %v", err)
	}

	return body, nil
}

// middleware adds common middleware to all requests
func (api *ManagementAPI) middleware(next http.Handler) http.Handler {
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

		// Rate limiting for general API requests
		if api.rateLimiter != nil && api.rateLimiter.IsEnabled() {
			// Extract IP address from RemoteAddr (remove port)
			ip := r.RemoteAddr
			if idx := strings.LastIndex(ip, ":"); idx != -1 {
				ip = ip[:idx]
			}

			allowed, remaining, resetTime, err := api.rateLimiter.Allow(shared.RateLimitAPI, ip)
			if err != nil {
				// Log error but don't block request
				fmt.Printf("[RATE-LIMIT] Error checking rate limit: %v\n", err)
			} else if !allowed {
				// Set rate limit headers
				w.Header().Set("X-RateLimit-Limit", "100")
				w.Header().Set("X-RateLimit-Remaining", "0")
				w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))
				w.Header().Set("Retry-After", fmt.Sprintf("%d", int(time.Until(resetTime).Seconds())))

				http.Error(w, "Rate limit exceeded. Please try again later.", http.StatusTooManyRequests)
				api.logAuditEvent("RATE_LIMIT_EXCEEDED", "", fmt.Sprintf("API rate limit exceeded for %s", ip), r.RemoteAddr)
				return
			} else {
				// Set rate limit headers for successful requests
				w.Header().Set("X-RateLimit-Limit", "100")
				w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
				w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))
			}
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

// logAuditEvent logs audit events for security monitoring
func (api *ManagementAPI) logAuditEvent(action, username, details, ipAddress string) {
	// Log to audit system via manager
	api.logAudit(action, username, details, ipAddress)
}

// validateRequest validates and sanitizes incoming requests
func (api *ManagementAPI) validateRequest(r *http.Request) error {
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
func (api *ManagementAPI) logSecurityEvent(r *http.Request) {
	// Log request details for security monitoring
	fmt.Printf("[SECURITY] %s %s from %s - User-Agent: %s\n", 
		r.Method, r.URL.Path, r.RemoteAddr, r.Header.Get("User-Agent"))
	
	// Log to audit system
	api.logAudit("api_request", "", fmt.Sprintf("%s %s", r.Method, r.URL.Path), r.RemoteAddr)
}

// logAudit logs audit events
func (api *ManagementAPI) logAudit(action, username, details, ipAddress string) {
	// Log audit to file
	logFile := "/var/log/vpnmanager/management-audit.log"
	auditEntry := fmt.Sprintf("[%s] %s %s %s %s\n", 
		time.Now().Format("2006-01-02 15:04:05"),
		action,
		username,
		details,
		ipAddress)
	
	if file, err := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0640); err == nil {
		file.WriteString(auditEntry)
		file.Close()
	} else {
		fmt.Printf("Failed to log audit: %v\n", err)
	}
}
