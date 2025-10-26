# BarqNet - Enterprise VPN Management System

A modern, distributed VPN management system with centralized PostgreSQL database, management server, and distributed end-node servers. Designed for enterprise-scale VPN deployments with comprehensive security, monitoring, and management capabilities.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   End-Node 1    │    │   End-Node 2    │    │   End-Node N    │
│                 │    │                 │    │                 │
│ - OpenVPN Server│    │ - OpenVPN Server│    │ - OpenVPN Server│
│ - EasyRSA PKI   │    │ - EasyRSA PKI   │    │ - EasyRSA PKI   │
│ - Local API     │    │ - Local API     │    │ - Local API     │
│ - Health Check  │    │ - Health Check  │    │ - Health Check  │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │    Management Server    │
                    │                         │
                    │ - Centralized Database  │
                    │ - User Coordination     │
                    │ - End-Node Monitoring   │
                    │ - Web UI Dashboard      │
                    │ - API Gateway          │
                    └─────────────┬───────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │    PostgreSQL Database   │
                    │                         │
                    │ - Users & Servers      │
                    │ - Audit Logs           │
                    │ - Health Monitoring     │
                    │ - Automated Backups     │
                    └─────────────────────────┘
```

## ✨ Key Features

### 🚀 **Distributed Architecture**
- **Management Server** - Central coordination and monitoring
- **End-Node Servers** - Distributed VPN servers with local management
- **PostgreSQL Database** - Enterprise-grade centralized data storage
- **Web UI Dashboard** - Modern web interface for management
- **Scalable Design** - Easy to add new VPN servers

### 🛡️ **Enterprise Security**
- **EasyRSA PKI** - Industry-standard certificate management
- **Certificate Revocation** - Real-time certificate revocation with CRL
- **API Authentication** - Secure API key-based authentication
- **Session Management** - Automatic session termination on user deletion
- **Audit Logging** - Complete operation history and compliance
- **Firewall Integration** - Automated UFW firewall configuration

### 📊 **Monitoring & Management**
- **Health Checks** - Automatic service and end-node monitoring
- **Real-time Status** - Live system status and performance metrics
- **Interactive Web UI** - Modern dashboard with user management
- **API Endpoints** - RESTful APIs for all operations
- **Automated Backups** - Daily database backups with retention

### 🔧 **Advanced Features**
- **User Management** - Create, delete, and manage VPN users
- **OVPN File Generation** - Automatic OpenVPN configuration files
- **Certificate Management** - Full PKI lifecycle management
- **Multi-Server Support** - Manage multiple VPN servers
- **Sync Management** - Real-time synchronization between servers

## 🚀 Quick Start

### Option 1: Single Server Setup (Recommended for Testing)
```bash
# Setup everything on one machine
sudo bash scripts/setup-single-server.sh
```

### Option 2: Multi-Server Setup (Production)
```bash
# 1. Setup database server
sudo bash scripts/setup-database.sh

# 2. Setup management server
sudo bash scripts/setup-management.sh

# 3. Setup end-node servers
sudo bash scripts/setup-endnode.sh
```

### Option 3: Interactive Setup
```bash
# Run the master installer
sudo bash scripts/install.sh
```

## 📋 Components

### **Management Server** (`barqnet-management`)
- **Purpose**: Central coordination and management
- **Features**:
  - User management and synchronization
  - End-node monitoring and health checks
  - Web UI dashboard
  - API gateway for all operations
  - Audit logging and compliance

### **End-Node Servers** (`barqnet-endnode`)
- **Purpose**: Individual VPN servers with local management
- **Features**:
  - OpenVPN server with EasyRSA PKI
  - Local user management
  - Certificate generation and revocation
  - Health reporting to management server
  - Real-time sync with central database

### **PostgreSQL Database**
- **Purpose**: Centralized data storage
- **Features**:
  - Users, servers, and audit logs
  - Health monitoring data
  - Automated backups
  - Enterprise-grade security

### **Web UI Dashboard**
- **Purpose**: Modern web interface for management
- **Features**:
  - Interactive user management
  - Real-time health monitoring
  - End-node status and management
  - Log viewing and analysis
  - OVPN file download

## 🔧 Configuration

### **Management Server Configuration**
```json
{
  "server_id": "management-server",
  "api_key": "your-secure-api-key",
  "database": {
    "host": "localhost",
    "port": 5432,
    "user": "barqnet",
    "password": "your-secure-password",
    "dbname": "barqnet",
    "sslmode": "require"
  },
  "web_ui": {
    "enabled": true,
    "port": 8080
  }
}
```

### **End-Node Server Configuration**
```json
{
  "server_id": "endnode-1",
  "management_url": "http://management-server:8080",
  "api_key": "your-secure-api-key",
  "database": {
    "host": "database-server",
    "port": 5432,
    "user": "barqnet",
    "password": "your-secure-password",
    "dbname": "barqnet",
    "sslmode": "require"
  },
  "openvpn": {
    "port": 1194,
    "protocol": "udp",
    "network": "10.8.0.0/24"
  }
}
```

## 🌐 Web UI Dashboard

Access the web interface at `http://management-server:8080` to:

- **User Management**: Create, delete, and manage VPN users
- **End-Node Monitoring**: View status and health of all VPN servers
- **OVPN Downloads**: Download user configuration files
- **Health Monitoring**: Real-time system status and performance
- **Log Analysis**: View and analyze system logs
- **Server Management**: Add and remove VPN servers

