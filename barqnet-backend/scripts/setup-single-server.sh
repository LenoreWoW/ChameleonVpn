#!/bin/bash

# VPN Manager - Single Server Setup Script for Ubuntu
# This script sets up both database and management server on one machine

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
VPNMANAGER_USER="vpnmanager"
VPNMANAGER_HOME="/opt/vpnmanager"
VPNMANAGER_LOG="/var/log/vpnmanager"
DB_NAME="vpnmanager"
DB_USER="vpnmanager"
DB_PASSWORD=""
API_KEY=""
MANAGEMENT_PORT="8080"
SERVER_HOSTNAME=""

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              VPN Manager Single Server Setup                ║"
    echo "║                                                              ║"
    echo "║  This script will install:                                 ║"
    echo "║  • PostgreSQL Database                                      ║"
    echo "║  • Management Server                                        ║"
    echo "║  • Complete VPN Manager System                             ║"
    echo "║                                                              ║"
    echo "║  Perfect for:                                              ║"
    echo "║  • Small to medium deployments                             ║"
    echo "║  • Testing and development                                 ║"
    echo "║  • Centralized management                                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

cleanup_previous_installation() {
    log_info "Checking for previous VPN Manager installation..."
    
    # Stop and disable services
    if systemctl is-active --quiet vpnmanager-management; then
        log_info "Stopping existing management service..."
        systemctl stop vpnmanager-management
        systemctl disable vpnmanager-management
    fi
    
    if systemctl is-active --quiet vpnmanager-endnode; then
        log_info "Stopping existing end-node service..."
        systemctl stop vpnmanager-endnode
        systemctl disable vpnmanager-endnode
    fi
    
    # Remove systemd services
    if [[ -f "/etc/systemd/system/vpnmanager-management.service" ]]; then
        log_info "Removing management service..."
        systemctl daemon-reload
        rm -f /etc/systemd/system/vpnmanager-management.service
    fi
    
    if [[ -f "/etc/systemd/system/vpnmanager-endnode.service" ]]; then
        log_info "Removing end-node service..."
        systemctl daemon-reload
        rm -f /etc/systemd/system/vpnmanager-endnode.service
    fi
    
    # Remove VPN Manager user and directories
    if id "$VPNMANAGER_USER" &>/dev/null; then
        log_info "Removing VPN Manager user and directories..."
        userdel -r "$VPNMANAGER_USER" 2>/dev/null || true
    fi
    
    # Remove VPN Manager directories
    if [[ -d "$VPNMANAGER_HOME" ]]; then
        log_info "Removing VPN Manager installation directory..."
        rm -rf "$VPNMANAGER_HOME"
    fi
    
    if [[ -d "$VPNMANAGER_LOG" ]]; then
        log_info "Removing VPN Manager log directory..."
        rm -rf "$VPNMANAGER_LOG"
    fi
    
    # Remove cron jobs
    if crontab -u "$VPNMANAGER_USER" -l &>/dev/null; then
        log_info "Removing VPN Manager cron jobs..."
        crontab -u "$VPNMANAGER_USER" -r 2>/dev/null || true
    fi
    
    # Remove firewall rules (optional - be careful)
    log_info "Cleaning up firewall rules..."
    ufw --force delete allow "$MANAGEMENT_PORT/tcp" 2>/dev/null || true
    ufw --force delete allow 5432/tcp 2>/dev/null || true
    ufw --force delete allow 1194/udp 2>/dev/null || true
    # Remove API port rules
    ufw --force delete allow "$MANAGEMENT_PORT/tcp" 2>/dev/null || true
    
    # Clean up any remaining processes
    pkill -f vpnmanager-management 2>/dev/null || true
    pkill -f vpnmanager-endnode 2>/dev/null || true
    
    log_success "Previous installation cleaned up"
}

