#!/bin/bash
###############################################################################
# BarqNet Management Server - Ubuntu Deployment Script
#
# This script automatically deploys the BarqNet Management Server on Ubuntu.
# It installs all dependencies, configures the database, and sets up the service.
#
# Requirements:
#   - Ubuntu 20.04 LTS or newer
#   - Root or sudo access
#   - Internet connection
#
# Usage:
#   sudo bash ubuntu-deploy-management.sh
#
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BARQNET_USER="barqnet"
INSTALL_DIR="/opt/barqnet"
CONFIG_DIR="/etc/barqnet"
LOG_DIR="/var/log/barqnet"
DB_NAME="barqnet"
DB_USER="barqnet"
DB_PORT="5432"
API_PORT="8080"

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

log_info "Starting BarqNet Management Server deployment..."
echo ""

###############################################################################
# Step 1: System Update
###############################################################################

log_info "Step 1: Updating system packages..."
apt update
apt upgrade -y
log_success "System updated"
echo ""

###############################################################################
# Step 2: Install Dependencies
###############################################################################

log_info "Step 2: Installing dependencies..."

# Install PostgreSQL
log_info "Installing PostgreSQL..."
apt install -y postgresql postgresql-contrib
systemctl enable postgresql
systemctl start postgresql
log_success "PostgreSQL installed and started"

# Install Go
log_info "Installing Go 1.21..."
cd /tmp
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
rm -rf /usr/local/go
tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
rm go1.21.5.linux-amd64.tar.gz

# Add Go to PATH
if ! grep -q "/usr/local/go/bin" /etc/profile; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
fi
export PATH=$PATH:/usr/local/go/bin

log_success "Go 1.21 installed"

# Install other utilities
log_info "Installing utilities..."
apt install -y git curl wget ufw
log_success "Utilities installed"

echo ""

###############################################################################
# Step 3: Create System User
###############################################################################

log_info "Step 3: Creating system user..."

if id "$BARQNET_USER" &>/dev/null; then
    log_warning "User $BARQNET_USER already exists"
else
    useradd -r -s /bin/bash -d /home/$BARQNET_USER -m $BARQNET_USER
    log_success "User $BARQNET_USER created"
fi

echo ""

###############################################################################
# Step 4: Set Up PostgreSQL Database
###############################################################################

log_info "Step 4: Setting up PostgreSQL database..."

# Generate secure random password for database
DB_PASSWORD=$(openssl rand -base64 32)
log_info "Generated secure database password"

# Create database and user
sudo -u postgres psql <<EOF
-- Create database
CREATE DATABASE $DB_NAME;

-- Create user
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;

-- Grant schema privileges
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;

EOF

log_success "Database created: $DB_NAME"
log_success "Database user created: $DB_USER"

# Configure PostgreSQL to allow password authentication
PG_HBA="/etc/postgresql/$(ls /etc/postgresql | head -1)/main/pg_hba.conf"
if ! grep -q "host.*$DB_NAME.*$DB_USER.*md5" "$PG_HBA"; then
    echo "host    $DB_NAME    $DB_USER    127.0.0.1/32    md5" >> "$PG_HBA"
    systemctl restart postgresql
    log_success "PostgreSQL configured for password authentication"
fi

echo ""

###############################################################################
# Step 5: Clone and Build Application
###############################################################################

log_info "Step 5: Cloning and building application..."

# Create installation directory
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Clone repository
log_info "Cloning BarqNet repository..."
if [ -d "ChameleonVpn" ]; then
    log_warning "Repository already exists, pulling latest changes..."
    cd ChameleonVpn
    git pull origin main
else
    git clone https://github.com/LenoreWoW/ChameleonVpn.git
    cd ChameleonVpn
fi

cd barqnet-backend
log_success "Repository cloned/updated"

# Download Go dependencies
log_info "Downloading Go dependencies..."
/usr/local/go/bin/go mod download
log_success "Dependencies downloaded"