## 📡 API Endpoints

### **Management Server API**
- `GET /health` - Health check
- `GET /api/users` - List all users
- `POST /api/users` - Create user
- `DELETE /api/users/{username}` - Delete user
- `GET /api/endnodes` - List end-nodes
- `POST /api/endnodes/register` - Register end-node
- `DELETE /api/endnodes/{server_id}` - Delete end-node
- `GET /api/logs` - Get system logs
- `GET /api/ovpn/{username}/{server_id}` - Download OVPN file

### **End-Node Server API**
- `GET /health` - Health check
- `POST /api/ovpn/create` - Create OVPN file
- `DELETE /api/ovpn/delete/{username}` - Delete OVPN file
- `GET /api/ovpn/{username}` - Download OVPN file
- `POST /api/sync/users` - Sync users from management

## 🔒 Security Features

### **Certificate Management**
- **EasyRSA PKI**: Industry-standard certificate authority
- **Certificate Revocation**: Real-time CRL updates
- **Secure Key Storage**: Proper file permissions and access control
- **Certificate Lifecycle**: Full management from generation to revocation

### **API Security**
- **API Key Authentication**: Secure API access control
- **HTTPS Support**: Encrypted communications (configurable)
- **Rate Limiting**: Protection against abuse
- **Input Validation**: Comprehensive input sanitization
- **Audit Logging**: Complete operation history

### **Network Security**
- **UFW Firewall**: Automated firewall configuration
- **Port Management**: Secure port access control
- **Service Isolation**: Restricted system privileges
- **Network Segmentation**: Secure network architecture

### **Database Security**
- **PostgreSQL Encryption**: Encrypted database connections
- **User Access Control**: Role-based database access
- **Automated Backups**: Secure backup and recovery
- **Audit Logging**: Database operation tracking

## 🚀 Deployment Options

### **Single Server (Testing/Development)**
```bash
# Everything on one machine
sudo bash scripts/setup-single-server.sh
```

### **Multi-Server (Production)**
```bash
# Database server
sudo bash scripts/setup-database.sh

# Management server
sudo bash scripts/setup-management.sh

# Each VPN server
sudo bash scripts/setup-endnode.sh
```

### **Docker Deployment**
```yaml
# docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: barqnet
      POSTGRES_USER: barqnet
      POSTGRES_PASSWORD: your_secure_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - barqnet_network

  management:
    build: .
    command: ./bin/barqnet-management
    environment:
      DB_HOST: postgres
      DB_USER: barqnet
      DB_PASSWORD: your_secure_password
      DB_NAME: barqnet
      API_KEY: your_secure_api_key
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    networks:
      - barqnet_network

volumes:
  postgres_data:

networks:
  barqnet_network:
    driver: bridge
```

## 📈 Monitoring & Health Checks

### **System Status**
```bash
# Check all services
systemctl status barqnet-management barqnet-endnode postgresql

# View logs
journalctl -u barqnet-management -f
journalctl -u barqnet-endnode -f
journalctl -u postgresql -f
```

### **API Health Checks**
```bash
# Management server
curl http://management-server:8080/health

# End-node servers
curl http://endnode-server:8080/health

# Database
psql -h localhost -U barqnet -d barqnet -c "SELECT 1;"
```

### **Web UI Monitoring**
- **Dashboard**: Real-time system overview
- **Health Status**: Service and end-node health
- **Performance Metrics**: Response times and throughput
- **Log Analysis**: System and application logs

## 🔧 Troubleshooting

### **Common Issues**

#### **Database Connection Failed**
```bash
# Check PostgreSQL status
systemctl status postgresql

# Test connection
psql -h localhost -U barqnet -d barqnet -c "SELECT 1;"

# Check firewall
ufw status
```

#### **End-Node Sync Issues**
```bash
# Check end-node logs
journalctl -u barqnet-endnode -f

# Test management server connectivity
curl http://management-server:8080/health

# Check API key configuration
cat /opt/barqnet/config/endnode-config.json
```

#### **OpenVPN Server Issues**
```bash
# Check OpenVPN status
systemctl status openvpn@server

# Check OpenVPN logs
journalctl -u openvpn@server -f

# Verify certificates
ls -la /etc/openvpn/
```

#### **Web UI Not Loading**
```bash
# Check management server
systemctl status barqnet-management

# Check web UI logs
journalctl -u barqnet-management -f

# Test API endpoints
curl http://management-server:8080/api
```

## 📚 Documentation

- **[API Documentation](API_DOCUMENTATION.md)** - Complete API reference
- **[Security Guide](SECURITY.md)** - Security best practices
- **[Deployment Guide](DEPLOYMENT.md)** - Production deployment
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Common issues and solutions

## 🆘 Support

### **Getting Help**
1. **Check Logs**: `journalctl -u barqnet-* -f`
2. **Verify Configuration**: Check config files in `/opt/barqnet/config/`
3. **Test Connectivity**: Verify network and database connections
4. **Review Documentation**: Check the troubleshooting guides

### **Community Support**
- **GitHub Issues**: Report bugs and request features
- **Documentation**: Comprehensive guides and examples
- **Security**: Report security issues responsibly

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

---

**BarqNet** - Enterprise-grade VPN management made simple and secure.