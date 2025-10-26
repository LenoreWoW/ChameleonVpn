#!/bin/bash

# VPN Manager - Database Setup Script for Ubuntu
# This script sets up PostgreSQL database for VPN Manager

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DB_NAME="vpnmanager"
DB_USER="vpnmanager"
DB_PASSWORD=""
DB_HOST="localhost"
DB_PORT="5432"

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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

cleanup_previous_installation() {
    log_info "Checking for previous VPN Manager database installation..."
    
    # Drop database if it exists
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        log_info "Dropping existing database..."
        sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;"
    fi
    
    # Drop user if it exists
    if sudo -u postgres psql -t -c "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER';" | grep -q 1; then
        log_info "Dropping existing user..."
        sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;"
    fi
    
    # Remove backup directory and files
    if [[ -d "/opt/vpnmanager/backups" ]]; then
        log_info "Removing backup directory..."
        rm -rf /opt/vpnmanager/backups
    fi
    
    # Remove cron jobs for postgres user
    if crontab -u postgres -l &>/dev/null; then
        log_info "Removing database backup cron jobs..."
        crontab -u postgres -r 2>/dev/null || true
    fi
    
    log_success "Previous database installation cleaned up"
}

get_user_input() {
    echo
    log_info "VPN Manager Database Setup"
    echo "============================"
    echo
    
    # Get database password
    while [[ -z "$DB_PASSWORD" ]]; do
        read -s -p "Enter PostgreSQL password for $DB_USER user: " DB_PASSWORD
        echo
        if [[ -z "$DB_PASSWORD" ]]; then
            log_error "Password cannot be empty"
        fi
    done
    
    # Get database host
    read -p "Enter database host (default: localhost): " input_host
    if [[ -n "$input_host" ]]; then
        DB_HOST="$input_host"
    fi
    
    # Get database port
    read -p "Enter database port (default: 5432): " input_port
    if [[ -n "$input_port" ]]; then
        DB_PORT="$input_port"
    fi
    
    echo
    log_info "Configuration Summary:"
    echo "  Database Host: $DB_HOST"
    echo "  Database Port: $DB_PORT"
    echo "  Database Name: $DB_NAME"
    echo "  Database User: $DB_USER"
    echo
    read -p "Continue with database setup? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Database setup cancelled"
        exit 0
    fi
}

install_postgresql() {
    log_info "Installing PostgreSQL..."
    
    # Update package list
    apt-get update
    
    # Install PostgreSQL
    apt-get install -y postgresql postgresql-contrib postgresql-client cron
    
    # Start and enable PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    log_success "PostgreSQL installed and started"
}

configure_postgresql() {
    log_info "Configuring PostgreSQL..."
    
    # Get PostgreSQL version
    PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP '\d+\.\d+' | head -1)
    PG_CONFIG="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
    
    log_info "PostgreSQL version: $PG_VERSION"
    
    # Configure postgresql.conf
    if [[ -f "$PG_CONFIG" ]]; then
        # Enable logging
        sed -i "s/#log_statement = 'none'/log_statement = 'all'/" "$PG_CONFIG"
        sed -i "s/#log_line_prefix = ''/log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '/" "$PG_CONFIG"
        
        # Set connection limits
        sed -i "s/#max_connections = 100/max_connections = 200/" "$PG_CONFIG"
        
        # Set shared_buffers
        sed -i "s/#shared_buffers = 128MB/shared_buffers = 256MB/" "$PG_CONFIG"
        
        log_success "PostgreSQL configuration updated"
    else
        log_warning "PostgreSQL configuration file not found: $PG_CONFIG"
    fi
    
    # Configure pg_hba.conf for local connections
    if [[ -f "$PG_HBA" ]]; then
        # Add local connections for vpnmanager user
        if ! grep -q "local.*$DB_NAME.*$DB_USER.*md5" "$PG_HBA"; then
            echo "local   $DB_NAME             $DB_USER                                md5" >> "$PG_HBA"
            log_success "Added local connection rule to pg_hba.conf"
        else
            log_info "Local connection rule already exists"
        fi
        
        # Add host connections (for remote access)
        if ! grep -q "host.*$DB_NAME.*$DB_USER.*127.0.0.1.*md5" "$PG_HBA"; then
            echo "host    $DB_NAME             $DB_USER            127.0.0.1/32            md5" >> "$PG_HBA"
            log_success "Added host connection rule to pg_hba.conf"
        else
            log_info "Host connection rule already exists"
        fi
    else
        log_warning "pg_hba.conf file not found: $PG_HBA"
    fi
    
    # Restart PostgreSQL to apply changes
    systemctl restart postgresql
    
    log_success "PostgreSQL configured"
}

