#!/bin/bash

# VPN Manager - End-Node Setup Script for Ubuntu
# This script sets up a complete end-node environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VPNMANAGER_USER="vpnmanager"
VPNMANAGER_HOME="/opt/vpnmanager"
VPNMANAGER_LOG="/var/log/vpnmanager"
SERVER_ID=""
MANAGEMENT_URL=""
API_KEY=""
ENDPOINT_PORT="8080"

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
    log_info "Checking for previous VPN Manager installation..."
    
    # Stop and disable services
    if systemctl is-active --quiet vpnmanager-endnode; then
        log_info "Stopping existing end-node service..."
        systemctl stop vpnmanager-endnode
        systemctl disable vpnmanager-endnode
    fi
    
    if systemctl is-active --quiet vpnmanager-management; then
        log_info "Stopping existing management service..."
        systemctl stop vpnmanager-management
        systemctl disable vpnmanager-management
    fi
    
    # Remove systemd services
    if [[ -f "/etc/systemd/system/vpnmanager-endnode.service" ]]; then
        log_info "Removing end-node service..."
        systemctl daemon-reload
        rm -f /etc/systemd/system/vpnmanager-endnode.service
    fi
    
    if [[ -f "/etc/systemd/system/vpnmanager-management.service" ]]; then
        log_info "Removing management service..."
        systemctl daemon-reload
        rm -f /etc/systemd/system/vpnmanager-management.service
    fi
    
    # Stop OpenVPN server
    if systemctl is-active --quiet openvpn@server; then
        log_info "Stopping OpenVPN server..."
        systemctl stop openvpn@server
        systemctl disable openvpn@server
    fi
    
    # Remove OpenVPN server files
    log_info "Removing OpenVPN server files..."
    rm -f /etc/openvpn/server.conf
    rm -f /etc/openvpn/ca.crt
    rm -f /etc/openvpn/server.crt
    rm -f /etc/openvpn/server.key
    rm -f /etc/openvpn/dh.pem
    rm -f /etc/openvpn/ta.key
    rm -f /etc/openvpn/tls-crypt.key
    rm -f /etc/openvpn/ipp.txt
    rm -f /etc/openvpn/openvpn-status.log
    rm -f /run/openvpn/server.pid
    rm -f /run/openvpn/server.status
    
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
    
    # Remove additional directories
    rm -rf /var/lib/vpnmanager
    rm -rf /opt/vpnmanager
    rm -rf /tmp/vpnmanager
    
    # Remove cron jobs
    if crontab -u "$VPNMANAGER_USER" -l &>/dev/null; then
        log_info "Removing VPN Manager cron jobs..."
        crontab -u "$VPNMANAGER_USER" -r 2>/dev/null || true
    fi
    
    # Remove firewall rules (optional - be careful)
    log_info "Cleaning up firewall rules..."
    ufw --force delete allow "$ENDPOINT_PORT/tcp" 2>/dev/null || true
    ufw --force delete allow 1194/udp 2>/dev/null || true
    # Remove API port rules
    ufw --force delete allow "$ENDPOINT_PORT/tcp" 2>/dev/null || true
    
    # Clean up any remaining processes
    pkill -f vpnmanager-endnode 2>/dev/null || true
    pkill -f vpnmanager-management 2>/dev/null || true
    pkill -f openvpn 2>/dev/null || true
    
    # Remove any existing tunnel interfaces
    ip link delete tun0 2>/dev/null || true
    ip link delete tun1 2>/dev/null || true
    
    # Reload systemd and UFW
    systemctl daemon-reload
    ufw --force reload
    
    log_success "Previous installation cleaned up"
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
    log_info "VPN Manager End-Node Setup"
    echo "============================"
    echo
    
    # Get server ID
    while [[ -z "$SERVER_ID" ]]; do
        read -p "Enter server ID for this end-node (e.g., server-1, vpn-node-01): " SERVER_ID
        if [[ -z "$SERVER_ID" ]]; then
            log_error "Server ID cannot be empty"
        fi
    done
    
    # Get management URL
    while [[ -z "$MANAGEMENT_URL" ]]; do
        read -p "Enter management server URL (e.g., http://management-server:8080): " MANAGEMENT_URL
        if [[ -z "$MANAGEMENT_URL" ]]; then
            log_error "Management URL cannot be empty"
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
    
    # End-nodes don't need database credentials - they communicate via API only
    log_info "Note: End-nodes communicate with the management server via API only."
    log_info "No database credentials are needed for end-nodes."
    
    # Get endpoint port
    read -p "Enter end-node API port (default: 8080): " input_port
    if [[ -n "$input_port" ]]; then
        ENDPOINT_PORT="$input_port"
    fi
    
    echo
    log_info "Configuration Summary:"
    echo "  Server ID: $SERVER_ID"
    echo "  Management URL: $MANAGEMENT_URL"
    echo "  API Key: [CONFIGURED]"
    echo "  End-Node Port: $ENDPOINT_PORT"
    echo "  Installation Path: $VPNMANAGER_HOME"
    echo
    log_info "Note: End-nodes communicate with the management server via API only."
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
    
    # Ensure required packages are installed
    log_info "Installing essential packages..."
    apt-get install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates
    
    log_success "System updated"
}

