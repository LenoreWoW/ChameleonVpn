package api

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"barqnet-backend/pkg/shared"
)

// handleVPNLocations handles listing all server locations
// GET /vpn/locations
func (api *ManagementAPI) handleVPNLocations(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Validate JWT token
	username, err := api.validateJWTToken(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Get all server locations with metadata
	locations, err := api.getServerLocationsWithMetadata()
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to retrieve locations: %v", err), http.StatusInternalServerError)
		return
	}

	// Log the access
	api.logAudit(
		"VPN_LOCATIONS_ACCESSED",
		username,
		"Server locations list accessed",
		r.RemoteAddr,
	)

	response := shared.APIResponse{
		Success:   true,
		Message:   "Server locations retrieved successfully",
		Data:      locations,
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleLocationServers handles getting servers for a specific location
// GET /vpn/locations/{location_id}/servers
func (api *ManagementAPI) handleLocationServers(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Validate JWT token
	username, err := api.validateJWTToken(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Extract location ID from URL path
	// Expected format: /vpn/locations/{location_id}/servers
	pathParts := strings.Split(strings.TrimPrefix(r.URL.Path, "/vpn/locations/"), "/")
	if len(pathParts) < 1 || pathParts[0] == "" {
		http.Error(w, "Location ID required", http.StatusBadRequest)
		return
	}

	locationIDStr := pathParts[0]
	locationID, err := strconv.Atoi(locationIDStr)
	if err != nil {
		http.Error(w, "Invalid location ID", http.StatusBadRequest)
		return
	}

	// Get servers for the location
	servers, err := api.getServersForLocation(locationID)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to retrieve servers: %v", err), http.StatusInternalServerError)
		return
	}

	// Log the access
	api.logAudit(
		"VPN_LOCATION_SERVERS_ACCESSED",
		username,
		fmt.Sprintf("Servers for location %d accessed", locationID),
		r.RemoteAddr,
	)

	response := shared.APIResponse{
		Success:   true,
		Message:   fmt.Sprintf("Servers for location %d retrieved successfully", locationID),
		Data:      servers,
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// getServerLocationsWithMetadata retrieves all server locations with metadata
func (api *ManagementAPI) getServerLocationsWithMetadata() ([]shared.ServerLocationWithMetadata, error) {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	// Get all enabled locations
	query := `
		SELECT id, country, city, country_code, latitude, longitude, enabled
		FROM server_locations
		WHERE enabled = true
		ORDER BY country, city
	`

	rows, err := conn.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var locations []shared.ServerLocationWithMetadata
	for rows.Next() {
		var loc shared.ServerLocationWithMetadata
		var lat, lon sql.NullFloat64

		err := rows.Scan(
			&loc.ID,
			&loc.Country,
			&loc.City,
			&loc.CountryCode,
			&lat,
			&lon,
			&loc.Enabled,
		)

		if err != nil {
			return nil, err
		}

		if lat.Valid {
			loc.Latitude = lat.Float64
		}
		if lon.Valid {
			loc.Longitude = lon.Float64
		}

		// Get metadata for this location
		if err := api.enrichLocationMetadata(&loc); err != nil {
			// Log error but continue
			fmt.Printf("Failed to enrich metadata for location %d: %v\n", loc.ID, err)
		}

		locations = append(locations, loc)
	}

	// If no locations exist, return sample locations
	if len(locations) == 0 {
		locations = api.generateSampleLocations()
	}

	return locations, rows.Err()
}

// enrichLocationMetadata adds server count, load, and latency information to a location
func (api *ManagementAPI) enrichLocationMetadata(loc *shared.ServerLocationWithMetadata) error {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	// Get server count and average load for this location
	query := `
		SELECT COUNT(*) as server_count
		FROM servers
		WHERE location_id = $1 AND enabled = true
	`

	err := conn.QueryRow(query, loc.ID).Scan(&loc.ServerCount)
	if err != nil {
		return err
	}

	// Calculate average load (simplified - based on user count)
	loadQuery := `
		SELECT COUNT(DISTINCT u.username) as user_count
		FROM users u
		JOIN servers s ON u.server_id = s.name
		WHERE s.location_id = $1 AND u.active = true
	`

	var userCount int
	if err := conn.QueryRow(loadQuery, loc.ID).Scan(&userCount); err == nil {
		// Assume max 100 users per location as capacity
		loc.LoadPercentage = float64(userCount) / float64(100) * 100
		if loc.LoadPercentage > 100 {
			loc.LoadPercentage = 100
		}
	}

	// Estimate latency based on geographic distance (simplified)
	// In production, this should use actual ping measurements
	loc.EstimatedLatency = api.estimateLatency(loc.Latitude, loc.Longitude)

	return nil
}

// getServersForLocation retrieves all servers for a specific location with health status
func (api *ManagementAPI) getServersForLocation(locationID int) ([]shared.ServerWithHealth, error) {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	// Get servers for the location
	query := `
		SELECT s.id, s.name, s.host, s.port, s.username, s.password, s.enabled,
		       s.last_sync, s.server_type, s.management_url, s.created_at
		FROM servers s
		WHERE s.location_id = $1 AND s.enabled = true
		ORDER BY s.name
	`

	rows, err := conn.Query(query, locationID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var servers []shared.ServerWithHealth
	for rows.Next() {
		var srv shared.ServerWithHealth
		var lastSync sql.NullTime
		var username, password, managementURL sql.NullString

		err := rows.Scan(
			&srv.ID,
			&srv.Name,
			&srv.Host,
			&srv.Port,
			&username,
			&password,
			&srv.Enabled,
			&lastSync,
			&srv.ServerType,
			&managementURL,
			&srv.CreatedAt,
		)

		if err != nil {
			return nil, err
		}

		if lastSync.Valid {
			srv.LastSync = lastSync.Time
		}
		if username.Valid {
			srv.Username = username.String
		}
		if password.Valid {
			srv.Password = password.String
		}
		if managementURL.Valid {
			srv.ManagementURL = managementURL.String
		}

		// Get health status for this server
		health, err := api.getServerHealth(srv.Name)
		if err == nil {
			srv.Health = *health
		} else {
			// Default health if not available
			srv.Health = shared.ServerHealth{
				ServerID:     srv.Name,
				Status:       "unknown",
				LastCheck:    time.Now(),
				ResponseTime: 0,
				ErrorMessage: "No health data available",
			}
		}

		// Get user count for this server
		userCount, err := api.getServerUserCount(srv.Name)
		if err == nil {
			srv.UserCount = userCount
			// Calculate load percentage (assume max 50 users per server)
			srv.LoadPercent = float64(userCount) / float64(50) * 100
			if srv.LoadPercent > 100 {
				srv.LoadPercent = 100
			}
		}

		servers = append(servers, srv)
	}

	return servers, rows.Err()
}

// getServerHealth retrieves health status for a server
func (api *ManagementAPI) getServerHealth(serverID string) (*shared.ServerHealth, error) {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	query := `
		SELECT id, server_id, status, last_check, response_time_ms, error_message
		FROM server_health
		WHERE server_id = $1
		ORDER BY last_check DESC
		LIMIT 1
	`

	var health shared.ServerHealth
	var errorMsg sql.NullString

	err := conn.QueryRow(query, serverID).Scan(
		&health.ID,
		&health.ServerID,
		&health.Status,
		&health.LastCheck,
		&health.ResponseTime,
		&errorMsg,
	)

	if err != nil {
		return nil, err
	}

	if errorMsg.Valid {
		health.ErrorMessage = errorMsg.String
	}

	return &health, nil
}

// getServerUserCount returns the number of active users on a server
func (api *ManagementAPI) getServerUserCount(serverID string) (int, error) {
	db := api.manager.GetDB()
	conn := db.GetConnection()

	query := `
		SELECT COUNT(*)
		FROM users
		WHERE server_id = $1 AND active = true
	`

	var count int
	err := conn.QueryRow(query, serverID).Scan(&count)
	return count, err
}

// estimateLatency estimates network latency based on geographic coordinates
// This is a simplified estimation - in production, use actual measurements
func (api *ManagementAPI) estimateLatency(latitude, longitude float64) int {
	// Base latency
	baseLatency := 50

	// Add latency based on distance (simplified)
	// In production, calculate actual geographic distance and use real measurements
	// For now, return a range based on latitude to simulate different regions
	if latitude > 50 || latitude < -50 {
		return baseLatency + 100 // Far regions
	} else if latitude > 30 || latitude < -30 {
		return baseLatency + 50 // Medium distance
	}
	return baseLatency // Close regions
}

// generateSampleLocations creates sample locations for demonstration
func (api *ManagementAPI) generateSampleLocations() []shared.ServerLocationWithMetadata {
	return []shared.ServerLocationWithMetadata{
		{
			ServerLocation: shared.ServerLocation{
				ID:          1,
				Country:     "United States",
				City:        "New York",
				CountryCode: "US",
				Latitude:    40.7128,
				Longitude:   -74.0060,
				Enabled:     true,
			},
			ServerCount:      3,
			LoadPercentage:   45.5,
			EstimatedLatency: 25,
		},
		{
			ServerLocation: shared.ServerLocation{
				ID:          2,
				Country:     "United Kingdom",
				City:        "London",
				CountryCode: "GB",
				Latitude:    51.5074,
				Longitude:   -0.1278,
				Enabled:     true,
			},
			ServerCount:      2,
			LoadPercentage:   62.3,
			EstimatedLatency: 85,
		},
		{
			ServerLocation: shared.ServerLocation{
				ID:          3,
				Country:     "Singapore",
				City:        "Singapore",
				CountryCode: "SG",
				Latitude:    1.3521,
				Longitude:   103.8198,
				Enabled:     true,
			},
			ServerCount:      2,
			LoadPercentage:   38.7,
			EstimatedLatency: 180,
		},
		{
			ServerLocation: shared.ServerLocation{
				ID:          4,
				Country:     "Germany",
				City:        "Frankfurt",
				CountryCode: "DE",
				Latitude:    50.1109,
				Longitude:   8.6821,
				Enabled:     true,
			},
			ServerCount:      4,
			LoadPercentage:   55.2,
			EstimatedLatency: 95,
		},
	}
}