# Build Management Server
log_info "Building Management Server..."
/usr/local/go/bin/go build -o $INSTALL_DIR/barqnet-management ./apps/management
log_success "Management Server built successfully"

# Make executable
chmod +x $INSTALL_DIR/barqnet-management

echo ""

###############################################################################
# Step 6: Run Database Migrations
###############################################################################

log_info "Step 6: Running database migrations..."

cd migrations
DATABASE_URL="postgres://$DB_USER:$DB_PASSWORD@localhost:$DB_PORT/$DB_NAME?sslmode=disable" \
    /usr/local/go/bin/go run run_migrations.go

log_success "Database migrations completed"

echo ""

###############################################################################
# Step 7: Create Configuration
###############################################################################

log_info "Step 7: Creating configuration..."

# Create config directory
mkdir -p $CONFIG_DIR

# Generate JWT secret
JWT_SECRET=$(openssl rand -base64 64)

# Create configuration file
cat > $CONFIG_DIR/management-config.env <<EOF
# BarqNet Management Server Configuration
# Generated on $(date)

# Database Configuration
DATABASE_URL=postgres://$DB_USER:$DB_PASSWORD@localhost:$DB_PORT/$DB_NAME?sslmode=disable

# JWT Configuration
JWT_SECRET=$JWT_SECRET

# Server Configuration
PORT=$API_PORT

# Environment
ENVIRONMENT=production

# OTP Configuration (Twilio)
# IMPORTANT: Configure these for production SMS/OTP
# TWILIO_ACCOUNT_SID=your_account_sid
# TWILIO_AUTH_TOKEN=your_auth_token
# TWILIO_PHONE_NUMBER=+1234567890

# For testing only - remove in production
# ENABLE_OTP_CONSOLE=true

# CORS Configuration
# CORS_ALLOWED_ORIGINS=https://yourdomain.com

# Rate Limiting
# RATE_LIMIT_ENABLED=true
# RATE_LIMIT_REQUESTS=100
# RATE_LIMIT_WINDOW=60

# Logging
LOG_LEVEL=info
EOF

chmod 600 $CONFIG_DIR/management-config.env
chown $BARQNET_USER:$BARQNET_USER $CONFIG_DIR/management-config.env

log_success "Configuration file created: $CONFIG_DIR/management-config.env"

# Save credentials for reference
cat > $CONFIG_DIR/CREDENTIALS.txt <<EOF
BarqNet Management Server Credentials
Generated on $(date)

Database Name: $DB_NAME
Database User: $DB_USER
Database Password: $DB_PASSWORD
Database Port: $DB_PORT

JWT Secret: $JWT_SECRET

API Port: $API_PORT

IMPORTANT: Keep this file secure and delete it after noting the credentials!
EOF

chmod 600 $CONFIG_DIR/CREDENTIALS.txt
chown $BARQNET_USER:$BARQNET_USER $CONFIG_DIR/CREDENTIALS.txt

log_warning "Credentials saved to: $CONFIG_DIR/CREDENTIALS.txt"
log_warning "Please save these credentials and delete this file!"

echo ""

###############################################################################
# Step 8: Create Systemd Service
###############################################################################

log_info "Step 8: Creating systemd service..."

cat > /etc/systemd/system/barqnet-management.service <<EOF
[Unit]
Description=BarqNet Management Server
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=$BARQNET_USER
Group=$BARQNET_USER

# Working directory
WorkingDirectory=$INSTALL_DIR

# Environment file
EnvironmentFile=$CONFIG_DIR/management-config.env

# Start command
ExecStart=$INSTALL_DIR/barqnet-management

# Restart policy
Restart=always
RestartSec=10

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=barqnet-management

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$LOG_DIR

# Resource limits
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

log_success "Systemd service created"

# Create log directory
mkdir -p $LOG_DIR
chown $BARQNET_USER:$BARQNET_USER $LOG_DIR

# Set ownership
chown -R $BARQNET_USER:$BARQNET_USER $INSTALL_DIR