install_dependencies() {
    log_info "Installing dependencies..."
    
    # Note: End-nodes don't need database access - they only create OVPN files
    
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
    apt-get install -y curl wget git build-essential ufw cron openssl easy-rsa openvpn iproute2 iptables net-tools
    
    # Enable IP forwarding for VPN
    log_info "Enabling IP forwarding..."
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    sysctl -p
    
    log_success "Dependencies installed"
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
    mkdir -p "$VPNMANAGER_HOME/clients"
    
    # Set permissions
    chown -R "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_HOME"
    chown -R "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_LOG"
    chmod 755 "$VPNMANAGER_HOME"
    chmod 755 "$VPNMANAGER_LOG"
    
    log_success "User and directories created"
}

build_application() {
    log_info "Building VPN Manager End-Node application..."
    
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
    go build -o "$VPNMANAGER_HOME/bin/vpnmanager-endnode" ./apps/endnode/
    
    # Set permissions
    chown "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_HOME/bin/vpnmanager-endnode"
    chmod +x "$VPNMANAGER_HOME/bin/vpnmanager-endnode"
    
    log_success "End-node application built"
}

create_config() {
    log_info "Creating configuration files..."
    
    # End-node configuration
    cat > "$VPNMANAGER_HOME/config/endnode-config.json" << EOF
{
  "server_id": "$SERVER_ID",
  "management_url": "$MANAGEMENT_URL",
  "api_key": "$API_KEY"
}
EOF
    
    # Environment file
    cat > "$VPNMANAGER_HOME/.env" << EOF
# VPN Manager End-Node Environment
SERVER_ID=$SERVER_ID
MANAGEMENT_URL=$MANAGEMENT_URL
API_KEY=$API_KEY
ENDPOINT_PORT=$ENDPOINT_PORT
EOF
    
    # Set permissions
    chown "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_HOME/config/endnode-config.json"
    chown "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_HOME/.env"
    chmod 600 "$VPNMANAGER_HOME/.env"
    
    log_success "Configuration files created"
}

create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat > /etc/systemd/system/vpnmanager-endnode.service << EOF
[Unit]
Description=VPN Manager End-Node
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$VPNMANAGER_HOME
ExecStart=$VPNMANAGER_HOME/bin/vpnmanager-endnode -server-id $SERVER_ID -config $VPNMANAGER_HOME/config/endnode-config.json
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
SyslogIdentifier=vpnmanager-endnode

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable vpnmanager-endnode.service
    
    log_success "Systemd service created"
}

setup_firewall() {
    log_info "Configuring firewall..."
    
    # Enable UFW if not already enabled
    ufw --force enable
    
    # Allow SSH
    ufw allow ssh
    
    # Allow end-node port
    ufw allow "$ENDPOINT_PORT/tcp"
    
    # Allow API port (same as end-node port)
    ufw allow "$ENDPOINT_PORT/tcp" comment "VPN Manager End-Node API"
    
    # Allow OpenVPN port
    ufw allow 1194/udp comment "OpenVPN Server"
    
    log_success "Firewall configured"
}

