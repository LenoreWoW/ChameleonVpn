#!/bin/bash
# Extract Certificate Pins Script
# Extracts SHA-256 public key pins from certificates for certificate pinning

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "$1"
}

# Check for required tools
check_requirements() {
    if ! command -v openssl &> /dev/null; then
        print_error "openssl is not installed. Please install it first."
        exit 1
    fi
    print_success "All required tools are available"
}

# Extract pin from a server
extract_pin_from_server() {
    local SERVER=$1
    local PORT=${2:-443}

    print_info "\n${BLUE}Extracting pin from:${NC} $SERVER:$PORT"

    # Get certificate chain
    local CERT_CHAIN=$(openssl s_client -connect "$SERVER:$PORT" -servername "$SERVER" < /dev/null 2>/dev/null)

    if [ $? -ne 0 ]; then
        print_error "Failed to connect to $SERVER:$PORT"
        return 1
    fi

    # Extract leaf certificate
    local LEAF_CERT=$(echo "$CERT_CHAIN" | openssl x509 -outform PEM 2>/dev/null)

    if [ -z "$LEAF_CERT" ]; then
        print_error "Failed to extract certificate from $SERVER"
        return 1
    fi

    # Extract public key and calculate pin
    local PIN=$(echo "$LEAF_CERT" | openssl x509 -pubkey -noout | \
                openssl pkey -pubin -outform der | \
                openssl dgst -sha256 -binary | \
                base64)

    if [ -z "$PIN" ]; then
        print_error "Failed to calculate pin for $SERVER"
        return 1
    fi

    print_success "Pin extracted: sha256/$PIN"

    # Extract certificate info
    local SUBJECT=$(echo "$LEAF_CERT" | openssl x509 -subject -noout | sed 's/subject=//')
    local ISSUER=$(echo "$LEAF_CERT" | openssl x509 -issuer -noout | sed 's/issuer=//')
    local NOT_AFTER=$(echo "$LEAF_CERT" | openssl x509 -enddate -noout | sed 's/notAfter=//')

    print_info "  Subject: $SUBJECT"
    print_info "  Issuer: $ISSUER"
    print_info "  Expires: $NOT_AFTER"

    # Return pin for use in scripts
    echo "sha256/$PIN"
}

# Extract pin from a PEM file
extract_pin_from_file() {
    local FILE=$1

    if [ ! -f "$FILE" ]; then
        print_error "File not found: $FILE"
        return 1
    fi

    print_info "\n${BLUE}Extracting pin from file:${NC} $FILE"

    # Calculate pin
    local PIN=$(openssl x509 -in "$FILE" -pubkey -noout | \
                openssl pkey -pubin -outform der | \
                openssl dgst -sha256 -binary | \
                base64)

    if [ -z "$PIN" ]; then
        print_error "Failed to calculate pin from file"
        return 1
    fi

    print_success "Pin extracted: sha256/$PIN"

    # Extract certificate info
    local SUBJECT=$(openssl x509 -in "$FILE" -subject -noout | sed 's/subject=//')
    local ISSUER=$(openssl x509 -in "$FILE" -issuer -noout | sed 's/issuer=//')
    local NOT_AFTER=$(openssl x509 -in "$FILE" -enddate -noout | sed 's/notAfter=//')

    print_info "  Subject: $SUBJECT"
    print_info "  Issuer: $ISSUER"
    print_info "  Expires: $NOT_AFTER"

    echo "sha256/$PIN"
}

# Get pins for common Let's Encrypt intermediate CAs
get_letsencrypt_pins() {
    print_header "Let's Encrypt Certificate Pins"

    print_info "\nThese are backup pins for Let's Encrypt intermediate CAs."
    print_info "Use these as backup pins if your API uses Let's Encrypt certificates."
    print_info ""

    # Let's Encrypt R3 (current primary intermediate)
    # This is a well-known intermediate CA certificate
    print_info "${GREEN}Let's Encrypt R3 (Primary Intermediate):${NC}"
    print_info "sha256/jQJTbIh0grw0/1TkHSumWb+Fs0Ggogr621gT3PvPKG0="

    # Let's Encrypt E1 (ECDSA intermediate)
    print_info "\n${GREEN}Let's Encrypt E1 (ECDSA Intermediate):${NC}"
    print_info "sha256/VQYeFC8zhEDLrcyYYWBvPTfM5VWhTzfhEHQ9L5wBaB0="

    # ISRG Root X1 (Let's Encrypt root)
    print_info "\n${GREEN}ISRG Root X1 (Let's Encrypt Root):${NC}"
    print_info "sha256/C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M="

    print_info "\n${YELLOW}Note:${NC} These are intermediate/root CA pins. You should ALSO pin your"
    print_info "specific leaf certificate for maximum security."
}

