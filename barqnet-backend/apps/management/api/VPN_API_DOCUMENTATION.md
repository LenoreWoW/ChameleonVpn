# VPN Statistics and Locations API Documentation

This documentation covers the VPN statistics tracking and server locations API endpoints for the backend management server.

## Authentication

All endpoints require JWT authentication via the `Authorization` header:

```
Authorization: Bearer <jwt_token>
```

For testing purposes, include `?username={username}` in the query string.

## Endpoints Overview

### VPN Statistics & Status
- `POST /vpn/status` - Update VPN connection status
- `POST /vpn/stats` - Upload usage statistics
- `GET /vpn/stats/{username}` - Get user statistics

### Server Locations
- `GET /vpn/locations` - List all server locations
- `GET /vpn/locations/{location_id}/servers` - Get servers in specific location

### VPN Configuration
- `GET /vpn/config?username={username}` - Get VPN configuration with auto server selection

---

## VPN Statistics Endpoints

### POST /vpn/status

Update VPN connection status (connected, disconnected, connecting, error).

**Request Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "status": "connected",
  "server_id": "server-us-east-1",
  "ip_address": "192.168.1.100"
}
```

**Fields:**
- `status` (required): One of `connected`, `disconnected`, `connecting`, `error`
- `server_id` (required): The VPN server identifier
- `ip_address` (optional): Client IP address

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Connection status updated to connected",
  "timestamp": 1698765432
}
```

**Error Responses:**
- `401 Unauthorized` - Invalid or missing JWT token
- `400 Bad Request` - Invalid status value
- `500 Internal Server Error` - Database error

---

### POST /vpn/stats

Upload VPN usage statistics (data transfer and connection duration).

**Request Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "server_id": "server-us-east-1",
  "bytes_in": 1048576,
  "bytes_out": 524288,
  "duration_seconds": 3600
}
```

**Fields:**
- `server_id` (required): The VPN server identifier
- `bytes_in` (required): Bytes received (incoming traffic)
- `bytes_out` (required): Bytes sent (outgoing traffic)
- `duration_seconds` (required): Connection duration in seconds

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Statistics uploaded successfully",
  "timestamp": 1698765432
}
```

**Error Responses:**
- `401 Unauthorized` - Invalid or missing JWT token
- `400 Bad Request` - Invalid statistics values (negative numbers)
- `500 Internal Server Error` - Database error

---

### GET /vpn/stats/{username}

Retrieve aggregated statistics and connection history for a user.

**Request Headers:**
```
Authorization: Bearer <jwt_token>
```

**URL Parameters:**
- `username` (required): Username to retrieve statistics for

**Authorization:**
- Users can only access their own statistics
- Admin users can access any user's statistics

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Statistics retrieved successfully",
  "data": {
    "summary": {
      "username": "john_doe",
      "total_bytes_in": 10485760,
      "total_bytes_out": 5242880,
      "total_duration_seconds": 7200,
      "connection_count": 5,
      "last_connection": "2023-10-31T14:30:00Z"
    },
    "connections": [
      {
        "id": 1,
        "username": "john_doe",
        "status": "connected",
        "server_id": "server-us-east-1",
        "connected_at": "2023-10-31T14:30:00Z",
        "ip_address": "192.168.1.100",
        "created_at": "2023-10-31T14:30:00Z"
      },
      {
        "id": 2,
        "username": "john_doe",
        "status": "disconnected",
        "server_id": "server-us-east-1",
        "disconnected_at": "2023-10-31T13:00:00Z",
        "ip_address": "192.168.1.100",
        "created_at": "2023-10-31T13:00:00Z"
      }
    ]
  },
  "timestamp": 1698765432
}
```

**Error Responses:**
- `401 Unauthorized` - Invalid or missing JWT token
- `403 Forbidden` - User attempting to access another user's statistics
- `404 Not Found` - User not found
- `500 Internal Server Error` - Database error

---

## Server Locations Endpoints

### GET /vpn/locations

List all available VPN server locations with metadata including server count, load percentage, and estimated latency.

**Request Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Server locations retrieved successfully",
  "data": [
    {
      "id": 1,
      "country": "United States",
      "city": "New York",
      "country_code": "US",
      "latitude": 40.7128,
      "longitude": -74.0060,
      "enabled": true,
      "server_count": 3,
      "load_percentage": 45.5,
      "estimated_latency_ms": 25
    },
    {
      "id": 2,
      "country": "United Kingdom",
      "city": "London",
      "country_code": "GB",
      "latitude": 51.5074,
      "longitude": -0.1278,
      "enabled": true,
      "server_count": 2,
      "load_percentage": 62.3,
      "estimated_latency_ms": 85
    }
  ],
  "timestamp": 1698765432
}
```

