# VPN Manager - Distributed Architecture

This is the new distributed architecture for VPN Manager, designed to solve sync issues by using a centralized PostgreSQL database and separating concerns into end-node and management applications.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   End-Node 1    │    │   End-Node 2    │    │   End-Node N    │
│                 │    │                 │    │                 │
│ - User Mgmt     │    │ - User Mgmt     │    │ - User Mgmt     │
│ - Local API     │    │ - Local API     │    │ - Local API     │
│ - Health Check  │    │ - Health Check  │    │ - Health Check  │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │    Management Server      │
                    │                           │
                    │ - Centralized Database    │
                    │ - User Coordination       │
                    │ - End-Node Monitoring     │
                    │ - Sync Management         │
                    └───────────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │    PostgreSQL Database   │
                    │                           │
                    │ - Users Table            │
                    │ - Servers Table          │
                    │ - Audit Log Table        │
                    │ - Health Status Table    │
                    └───────────────────────────┘
```

## Components

### 1. End-Node Application (`vpnmanager-endnode`)
- **Purpose**: Manages users on individual VPN servers
- **Responsibilities**:
  - Create/delete users locally
  - Sync with management server
  - Health reporting
  - Local API for user operations

### 2. Management Application (`vpnmanager-management`)
- **Purpose**: Central coordination and management
- **Responsibilities**:
  - Centralized user management
  - End-node monitoring
  - User sync coordination
  - Database management

### 3. Shared Components (`pkg/shared/`)
- **Purpose**: Common functionality for both applications
- **Components**:
  - Database layer (PostgreSQL)
  - User management
  - Server management
  - Audit logging

## Quick Start

### 1. Setup PostgreSQL Database

```bash
# Install PostgreSQL (Ubuntu/Debian)
sudo apt-get install postgresql postgresql-contrib

# Create database and user
sudo -u postgres psql
CREATE DATABASE vpnmanager;
CREATE USER vpnmanager WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE vpnmanager TO vpnmanager;
\q
```

### 2. Build Applications

```bash
# Build all components
make all

# Or build individually
make build-endnode
make build-management
```

### 3. Create Configuration

```bash
# Create sample configuration files
make config
```

### 4. Run Management Server

```bash
# Set environment variables
export DB_HOST=localhost
export DB_USER=vpnmanager
export DB_PASSWORD=your_password
export DB_NAME=vpnmanager
export API_KEY=your-secret-api-key

# Run management server
make run-management
```

### 5. Run End-Node Servers

```bash
# On each VPN server
export SERVER_ID=server-1
export MANAGEMENT_URL=http://management-server:8080
export API_KEY=your-secret-api-key
export DB_HOST=management-server
export DB_USER=vpnmanager
export DB_PASSWORD=your_password
export DB_NAME=vpnmanager

# Run end-node
make run-endnode
```

## API Endpoints

### Management Server API

#### Health Check
```
GET /health
```

#### User Management
```
GET    /api/users           # List all users
POST   /api/users           # Create user
GET    /api/users/{username} # Get specific user
DELETE /api/users/{username} # Delete user
```

#### End-Node Management
```
GET    /api/endnodes                    # List all end-nodes
POST   /api/endnodes/register          # Register end-node
GET    /api/endnodes/{server-id}       # Get end-node info
POST   /api/endnodes/{server-id}/health # Update health status
POST   /api/endnodes/{server-id}/deregister # Deregister end-node
```

### End-Node API

#### Health Check
```
GET /health
```

#### User Management
```
GET    /api/users           # List local users
POST   /api/users           # Create user locally
GET    /api/users/{username} # Get specific user
DELETE /api/users/{username} # Delete user
```

#### Sync Endpoints
```
POST /api/sync/users       # Receive sync from management
```

## Configuration

### End-Node Configuration (`endnode-config.json`)
```json
{
  "server_id": "endnode-1",
  "management_url": "http://management-server:8080",
  "api_key": "your-api-key",
  "database": {
    "host": "management-server",
    "port": 5432,
    "user": "vpnmanager",
    "password": "your-password",
    "dbname": "vpnmanager",
    "sslmode": "disable"
  }
}
```

### Management Configuration (`management-config.json`)
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

## Database Schema

### Users Table
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    active BOOLEAN DEFAULT true,
    ovpn_path TEXT,
    port INTEGER DEFAULT 1194,
    protocol VARCHAR(10) DEFAULT 'udp',
    last_access TIMESTAMP,
    checksum VARCHAR(255),
    synced BOOLEAN DEFAULT false,
    server_id VARCHAR(255) NOT NULL,
    created_by VARCHAR(255) NOT NULL
);
```