# Get pins for DigiCert intermediate CAs
get_digicert_pins() {
    print_header "DigiCert Certificate Pins"

    print_info "\nThese are backup pins for DigiCert intermediate CAs."
    print_info "Use these as backup pins if your API uses DigiCert certificates."
    print_info ""

    # DigiCert Global Root G2
    print_info "${GREEN}DigiCert Global Root G2:${NC}"
    print_info "sha256/i7WTqTvh0OioIruIfFR4kMPnBqrS2rdiVPl/s2uC/CY="

    # DigiCert TLS RSA SHA256 2020 CA1
    print_info "\n${GREEN}DigiCert TLS RSA SHA256 2020 CA1:${NC}"
    print_info "sha256/RQeZkB42znUfsDIIFWWHm0nizHcVpsJNL8Qgg6iEvto="
}

# Interactive mode
interactive_mode() {
    print_header "Certificate Pin Extraction Tool"

    check_requirements

    echo ""
    print_info "What would you like to do?"
    print_info ""
    print_info "1) Extract pin from a server (e.g., api.example.com)"
    print_info "2) Extract pin from a certificate file (.pem, .crt)"
    print_info "3) Show Let's Encrypt backup pins"
    print_info "4) Show DigiCert backup pins"
    print_info "5) Extract from your API server (uses API_BASE_URL from .env)"
    print_info "0) Exit"
    print_info ""

    read -p "Enter your choice [0-5]: " CHOICE

    case $CHOICE in
        1)
            read -p "Enter server hostname (e.g., api.example.com): " SERVER
            read -p "Enter port [443]: " PORT
            PORT=${PORT:-443}
            extract_pin_from_server "$SERVER" "$PORT"
            ;;
        2)
            read -p "Enter certificate file path: " FILE
            extract_pin_from_file "$FILE"
            ;;
        3)
            get_letsencrypt_pins
            ;;
        4)
            get_digicert_pins
            ;;
        5)
            if [ -f ".env" ]; then
                API_URL=$(grep "^API_BASE_URL=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
                if [ -n "$API_URL" ]; then
                    # Extract hostname from URL
                    HOSTNAME=$(echo "$API_URL" | sed -E 's|https?://([^:/]+).*|\1|')
                    if [ "$HOSTNAME" != "localhost" ] && [ "$HOSTNAME" != "127.0.0.1" ]; then
                        extract_pin_from_server "$HOSTNAME" 443
                    else
                        print_error "API_BASE_URL points to localhost. Cannot extract pin from local server."
                        print_info "Please use a production HTTPS URL."
                    fi
                else
                    print_error "API_BASE_URL not found in .env"
                fi
            else
                print_error ".env file not found"
            fi
            ;;
        0)
            print_info "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac

    echo ""
    print_info "${YELLOW}Usage in .env file:${NC}"
    print_info "CERT_PIN_PRIMARY=sha256/YOUR_PRIMARY_PIN_HERE"
    print_info "CERT_PIN_BACKUP=sha256/YOUR_BACKUP_PIN_HERE"
}

# Main execution
if [ $# -eq 0 ]; then
    # No arguments, run interactive mode
    interactive_mode
elif [ "$1" == "--server" ] && [ -n "$2" ]; then
    # Extract from server
    check_requirements
    extract_pin_from_server "$2" "${3:-443}"
elif [ "$1" == "--file" ] && [ -n "$2" ]; then
    # Extract from file
    check_requirements
    extract_pin_from_file "$2"
elif [ "$1" == "--letsencrypt" ]; then
    # Show Let's Encrypt pins
    get_letsencrypt_pins
elif [ "$1" == "--digicert" ]; then
    # Show DigiCert pins
    get_digicert_pins
elif [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    print_header "Certificate Pin Extraction Tool - Help"
    echo ""
    print_info "Usage:"
    print_info "  $0                              # Interactive mode"
    print_info "  $0 --server <hostname> [port]   # Extract from server"
    print_info "  $0 --file <cert.pem>            # Extract from file"
    print_info "  $0 --letsencrypt                # Show Let's Encrypt pins"
    print_info "  $0 --digicert                   # Show DigiCert pins"
    print_info "  $0 --help                       # Show this help"
    echo ""
    print_info "Examples:"
    print_info "  $0 --server api.example.com"
    print_info "  $0 --server api.example.com 443"
    print_info "  $0 --file /path/to/certificate.pem"
    print_info "  $0 --letsencrypt"
else
    print_error "Invalid arguments. Use --help for usage information."
    exit 1
fi