**Response Fields:**
- `id`: Location identifier
- `country`: Country name
- `city`: City name
- `country_code`: ISO country code
- `latitude`: Geographic latitude
- `longitude`: Geographic longitude
- `enabled`: Whether location is active
- `server_count`: Number of servers in this location
- `load_percentage`: Current load (0-100)
- `estimated_latency_ms`: Estimated latency in milliseconds

**Error Responses:**
- `401 Unauthorized` - Invalid or missing JWT token
- `500 Internal Server Error` - Database error

---

### GET /vpn/locations/{location_id}/servers

Get detailed information about all servers in a specific location, including health status and current load.

**Request Headers:**
```
Authorization: Bearer <jwt_token>
```

**URL Parameters:**
- `location_id` (required): Location identifier

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Servers for location 1 retrieved successfully",
  "data": [
    {
      "id": 1,
      "name": "server-us-ny-1",
      "host": "192.168.10.100",
      "port": 8080,
      "enabled": true,
      "last_sync": "2023-10-31T14:00:00Z",
      "server_type": "endnode",
      "created_at": "2023-10-01T10:00:00Z",
      "health": {
        "id": 1,
        "server_id": "server-us-ny-1",
        "status": "healthy",
        "last_check": "2023-10-31T14:30:00Z",
        "response_time_ms": 45,
        "error_message": ""
      },
      "load_percent": 35.5,
      "user_count": 15
    }
  ],
  "timestamp": 1698765432
}
```

**Response Fields:**
- `health.status`: Server health status (`healthy`, `unhealthy`, `unknown`)
- `health.response_time_ms`: Last health check response time
- `load_percent`: Current server load (0-100)
- `user_count`: Number of active users on this server

**Error Responses:**
- `401 Unauthorized` - Invalid or missing JWT token
- `400 Bad Request` - Invalid location ID
- `500 Internal Server Error` - Database error

---

## VPN Configuration Endpoint

### GET /vpn/config?username={username}

Get VPN configuration with automatic best server selection based on current load.

**Request Headers:**
```
Authorization: Bearer <jwt_token>
```

**Query Parameters:**
- `username` (optional): Username to get configuration for (defaults to authenticated user)

**Authorization:**
- Users can only get their own configuration unless they're admin

**Response (200 OK):**
```json
{
  "success": true,
  "message": "VPN configuration retrieved successfully",
  "data": {
    "username": "john_doe",
    "server_id": "server-us-east-1",
    "server_host": "192.168.10.100",
    "server_port": 1194,
    "protocol": "udp",
    "ovpn_content": "client\ndev tun\nproto udp\nremote 192.168.10.100 1194\n...",
    "recommended_servers": [
      "server-us-west-1",
      "server-eu-london-1",
      "server-asia-singapore-1"
    ]
  },
  "timestamp": 1698765432
}
```

**Server Selection Logic:**
1. Attempts to use the user's preferred server if load < 80%
2. If preferred server is overloaded, selects the server with the lowest current load
3. Only considers enabled servers of type "endnode"

**Response Fields:**
- `username`: VPN username
- `server_id`: Selected server identifier
- `server_host`: Server IP/hostname
- `server_port`: Server port number
- `protocol`: VPN protocol (udp/tcp)
- `ovpn_content`: Complete OpenVPN configuration file content
- `recommended_servers`: List of alternative server IDs with low load

**Error Responses:**
- `401 Unauthorized` - Invalid or missing JWT token
- `403 Forbidden` - User attempting to access another user's configuration or account inactive
- `404 Not Found` - User not found
- `500 Internal Server Error` - Database error or no servers available

---

## Database Schema

### vpn_connections Table
Stores VPN connection status history.

```sql
CREATE TABLE vpn_connections (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    server_id VARCHAR(255) NOT NULL,
    connected_at TIMESTAMP,
    disconnected_at TIMESTAMP,
    ip_address INET,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Indexes:**
- `idx_vpn_connections_username` on username
- `idx_vpn_connections_status` on status
- `idx_vpn_connections_created_at` on created_at

### vpn_statistics Table
Stores VPN usage statistics.

```sql
CREATE TABLE vpn_statistics (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL,
    server_id VARCHAR(255) NOT NULL,
    bytes_in BIGINT DEFAULT 0,
    bytes_out BIGINT DEFAULT 0,
    duration_seconds INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Indexes:**
- `idx_vpn_statistics_username` on username
- `idx_vpn_statistics_server_id` on server_id
- `idx_vpn_statistics_created_at` on created_at

### server_locations Table
Stores VPN server geographic locations.

```sql
CREATE TABLE server_locations (
    id SERIAL PRIMARY KEY,
    country VARCHAR(255) NOT NULL,
    city VARCHAR(255) NOT NULL,
    country_code VARCHAR(10) NOT NULL,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    enabled BOOLEAN DEFAULT true
);
```

**Indexes:**
- `idx_server_locations_enabled` on enabled

**Note:** The `servers` table has been extended with a `location_id` column that references `server_locations(id)`.

---

## Audit Logging

All API endpoints automatically log actions to the audit system:

- `VPN_STATUS_UPDATE` - Connection status changes
- `VPN_STATS_UPLOADED` - Statistics uploaded
- `VPN_STATS_ACCESSED` - Statistics retrieved
- `VPN_LOCATIONS_ACCESSED` - Locations list accessed
- `VPN_LOCATION_SERVERS_ACCESSED` - Location servers accessed
- `VPN_CONFIG_ACCESSED` - Configuration retrieved

Audit logs include:
- Action type
- Username
- Details (varies by action)
- IP address
- Timestamp
- Server ID

---

## Security Features

### JWT Authentication
- All endpoints require valid JWT token
- Token passed via `Authorization: Bearer <token>` header
- Token validation extracts username for authorization

### Authorization
- Users can only access their own data
- Admin users have unrestricted access
- Checked via `isAdmin()` function

### Input Validation
- All inputs validated before processing
- Status values restricted to whitelist
- Numeric values checked for negative numbers
- Username validation prevents injection attacks

### Rate Limiting
- Implemented via middleware
- Prevents abuse and DoS attacks

### Audit Trail
- All actions logged to database
- Includes IP address and timestamp
- Queryable via `/api/logs` endpoint

---

## Error Handling

All endpoints return consistent error responses:

```json
{
  "error": "Error message description"
}
```

HTTP Status Codes:
- `200 OK` - Successful request
- `400 Bad Request` - Invalid input
- `401 Unauthorized` - Missing or invalid authentication
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Resource not found
- `405 Method Not Allowed` - Wrong HTTP method
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - Server error

---

## Example Usage

### Update Connection Status
```bash
curl -X POST http://localhost:8080/vpn/status \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "connected",
    "server_id": "server-us-east-1",
    "ip_address": "192.168.1.100"
  }'
