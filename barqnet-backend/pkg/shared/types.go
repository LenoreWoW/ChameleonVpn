package shared

import (
	"time"
)

// AuthUser represents an authenticated user in the auth_users table
type AuthUser struct {
	ID              int       `json:"id"`
	Email           string    `json:"email"`
	PasswordHash    string    `json:"-"` // Never expose password hash in JSON
	CreatedAt       time.Time `json:"created_at"`
	LastLogin       time.Time `json:"last_login"`
	Active          bool      `json:"active"`
	MigratedFromPhone bool    `json:"migrated_from_phone,omitempty"`
}

// User represents a VPN user
type User struct {
	ID         int       `json:"id"`
	Username   string    `json:"username"`
	CreatedAt  time.Time `json:"created_at"`
	ExpiresAt  time.Time `json:"expires_at"`
	Active     bool      `json:"active"`
	OvpnPath   string    `json:"ovpn_path"`
	Port       int       `json:"port"`
	Protocol   string    `json:"protocol"`
	LastAccess time.Time `json:"last_access"`
	Checksum   string    `json:"checksum"`
	Synced     bool      `json:"synced"`
	ServerID   string    `json:"server_id"`
	CreatedBy  string    `json:"created_by"`
}

// Server represents a VPN server
type Server struct {
	ID            int       `json:"id"`
	Name          string    `json:"name"`
	Host          string    `json:"host"`
	Port          int       `json:"port"`
	Username      string    `json:"username"`
	Password      string    `json:"password"`
	Enabled       bool      `json:"enabled"`
	LastSync      time.Time `json:"last_sync"`
	ServerType    string    `json:"server_type"`
	ManagementURL string    `json:"management_url"`
	CreatedAt     time.Time `json:"created_at"`
}

// AuditLog represents an audit log entry
type AuditLog struct {
	ID        int       `json:"id"`
	Timestamp time.Time `json:"timestamp"`
	Action    string    `json:"action"`
	Username  string    `json:"username"`
	Details   string    `json:"details"`
	IPAddress string    `json:"ip_address"`
	ServerID  string    `json:"server_id"`
}

// ServerHealth represents server health status
type ServerHealth struct {
	ID           int       `json:"id"`
	ServerID     string    `json:"server_id"`
	Status       string    `json:"status"`
	LastCheck    time.Time `json:"last_check"`
	ResponseTime int       `json:"response_time_ms"`
	ErrorMessage string    `json:"error_message"`
}

// EndNodeConfig represents end-node configuration
type EndNodeConfig struct {
	ServerID      string `json:"server_id"`
	ManagementURL string `json:"management_url"`
	APIKey        string `json:"api_key"`
	Database      DatabaseConfig `json:"database"`
}

// ManagementConfig represents management server configuration
type ManagementConfig struct {
	ServerID string `json:"server_id"`
	Database DatabaseConfig `json:"database"`
	APIKey   string `json:"api_key"`
}

// APIResponse represents a standard API response
type APIResponse struct {
	Success   bool        `json:"success"`
	Message   string      `json:"message"`
	Data      interface{} `json:"data,omitempty"`
	Timestamp int64       `json:"timestamp"`
}

// SyncRequest represents a sync request
type SyncRequest struct {
	Action   string      `json:"action"`
	Username string      `json:"username"`
	Data     interface{} `json:"data"`
	ServerID string      `json:"server_id"`
}

// HealthCheck represents a health check response
type HealthCheck struct {
	Status    string `json:"status"`
	Timestamp int64  `json:"timestamp"`
	Version   string `json:"version"`
	ServerID string `json:"server_id"`
}

// VPNConnectionStatus represents a VPN connection status
type VPNConnectionStatus struct {
	ID           int       `json:"id"`
	Username     string    `json:"username"`
	Status       string    `json:"status"` // connected, disconnected, connecting, error
	ServerID     string    `json:"server_id"`
	ConnectedAt  time.Time `json:"connected_at,omitempty"`
	DisconnectedAt time.Time `json:"disconnected_at,omitempty"`
	IPAddress    string    `json:"ip_address"`
	CreatedAt    time.Time `json:"created_at"`
}

// VPNStatistics represents VPN usage statistics
type VPNStatistics struct {
	ID        int       `json:"id"`
	Username  string    `json:"username"`
	ServerID  string    `json:"server_id"`
	BytesIn   int64     `json:"bytes_in"`
	BytesOut  int64     `json:"bytes_out"`
	Duration  int       `json:"duration_seconds"`
	CreatedAt time.Time `json:"created_at"`
}

// UserStatisticsSummary represents aggregated user statistics
type UserStatisticsSummary struct {
	Username       string    `json:"username"`
	TotalBytesIn   int64     `json:"total_bytes_in"`
	TotalBytesOut  int64     `json:"total_bytes_out"`
	TotalDuration  int       `json:"total_duration_seconds"`
	ConnectionCount int      `json:"connection_count"`
	LastConnection time.Time `json:"last_connection,omitempty"`
}

// ServerLocation represents a VPN server location
type ServerLocation struct {
	ID          int     `json:"id"`
	Country     string  `json:"country"`
	City        string  `json:"city"`
	CountryCode string  `json:"country_code"`
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
	Enabled     bool    `json:"enabled"`
}

// ServerLocationWithMetadata includes location with server info
type ServerLocationWithMetadata struct {
	ServerLocation
	ServerCount      int     `json:"server_count"`
	LoadPercentage   float64 `json:"load_percentage"`
	EstimatedLatency int     `json:"estimated_latency_ms"`
	AvailableServers []ServerWithHealth `json:"available_servers,omitempty"`
}

// ServerWithHealth represents a server with health status
type ServerWithHealth struct {
	Server
	Health       ServerHealth `json:"health"`
	LoadPercent  float64      `json:"load_percent"`
	UserCount    int          `json:"user_count"`
}

// VPNConfigResponse represents VPN configuration response
type VPNConfigResponse struct {
	Username           string `json:"username"`
	ServerID           string `json:"server_id"`
	ServerHost         string `json:"server_host"`
	ServerPort         int    `json:"server_port"`
	Protocol           string `json:"protocol"`
	OVPNContent        string `json:"ovpn_content"`
	RecommendedServers []string `json:"recommended_servers"`
}
