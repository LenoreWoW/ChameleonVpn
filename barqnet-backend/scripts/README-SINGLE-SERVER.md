# VPN Manager - Single Server Setup

This guide covers setting up VPN Manager with both database and management server on a single Ubuntu machine. This is perfect for small to medium deployments or testing environments.

## 🚀 Quick Start

### Option 1: Automated Setup (Recommended)
```bash
# Run the single server setup script
sudo bash scripts/setup-single-server.sh
```

### Option 2: Manual Setup
```bash
# 1. Setup database
sudo bash scripts/setup-database.sh

# 2. Setup management server
sudo bash scripts/setup-management.sh
```

## 📋 What Gets Installed

### Database Components
- ✅ **PostgreSQL 13+** - Database server
- ✅ **Database Schema** - Complete VPN Manager schema
- ✅ **User Management** - Database user and permissions
- ✅ **Backup System** - Automated daily backups
- ✅ **Connection Testing** - Database connectivity verification

### Management Server Components
- ✅ **Go 1.21+** - Programming language runtime
- ✅ **Management Application** - Central coordination server
- ✅ **Systemd Service** - Production-ready service management
- ✅ **Configuration Files** - JSON and environment configuration
- ✅ **Firewall Rules** - UFW firewall configuration
- ✅ **Health Monitoring** - Service status and API health checks

## 🔧 Configuration

The setup script will prompt you for:

### Database Configuration
- **PostgreSQL password** for vpnmanager user
- **Database host** (default: localhost)
- **Database port** (default: 5432)

### Management Server Configuration
- **Server hostname/IP** (auto-detected)
- **API key** for authentication
- **Management port** (default: 8080)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                Single Ubuntu Server                     │
│                                                         │
│  ┌─────────────────┐    ┌─────────────────────────────┐  │
│  │   PostgreSQL    │    │    Management Server       │  │
│  │                 │    │                           │  │
│  │ - Database      │    │ - Central Coordination     │  │
│  │ - Users Table   │    │ - User Management          │  │
│  │ - Servers Table │    │ - End-Node Monitoring     │  │
│  │ - Audit Log     │    │ - API Endpoints           │  │
│  │ - Health Status │    │ - Health Checks           │  │
│  └─────────────────┘    └─────────────────────────────┘  │
│           │                        │                    │
│           └────────┬────────────────┘                    │
│                    │                                     │
│  ┌─────────────────▼─────────────────────────────────┐  │
│  │              End-Node Servers                      │  │
│  │  (Connect to this management server)               │  │
│  │                                                     │  │
│  │  • VPN Server 1 (192.168.1.10)                     │  │
│  │  • VPN Server 2 (192.168.1.11)                     │  │
│  │  • VPN Server N (192.168.1.12)                     │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 📊 System Status

After installation, check the system status:

```bash
# Check all services
systemctl status vpnmanager-management postgresql

# Check management server health
curl http://localhost:8080/health

# Check database connection
psql -h localhost -U vpnmanager -d vpnmanager -c "SELECT 1;"
```

## 🔍 Verification

### 1. Service Status
```bash
# Management server
systemctl status vpnmanager-management

# PostgreSQL
systemctl status postgresql

# Check if ports are listening
netstat -tlnp | grep -E "(8080|5432)"
```

### 2. API Health Check
```bash
# Test management API
curl http://localhost:8080/health

# Expected response:
# {
#   "status": "healthy",
#   "timestamp": 1234567890,
#   "version": "1.0.0",
#   "server_id": "management-server"
# }
```

### 3. Database Connection
```bash
# Connect to database
psql -h localhost -U vpnmanager -d vpnmanager

# Check tables
\dt

# Check users table
SELECT COUNT(*) FROM users;
```

## 🛠️ Management Commands

### Service Management
```bash
# Start/stop/restart management server
systemctl start vpnmanager-management
systemctl stop vpnmanager-management
systemctl restart vpnmanager-management

# Check status
systemctl status vpnmanager-management

# View logs
journalctl -u vpnmanager-management -f
```

### Database Management
```bash
# Connect to database
psql -h localhost -U vpnmanager -d vpnmanager

# Backup database
/opt/vpnmanager/backups/backup.sh

# Restore database
gunzip -c backup.sql.gz | psql -h localhost -U vpnmanager -d vpnmanager
```

## 📈 Monitoring

### Health Checks
```bash
# Management server health
curl http://localhost:8080/health

# Database health
psql -h localhost -U vpnmanager -d vpnmanager -c "SELECT 1;"

# Service status
systemctl is-active vpnmanager-management
systemctl is-active postgresql
```

### Log Monitoring
```bash
# Management server logs
journalctl -u vpnmanager-management -f

# PostgreSQL logs
journalctl -u postgresql -f

# Application logs
tail -f /var/log/vpnmanager/*
```

## 🔒 Security