clear_database() {
    log_info "Clearing VPN Manager database..."
    
    # Check if PostgreSQL is running
    if ! systemctl is-active --quiet postgresql; then
        log_info "Starting PostgreSQL service..."
        systemctl start postgresql
    fi
    
    # Drop and recreate database
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        log_info "Dropping existing database..."
        sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;"
    fi
    
    # Drop and recreate user
    if sudo -u postgres psql -t -c "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER';" | grep -q 1; then
        log_info "Dropping existing user..."
        sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;"
    fi
    
    # Clear any existing data in related tables (if database exists)
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        log_info "Clearing existing data..."
        sudo -u postgres psql -d "$DB_NAME" -c "
            DROP TABLE IF EXISTS users CASCADE;
            DROP TABLE IF EXISTS servers CASCADE;
            DROP TABLE IF EXISTS audit_log CASCADE;
            DROP TABLE IF EXISTS server_health CASCADE;
        " 2>/dev/null || true
    fi
    
    log_success "Database cleared"
}

recreate_directories() {
    log_info "Recreating VPN Manager directories with proper permissions..."
    
    # Remove existing directories if they exist
    if [[ -d "$VPNMANAGER_HOME" ]]; then
        log_info "Removing existing VPN Manager home directory..."
        rm -rf "$VPNMANAGER_HOME"
    fi
    
    if [[ -d "$VPNMANAGER_LOG" ]]; then
        log_info "Removing existing VPN Manager log directory..."
        rm -rf "$VPNMANAGER_LOG"
    fi
    
    # Create directories with proper structure
    log_info "Creating VPN Manager directories..."
    mkdir -p "$VPNMANAGER_HOME"
    mkdir -p "$VPNMANAGER_LOG"
    mkdir -p "$VPNMANAGER_HOME/bin"
    mkdir -p "$VPNMANAGER_HOME/config"
    mkdir -p "$VPNMANAGER_HOME/logs"
    mkdir -p "$VPNMANAGER_HOME/backups"
    mkdir -p "$VPNMANAGER_HOME/clients"
    
    # Create additional directories for OVPN files
    mkdir -p "/var/lib/vpnmanager/clients"
    mkdir -p "/opt/vpnmanager/clients"
    
    # Set proper ownership
    if id "$VPNMANAGER_USER" &>/dev/null; then
        log_info "Setting directory ownership to $VPNMANAGER_USER..."
        chown -R "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_HOME"
        chown -R "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_LOG"
        chown -R "$VPNMANAGER_USER:$VPNMANAGER_USER" "/var/lib/vpnmanager"
        chown -R "$VPNMANAGER_USER:$VPNMANAGER_USER" "/opt/vpnmanager"
    fi
    
    # Set proper permissions
    log_info "Setting directory permissions..."
    chmod 755 "$VPNMANAGER_HOME"
    chmod 755 "$VPNMANAGER_LOG"
    chmod 755 "$VPNMANAGER_HOME/bin"
    chmod 755 "$VPNMANAGER_HOME/config"
    chmod 755 "$VPNMANAGER_HOME/logs"
    chmod 755 "$VPNMANAGER_HOME/backups"
    chmod 755 "$VPNMANAGER_HOME/clients"
    chmod 755 "/var/lib/vpnmanager"
    chmod 755 "/var/lib/vpnmanager/clients"
    chmod 755 "/opt/vpnmanager"
    chmod 755 "/opt/vpnmanager/clients"
    
    log_success "Directories recreated with proper permissions"
}