# Reload systemd
systemctl daemon-reload

# Enable service
systemctl enable barqnet-management

log_success "Service enabled to start on boot"

echo ""

###############################################################################
# Step 9: Configure Firewall
###############################################################################

log_info "Step 9: Configuring firewall..."

# Enable UFW if not already enabled
if ! ufw status | grep -q "Status: active"; then
    ufw --force enable
fi

# Allow SSH
ufw allow ssh
log_success "Allowed SSH"

# Allow API port
ufw allow $API_PORT/tcp
log_success "Allowed port $API_PORT (API)"

# Allow PostgreSQL only from localhost (already default)
log_success "PostgreSQL restricted to localhost"

ufw reload

log_success "Firewall configured"

echo ""

###############################################################################
# Step 10: Start Service
###############################################################################

log_info "Step 10: Starting BarqNet Management Server..."

systemctl start barqnet-management

# Wait a moment for service to start
sleep 3

# Check service status
if systemctl is-active --quiet barqnet-management; then
    log_success "BarqNet Management Server started successfully!"
else
    log_error "Failed to start BarqNet Management Server"
    log_info "Check logs with: journalctl -u barqnet-management -f"
    exit 1
fi

echo ""

###############################################################################
# Step 11: Verify Installation
###############################################################################

log_info "Step 11: Verifying installation..."

# Test health endpoint
sleep 2
if curl -s http://localhost:$API_PORT/api/health | grep -q "healthy"; then
    log_success "API health check passed!"
else
    log_warning "API health check failed - server may still be starting"
fi

echo ""

###############################################################################
# Installation Complete
###############################################################################

echo ""
echo "═══════════════════════════════════════════════════════════════"
log_success "BarqNet Management Server Deployment Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📍 Installation Details:"
echo "   - Installation Directory: $INSTALL_DIR"
echo "   - Configuration Directory: $CONFIG_DIR"
echo "   - Log Directory: $LOG_DIR"
echo "   - API Port: $API_PORT"
echo ""
echo "🔐 Credentials (SAVE THESE!):"
echo "   - Database: $DB_NAME"
echo "   - DB User: $DB_USER"
echo "   - DB Password: $DB_PASSWORD"
echo "   - Credentials file: $CONFIG_DIR/CREDENTIALS.txt"
echo ""
echo "🔧 Service Management:"
echo "   - Start: sudo systemctl start barqnet-management"
echo "   - Stop: sudo systemctl stop barqnet-management"
echo "   - Restart: sudo systemctl restart barqnet-management"
echo "   - Status: sudo systemctl status barqnet-management"
echo "   - Logs: sudo journalctl -u barqnet-management -f"
echo ""
echo "🌐 API Access:"
echo "   - Health: http://localhost:$API_PORT/api/health"
echo "   - Base URL: http://YOUR_SERVER_IP:$API_PORT"
echo ""
echo "⚠️  IMPORTANT Next Steps:"
echo "   1. Configure Twilio for production OTP (edit $CONFIG_DIR/management-config.env)"
echo "   2. Set up HTTPS/SSL certificate (recommended: Let's Encrypt + nginx)"
echo "   3. Update client apps to use production URL"
echo "   4. Save credentials from $CONFIG_DIR/CREDENTIALS.txt and DELETE the file"
echo "   5. Configure backup for PostgreSQL database"
echo ""
echo "📚 Documentation:"
echo "   - Full guide: UBUNTU_DEPLOYMENT_GUIDE.md"
echo "   - API docs: barqnet-backend/API_DOCUMENTATION.md"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Save deployment info
cat > $INSTALL_DIR/deployment-info.txt <<EOF
BarqNet Management Server Deployment
Deployed on: $(date)
Server IP: $(hostname -I | awk '{print $1}')
API Port: $API_PORT
Database: $DB_NAME
Service: barqnet-management
EOF

log_success "Deployment information saved to: $INSTALL_DIR/deployment-info.txt"
echo ""

exit 0