create_database() {
    log_info "Creating database and user..."
    
    # Create database and user
    sudo -u postgres psql << EOF
-- Create database
CREATE DATABASE $DB_NAME;

-- Create user
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
ALTER USER $DB_USER CREATEROLE;

-- Connect to the database and grant schema privileges
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO $DB_USER;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO $DB_USER;

\q
EOF
    
    log_success "Database and user created"
}

create_schema() {
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
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f /tmp/vpnmanager_schema.sql
    
    # Clean up
    rm /tmp/vpnmanager_schema.sql
    
    log_success "Database schema created"
}

test_connection() {
    log_info "Testing database connection..."
    
    # Test connection
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
        log_success "Database connection successful"
    else
        log_error "Failed to connect to database"
        exit 1
    fi
    
    # Test table creation
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM users;" > /dev/null 2>&1; then
        log_success "Database schema verified"
    else
        log_error "Database schema verification failed"
        exit 1
    fi
}

setup_backup() {
    log_info "Setting up database backup..."
    
    # Create backup directory
    mkdir -p /opt/vpnmanager/backups
    chown postgres:postgres /opt/vpnmanager/backups
    
    # Create backup script
    cat > /opt/vpnmanager/backups/backup.sh << EOF
#!/bin/bash
# VPN Manager Database Backup Script

BACKUP_DIR="/opt/vpnmanager/backups"
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_HOST="$DB_HOST"
DB_PORT="$DB_PORT"
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="\$BACKUP_DIR/vpnmanager_backup_\$DATE.sql"

# Create backup
PGPASSWORD="$DB_PASSWORD" pg_dump -h \$DB_HOST -p \$DB_PORT -U \$DB_USER -d \$DB_NAME > \$BACKUP_FILE

# Compress backup
gzip \$BACKUP_FILE

# Remove backups older than 7 days
find \$BACKUP_DIR -name "vpnmanager_backup_*.sql.gz" -mtime +7 -delete

echo "Backup completed: \$BACKUP_FILE.gz"
EOF
    
    chmod +x /opt/vpnmanager/backups/backup.sh
    chown postgres:postgres /opt/vpnmanager/backups/backup.sh
    
    # Create cron job for daily backups
    if command -v crontab &> /dev/null; then
        echo "0 2 * * * /opt/vpnmanager/backups/backup.sh" | crontab -u postgres -
        log_success "Cron job created for daily backups"
    else
        log_warning "crontab command not found. Please manually set up daily backups:"
        echo "  Add this line to crontab for user postgres:"
        echo "  0 2 * * * /opt/vpnmanager/backups/backup.sh"
    fi
    
    log_success "Database backup configured"
}

show_status() {
    log_info "Database Setup Complete"
    echo "========================"
    echo
    
    # Database status
    echo "PostgreSQL Status:"
    systemctl status postgresql --no-pager
    echo
    
    # Database info
    echo "Database Information:"
    echo "  Host: $DB_HOST"
    echo "  Port: $DB_PORT"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    echo
    
    # Connection test
    echo "Connection Test:"
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 'Connection successful' as status;" 2>/dev/null; then
        echo "  ✓ Database connection successful"
    else
        echo "  ✗ Database connection failed"
    fi
    echo
    
    # Tables info
    echo "Database Tables:"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "\dt" 2>/dev/null || echo "  Failed to list tables"
    echo
    
    echo "Backup Information:"
    echo "  Backup script: /opt/vpnmanager/backups/backup.sh"
    echo "  Backup directory: /opt/vpnmanager/backups/"
    echo "  Cron job: Daily at 2:00 AM"
    echo
    
    echo "Connection String:"
    echo "  postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME"
    echo
    
    log_success "Database setup complete!"
    echo
    echo "You can now run the management server setup script."
    echo "Use the following connection details:"
    echo "  Host: $DB_HOST"
    echo "  Port: $DB_PORT"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    echo "  Password: [hidden]"
}

# Main execution
main() {
    log_info "Starting VPN Manager Database setup..."
    
    check_root
    cleanup_previous_installation
    get_user_input
    install_postgresql
    configure_postgresql
    create_database
    create_schema
    test_connection
    setup_backup
    show_status
}

# Run main function
main "$@"
