# VPN Manager API Documentation

Complete API reference for the VPN Manager distributed VPN management system.

## 📋 Table of Contents

- [Authentication](#authentication)
- [Management Server API](#management-server-api)
- [End-Node Server API](#end-node-server-api)
- [Error Handling](#error-handling)
- [Rate Limiting](#rate-limiting)
- [Examples](#examples)

## 🔐 Authentication

All API endpoints require authentication via API key in the request header:

```http
X-API-Key: your-secure-api-key
```

### Authentication Headers
```http
Content-Type: application/json
X-API-Key: your-secure-api-key
```

## 🏢 Management Server API

Base URL: `http://management-server:8080`

### Health Check

#### GET /health
Check the health status of the management server.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": 1699123456,
  "version": "1.0.0",
  "server_id": "management-server"
}
```

### API Information

#### GET /api
Get API information and available endpoints.

**Response:**
```json
{
  "service": "VPN Manager Management Server",
  "version": "1.0.0",
  "status": "running",
  "endpoints": {
    "health": "/health",
    "users": "/api/users",
    "endnodes": "/api/endnodes",
    "endnode_register": "/api/endnodes/register",
    "endnode_delete": "/api/endnodes/delete/",
    "user_sync": "/api/users/sync",
    "logs": "/api/logs",
    "ovpn_download": "/api/ovpn/{username}/{server_id}"
  }
}
```

### User Management

#### GET /api/users
List all users in the system.

**Headers:**
```http
X-API-Key: your-secure-api-key
```

**Response:**
```json
{
  "success": true,
  "message": "Users retrieved successfully",
  "data": [
    {
      "id": 1,
      "username": "john_doe",
      "created_at": "2025-10-25T10:00:00Z",
      "expires_at": null,
      "active": true,
      "ovpn_path": "/opt/vpnmanager/clients/john_doe.ovpn",
      "port": 1194,
      "protocol": "udp",
      "last_access": null,
      "checksum": "abc123def456",
      "synced": true,
      "server_id": "endnode-1",
      "created_by": "admin"
    }
  ],
  "timestamp": 1699123456
}
```

#### POST /api/users
Create a new user.

**Headers:**
```http
Content-Type: application/json
X-API-Key: your-secure-api-key
```

**Request Body:**
```json
{
  "username": "jane_doe",
  "port": 1194,
  "protocol": "udp",
  "target_server_id": "endnode-1"
}
```

**Response:**
```json
{
  "success": true,
  "message": "User created successfully",
  "data": {
    "id": 2,
    "username": "jane_doe",
    "created_at": "2025-10-25T10:30:00Z",
    "active": true,
    "server_id": "endnode-1",
    "port": 1194,
    "protocol": "udp"
  },
  "timestamp": 1699123456
}
```

#### GET /api/users/{username}
Get a specific user by username.

**Headers:**
```http
X-API-Key: your-secure-api-key
```

**Response:**
```json
{
  "success": true,
  "message": "User retrieved successfully",
  "data": {
    "id": 1,
    "username": "john_doe",
    "created_at": "2025-10-25T10:00:00Z",
    "active": true,
    "server_id": "endnode-1",
    "port": 1194,
    "protocol": "udp"
  },
  "timestamp": 1699123456
}
```

#### DELETE /api/users/{username}
Delete a user and remove from all end-nodes.

**Headers:**
```http
X-API-Key: your-secure-api-key
```

**Response:**
```json
{
  "success": true,
  "message": "User deleted successfully",
  "timestamp": 1699123456
}
```

### End-Node Management

#### GET /api/endnodes
List all registered end-nodes.

**Headers:**
```http
X-API-Key: your-secure-api-key
```

**Response:**
```json
{
  "success": true,
  "message": "End-nodes retrieved successfully",
  "data": [
    {
      "id": 1,
      "name": "endnode-1",
      "host": "192.168.1.100",
      "port": 8080,
      "enabled": true,
      "last_sync": "2025-10-25T10:25:00Z",
      "server_type": "endnode",
      "created_at": "2025-10-25T09:00:00Z"
    }
  ],
  "timestamp": 1699123456
}
```

#### POST /api/endnodes/register
Register a new end-node.

**Headers:**
```http
Content-Type: application/json
X-API-Key: your-secure-api-key
```

**Request Body:**
```json
{
  "name": "endnode-2",
  "host": "192.168.1.101",
  "port": 8080,
  "username": "vpnmanager",
  "password": "secure-password"
}
```

**Response:**
```json
{
  "success": true,
  "message": "End-node registered successfully",
  "data": {
    "id": 2,
    "name": "endnode-2",
    "host": "192.168.1.101",
    "port": 8080,
    "enabled": true,
    "created_at": "2025-10-25T10:30:00Z"
  },
  "timestamp": 1699123456
}
```

#### DELETE /api/endnodes/{server_id}
Delete an end-node.

**Headers:**
```http
X-API-Key: your-secure-api-key
```

**Response:**
```json
{
  "success": true,
  "message": "End-node deleted successfully",
  "timestamp": 1699123456
}
```

### User Synchronization

#### POST /api/users/sync
Synchronize users with all end-nodes.

**Headers:**
```http
X-API-Key: your-secure-api-key
```

**Response:**
```json
{
  "success": true,
  "message": "User sync completed. 2 users × 2 end-nodes = 4 sync operations.",
  "results": [
    "✅ john_doe → endnode-1 (synced)",
    "✅ john_doe → endnode-2 (synced)",
    "✅ jane_doe → endnode-1 (synced)",
    "✅ jane_doe → endnode-2 (synced)"
  ],
  "timestamp": 1699123456
}
```

### OVPN File Management

#### GET /api/ovpn/{username}/{server_id}
Download OVPN configuration file for a user.

**Headers:**
```http
X-API-Key: your-secure-api-key
```

**Response:**
```
# OpenVPN Configuration for john_doe on endnode-1
# Generated by VPN Manager End-Node
# Server: endnode-1 (192.168.1.100:1194)
# User: john_doe
# Port: 1194
# Protocol: udp

client
dev tun
proto udp
remote 192.168.1.100 1194
nobind
cipher AES-256-CBC
verb 3

tls-client
remote-cert-tls server

tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384:TLS-ECDHE-RSA-WITH-AES-256-CBC-SHA

keepalive 10 60

<ca>
-----BEGIN CERTIFICATE-----
[CA Certificate Content]
-----END CERTIFICATE-----
</ca>

<cert>
-----BEGIN CERTIFICATE-----
[Client Certificate Content]
-----END CERTIFICATE-----
</cert>

<key>
-----BEGIN PRIVATE KEY-----
[Client Private Key Content]
-----END PRIVATE KEY-----
</key>

<tls-crypt>
-----BEGIN OpenVPN Static key V1-----
[TLS Auth Key Content]
-----END OpenVPN Static key V1-----
</tls-crypt>
```

### Logs

#### GET /api/logs
Get system logs.

**Headers:**
```http
X-API-Key: your-secure-api-key
```

**Query Parameters:**
- `source` (optional): Log source (management, endnode, all)
- `level` (optional): Log level (info, warn, error)
- `limit` (optional): Number of log entries (default: 100)

**Response:**
```json
{
  "success": true,
  "message": "Logs retrieved successfully",
  "data": [
    {
      "timestamp": "2025-10-25T10:30:00Z",
      "level": "info",
      "server": "management-server",
      "user": "admin",
      "action": "user_created",
      "message": "User john_doe created successfully"
    }
  ],
  "timestamp": 1699123456
}
```

## 🖥️ End-Node Server API

Base URL: `http://endnode-server:8080`

### Health Check

#### GET /health
Check the health status of the end-node server.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": 1699123456,
  "version": "1.0.0",
  "server_id": "endnode-1"
}
```

### OVPN File Management

#### POST /api/ovpn/create
Create an OVPN file for a user.

**Headers:**
```http
Content-Type: application/json
X-API-Key: your-secure-api-key
```

**Request Body:**
```json
{
  "username": "john_doe",
  "port": 1194,
  "protocol": "udp",
  "server_id": "endnode-1",
  "server_ip": "192.168.1.100",
  "cert_data": {
    "ca": "-----BEGIN CERTIFICATE-----\n[CA Certificate]\n-----END CERTIFICATE-----",
    "cert": "-----BEGIN CERTIFICATE-----\n[Client Certificate]\n-----END CERTIFICATE-----",
    "key": "-----BEGIN PRIVATE KEY-----\n[Client Private Key]\n-----END PRIVATE KEY-----",
    "ta": "-----BEGIN OpenVPN Static key V1-----\n[TLS Auth Key]\n-----END OpenVPN Static key V1-----"
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "OVPN file created for user john_doe",
  "timestamp": 1699123456
}
```

#### GET /api/ovpn/{username}
Download OVPN file for a user.

**Headers:**
```http
X-API-Key: your-secure-api-key
```

**Response:**
```
# OpenVPN Configuration for john_doe on endnode-1
# Generated by VPN Manager End-Node
# Server: endnode-1 (192.168.1.100:1194)
# User: john_doe
# Port: 1194
# Protocol: udp

client
dev tun
proto udp
remote 192.168.1.100 1194
nobind
cipher AES-256-CBC
verb 3

tls-client
remote-cert-tls server

tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384:TLS-ECDHE-RSA-WITH-AES-256-CBC-SHA

keepalive 10 60

<ca>
-----BEGIN CERTIFICATE-----
[CA Certificate Content]
-----END CERTIFICATE-----
</ca>

<cert>
-----BEGIN CERTIFICATE-----
[Client Certificate Content]
-----END CERTIFICATE-----
</cert>

<key>
-----BEGIN PRIVATE KEY-----
[Client Private Key Content]
-----END PRIVATE KEY-----
</key>

<tls-crypt>
-----BEGIN OpenVPN Static key V1-----
[TLS Auth Key Content]
-----END OpenVPN Static key V1-----
</tls-crypt>
```

#### DELETE /api/ovpn/delete/{username}
Delete OVPN file and revoke certificate for a user.

**Headers:**
```http
X-API-Key: your-secure-api-key
```

**Response:**
```json
{
  "success": true,
  "message": "OVPN file deleted and certificate revoked for user john_doe",
  "timestamp": 1699123456
}
```

### User Synchronization

#### POST /api/sync/users
Receive user synchronization from management server.

**Headers:**
```http
Content-Type: application/json
X-API-Key: your-secure-api-key
```

**Request Body:**
```json
{
  "users": [
    {
      "username": "john_doe",
      "port": 1194,
      "protocol": "udp",
      "server_id": "endnode-1",
      "server_ip": "192.168.1.100"
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Users synchronized successfully",
  "timestamp": 1699123456
}
```

## ❌ Error Handling

### Standard Error Response
```json
{
  "success": false,
  "error": "Error message",
  "timestamp": 1699123456
}
```

### HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 405 | Method Not Allowed |
| 500 | Internal Server Error |

### Common Error Responses

#### 401 Unauthorized
```json
{
  "success": false,
  "error": "Invalid API key",
  "timestamp": 1699123456
}
```

#### 404 Not Found
```json
{
  "success": false,
  "error": "User not found",
  "timestamp": 1699123456
}
```

#### 500 Internal Server Error
```json
{
  "success": false,
  "error": "Failed to create user: database connection failed",
  "timestamp": 1699123456
}
```

## 🚦 Rate Limiting

### Rate Limits
- **Management Server**: 100 requests per minute per IP
- **End-Node Server**: 50 requests per minute per IP
- **Health Checks**: No rate limiting

### Rate Limit Headers
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1699123500
```

### Rate Limit Exceeded Response
```json
{
  "success": false,
  "error": "Rate limit exceeded. Try again in 60 seconds.",
  "timestamp": 1699123456
}
```

## 📝 Examples

### Complete User Management Workflow

#### 1. Create a User
```bash
curl -X POST http://management-server:8080/api/users \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-secure-api-key" \
  -d '{
    "username": "john_doe",
    "port": 1194,
    "protocol": "udp",
    "target_server_id": "endnode-1"
  }'
```

#### 2. List All Users
```bash
curl -X GET http://management-server:8080/api/users \
  -H "X-API-Key: your-secure-api-key"
```

#### 3. Download OVPN File
```bash
curl -X GET http://management-server:8080/api/ovpn/john_doe/endnode-1 \
  -H "X-API-Key: your-secure-api-key" \
  -o john_doe.ovpn
```

#### 4. Delete User
```bash
curl -X DELETE http://management-server:8080/api/users/john_doe \
  -H "X-API-Key: your-secure-api-key"
```

### End-Node Management

#### 1. Register End-Node
```bash
curl -X POST http://management-server:8080/api/endnodes/register \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-secure-api-key" \
  -d '{
    "name": "endnode-2",
    "host": "192.168.1.101",
    "port": 8080,
    "username": "vpnmanager",
    "password": "secure-password"
  }'
```

#### 2. List End-Nodes
```bash
curl -X GET http://management-server:8080/api/endnodes \
  -H "X-API-Key: your-secure-api-key"
```

#### 3. Sync Users
```bash
curl -X POST http://management-server:8080/api/users/sync \
  -H "X-API-Key: your-secure-api-key"
```

### Health Monitoring

#### 1. Check Management Server Health
```bash
curl -X GET http://management-server:8080/health
```

#### 2. Check End-Node Health
```bash
curl -X GET http://endnode-server:8080/health
```

#### 3. Get System Logs
```bash
curl -X GET "http://management-server:8080/api/logs?source=all&level=info&limit=50" \
  -H "X-API-Key: your-secure-api-key"
```

## 🔧 SDK Examples

### Python SDK Example
```python
import requests

class VPNManagerClient:
    def __init__(self, base_url, api_key):
        self.base_url = base_url
        self.headers = {
            'Content-Type': 'application/json',
            'X-API-Key': api_key
        }
    
    def create_user(self, username, port=1194, protocol='udp', target_server_id=None):
        data = {
            'username': username,
            'port': port,
            'protocol': protocol,
            'target_server_id': target_server_id
        }
        response = requests.post(f"{self.base_url}/api/users", 
                                json=data, headers=self.headers)
        return response.json()
    
    def list_users(self):
        response = requests.get(f"{self.base_url}/api/users", 
                              headers=self.headers)
        return response.json()
    
    def delete_user(self, username):
        response = requests.delete(f"{self.base_url}/api/users/{username}", 
                                  headers=self.headers)
        return response.json()

# Usage
client = VPNManagerClient('http://management-server:8080', 'your-api-key')
client.create_user('john_doe', target_server_id='endnode-1')
```

### JavaScript SDK Example
```javascript
class VPNManagerClient {
    constructor(baseUrl, apiKey) {
        this.baseUrl = baseUrl;
        this.headers = {
            'Content-Type': 'application/json',
            'X-API-Key': apiKey
        };
    }
    
    async createUser(username, port = 1194, protocol = 'udp', targetServerId = null) {
        const response = await fetch(`${this.baseUrl}/api/users`, {
            method: 'POST',
            headers: this.headers,
            body: JSON.stringify({
                username,
                port,
                protocol,
                target_server_id: targetServerId
            })
        });
        return response.json();
    }
    
    async listUsers() {
        const response = await fetch(`${this.baseUrl}/api/users`, {
            headers: this.headers
        });
        return response.json();
    }
    
    async deleteUser(username) {
        const response = await fetch(`${this.baseUrl}/api/users/${username}`, {
            method: 'DELETE',
            headers: this.headers
        });
        return response.json();
    }
}

// Usage
const client = new VPNManagerClient('http://management-server:8080', 'your-api-key');
client.createUser('john_doe', 1194, 'udp', 'endnode-1');
```

## 🔒 Security Considerations

### API Key Security
- Use strong, randomly generated API keys
- Rotate API keys regularly
- Store API keys securely
- Use HTTPS in production

### Input Validation
- All input is validated and sanitized
- SQL injection protection
- XSS protection
- Rate limiting protection

### Network Security
- Use HTTPS in production
- Implement proper firewall rules
- Use VPN for management access
- Monitor API access logs

---

**VPN Manager API** - Complete reference for enterprise VPN management.