get_user_input() {
    echo
    log_info "VPN Manager Single Server Setup"
    echo "=================================="
    echo
    
    # Get server hostname/IP
    SERVER_HOSTNAME=$(hostname -I | awk '{print $1}')
    read -p "Enter server hostname/IP (default: $SERVER_HOSTNAME): " input_hostname
    if [[ -n "$input_hostname" ]]; then
        SERVER_HOSTNAME="$input_hostname"
    fi
    
    # Get database password
    while [[ -z "$DB_PASSWORD" ]]; do
        read -s -p "Enter PostgreSQL password for vpnmanager user: " DB_PASSWORD
        echo
        if [[ -z "$DB_PASSWORD" ]]; then
            log_error "Password cannot be empty"
        fi
    done
    
    # Get API key
    while [[ -z "$API_KEY" ]]; do
        read -s -p "Enter API key for authentication: " API_KEY
        echo
        if [[ -z "$API_KEY" ]]; then
            log_error "API key cannot be empty"
        fi
    done
    
    # Get management port
    read -p "Enter management server port (default: 8080): " input_port
    if [[ -n "$input_port" ]]; then
        MANAGEMENT_PORT="$input_port"
    fi
    
    echo
    log_info "Configuration Summary:"
    echo "  Server Hostname: $SERVER_HOSTNAME"
    echo "  Database: $DB_NAME"
    echo "  Database User: $DB_USER"
    echo "  Management Port: $MANAGEMENT_PORT"
    echo "  Installation Path: $VPNMANAGER_HOME"
    echo
    read -p "Continue with installation? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
}

update_system() {
    log_info "Updating system packages..."
    apt-get update
    apt-get upgrade -y
    log_success "System updated"
}

install_dependencies() {
    log_info "Installing dependencies..."
    
    # Install PostgreSQL
    apt-get install -y postgresql postgresql-contrib postgresql-client
    
    # Install Go
    if ! command -v go &> /dev/null; then
        log_info "Installing Go..."
        wget -O /tmp/go1.21.0.linux-amd64.tar.gz https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
        tar -C /usr/local -xzf /tmp/go1.21.0.linux-amd64.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
        export PATH=$PATH:/usr/local/go/bin
        rm /tmp/go1.21.0.linux-amd64.tar.gz
        log_success "Go installed"
    else
        log_info "Go already installed"
    fi
    
    # Install other dependencies
    apt-get install -y curl wget git build-essential ufw cron
    
    log_success "Dependencies installed"
}

setup_postgresql() {
    log_info "Setting up PostgreSQL database..."
    
    # Start PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    # Create database and user
    sudo -u postgres psql << EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
ALTER USER $DB_USER CREATEROLE;
\q
EOF
    
    # Grant additional permissions on the database
    sudo -u postgres psql -d "$DB_NAME" << EOF
-- Grant schema permissions
GRANT ALL ON SCHEMA public TO $DB_USER;

-- Grant permissions on existing objects
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO $DB_USER;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO $DB_USER;

\q
EOF
    
    # Find PostgreSQL configuration directory
    PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP '\d+\.\d+' | head -1)
    PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"
    
    # Check if the directory exists, if not try alternative locations
    if [[ ! -d "$PG_CONFIG_DIR" ]]; then
        # Try to find the actual PostgreSQL data directory
        PG_DATA_DIR=$(sudo -u postgres psql -t -c "SHOW data_directory;" | xargs)
        if [[ -n "$PG_DATA_DIR" ]]; then
            PG_CONFIG_DIR=$(dirname "$PG_DATA_DIR")
        else
            # Fallback to common locations
            for dir in /etc/postgresql/*/main /var/lib/postgresql/*/main; do
                if [[ -d "$dir" ]]; then
                    PG_CONFIG_DIR="$dir"
                    break
                fi
            done
        fi
    fi
    
    log_info "Using PostgreSQL config directory: $PG_CONFIG_DIR"
    
    PG_CONFIG="$PG_CONFIG_DIR/postgresql.conf"
    PG_HBA="$PG_CONFIG_DIR/pg_hba.conf"
    
    # Check if files exist
    if [[ ! -f "$PG_HBA" ]]; then
        log_warning "PostgreSQL configuration files not found in expected location"
        log_warning "PostgreSQL will use default configuration"
        log_warning "You may need to manually configure database access if needed"
    else
        # Allow local connections
        if ! grep -q "local.*$DB_NAME.*$DB_USER.*md5" "$PG_HBA"; then
            echo "local   $DB_NAME             $DB_USER                                md5" >> "$PG_HBA"
        fi
        
        # Allow host connections
        if ! grep -q "host.*$DB_NAME.*$DB_USER.*127.0.0.1.*md5" "$PG_HBA"; then
            echo "host    $DB_NAME             $DB_USER            127.0.0.1/32            md5" >> "$PG_HBA"
        fi
    fi
    
    # Restart PostgreSQL
    systemctl restart postgresql
    
    log_success "PostgreSQL configured"
}

