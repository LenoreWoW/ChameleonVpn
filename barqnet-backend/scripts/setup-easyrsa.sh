#!/bin/bash

# VPN Manager - EasyRSA Setup Script
# This script sets up EasyRSA for certificate generation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
EASYRSA_DIR="/opt/vpnmanager/easyrsa"
PKI_DIR="$EASYRSA_DIR/pki"
VPNMANAGER_USER="vpnmanager"

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

install_dependencies() {
    log_info "Installing dependencies..."
    
    # Update package list
    apt-get update
    
    # Install required packages
    apt-get install -y openssl easy-rsa
    
    log_success "Dependencies installed"
}

setup_easyrsa() {
    log_info "Setting up EasyRSA..."
    
    # Create EasyRSA directory
    mkdir -p "$EASYRSA_DIR"
    
    # Copy EasyRSA from system installation
    if [[ -d "/usr/share/easy-rsa" ]]; then
        cp -r /usr/share/easy-rsa/* "$EASYRSA_DIR/"
    elif [[ -d "/etc/easy-rsa" ]]; then
        cp -r /etc/easy-rsa/* "$EASYRSA_DIR/"
    else
        log_error "EasyRSA not found in system directories"
        log_info "Please install easy-rsa package first"
        exit 1
    fi
    
    # Make EasyRSA executable
    chmod +x "$EASYRSA_DIR/easyrsa"
    
    # Set proper ownership
    chown -R "$VPNMANAGER_USER:$VPNMANAGER_USER" "$EASYRSA_DIR"
    
    log_success "EasyRSA setup complete"
}

init_pki() {
    log_info "Initializing PKI..."
    
    # Navigate to EasyRSA directory
    cd "$EASYRSA_DIR"
    
    # Initialize PKI
    ./easyrsa init-pki
    
    # Build CA
    ./easyrsa build-ca nopass
    
    # Generate TLS auth key
    openvpn --genkey --secret pki/ta.key
    
    # Set proper ownership
    chown -R "$VPNMANAGER_USER:$VPNMANAGER_USER" "$PKI_DIR"
    
    log_success "PKI initialized"
}

create_server_cert() {
    log_info "Creating server certificate..."
    
    cd "$EASYRSA_DIR"
    
    # Generate server certificate request
    ./easyrsa gen-req server nopass
    
    # Sign server certificate
    ./easyrsa sign-req server server
    
    # Set proper ownership
    chown -R "$VPNMANAGER_USER:$VPNMANAGER_USER" "$PKI_DIR"
    
    log_success "Server certificate created"
}

test_certificate_generation() {
    log_info "Testing certificate generation..."
    
    cd "$EASYRSA_DIR"
    
    # Generate test client certificate
    ./easyrsa gen-req testclient nopass
    ./easyrsa sign-req client testclient
    
    # Check if files were created
    if [[ -f "$PKI_DIR/issued/testclient.crt" ]] && [[ -f "$PKI_DIR/private/testclient.key" ]]; then
        log_success "Certificate generation test passed"
        
        # Clean up test certificate
        rm -f "$PKI_DIR/issued/testclient.crt"
        rm -f "$PKI_DIR/private/testclient.key"
        rm -f "$PKI_DIR/reqs/testclient.req"
    else
        log_error "Certificate generation test failed"
        exit 1
    fi
}

setup_permissions() {
    log_info "Setting up permissions..."
    
    # Set proper ownership
    chown -R "$VPNMANAGER_USER:$VPNMANAGER_USER" "$EASYRSA_DIR"
    
    # Set proper permissions
    chmod 755 "$EASYRSA_DIR"
    chmod 700 "$PKI_DIR"
    chmod 600 "$PKI_DIR/private"/*
    chmod 644 "$PKI_DIR/issued"/*
    chmod 644 "$PKI_DIR/ca.crt"
    chmod 600 "$PKI_DIR/ta.key"
    
    log_success "Permissions set"
}

show_status() {
    log_info "EasyRSA Setup Status"
    echo "======================"
    echo
    
    echo "EasyRSA Directory: $EASYRSA_DIR"
    echo "PKI Directory: $PKI_DIR"
    echo
    
    echo "Files created:"
    ls -la "$PKI_DIR/"
    echo
    
    log_success "EasyRSA setup complete!"
    echo
    echo "Certificate generation commands:"
    echo "  Generate client cert: cd $EASYRSA_DIR && ./easyrsa gen-req <username> nopass"
    echo "  Sign client cert: cd $EASYRSA_DIR && ./easyrsa sign-req client <username>"
    echo
    echo "Certificate locations:"
    echo "  CA Certificate: $PKI_DIR/ca.crt"
    echo "  Client Certificate: $PKI_DIR/issued/<username>.crt"
    echo "  Client Private Key: $PKI_DIR/private/<username>.key"
    echo "  TLS Auth Key: $PKI_DIR/ta.key"
}

# Main execution
main() {
    log_info "Starting EasyRSA setup..."
    
    check_root
    install_dependencies
    setup_easyrsa
    init_pki
    create_server_cert
    test_certificate_generation
    setup_permissions
    show_status
}

# Run main function
main "$@"
