# BarqNet Endnode Server

**VPN Traffic Handling Server - No Direct Database Access**

## Architecture Overview

The Endnode server is a **lightweight, distributed VPN server** that handles VPN connections and traffic routing. It communicates with the **Management Server via API only** and does NOT have direct database access.

```
┌─────────────────────────────────────────────────────────────┐
│                     BarqNet Architecture                     │
└─────────────────────────────────────────────────────────────┘

Clients (Desktop/iOS/Android)
        │
        ├──── Authentication ────→ Management Server (Port 8080)
        │                           │
        │                           ├─ PostgreSQL Database
        │                           ├─ User Authentication
        │                           ├─ Email OTP
        │                           └─ Endnode Management
        │
        └──── VPN Traffic ────→ Endnode Servers (Port 8080 each)
                                   │
                                   ├─ No Database (API Only!)
                                   ├─ OpenVPN Connections
                                   ├─ Traffic Routing
                                   └─ Stats Reporting
```

## Key Differences: Management vs Endnode

| Feature | Management Server | Endnode Server |
|---------|------------------|----------------|
| **Database Access** | ✅ Direct PostgreSQL | ❌ **No Database** |
| **Authentication** | ✅ User login, OTP | ❌ Validates JWT only |
| **User Management** | ✅ Create/update users | ❌ Read-only via API |
| **VPN Connections** | ❌ No VPN handling | ✅ OpenVPN traffic |
| **Purpose** | Central auth/management | Distributed VPN nodes |
| **Deployment** | Usually 1 (or cluster) | Multiple (geo-distributed) |
| **Communication** | Talks to: Clients, Endnodes | Talks to: Management API |

## Why No Database Access?

**Security Benefits:**
1. **Reduced attack surface** - Endnodes can't leak database credentials
2. **Principle of least privilege** - Endnodes only access what they need
3. **Easier compliance** - User data stays in central location
4. **Simpler deployment** - No database setup needed for each endnode

**Operational Benefits:**
1. **Faster deployment** - Just set API URL and keys
2. **Easier scaling** - Deploy endnodes anywhere without database access
3. **Geographic distribution** - Put endnodes close to users without security concerns
4. **Simpler configuration** - Only 3 critical environment variables

## Environment Variables

### Required Variables (No Database Credentials!)

```bash
# Security (CRITICAL) - Must match Management Server
JWT_SECRET=your_jwt_secret_key_here_minimum_32_characters_required
API_KEY=your_api_key_here_min_16_chars

# Management Server Connection
MANAGEMENT_URL=http://localhost:8080  # or https://api.barqnet.com
```

### Optional Variables

```bash
# Redis (for caching)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0

# Server Configuration
ENDNODE_SERVER_ID=server-1  # Can also use -server-id flag
PORT=8080
```

### What You DON'T Need

```bash
# ❌ NOT NEEDED - Endnode has no database access
# DB_HOST=
# DB_PORT=
# DB_USER=
# DB_PASSWORD=
# DB_NAME=
```

## Quick Start

### 1. Create Configuration

```bash
cd barqnet-backend/apps/endnode

# Copy example configuration
cp .env.example .env

# Edit with your values
nano .env
```

**Critical Configuration:**
- Set `JWT_SECRET` (MUST match Management Server exactly)
- Set `API_KEY` (register this with Management Server)
- Set `MANAGEMENT_URL` (your Management Server address)

### 2. Build

```bash
go build -o endnode main.go
```

### 3. Run

```bash
./endnode -server-id server-1
```

**Expected Output:**
```
========================================
BarqNet Endnode Server - Starting...
========================================
[ENV] ✅ Loaded configuration from .env file
[ENV] Validating endnode environment variables...
[ENV] Note: Endnodes use Management API, no direct database access needed
[ENV] ✅ VALID: JWT_SECRET = yo**************************re
[ENV] ✅ VALID: API_KEY = yo**********rs
[ENV] ✅ VALID: MANAGEMENT_URL = http://localhost:8080
[ENV] ============================================================
[ENV] ✅ Endnode environment validation PASSED
[ENV] ============================================================
End-node mode: No direct database connection needed
Communication with management server via API only
Waiting for API server to fully initialize...
✅ API server is ready
Attempting to register with management server...
✅ Successfully registered with management server
🚀 Endnode server 'server-1' started successfully on port 8080
```

## How Endnode Works

### 1. Startup Process

```
1. Load .env configuration
   └─ Validates: JWT_SECRET, API_KEY, MANAGEMENT_URL

2. Start API server on port 8080
   └─ No database connection needed

3. Register with Management Server
   └─ POST to MANAGEMENT_URL/api/endnode/register
   └─ Sends: server_id, host, port, capabilities
   └─ Authenticates with API_KEY

4. Begin accepting VPN connections
   └─ OpenVPN traffic handling
   └─ Statistics reporting to Management
```

### 2. Runtime Operations

**VPN Connection Flow:**
```
1. Client authenticates with Management Server
   └─ Receives JWT token

2. Management Server assigns Endnode
   └─ Returns: endnode_host, endnode_port, config

3. Client connects to Endnode
   └─ Provides JWT token for validation

4. Endnode validates JWT (using shared JWT_SECRET)
   └─ No database query needed!
   └─ Token contains: user_id, permissions, expiry

5. Endnode establishes VPN tunnel
   └─ Routes traffic
   └─ Reports stats to Management API
```

