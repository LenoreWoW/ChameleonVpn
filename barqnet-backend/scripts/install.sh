#!/bin/bash

# VPN Manager - Master Installation Script
# This script provides a menu-driven interface for setting up VPN Manager

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo "║                    VPN Manager Installer                     ║"
    echo "║                                                              ║"
    echo "║              Distributed Architecture Setup                 ║"
    echo "║                                                              ║"
    echo "║  This installer will help you set up VPN Manager with:     ║"
    echo "║  • Centralized PostgreSQL Database                         ║"
    echo "║  • Management Server (Central Coordination)                ║"
    echo "║  • End-Node Servers (Distributed VPN Servers)             ║"
    echo "║  • Real-time Synchronization                              ║"
    echo "║  • Health Monitoring                                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        echo "Please run: sudo $0"
        exit 1
    fi
}

show_menu() {
    echo
    echo -e "${PURPLE}VPN Manager Installation Menu${NC}"
    echo "================================="
    echo
    echo "1. Setup Database Only (PostgreSQL)"
    echo "2. Setup Management Server"
    echo "3. Setup End-Node Server"
    echo "4. Setup Complete System (Database + Management)"
    echo "5. Show System Status"
    echo "6. Show Help"
    echo "7. Exit"
    echo
}

setup_database() {
    log_info "Setting up PostgreSQL database..."
    bash "$SCRIPT_DIR/setup-database.sh"
}

setup_management() {
    log_info "Setting up Management Server..."
    bash "$SCRIPT_DIR/setup-management.sh"
}

setup_endnode() {
    log_info "Setting up End-Node Server..."
    bash "$SCRIPT_DIR/setup-endnode.sh"
}

setup_complete() {
    log_info "Setting up complete system (Database + Management)..."
    
    echo
    log_info "Step 1: Setting up database..."
    bash "$SCRIPT_DIR/setup-database.sh"
    
    echo
    log_info "Step 2: Setting up management server..."
    bash "$SCRIPT_DIR/setup-management.sh"
    
    log_success "Complete system setup finished!"
}

show_system_status() {
    log_info "VPN Manager System Status"
    echo "==========================="
    echo
    
    # Check PostgreSQL
    echo "PostgreSQL Status:"
    if systemctl is-active --quiet postgresql; then
        echo "  ✓ PostgreSQL is running"
    else
        echo "  ✗ PostgreSQL is not running"
    fi
    echo
    
    # Check Management Server
    echo "Management Server Status:"
    if systemctl is-active --quiet vpnmanager-management; then
        echo "  ✓ Management server is running"
        echo "  Port: $(netstat -tlnp | grep vpnmanager-management | awk '{print $4}' | cut -d: -f2)"
    else
        echo "  ✗ Management server is not running"
    fi
    echo
    
    # Check End-Node Servers
    echo "End-Node Servers Status:"
    if systemctl is-active --quiet vpnmanager-endnode; then
        echo "  ✓ End-node server is running"
        echo "  Port: $(netstat -tlnp | grep vpnmanager-endnode | awk '{print $4}' | cut -d: -f2)"
    else
        echo "  ✗ No end-node servers running"
    fi
    echo
    
    # Check Database Connection
    echo "Database Connection:"
    if command -v psql &> /dev/null; then
        if psql -h localhost -U vpnmanager -d vpnmanager -c "SELECT 1;" > /dev/null 2>&1; then
            echo "  ✓ Database connection successful"
        else
            echo "  ✗ Database connection failed"
        fi
    else
        echo "  ✗ PostgreSQL client not installed"
    fi
    echo
    
    # Show recent logs
    echo "Recent Management Server Logs:"
    journalctl -u vpnmanager-management --no-pager -n 5 2>/dev/null || echo "  No management server logs"
    echo
    
    echo "Recent End-Node Server Logs:"
    journalctl -u vpnmanager-endnode --no-pager -n 5 2>/dev/null || echo "  No end-node server logs"
    echo
}

show_help() {
    echo
    echo -e "${CYAN}VPN Manager Help${NC}"
    echo "================"
    echo
    echo "This installer provides several setup options:"
    echo
    echo -e "${YELLOW}1. Database Only${NC}"
    echo "   Sets up PostgreSQL database with VPN Manager schema"
    echo "   Use this on the database server"
    echo
    echo -e "${YELLOW}2. Management Server${NC}"
    echo "   Sets up the central management server"
    echo "   Connects to PostgreSQL database"
    echo "   Manages all end-node servers"
    echo
    echo -e "${YELLOW}3. End-Node Server${NC}"
    echo "   Sets up an end-node server"
    echo "   Connects to management server"
    echo "   Manages local VPN users"
    echo
    echo -e "${YELLOW}4. Complete System${NC}"
    echo "   Sets up both database and management server"
    echo "   Use this for a single-server deployment"
    echo
    echo -e "${YELLOW}Architecture Overview:${NC}"
    echo "┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐"
    echo "│   End-Node 1    │    │   End-Node 2    │    │   End-Node N    │"
    echo "│                 │    │                 │    │                 │"
    echo "│ - User Mgmt     │    │ - User Mgmt     │    │ - User Mgmt     │"
    echo "│ - Local API     │    │ - Local API     │    │ - Local API     │"
    echo "└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘"
    echo "          │                      │                      │"
    echo "          └──────────────────────┼──────────────────────┘"
    echo "                                 │"
    echo "                    ┌─────────────▼─────────────┐"
    echo "                    │    Management Server      │"
    echo "                    │                           │"
    echo "                    │ - Centralized Database    │"
    echo "                    │ - User Coordination       │"
    echo "                    │ - End-Node Monitoring     │"
    echo "                    └───────────────────────────┘"
    echo "                                 │"
    echo "                    ┌─────────────▼─────────────┐"
    echo "                    │    PostgreSQL Database   │"
    echo "                    │                           │"
    echo "                    │ - Users Table            │"
    echo "                    │ - Servers Table          │"
    echo "                    │ - Audit Log Table        │"
    echo "                    └───────────────────────────┘"
    echo
    echo -e "${YELLOW}Installation Order:${NC}"
    echo "1. Setup Database (on database server)"
    echo "2. Setup Management Server (on management server)"
    echo "3. Setup End-Node Servers (on each VPN server)"
    echo
    echo -e "${YELLOW}Requirements:${NC}"
    echo "• Ubuntu 18.04+ or Debian 10+"
    echo "• Root access"
    echo "• Internet connection"
    echo "• PostgreSQL (for database server)"
    echo "• Go 1.21+ (automatically installed)"
    echo
    echo -e "${YELLOW}Ports:${NC}"
    echo "• Management Server: 8080"
    echo "• End-Node Servers: 8080 (configurable)"
    echo "• PostgreSQL: 5432"
    echo "• OpenVPN: 1194/udp (standard)"
    echo
}

main_menu() {
    while true; do
        show_menu
        read -p "Select an option (1-7): " choice
        
        case $choice in
            1)
                setup_database
                ;;
            2)
                setup_management
                ;;
            3)
                setup_endnode
                ;;
            4)
                setup_complete
                ;;
            5)
                show_system_status
                ;;
            6)
                show_help
                ;;
            7)
                log_info "Exiting installer"
                exit 0
                ;;
            *)
                log_error "Invalid option. Please select 1-7."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Main execution
main() {
    show_banner
    check_root
    main_menu
}

# Run main function
main "$@"
