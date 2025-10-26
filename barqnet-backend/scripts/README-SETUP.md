# VPN Manager - Ubuntu Setup Scripts

This directory contains automated setup scripts for deploying VPN Manager with the new distributed architecture on Ubuntu systems.

## 🚀 Quick Start

### Option 1: Interactive Installer (Recommended)
```bash
# Download and run the master installer
sudo bash scripts/install.sh
```

### Option 2: Individual Scripts
```bash
# 1. Setup database first
sudo bash scripts/setup-database.sh

# 2. Setup management server
sudo bash scripts/setup-management.sh

# 3. Setup end-node servers
sudo bash scripts/setup-endnode.sh
```

## 📋 Setup Scripts

### 1. `install.sh` - Master Installer
Interactive menu-driven installer that guides you through the entire setup process.

**Features:**
- Menu-driven interface
- System status checking
- Help and documentation
- Complete system setup option

### 2. `setup-database.sh` - Database Setup
Sets up PostgreSQL database with VPN Manager schema.

**What it does:**
- Installs PostgreSQL
- Creates database and user
- Sets up schema (users, servers, audit_log, server_health tables)
- Configures backup system
- Tests connection

**Usage:**
```bash
sudo bash scripts/setup-database.sh
```

### 3. `setup-management.sh` - Management Server
Sets up the central management server.

**What it does:**
- Installs dependencies (Go, PostgreSQL client)
- Creates vpnmanager user and directories
- Builds management application
- Creates configuration files
- Sets up systemd service
- Configures firewall
- Starts services

**Usage:**
```bash
sudo bash scripts/setup-management.sh
```

### 4. `setup-endnode.sh` - End-Node Server
Sets up an end-node server that connects to the management server.

**What it does:**
- Installs dependencies
- Creates vpnmanager user and directories
- Builds end-node application
- Creates configuration files
- Sets up systemd service
- Tests database and management server connections
- Starts services

**Usage:**
```bash
sudo bash scripts/setup-endnode.sh
```

## 🏗️ Architecture Setup

### Single Server Deployment
For testing or small deployments, you can run everything on one server:

```bash
# Run the master installer
sudo bash scripts/install.sh

# Select option 4: "Setup Complete System"
```

### Multi-Server Deployment
For production deployments:

#### Step 1: Database Server
```bash
# On the database server
sudo bash scripts/setup-database.sh
```

#### Step 2: Management Server
```bash
# On the management server
sudo bash scripts/setup-management.sh
```

#### Step 3: End-Node Servers
```bash
# On each VPN server
sudo bash scripts/setup-endnode.sh
```

## 🔧 Configuration

### Database Configuration
The database setup script will prompt for:
- PostgreSQL password for vpnmanager user
- Database host (default: localhost)
- Database port (default: 5432)

### Management Server Configuration
The management setup script will prompt for:
- PostgreSQL password
- API key for authentication
- Management server port (default: 8080)

### End-Node Configuration
The end-node setup script will prompt for:
- Server ID (unique identifier for this end-node)
- Management server URL
- API key for authentication
- Database connection details
- End-node API port (default: 8080)

## 📊 System Status

Check the status of your VPN Manager installation:

```bash
# Run the master installer and select option 5
sudo bash scripts/install.sh

# Or check individual services
systemctl status vpnmanager-management
systemctl status vpnmanager-endnode
systemctl status postgresql
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Database Connection Failed
```bash
# Check PostgreSQL status
systemctl status postgresql

# Check database connection
psql -h localhost -U vpnmanager -d vpnmanager

# Check firewall
ufw status
```

#### 2. Management Server Not Starting
```bash
# Check logs
journalctl -u vpnmanager-management -f

# Check configuration
cat /opt/vpnmanager/config/management-config.json

# Restart service
systemctl restart vpnmanager-management
```

#### 3. End-Node Registration Failed
```bash
# Check end-node logs
journalctl -u vpnmanager-endnode -f

# Test management server connection
curl http://management-server:8080/health

# Check configuration
cat /opt/vpnmanager/config/endnode-config.json
```

### Log Locations

- **Management Server**:** `journalctl -u vpnmanager-management -f`
- **End-Node Servers**:** `journalctl -u vpnmanager-endnode -f`
- **PostgreSQL**:** `journalctl -u postgresql -f`
- **Application Logs**:** `/var/log/vpnmanager/`

### Configuration Files

- **Management Config**:** `/opt/vpnmanager/config/management-config.json`
- **End-Node Config**:** `/opt/vpnmanager/config/endnode-config.json`
- **Environment Files**:** `/opt/vpnmanager/.env`

## 🛠️ Manual Operations

### Start/Stop Services
```bash
# Management server
systemctl start vpnmanager-management
systemctl stop vpnmanager-management
systemctl restart vpnmanager-management

# End-node servers
systemctl start vpnmanager-endnode
systemctl stop vpnmanager-endnode
systemctl restart vpnmanager-endnode
```

### Database Operations
```bash
# Connect to database
psql -h localhost -U vpnmanager -d vpnmanager

# Backup database
/opt/vpnmanager/backups/backup.sh

# Restore database
gunzip -c backup.sql.gz | psql -h localhost -U vpnmanager -d vpnmanager
```

### Application Updates
```bash
# Stop services
systemctl stop vpnmanager-management
systemctl stop vpnmanager-endnode

# Update application
cd /opt/vpnmanager
go build -o bin/vpnmanager-management ./apps/management/
go build -o bin/vpnmanager-endnode ./apps/endnode/

# Restart services
systemctl start vpnmanager-management
systemctl start vpnmanager-endnode
```

## 📈 Monitoring

### Health Checks
```bash
# Management server health
curl http://localhost:8080/health

# End-node health
curl http://localhost:8080/health

# Database health
psql -h localhost -U vpnmanager -d vpnmanager -c "SELECT 1;"
```

### API Endpoints

#### Management Server
- `GET /health` - Health check
- `GET /api/users` - List all users
- `POST /api/users` - Create user
- `GET /api/endnodes` - List end-nodes
- `POST /api/endnodes/register` - Register end-node

#### End-Node Server
- `GET /health` - Health check
- `GET /api/users` - List local users
- `POST /api/users` - Create user locally
- `POST /api/sync/users` - Receive sync from management

## 🔒 Security

### Firewall Configuration
The scripts automatically configure UFW firewall:
- SSH (port 22)
- Management server port (default: 8080)
- End-node server port (default: 8080)
- PostgreSQL port (5432)
- OpenVPN port (1194/udp)

### User Permissions
- Services run as `vpnmanager` user
- Limited system privileges
- Restricted file system access
- Secure configuration file permissions

### Database Security
- Encrypted connections (configurable)
- User-based access control
- Regular backups
- Audit logging

## 📚 Additional Resources

- [Main Documentation](../README-DISTRIBUTED.md)
- [API Documentation](../API_CONTRACT.md)
- [Architecture Overview](../README-DISTRIBUTED.md#architecture-overview)
- [Troubleshooting Guide](../README-DISTRIBUTED.md#troubleshooting)

## 🆘 Support

If you encounter issues:

1. Check the logs: `journalctl -u vpnmanager-* -f`
2. Verify configuration files
3. Test network connectivity
4. Check firewall rules
5. Review the troubleshooting section above

For additional help, check the main documentation or create an issue in the project repository.