setup_easyrsa() {
    log_info "Setting up EasyRSA for certificate generation..."
    
    # Create EasyRSA directory
    mkdir -p "$VPNMANAGER_HOME/easyrsa"
    
    # Copy EasyRSA from system installation
    if [[ -d "/usr/share/easy-rsa" ]]; then
        cp -r /usr/share/easy-rsa/* "$VPNMANAGER_HOME/easyrsa/"
    elif [[ -d "/etc/easy-rsa" ]]; then
        cp -r /etc/easy-rsa/* "$VPNMANAGER_HOME/easyrsa/"
    else
        log_warning "EasyRSA not found in system directories"
        log_info "Please install easy-rsa package first"
        return
    fi
    
    # Make EasyRSA executable
    chmod +x "$VPNMANAGER_HOME/easyrsa/easyrsa"
    
    # Initialize PKI
    cd "$VPNMANAGER_HOME/easyrsa"
    ./easyrsa init-pki
    ./easyrsa build-ca nopass
    
    # Generate TLS-crypt key (more secure than tls-auth)
    openvpn --genkey secret /etc/openvpn/tls-crypt.key
    
    # Set proper ownership
    chown -R "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_HOME/easyrsa"
    
    # Set proper permissions for EasyRSA and PKI directories
    chmod 755 "$VPNMANAGER_HOME/easyrsa"
    chmod +x "$VPNMANAGER_HOME/easyrsa/easyrsa"
    
    # Set permissions for PKI directory and subdirectories
    chmod 755 "$VPNMANAGER_HOME/easyrsa/pki"
    chmod 644 "$VPNMANAGER_HOME/easyrsa/pki"/*.crt 2>/dev/null || true
    chmod 600 "$VPNMANAGER_HOME/easyrsa/pki"/*.key 2>/dev/null || true
    # TLS-crypt key is generated in /etc/openvpn/tls-crypt.key
    
    # Set permissions for PKI subdirectories
    if [[ -d "$VPNMANAGER_HOME/easyrsa/pki/private" ]]; then
        chmod 755 "$VPNMANAGER_HOME/easyrsa/pki/private"
        chmod 600 "$VPNMANAGER_HOME/easyrsa/pki/private"/* 2>/dev/null || true
    fi
    
    if [[ -d "$VPNMANAGER_HOME/easyrsa/pki/issued" ]]; then
        chmod 755 "$VPNMANAGER_HOME/easyrsa/pki/issued"
        chmod 644 "$VPNMANAGER_HOME/easyrsa/pki/issued"/* 2>/dev/null || true
    fi
    
    if [[ -d "$VPNMANAGER_HOME/easyrsa/pki/reqs" ]]; then
        chmod 755 "$VPNMANAGER_HOME/easyrsa/pki/reqs"
        chmod 644 "$VPNMANAGER_HOME/easyrsa/pki/reqs"/* 2>/dev/null || true
    fi
    
    # Create EasyRSA vars configuration file
    log_info "Creating EasyRSA vars configuration..."
    cat > "$VPNMANAGER_HOME/easyrsa/vars" << 'EOF'
# EasyRSA configuration for VPN Manager
# This file is sourced by EasyRSA to set default values

# Set default values
export KEY_SIZE=2048
export CA_EXPIRE=3650
export KEY_EXPIRE=3650
export KEY_COUNTRY="US"
export KEY_PROVINCE="CA"
export KEY_CITY="SanFrancisco"
export KEY_ORG="VPN Manager"
export KEY_EMAIL="admin@vpnmanager.local"
export KEY_OU="VPN Manager"
export KEY_NAME="VPN Manager CA"

# Set batch mode
export EASYRSA_BATCH=1

# Set PKI directory
export EASYRSA_PKI="/opt/vpnmanager/easyrsa/pki"

# Set OpenSSL configuration
export EASYRSA_OPENSSL="openssl"
EOF
    
    # Set proper ownership for vars file
    chown "$VPNMANAGER_USER:$VPNMANAGER_USER" "$VPNMANAGER_HOME/easyrsa/vars"
    chmod 644 "$VPNMANAGER_HOME/easyrsa/vars"
    
    log_success "EasyRSA vars configuration created"
    
    # Sync certificates with OpenVPN server
    log_info "Syncing certificates with OpenVPN server..."
    
    # Copy CA certificate to OpenVPN server
    if [[ -f "$VPNMANAGER_HOME/easyrsa/pki/ca.crt" ]]; then
        cp "$VPNMANAGER_HOME/easyrsa/pki/ca.crt" /etc/openvpn/ca.crt
        log_success "CA certificate synced to OpenVPN server"
    else
        log_warning "CA certificate not found, skipping sync"
    fi
    
    # TLS-crypt key is already generated in /etc/openvpn/tls-crypt.key
    if [[ -f "/etc/openvpn/tls-crypt.key" ]]; then
        log_success "TLS-crypt key already available"
    else
        log_warning "TLS-crypt key not found, this may cause issues"
    fi
    
    # Generate server certificate if it doesn't exist
    if [[ ! -f "$VPNMANAGER_HOME/easyrsa/pki/issued/server.crt" ]]; then
        log_info "Generating server certificate..."
        cd "$VPNMANAGER_HOME/easyrsa"
        ./easyrsa gen-req server nopass
        ./easyrsa sign-req server server
        log_success "Server certificate generated"
    fi
    
    # Copy server certificate and key to OpenVPN server
    if [[ -f "$VPNMANAGER_HOME/easyrsa/pki/issued/server.crt" ]]; then
        cp "$VPNMANAGER_HOME/easyrsa/pki/issued/server.crt" /etc/openvpn/server.crt
        cp "$VPNMANAGER_HOME/easyrsa/pki/private/server.key" /etc/openvpn/server.key
        log_success "Server certificate and key synced to OpenVPN server"
    else
        log_warning "Server certificate not found, skipping sync"
    fi
    
    # Generate initial Certificate Revocation List (CRL)
    log_info "Generating initial Certificate Revocation List..."
    cd "$VPNMANAGER_HOME/easyrsa"
    export EASYRSA_PKI="$VPNMANAGER_HOME/easyrsa/pki"
    ./easyrsa gen-crl
    cp "$VPNMANAGER_HOME/easyrsa/pki/crl.pem" /etc/openvpn/crl.pem
    chown root:root /etc/openvpn/crl.pem
    chmod 644 /etc/openvpn/crl.pem
    log_success "Initial CRL generated"
    
    # Set proper permissions for OpenVPN certificates
    chown root:root /etc/openvpn/ca.crt /etc/openvpn/server.crt /etc/openvpn/server.key /etc/openvpn/tls-crypt.key /etc/openvpn/crl.pem
    chmod 644 /etc/openvpn/ca.crt /etc/openvpn/server.crt /etc/openvpn/crl.pem
    chmod 600 /etc/openvpn/server.key /etc/openvpn/tls-crypt.key
    
    # Note: OpenVPN server restart will be handled in setup_openvpn_server
    
    log_success "EasyRSA setup complete"
}

setup_openvpn_server() {
    log_info "Setting up OpenVPN server..."
    
    # Create OpenVPN server configuration
    log_info "Creating OpenVPN server configuration..."
    if cat << 'EOF' | sudo tee /etc/openvpn/server.conf > /dev/null
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-crypt /etc/openvpn/tls-crypt.key
cipher AES-256-CBC
auth SHA256
crl-verify /etc/openvpn/crl.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
persist-key
persist-tun
status openvpn-status.log
verb 3
explicit-exit-notify 1
EOF
    then
        log_success "OpenVPN server configuration created"
    else
        log_error "Failed to create OpenVPN server configuration"
        return 1
    fi
    
    # Generate Diffie-Hellman parameters
    log_info "Generating Diffie-Hellman parameters..."
    if [[ ! -f /etc/openvpn/dh.pem ]]; then
        if sudo openssl dhparam -out /etc/openvpn/dh.pem 2048; then
            log_success "Diffie-Hellman parameters generated"
        else
            log_error "Failed to generate Diffie-Hellman parameters"
            return 1
        fi
    else
        log_info "Diffie-Hellman parameters already exist"
    fi
    
    # Verify server configuration file was created
    if [[ -f /etc/openvpn/server.conf ]]; then
        log_success "OpenVPN server configuration created successfully"
    else
        log_error "Failed to create OpenVPN server configuration"
        return 1
    fi
    
    # Verify DH parameters file was created
    if [[ -f /etc/openvpn/dh.pem ]]; then
        log_success "Diffie-Hellman parameters file created successfully"
    else
        log_error "Failed to create Diffie-Hellman parameters file"
        return 1
    fi
    
    # Set proper permissions for OpenVPN configuration
    sudo chown root:root /etc/openvpn/server.conf
    sudo chmod 644 /etc/openvpn/server.conf
    
    # Enable IP forwarding for VPN routing
    log_info "Enabling IP forwarding..."
    echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl -p
    
    # Configure iptables rules for VPN traffic
    log_info "Configuring iptables rules for VPN traffic..."
    
    # Detect the main network interface
    MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -z "$MAIN_INTERFACE" ]]; then
        # Fallback to common interface names
        for iface in ens18 ens33 eth0 enp0s3; do
            if ip link show "$iface" >/dev/null 2>&1; then
                MAIN_INTERFACE="$iface"
                break
            fi
        done
    fi
    
    if [[ -z "$MAIN_INTERFACE" ]]; then
        log_warning "Could not detect main network interface, using ens18 as default"
        MAIN_INTERFACE="ens18"
    else
        log_info "Detected main network interface: $MAIN_INTERFACE"
    fi
    
    # Clear any existing rules that might conflict
    sudo iptables -t nat -F POSTROUTING
    
    # Add MASQUERADE rule for VPN traffic (10.8.0.0/24)
    sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$MAIN_INTERFACE" -j MASQUERADE
    
    # Add FORWARD rules for VPN traffic
    sudo iptables -A FORWARD -s 10.8.0.0/24 -j ACCEPT
    sudo iptables -A FORWARD -d 10.8.0.0/24 -j ACCEPT
    
    # Create iptables directory and save rules
    sudo mkdir -p /etc/iptables
    sudo iptables-save > /etc/iptables/rules.v4
    
    # Create systemd service to restore iptables rules on boot
    sudo tee /etc/systemd/system/iptables-restore.service > /dev/null << 'EOF'
[Unit]
Description=Restore iptables rules
Before=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables/rules.v4
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable iptables restore service
    sudo systemctl enable iptables-restore.service
    
    log_success "iptables rules configured for VPN traffic (10.8.0.0/24)"
    
    # Enable and start OpenVPN server
    log_info "Enabling OpenVPN server..."
    sudo systemctl enable openvpn@server
    sudo systemctl start openvpn@server
    
    if sudo systemctl is-active --quiet openvpn@server; then
        log_success "OpenVPN server started successfully"
    else
        log_warning "OpenVPN server failed to start, check configuration"
        sudo systemctl status openvpn@server
    fi
    
    log_success "OpenVPN server setup complete"
}

test_management_server() {
    log_info "Testing management server connection..."
    
    # Extract management host and port
    MANAGEMENT_HOST=$(echo "$MANAGEMENT_URL" | sed 's|http://||' | sed 's|https://||' | cut -d: -f1)
    MANAGEMENT_PORT=$(echo "$MANAGEMENT_URL" | sed 's|http://||' | sed 's|https://||' | cut -d: -f2)
    
    # Test HTTP connection
    if curl -s --connect-timeout 10 "$MANAGEMENT_URL/health" > /dev/null; then
        log_success "Management server connection successful"
    else
        log_warning "Failed to connect to management server. Please check:"
        echo "  - Management URL: $MANAGEMENT_URL"
        echo "  - Network connectivity to management server"
        echo "  - Management server is running"
        echo
        read -p "Continue anyway? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    fi
}

start_services() {
    log_info "Starting services..."
    
    # Start end-node service
    systemctl start vpnmanager-endnode
    systemctl enable vpnmanager-endnode
    
    # Wait a moment for service to start
    sleep 3
    
    # Check if service is running
    if systemctl is-active --quiet vpnmanager-endnode; then
        log_success "End-node service started successfully"
    else
        log_error "Failed to start end-node service"
        systemctl status vpnmanager-endnode
        exit 1
    fi
}

show_status() {
    log_info "VPN Manager End-Node Status"
    echo "============================="
    echo
    
    # Service status
    echo "Service Status:"
    systemctl status vpnmanager-endnode --no-pager
    echo
    
    # Port status
    echo "Port Status:"
    netstat -tlnp | grep ":$ENDPOINT_PORT" || echo "Port $ENDPOINT_PORT not listening"
    echo
    
    # Logs
    echo "Recent Logs:"
    journalctl -u vpnmanager-endnode --no-pager -n 10
    echo
    
    log_success "End-node setup complete!"
    echo
    echo "End-node server running at: http://localhost:$ENDPOINT_PORT"
    echo "API endpoints available at: http://localhost:$ENDPOINT_PORT/api/"
    echo
    echo "Configuration files:"
    echo "  Main config: $VPNMANAGER_HOME/config/endnode-config.json"
    echo "  Environment: $VPNMANAGER_HOME/.env"
    echo
    echo "Logs:"
    echo "  Service logs: journalctl -u vpnmanager-endnode -f"
    echo "  Application logs: $VPNMANAGER_LOG/"
    echo
    echo "Management commands:"
    echo "  Start: systemctl start vpnmanager-endnode"
    echo "  Stop: systemctl stop vpnmanager-endnode"
    echo "  Restart: systemctl restart vpnmanager-endnode"
    echo "  Status: systemctl status vpnmanager-endnode"
    echo
    echo "This end-node will automatically register with the management server."
    echo "Check the management server logs to verify registration."
}

# Main execution
main() {
    log_info "Starting VPN Manager End-Node setup..."
    
    check_root
    # Step 1: Clean up all old configurations first
    cleanup_previous_installation
    recreate_directories
    
    # Step 2: Get user input and prepare system
    get_user_input
    update_system
    install_dependencies
    create_user
    build_application
    create_config
    create_systemd_service
    setup_firewall
    
    # Step 3: Start EasyRSA and OpenVPN last
    setup_easyrsa
    setup_openvpn_server
    test_management_server
    start_services
    show_status
}

# Run main function
main "$@"