**Data Sync:**
```
Endnode periodically syncs with Management:
- Server health status
- Active connection count
- Bandwidth usage statistics
- Available capacity

All via Management API - no direct database access
```

## API Endpoints

The endnode exposes these endpoints:

### Health Check
```bash
GET /health
Response: {"status": "healthy"}
```

### VPN Connection (OpenVPN Protocol)
```bash
# OpenVPN client connects here
# Validates JWT token from Management Server
# No additional authentication needed
```

### Statistics Reporting
```bash
POST /api/stats
# Reports connection stats to Management Server
# Authenticated with API_KEY
```

## Deployment Scenarios

### Single Region (Development)

```bash
# Management Server (Port 8080)
cd barqnet-backend/apps/management
go run main.go

# Endnode Server (Port 8081)
cd barqnet-backend/apps/endnode
./endnode -server-id dev-local
```

### Multi-Region (Production)

**US East:**
```bash
# Endnode in us-east-1
MANAGEMENT_URL=https://api.barqnet.com \
JWT_SECRET=<same-as-management> \
API_KEY=<registered-key> \
./endnode -server-id us-east-1
```

**EU West:**
```bash
# Endnode in eu-west-1
MANAGEMENT_URL=https://api.barqnet.com \
JWT_SECRET=<same-as-management> \
API_KEY=<registered-key> \
./endnode -server-id eu-west-1
```

**Asia Pacific:**
```bash
# Endnode in ap-southeast-1
MANAGEMENT_URL=https://api.barqnet.com \
JWT_SECRET=<same-as-management> \
API_KEY=<registered-key> \
./endnode -server-id ap-southeast-1
```

## Troubleshooting

### "Missing required environment variables: JWT_SECRET, API_KEY"

**Solution:** Create .env file with required variables
```bash
cp .env.example .env
# Edit .env with your values
```

### "Failed to register with management server"

**Possible Causes:**
1. Management Server not running
2. Wrong MANAGEMENT_URL
3. Invalid API_KEY
4. Network connectivity issue
5. JWT_SECRET mismatch

**Debug Steps:**
```bash
# Test Management Server health
curl http://localhost:8080/health

# Check Management Server logs
# Look for registration attempts

# Verify API_KEY is registered in Management database
```

### "Token validation failed"

**Solution:** JWT_SECRET MUST match Management Server exactly
```bash
# On Management Server:
echo $JWT_SECRET

# On Endnode:
echo $JWT_SECRET

# These MUST be identical!
```

## Security Best Practices

### 1. JWT Secret Management
```bash
# ✅ DO: Use strong random value
JWT_SECRET=$(openssl rand -base64 48)

# ❌ DON'T: Use weak or common values
JWT_SECRET=your_jwt_secret  # Too weak!
```

### 2. API Key Management
```bash
# ✅ DO: Generate unique key per endnode
API_KEY=$(openssl rand -hex 32)

# ❌ DON'T: Share API keys between endnodes
```

### 3. HTTPS in Production
```bash
# ✅ DO: Use HTTPS for Management API
MANAGEMENT_URL=https://api.barqnet.com

# ❌ DON'T: Use HTTP in production
MANAGEMENT_URL=http://api.barqnet.com  # Insecure!
```

### 4. File Permissions
```bash
# ✅ DO: Protect .env file
chmod 600 .env

# ❌ DON'T: Leave .env world-readable
chmod 644 .env  # Insecure!
```

## Monitoring

### Key Metrics to Monitor

```bash
# Connection Count
GET /health
{"connections": 42, "capacity": 1000}

# Resource Usage
ps aux | grep endnode
top -p $(pgrep endnode)

# Network Traffic
iftop -i tun0  # VPN interface
```

### Log Analysis

```bash
# Real-time logs
tail -f endnode.log

# Connection logs
grep "VPN connection" endnode.log

# Error logs
grep "ERROR\|FATAL" endnode.log

# Registration logs
grep "register" endnode.log
```

## Comparison with Management Server

### Management Server Setup
```bash
# Management needs database
DB_HOST=localhost
DB_PORT=5432
DB_USER=barqnet
DB_PASSWORD=secure_password
DB_NAME=barqnet
JWT_SECRET=your_secret
API_KEY=your_key
```

### Endnode Setup (Much Simpler!)
```bash
# Endnode only needs API access
JWT_SECRET=your_secret  # Same as Management
API_KEY=your_key
MANAGEMENT_URL=http://management-server:8080
```

**Configuration Complexity:**
- Management: ~15 environment variables
- Endnode: **3 critical variables** ✅

## Summary

**BarqNet Endnode Server is:**
- ✅ Lightweight (no database dependency)
- ✅ Secure (limited credentials exposure)
- ✅ Scalable (easy to deploy multiple instances)
- ✅ Simple (3 environment variables to configure)
- ✅ API-first (all data via Management API)

**It is NOT:**
- ❌ An authentication server (uses Management API)
- ❌ A user management system (uses Management API)
- ❌ A database client (no direct DB access)

**Perfect for:**
- Geographic distribution
- Edge deployment
- Scaling VPN capacity
- Reducing database load
- Improving security posture