### Servers Table
```sql
CREATE TABLE servers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    host VARCHAR(255) NOT NULL,
    port INTEGER DEFAULT 8080,
    username VARCHAR(255),
    password VARCHAR(255),
    enabled BOOLEAN DEFAULT true,
    last_sync TIMESTAMP,
    server_type VARCHAR(50) DEFAULT 'endnode',
    management_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Audit Log Table
```sql
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    action VARCHAR(255) NOT NULL,
    username VARCHAR(255),
    details TEXT,
    ip_address INET,
    server_id VARCHAR(255) NOT NULL
);
```

## Deployment

### Docker Deployment (Recommended)

```yaml
# docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: vpnmanager
      POSTGRES_USER: vpnmanager
      POSTGRES_PASSWORD: your_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  management:
    build: .
    command: ./bin/vpnmanager-management
    environment:
      DB_HOST: postgres
      DB_USER: vpnmanager
      DB_PASSWORD: your_password
      DB_NAME: vpnmanager
      API_KEY: your-secret-api-key
    ports:
      - "8080:8080"
    depends_on:
      - postgres

volumes:
  postgres_data:
```

### Systemd Services

#### Management Server Service
```ini
[Unit]
Description=VPN Manager Management Server
After=network.target

[Service]
Type=simple
User=vpnmanager
WorkingDirectory=/opt/vpnmanager
ExecStart=/opt/vpnmanager/bin/vpnmanager-management
Restart=always
RestartSec=5
Environment=DB_HOST=localhost
Environment=DB_USER=vpnmanager
Environment=DB_PASSWORD=your_password
Environment=DB_NAME=vpnmanager
Environment=API_KEY=your-secret-api-key

[Install]
WantedBy=multi-user.target
```

#### End-Node Service
```ini
[Unit]
Description=VPN Manager End-Node
After=network.target

[Service]
Type=simple
User=vpnmanager
WorkingDirectory=/opt/vpnmanager
ExecStart=/opt/vpnmanager/bin/vpnmanager-endnode -server-id server-1
Restart=always
RestartSec=5
Environment=MANAGEMENT_URL=http://management-server:8080
Environment=API_KEY=your-secret-api-key
Environment=DB_HOST=management-server
Environment=DB_USER=vpnmanager
Environment=DB_PASSWORD=your_password
Environment=DB_NAME=vpnmanager

[Install]
WantedBy=multi-user.target
```

## Benefits of New Architecture

1. **Centralized Database**: Single source of truth eliminates sync issues
2. **Separation of Concerns**: End-nodes handle local operations, management handles coordination
3. **Scalability**: Easy to add new end-nodes
4. **Reliability**: Health monitoring and automatic failover
5. **Audit Trail**: Complete audit log of all operations
6. **Real-time Sync**: Changes propagate immediately across all nodes

## Migration from Old Architecture

1. **Backup existing data** from SQLite databases
2. **Setup PostgreSQL** database
3. **Deploy management server** first
4. **Migrate user data** to PostgreSQL
5. **Deploy end-node applications** on each VPN server
6. **Test sync functionality**
7. **Decommission old sync system**

## Troubleshooting

### Common Issues

1. **Database Connection Issues**
   - Check PostgreSQL is running
   - Verify connection parameters
   - Check firewall rules

2. **End-Node Registration Issues**
   - Verify management server is accessible
   - Check API key configuration
   - Review network connectivity

3. **Sync Issues**
   - Check end-node health status
   - Verify database connectivity
   - Review audit logs

### Logs and Monitoring

- **Management Server**: Check `/var/log/vpnmanager/management.log`
- **End-Node Servers**: Check `/var/log/vpnmanager/endnode.log`
- **Database**: Check PostgreSQL logs in `/var/log/postgresql/`
- **Audit Logs**: Query `audit_log` table in database

## Support

For issues and questions:
1. Check the audit logs in the database
2. Review application logs
3. Verify network connectivity between components
4. Check database connection and permissions