```

### Upload Statistics
```bash
curl -X POST http://localhost:8080/vpn/stats \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "server_id": "server-us-east-1",
    "bytes_in": 1048576,
    "bytes_out": 524288,
    "duration_seconds": 3600
  }'
```

### Get User Statistics
```bash
curl -X GET "http://localhost:8080/vpn/stats/john_doe?username=john_doe" \
  -H "Authorization: Bearer <jwt_token>"
```

### List Server Locations
```bash
curl -X GET "http://localhost:8080/vpn/locations?username=john_doe" \
  -H "Authorization: Bearer <jwt_token>"
```

### Get Servers in Location
```bash
curl -X GET "http://localhost:8080/vpn/locations/1/servers?username=john_doe" \
  -H "Authorization: Bearer <jwt_token>"
```

### Get VPN Configuration
```bash
curl -X GET "http://localhost:8080/vpn/config?username=john_doe" \
  -H "Authorization: Bearer <jwt_token>"
```

---

## Implementation Notes

### JWT Token Placeholder
The current implementation includes a placeholder JWT validation function. In production:
1. Implement actual JWT signature verification
2. Extract claims from token (username, roles, expiration)
3. Verify token hasn't expired
4. Consider using a JWT library like `github.com/golang-jwt/jwt/v5`

### Admin Check
The `isAdmin()` function currently uses a hardcoded list. In production:
1. Store admin roles in database
2. Check user roles from JWT claims
3. Implement role-based access control (RBAC)

### Server Load Calculation
Current implementation uses simplified load calculation:
- Assumes max 50 users per server
- Assumes max 100 users per location
- In production, use actual server capacity metrics

### Latency Estimation
Current implementation uses simplified distance-based estimation:
- In production, use actual ping measurements
- Store latency measurements in database
- Update via periodic health checks

---

## Integration with Existing System

The new endpoints integrate seamlessly with the existing VPN management system:

1. **User Management**: Uses existing `users` table and authentication
2. **Server Management**: Extends `servers` table with location references
3. **Audit Logging**: Uses existing audit system via `logAudit()` function
4. **Health Checks**: Leverages existing `server_health` table
5. **Middleware**: Uses existing security middleware for all endpoints

---

## Future Enhancements

Potential improvements for future versions:

1. **Real-time Statistics**: WebSocket endpoint for live stats updates
2. **Bandwidth Throttling**: Per-user bandwidth limits
3. **Geographic Routing**: Auto-select based on client location
4. **Analytics Dashboard**: Aggregate statistics visualization
5. **Alerts**: Notifications for connection issues or quota limits
6. **Multi-hop VPN**: Support for cascading VPN connections
7. **Performance Metrics**: Detailed latency and throughput measurements
