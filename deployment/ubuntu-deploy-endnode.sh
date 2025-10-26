#!/bin/bash
###############################################################################
# BarqNet End-Node VPN Server - Ubuntu Deployment Script
#
# This script automatically deploys a BarqNet VPN End-Node server on Ubuntu.
# It installs OpenVPN, configures PKI, and sets up the VPN service.
#
# Requirements:
#   - Ubuntu 20.04 LTS or newer
#   - Root or sudo access
#   - Internet connection
#   - Management Server already deployed
#
# Usage:
#   sudo bash ubuntu-deploy-endnode.sh
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
OPENVPN_DIR="/etc/openvpn"
EASYRSA_DIR="/etc/openvpn/easy-rsa"

# VPN Configuration
VPN_PORT="1194"
VPN_PROTOCOL="udp"
VPN_SUBNET="10.8.0.0"
VPN_NETMASK="255.255.255.0"

# API Configuration
API_PORT="8081"

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

prompt_input() {
    local prompt_text="$1"
    local var_name="$2"
    local default_value="$3"

    if [ -n "$default_value" ]; then
        read -p "$(echo -e ${BLUE}[INPUT]${NC}) $prompt_text [$default_value]: " input_value
        eval $var_name="${input_value:-$default_value}"
    else
        read -p "$(echo -e ${BLUE}[INPUT]${NC}) $prompt_text: " input_value
        eval $var_name="$input_value"
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

log_info "Starting BarqNet End-Node VPN Server deployment..."
echo ""

###############################################################################
# Step 0: Collect Configuration Information
###############################################################################

log_info "Step 0: Configuration Setup"
echo ""
log_info "Please provide the following information:"
echo ""

# Server ID
SERVER_ID="endnode-$(hostname)"
prompt_input "Server ID (unique identifier)" SERVER_ID "$SERVER_ID"

# Management Server URL
prompt_input "Management Server URL (e.g., http://192.168.1.100:8080)" MGMT_SERVER_URL ""

# API Key (should match Management Server)
prompt_input "API Key (shared with Management Server)" API_KEY ""

# Database Configuration
prompt_input "Database Host (Management Server IP)" DB_HOST ""
prompt_input "Database Port" DB_PORT "5432"
prompt_input "Database Name" DB_NAME "barqnet"
prompt_input "Database User" DB_USER "barqnet"
prompt_input "Database Password" DB_PASSWORD ""

# VPN Configuration
prompt_input "VPN Port" VPN_PORT "$VPN_PORT"
prompt_input "VPN Protocol (udp/tcp)" VPN_PROTOCOL "$VPN_PROTOCOL"
prompt_input "VPN Subnet (e.g., 10.8.0.0)" VPN_SUBNET "$VPN_SUBNET"

# Server public IP
PUBLIC_IP=$(curl -s ifconfig.me)
prompt_input "Server Public IP" PUBLIC_IP "$PUBLIC_IP"

# Server location (for client display)
prompt_input "Server Location (e.g., US-East, EU-West)" SERVER_LOCATION ""

echo ""
log_success "Configuration collected"
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

# Install OpenVPN and Easy-RSA
log_info "Installing OpenVPN and Easy-RSA..."
apt install -y openvpn easy-rsa
log_success "OpenVPN and Easy-RSA installed"

# Install PostgreSQL client (to connect to remote database)
log_info "Installing PostgreSQL client..."
apt install -y postgresql-client
log_success "PostgreSQL client installed"

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
apt install -y git curl wget ufw iptables-persistent
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
# Step 4: Set Up Easy-RSA PKI
###############################################################################

log_info "Step 4: Setting up PKI with Easy-RSA..."

# Initialize Easy-RSA
mkdir -p $EASYRSA_DIR
cp -r /usr/share/easy-rsa/* $EASYRSA_DIR/

cd $EASYRSA_DIR

# Create PKI
./easyrsa init-pki
log_success "PKI initialized"

# Build CA
log_info "Building Certificate Authority..."
./easyrsa --batch build-ca nopass
log_success "CA built"

# Generate server certificate
log_info "Generating server certificate..."
./easyrsa --batch build-server-full server nopass
log_success "Server certificate generated"

# Generate Diffie-Hellman parameters
log_info "Generating Diffie-Hellman parameters (this may take a while)..."
./easyrsa gen-dh
log_success "DH parameters generated"

# Generate TLS auth key
log_info "Generating TLS auth key..."
openvpn --genkey secret $OPENVPN_DIR/ta.key
log_success "TLS auth key generated"

# Generate CRL
log_info "Generating Certificate Revocation List..."
./easyrsa gen-crl
cp $EASYRSA_DIR/pki/crl.pem $OPENVPN_DIR/crl.pem
chmod 644 $OPENVPN_DIR/crl.pem
log_success "CRL generated"

echo ""

###############################################################################
# Step 5: Configure OpenVPN Server
###############################################################################

log_info "Step 5: Configuring OpenVPN server..."

# Create server configuration
cat > $OPENVPN_DIR/server.conf <<EOF
# BarqNet OpenVPN Server Configuration
# Generated on $(date)
# Server ID: $SERVER_ID

# Network settings
port $VPN_PORT
proto $VPN_PROTOCOL
dev tun

# Certificates
ca $EASYRSA_DIR/pki/ca.crt
cert $EASYRSA_DIR/pki/issued/server.crt
key $EASYRSA_DIR/pki/private/server.key
dh $EASYRSA_DIR/pki/dh.pem

# Certificate Revocation List
crl-verify $OPENVPN_DIR/crl.pem

# Network topology
server $VPN_SUBNET $VPN_NETMASK
topology subnet

# Client configuration
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"

# Client-to-client traffic
client-to-client

# Keepalive
keepalive 10 120

# Security
tls-auth $OPENVPN_DIR/ta.key 0
cipher AES-256-GCM
auth SHA256
tls-version-min 1.2

# User and group
user nobody
group nogroup

# Persist keys
persist-key
persist-tun

# Logging
status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log
verb 3
mute 20

# Management interface
management 127.0.0.1 7505
management-client-auth

# Client connect/disconnect scripts
script-security 2
client-connect /etc/openvpn/client-connect.sh
client-disconnect /etc/openvpn/client-disconnect.sh

# Maximum clients
max-clients 100

# Compression (disabled for security)
compress lz4-v2
push "compress lz4-v2"
EOF

log_success "OpenVPN server configured"

# Create log directory
mkdir -p /var/log/openvpn
chown -R $BARQNET_USER:$BARQNET_USER /var/log/openvpn

echo ""

###############################################################################
# Step 6: Enable IP Forwarding
###############################################################################

log_info "Step 6: Enabling IP forwarding..."

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Make permanent
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi

log_success "IP forwarding enabled"

echo ""

###############################################################################
# Step 7: Configure NAT and Firewall
###############################################################################

log_info "Step 7: Configuring NAT and firewall..."

# Get default network interface
DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)

# Configure NAT
iptables -t nat -A POSTROUTING -s $VPN_SUBNET/$VPN_NETMASK -o $DEFAULT_IFACE -j MASQUERADE

# Save iptables rules
netfilter-persistent save
log_success "NAT configured"

# Configure UFW
if ! ufw status | grep -q "Status: active"; then
    ufw --force enable
fi

# Allow SSH
ufw allow ssh
log_success "Allowed SSH"

# Allow OpenVPN
ufw allow $VPN_PORT/$VPN_PROTOCOL
log_success "Allowed OpenVPN port $VPN_PORT/$VPN_PROTOCOL"

# Allow End-Node API
ufw allow $API_PORT/tcp
log_success "Allowed API port $API_PORT"

# Allow forwarding
ufw default allow routed

ufw reload

log_success "Firewall configured"

echo ""

###############################################################################
# Step 8: Clone and Build Application
###############################################################################

log_info "Step 8: Cloning and building application..."

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

# Build End-Node Server
log_info "Building End-Node Server..."
/usr/local/go/bin/go build -o $INSTALL_DIR/barqnet-endnode ./apps/endnode
log_success "End-Node Server built successfully"

# Make executable
chmod +x $INSTALL_DIR/barqnet-endnode

# Copy scripts
log_info "Installing VPN management scripts..."
cp scripts/client-connect.sh $OPENVPN_DIR/client-connect.sh
cp scripts/client-disconnect.sh $OPENVPN_DIR/client-disconnect.sh
cp scripts/refresh-crl.sh $INSTALL_DIR/refresh-crl.sh
chmod +x $OPENVPN_DIR/client-connect.sh
chmod +x $OPENVPN_DIR/client-disconnect.sh
chmod +x $INSTALL_DIR/refresh-crl.sh
log_success "VPN scripts installed"

echo ""

###############################################################################
# Step 9: Create Configuration
###############################################################################

log_info "Step 9: Creating configuration..."

# Create config directory
mkdir -p $CONFIG_DIR

# Create configuration file
cat > $CONFIG_DIR/endnode-config.env <<EOF
# BarqNet End-Node Server Configuration
# Generated on $(date)

# Server Identity
SERVER_ID=$SERVER_ID
SERVER_LOCATION=$SERVER_LOCATION
PUBLIC_IP=$PUBLIC_IP

# Management Server
MANAGEMENT_URL=$MGMT_SERVER_URL
API_KEY=$API_KEY

# Database Configuration (connects to Management Server database)
DATABASE_URL=postgres://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME?sslmode=disable

# VPN Configuration
VPN_PORT=$VPN_PORT
VPN_PROTOCOL=$VPN_PROTOCOL
VPN_SUBNET=$VPN_SUBNET
VPN_NETMASK=$VPN_NETMASK

# API Configuration
PORT=$API_PORT

# Environment
ENVIRONMENT=production

# Logging
LOG_LEVEL=info

# OpenVPN Configuration
OPENVPN_DIR=$OPENVPN_DIR
EASYRSA_DIR=$EASYRSA_DIR

# Paths
INSTALL_DIR=$INSTALL_DIR
CONFIG_DIR=$CONFIG_DIR
LOG_DIR=$LOG_DIR
EOF

chmod 600 $CONFIG_DIR/endnode-config.env
chown $BARQNET_USER:$BARQNET_USER $CONFIG_DIR/endnode-config.env

log_success "Configuration file created: $CONFIG_DIR/endnode-config.env"

echo ""

###############################################################################
# Step 10: Create Systemd Services
###############################################################################

log_info "Step 10: Creating systemd services..."

# OpenVPN service (already exists, just enable)
systemctl enable openvpn@server
log_success "OpenVPN service enabled"

# End-Node API service
cat > /etc/systemd/system/barqnet-endnode.service <<EOF
[Unit]
Description=BarqNet End-Node Server
After=network.target openvpn@server.service
Wants=openvpn@server.service

[Service]
Type=simple
User=$BARQNET_USER
Group=$BARQNET_USER

# Working directory
WorkingDirectory=$INSTALL_DIR

# Environment file
EnvironmentFile=$CONFIG_DIR/endnode-config.env

# Start command
ExecStart=$INSTALL_DIR/barqnet-endnode

# Restart policy
Restart=always
RestartSec=10

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=barqnet-endnode

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$LOG_DIR $OPENVPN_DIR

# Resource limits
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

log_success "End-Node service created"

# CRL refresh service (cron job)
cat > /etc/cron.daily/barqnet-refresh-crl <<EOF
#!/bin/bash
# Refresh CRL daily
$INSTALL_DIR/refresh-crl.sh >> $LOG_DIR/crl-refresh.log 2>&1
EOF

chmod +x /etc/cron.daily/barqnet-refresh-crl
log_success "CRL refresh cron job created"

# Create log directory
mkdir -p $LOG_DIR
chown $BARQNET_USER:$BARQNET_USER $LOG_DIR

# Set ownership
chown -R $BARQNET_USER:$BARQNET_USER $INSTALL_DIR

# Reload systemd
systemctl daemon-reload

# Enable services
systemctl enable barqnet-endnode

log_success "Services enabled to start on boot"

echo ""

###############################################################################
# Step 11: Register with Management Server
###############################################################################

log_info "Step 11: Registering with Management Server..."

# Wait a moment for network
sleep 2

# Register end-node
REGISTER_RESPONSE=$(curl -s -X POST "$MGMT_SERVER_URL/api/endnodes/register" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $API_KEY" \
    -d "{\"server_id\":\"$SERVER_ID\",\"location\":\"$SERVER_LOCATION\",\"public_ip\":\"$PUBLIC_IP\",\"port\":$VPN_PORT,\"protocol\":\"$VPN_PROTOCOL\"}" \
    2>&1)

if echo "$REGISTER_RESPONSE" | grep -q "success\|registered"; then
    log_success "End-Node registered with Management Server"
else
    log_warning "Could not auto-register with Management Server"
    log_warning "Please register manually later"
fi

echo ""

###############################################################################
# Step 12: Start Services
###############################################################################

log_info "Step 12: Starting services..."

# Start OpenVPN
systemctl start openvpn@server
sleep 2

if systemctl is-active --quiet openvpn@server; then
    log_success "OpenVPN server started successfully!"
else
    log_error "Failed to start OpenVPN server"
    log_info "Check logs with: journalctl -u openvpn@server -f"
    exit 1
fi

# Start End-Node API
systemctl start barqnet-endnode
sleep 2

if systemctl is-active --quiet barqnet-endnode; then
    log_success "End-Node API server started successfully!"
else
    log_error "Failed to start End-Node API server"
    log_info "Check logs with: journalctl -u barqnet-endnode -f"
    exit 1
fi

echo ""

###############################################################################
# Step 13: Verify Installation
###############################################################################

log_info "Step 13: Verifying installation..."

# Test health endpoint
sleep 2
if curl -s http://localhost:$API_PORT/health | grep -q "healthy"; then
    log_success "API health check passed!"
else
    log_warning "API health check failed - server may still be starting"
fi

# Check OpenVPN status
if systemctl is-active --quiet openvpn@server; then
    log_success "OpenVPN server is running"
else
    log_warning "OpenVPN server is not running"
fi

echo ""

###############################################################################
# Installation Complete
###############################################################################

echo ""
echo "═══════════════════════════════════════════════════════════════"
log_success "BarqNet End-Node VPN Server Deployment Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📍 Installation Details:"
echo "   - Server ID: $SERVER_ID"
echo "   - Location: $SERVER_LOCATION"
echo "   - Public IP: $PUBLIC_IP"
echo "   - Installation Directory: $INSTALL_DIR"
echo "   - Configuration Directory: $CONFIG_DIR"
echo "   - Log Directory: $LOG_DIR"
echo ""
echo "🔐 VPN Configuration:"
echo "   - Port: $VPN_PORT"
echo "   - Protocol: $VPN_PROTOCOL"
echo "   - Subnet: $VPN_SUBNET/$VPN_NETMASK"
echo "   - Management Server: $MGMT_SERVER_URL"
echo ""
echo "🔧 Service Management:"
echo "   OpenVPN:"
echo "     - Start: sudo systemctl start openvpn@server"
echo "     - Stop: sudo systemctl stop openvpn@server"
echo "     - Status: sudo systemctl status openvpn@server"
echo "     - Logs: sudo journalctl -u openvpn@server -f"
echo ""
echo "   End-Node API:"
echo "     - Start: sudo systemctl start barqnet-endnode"
echo "     - Stop: sudo systemctl stop barqnet-endnode"
echo "     - Status: sudo systemctl status barqnet-endnode"
echo "     - Logs: sudo journalctl -u barqnet-endnode -f"
echo ""
echo "🌐 API Access:"
echo "   - Health: http://localhost:$API_PORT/health"
echo "   - Base URL: http://$PUBLIC_IP:$API_PORT"
echo ""
echo "📁 Important Files:"
echo "   - CA Certificate: $EASYRSA_DIR/pki/ca.crt"
echo "   - Server Cert: $EASYRSA_DIR/pki/issued/server.crt"
echo "   - TLS Auth Key: $OPENVPN_DIR/ta.key"
echo "   - CRL: $OPENVPN_DIR/crl.pem"
echo ""
echo "⚠️  IMPORTANT Next Steps:"
echo "   1. Verify registration with Management Server"
echo "   2. Create user certificates using Management API"
echo "   3. Test VPN connection from client"
echo "   4. Set up monitoring and alerts"
echo "   5. Configure automated backups"
echo "   6. Review and test CRL refresh (runs daily)"
echo ""
echo "🔨 Management Commands:"
echo "   - Create user certificate:"
echo "     curl -X POST $MGMT_SERVER_URL/api/users -d '{\"username\":\"user1\"}'"
echo ""
echo "   - Refresh CRL:"
echo "     sudo $INSTALL_DIR/refresh-crl.sh"
echo ""
echo "   - Check VPN connections:"
echo "     sudo cat /var/log/openvpn/openvpn-status.log"
echo ""
echo "📚 Documentation:"
echo "   - Full guide: UBUNTU_DEPLOYMENT_GUIDE.md"
echo "   - OpenVPN config: $OPENVPN_DIR/server.conf"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Save deployment info
cat > $INSTALL_DIR/deployment-info.txt <<EOF
BarqNet End-Node VPN Server Deployment
Deployed on: $(date)
Server ID: $SERVER_ID
Location: $SERVER_LOCATION
Public IP: $PUBLIC_IP
VPN Port: $VPN_PORT
VPN Protocol: $VPN_PROTOCOL
Management Server: $MGMT_SERVER_URL
API Port: $API_PORT
EOF

log_success "Deployment information saved to: $INSTALL_DIR/deployment-info.txt"
echo ""

exit 0