### Firewall Configuration
The setup script automatically configures UFW firewall:
- **SSH (22)** - Remote access
- **Management API (8080)** - Management server
- **PostgreSQL (5432)** - Database access
- **OpenVPN (1194/udp)** - VPN traffic

### User Permissions
- **vpnmanager user** - Limited system privileges
- **Service isolation** - Restricted file system access
- **Secure configuration** - Encrypted database connections

### Database Security
- **Local connections only** (by default)
- **User-based access control**
- **Encrypted connections** (configurable)
- **Regular backups**

## 📁 File Structure

After installation, the following structure is created:

```
/opt/vpnmanager/
├── bin/
│   └── vpnmanager-management    # Management application
├── config/
│   └── management-config.json  # Main configuration
├── backups/
│   └── backup.sh              # Database backup script
├── logs/                       # Application logs
└── .env                       # Environment variables

/var/log/vpnmanager/            # Application logs
/etc/systemd/system/
└── vpnmanager-management.service  # Systemd service
```

## 🔧 Configuration Files

### Management Configuration (`/opt/vpnmanager/config/management-config.json`)
```json
{
  "server_id": "management-server",
  "api_key": "your-api-key",
  "database": {
    "host": "localhost",
    "port": 5432,
    "user": "vpnmanager",
    "password": "your-password",
    "dbname": "vpnmanager",
    "sslmode": "disable"
  }
}
```

### Environment File (`/opt/vpnmanager/.env`)
```bash
DB_HOST=localhost
DB_USER=vpnmanager
DB_PASSWORD=your-password
DB_NAME=vpnmanager
DB_SSLMODE=disable
API_KEY=your-api-key
MANAGEMENT_PORT=8080
SERVER_HOSTNAME=your-server-ip
```

## 🌐 API Endpoints

The management server provides the following API endpoints:

### Health Check
```bash
GET /health
```

### User Management
```bash
GET    /api/users           # List all users
POST   /api/users           # Create user
GET    /api/users/{username} # Get specific user
DELETE /api/users/{username} # Delete user
```

### End-Node Management
```bash
GET    /api/endnodes                    # List all end-nodes
POST   /api/endnodes/register          # Register end-node
GET    /api/endnodes/{server-id}       # Get end-node info
POST   /api/endnodes/{server-id}/health # Update health status
```

## 🚀 Next Steps

### 1. Test the Management Server
```bash
# Health check
curl http://your-server-ip:8080/health

# List users (should be empty initially)
curl http://your-server-ip:8080/api/users
```

### 2. Set Up End-Node Servers
On each VPN server, run:
```bash
# Use the end-node setup script
sudo bash scripts/setup-endnode.sh

# Configure to connect to your management server
# Management URL: http://your-server-ip:8080
```

### 3. Create Your First User
```bash
# Create a user via API
curl -X POST http://your-server-ip:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "ovpn_path": "/path/to/testuser.ovpn",
    "checksum": "abc123",
    "port": 1194,
    "protocol": "udp",
    "target_server_id": "server-1"
  }'
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Management Server Not Starting
```bash
# Check logs
journalctl -u vpnmanager-management -f

# Check configuration
cat /opt/vpnmanager/config/management-config.json

# Restart service
systemctl restart vpnmanager-management
```

#### 2. Database Connection Failed
```bash
# Check PostgreSQL status
systemctl status postgresql

# Test connection
psql -h localhost -U vpnmanager -d vpnmanager

# Check firewall
ufw status
```

#### 3. Port Not Listening
```bash
# Check if port is in use
netstat -tlnp | grep 8080

# Check firewall rules
ufw status

# Restart service
systemctl restart vpnmanager-management
```

### Log Locations
- **Management Server**: `journalctl -u vpnmanager-management -f`
- **PostgreSQL**: `journalctl -u postgresql -f`
- **Application Logs**: `/var/log/vpnmanager/`

### Configuration Verification
```bash
# Check service configuration
systemctl show vpnmanager-management

# Check environment variables
cat /opt/vpnmanager/.env

# Test database connection
PGPASSWORD=your-password psql -h localhost -U vpnmanager -d vpnmanager -c "SELECT 1;"
```

## 📚 Additional Resources

- [Complete Documentation](../README-DISTRIBUTED.md)
- [API Documentation](../API_CONTRACT.md)
- [End-Node Setup Guide](README-SETUP.md)
- [Troubleshooting Guide](../README-DISTRIBUTED.md#troubleshooting)

## 🆘 Support

If you encounter issues:

1. **Check logs**: `journalctl -u vpnmanager-management -f`
2. **Verify configuration**: Check config files
3. **Test connectivity**: Database and API connections
4. **Review firewall**: UFW rules and port access
5. **Check system resources**: CPU, memory, disk space

For additional help, refer to the main documentation or create an issue in the project repository.