create_database_schema() {
    log_info "Creating database schema..."
    
    # Create schema SQL
    cat > /tmp/vpnmanager_schema.sql << 'EOF'
-- Users table
CREATE TABLE IF NOT EXISTS users (
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

-- Servers table
CREATE TABLE IF NOT EXISTS servers (
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

-- Audit log table
CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    action VARCHAR(255) NOT NULL,
    username VARCHAR(255),
    details TEXT,
    ip_address INET,
    server_id VARCHAR(255) NOT NULL
);

-- Server health table
CREATE TABLE IF NOT EXISTS server_health (
    id SERIAL PRIMARY KEY,
    server_id VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    last_check TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    response_time_ms INTEGER,
    error_message TEXT
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(active);
CREATE INDEX IF NOT EXISTS idx_users_server_id ON users(server_id);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_server_id ON audit_log(server_id);
CREATE INDEX IF NOT EXISTS idx_servers_enabled ON servers(enabled);
CREATE INDEX IF NOT EXISTS idx_servers_type ON servers(server_type);
CREATE INDEX IF NOT EXISTS idx_server_health_server_id ON server_health(server_id);
CREATE INDEX IF NOT EXISTS idx_server_health_last_check ON server_health(last_check);

-- Grant permissions on new tables
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO vpnmanager;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO vpnmanager;
EOF
    
    # Execute schema
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -f /tmp/vpnmanager_schema.sql
    
    # Clean up
    rm /tmp/vpnmanager_schema.sql
    
    log_success "Database schema created"
}

create_user() {
    log_info "Creating vpnmanager user..."
    
    # Create user if doesn't exist
    if ! id "$VPNMANAGER_USER" &>/dev/null; then
        useradd -r -s /bin/false -d "$VPNMANAGER_HOME" "$VPNMANAGER_USER"
        log_success "User $VPNMANAGER_USER created"
    else
        log_info "User $VPNMANAGER_USER already exists"
    fi
    
    # Create directories
    mkdir -p "$VPNMANAGER_HOME"
    mkdir -p "$VPNMANAGER_LOG"
    mkdir -p "$VPNMANAGER_HOME/bin"
    mkdir -p "$VPNMANAGER_HOME/config"
    mkdir -p "$VPNMANAGER_HOME/logs"
    mkdir -p "$VPNMANAGER_HOME/backups"
    
    # Set permissions
    chown -R "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_HOME"
    chown -R "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_LOG"
    chmod 755 "$VPNMANAGER_HOME"
    chmod 755 "$VPNMANAGER_LOG"
    
    log_success "User and directories created"
}

build_application() {
    log_info "Building VPN Manager Management application..."
    
    # Set Go path
    export PATH=$PATH:/usr/local/go/bin
    export GOPATH=/opt/go
    export GOBIN=/usr/local/go/bin
    
    # Create GOPATH if it doesn't exist
    mkdir -p "$GOPATH"
    
    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    
    # Navigate to project directory
    cd "$PROJECT_ROOT"
    
    # Check if source code exists
    if [[ ! -f "go.mod" ]]; then
        log_error "VPN Manager source code not found in $PROJECT_ROOT"
        log_error "Please ensure you're running this script from the VPN Manager project directory"
        exit 1
    fi
    
    log_info "Building from source code in: $PROJECT_ROOT"
    
    # Download dependencies
    go mod download
    go mod tidy
    
    # Build the application
    go build -o "$VPNMANAGER_HOME/bin/vpnmanager-management" ./apps/management/
    
    # Set permissions
    chown "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_HOME/bin/vpnmanager-management"
    chmod +x "$VPNMANAGER_HOME/bin/vpnmanager-management"
    
    log_success "Management application built"
}

create_config() {
    log_info "Creating configuration files..."
    
    # Management configuration
    cat > "$VPNMANAGER_HOME/config/management-config.json" << EOF
{
  "server_id": "management-server",
  "api_key": "$API_KEY",
  "database": {
    "host": "localhost",
    "port": 5432,
    "user": "$DB_USER",
    "password": "$DB_PASSWORD",
    "dbname": "$DB_NAME",
    "sslmode": "disable"
  }
}
EOF
    
    # Environment file
    cat > "$VPNMANAGER_HOME/.env" << EOF
# VPN Manager Management Server Environment
DB_HOST=localhost
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_NAME=$DB_NAME
DB_SSLMODE=disable
API_KEY=$API_KEY
MANAGEMENT_PORT=$MANAGEMENT_PORT
SERVER_HOSTNAME=$SERVER_HOSTNAME
EOF
    
    # Set permissions
    chown "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_HOME/config/management-config.json"
    chown "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_HOME/.env"
    chmod 600 "$VPNMANAGER_HOME/.env"
    
    log_success "Configuration files created"
}

create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat > /etc/systemd/system/vpnmanager-management.service << EOF
[Unit]
Description=VPN Manager Management Server
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=$VPNMANAGER_USER
Group=$VPNMANAGER_USER
WorkingDirectory=$VPNMANAGER_HOME
ExecStart=$VPNMANAGER_HOME/bin/vpnmanager-management -config $VPNMANAGER_HOME/config/management-config.json
Restart=always
RestartSec=5
EnvironmentFile=$VPNMANAGER_HOME/.env

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$VPNMANAGER_HOME $VPNMANAGER_LOG

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=vpnmanager-management

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable vpnmanager-management.service
    
    log_success "Systemd service created"
}

setup_backup() {
    log_info "Setting up database backup..."
    
    # Create backup script
    cat > "$VPNMANAGER_HOME/backups/backup.sh" << EOF
#!/bin/bash
# VPN Manager Database Backup Script

BACKUP_DIR="$VPNMANAGER_HOME/backups"
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="\$BACKUP_DIR/vpnmanager_backup_\$DATE.sql"

# Create backup
PGPASSWORD="$DB_PASSWORD" pg_dump -h localhost -U \$DB_USER -d \$DB_NAME > \$BACKUP_FILE

# Compress backup
gzip \$BACKUP_FILE

# Remove backups older than 7 days
find \$BACKUP_DIR -name "vpnmanager_backup_*.sql.gz" -mtime +7 -delete

echo "Backup completed: \$BACKUP_FILE.gz"
EOF
    
    chmod +x "$VPNMANAGER_HOME/backups/backup.sh"
    chown "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_HOME/backups/backup.sh"
    
    # Create cron job for daily backups
    if command -v crontab &> /dev/null; then
        echo "0 2 * * * $VPNMANAGER_HOME/backups/backup.sh" | crontab -u "$VPNMANAGER_USER" -
        log_success "Cron job created for daily backups"
    else
        log_warning "crontab command not found. Please manually set up daily backups:"
        echo "  Add this line to crontab for user $VPNMANAGER_USER:"
        echo "  0 2 * * * $VPNMANAGER_HOME/backups/backup.sh"
    fi
    
    log_success "Database backup configured"
}

setup_firewall() {
    log_info "Configuring firewall..."
    
    # Enable UFW if not already enabled
    ufw --force enable
    
    # Allow SSH
    ufw allow ssh
    
    # Allow management port
    ufw allow "$MANAGEMENT_PORT/tcp"
    
    # Allow PostgreSQL (if needed for remote connections)
    ufw allow 5432/tcp
    
    # Allow OpenVPN port (if using standard port)
    ufw allow 1194/udp
    
    # Allow API port (same as management port)
    ufw allow "$MANAGEMENT_PORT/tcp" comment "VPN Manager API"
    
    log_success "Firewall configured"
}

start_services() {
    log_info "Starting services..."
    
    # Start PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    # Start management service
    systemctl start vpnmanager-management
    systemctl enable vpnmanager-management
    
    # Wait a moment for service to start
    sleep 3
    
    # Check if service is running
    if systemctl is-active --quiet vpnmanager-management; then
        log_success "Management service started successfully"
    else
        log_error "Failed to start management service"
        systemctl status vpnmanager-management
        exit 1
    fi
}

test_system() {
    log_info "Testing system..."
    
    # Test database connection
    if PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
        log_success "Database connection successful"
    else
        log_error "Database connection failed"
        exit 1
    fi
    
    # Test management server
    if curl -s --connect-timeout 10 "http://localhost:$MANAGEMENT_PORT/health" > /dev/null; then
        log_success "Management server is responding"
    else
        log_error "Management server is not responding"
        exit 1
    fi
    
    log_success "System tests passed"
}

show_status() {
    log_info "VPN Manager Single Server Status"
    echo "=================================="
    echo
    
    # Service status
    echo "Service Status:"
    systemctl status vpnmanager-management --no-pager
    echo
    
    # Database status
    echo "Database Status:"
    systemctl status postgresql --no-pager
    echo
    
    # Port status
    echo "Port Status:"
    netstat -tlnp | grep ":$MANAGEMENT_PORT" || echo "Port $MANAGEMENT_PORT not listening"
    echo
    
    # Database info
    echo "Database Information:"
    echo "  Host: localhost"
    echo "  Port: 5432"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    echo
    
    # Connection test
    echo "Connection Test:"
    if PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 'Database connected' as status;" 2>/dev/null; then
        echo "  ✓ Database connection successful"
    else
        echo "  ✗ Database connection failed"
    fi
    echo
    
    # API test
    echo "API Test:"
    if curl -s "http://localhost:$MANAGEMENT_PORT/health" | grep -q "healthy"; then
        echo "  ✓ Management API is healthy"
    else
        echo "  ✗ Management API is not responding"
    fi
    echo
    
    # Logs
    echo "Recent Logs:"
    journalctl -u vpnmanager-management --no-pager -n 10
    echo
    
    log_success "Single server setup complete!"
    echo
    echo "Management server running at: http://$SERVER_HOSTNAME:$MANAGEMENT_PORT"
    echo "API endpoints available at: http://$SERVER_HOSTNAME:$MANAGEMENT_PORT/api/"
    echo
    echo "Configuration files:"
    echo "  Main config: $VPNMANAGER_HOME/config/management-config.json"
    echo "  Environment: $VPNMANAGER_HOME/.env"
    echo
    echo "Logs:"
    echo "  Service logs: journalctl -u vpnmanager-management -f"
    echo "  Application logs: $VPNMANAGER_LOG/"
    echo
    echo "Management commands:"
    echo "  Start: systemctl start vpnmanager-management"
    echo "  Stop: systemctl stop vpnmanager-management"
    echo "  Restart: systemctl restart vpnmanager-management"
    echo "  Status: systemctl status vpnmanager-management"
    echo
    echo "Database commands:"
    echo "  Connect: psql -h localhost -U $DB_USER -d $DB_NAME"
    echo "  Backup: $VPNMANAGER_HOME/backups/backup.sh"
    echo
    echo "Next steps:"
    echo "  1. Test the management server: curl http://$SERVER_HOSTNAME:$MANAGEMENT_PORT/health"
    echo "  2. Set up end-node servers using: bash scripts/setup-endnode.sh"
    echo "  3. Configure end-nodes to connect to: http://$SERVER_HOSTNAME:$MANAGEMENT_PORT"
}

# Main execution
main() {
    show_banner
    check_root
    cleanup_previous_installation
    clear_database
    recreate_directories
    get_user_input
    update_system
    install_dependencies
    setup_postgresql
    create_database_schema
    create_user
    build_application
    create_config
    create_systemd_service
    setup_backup
    setup_firewall
    start_services
    test_system
    show_status
}

# Run main function
main "$@"
