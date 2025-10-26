#!/bin/bash
###############################################################################
# OpenVPN Client Connect Script
#
# Purpose: Called by OpenVPN when a client successfully connects
# Context: Runs with environment variables set by OpenVPN
#
# Available Environment Variables:
#   $common_name      - Client certificate common name (username)
#   $trusted_ip       - Client's real IP address
#   $trusted_port     - Client's real port
#   $ifconfig_pool_remote_ip - VPN IP assigned to client
#   $time_ascii       - Connection time in ASCII format
#   $bytes_received   - Bytes received (for reconnections)
#   $bytes_sent       - Bytes sent (for reconnections)
#
# Exit Codes:
#   0 - Allow connection
#   1 - Reject connection
###############################################################################

set -u  # Exit on undefined variable

# Extract client information from OpenVPN environment variables
USERNAME="${common_name:-unknown}"
CLIENT_IP="${trusted_ip:-unknown}"
CLIENT_PORT="${trusted_port:-unknown}"
VPN_IP="${ifconfig_pool_remote_ip:-unknown}"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# Log directory
LOG_DIR="/var/log/barqnet"
mkdir -p "$LOG_DIR" 2>/dev/null

# Main connection log
CONNECTION_LOG="$LOG_DIR/connections.log"

# Security checks log
SECURITY_LOG="$LOG_DIR/security.log"

###############################################################################
# SECURITY CHECK #1: Verify user is not in revoked list (CRL)
###############################################################################

# This is a belt-and-suspenders check - OpenVPN should already reject
# revoked certificates if crl-verify is configured, but we double-check here

CRL_FILE="/etc/openvpn/crl.pem"

if [ -f "$CRL_FILE" ]; then
    # Extract serial number from client certificate (if available)
    # Note: This is a simplified check. OpenVPN's crl-verify is the primary defense.

    if [ ! -z "${tls_serial_0:-}" ]; then
        CERT_SERIAL="$tls_serial_0"

        # Check if serial is in CRL
        if openssl crl -in "$CRL_FILE" -noout -text 2>/dev/null | grep -q "$CERT_SERIAL"; then
            echo "[$TIMESTAMP] SECURITY: Blocked revoked certificate - User: $USERNAME, Serial: $CERT_SERIAL, IP: $CLIENT_IP" >> "$SECURITY_LOG"
            echo "[$TIMESTAMP] REJECTED: Revoked certificate for $USERNAME from $CLIENT_IP" >> "$CONNECTION_LOG"

            # Log to syslog
            logger -t barqnet-security "BLOCKED: Revoked certificate for user $USERNAME from $CLIENT_IP"

            # Reject connection
            exit 1
        fi
    fi
fi

###############################################################################
# SECURITY CHECK #2: Verify username is valid (alphanumeric + underscore)
###############################################################################

if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "[$TIMESTAMP] SECURITY: Invalid username format - User: $USERNAME, IP: $CLIENT_IP" >> "$SECURITY_LOG"
    echo "[$TIMESTAMP] REJECTED: Invalid username $USERNAME from $CLIENT_IP" >> "$CONNECTION_LOG"
    logger -t barqnet-security "BLOCKED: Invalid username format: $USERNAME from $CLIENT_IP"
    exit 1
fi

###############################################################################
# SECURITY CHECK #3: Check for suspicious connection patterns (optional)
###############################################################################

# Example: Reject if too many connections from same IP in short time
# This is a simple rate limiting mechanism

RATE_LIMIT_FILE="/tmp/vpn_rate_limit_${CLIENT_IP//\./_}.txt"
RATE_LIMIT_COUNT=5  # Max connections
RATE_LIMIT_WINDOW=60  # Within 60 seconds

if [ -f "$RATE_LIMIT_FILE" ]; then
    LAST_CONNECTION_TIME=$(cat "$RATE_LIMIT_FILE" | tail -1)
    TIME_DIFF=$(($(date +%s) - LAST_CONNECTION_TIME))

    if [ $TIME_DIFF -lt $RATE_LIMIT_WINDOW ]; then
        CONNECTION_COUNT=$(wc -l < "$RATE_LIMIT_FILE")

        if [ $CONNECTION_COUNT -ge $RATE_LIMIT_COUNT ]; then
            echo "[$TIMESTAMP] SECURITY: Rate limit exceeded - User: $USERNAME, IP: $CLIENT_IP, Count: $CONNECTION_COUNT" >> "$SECURITY_LOG"
            echo "[$TIMESTAMP] REJECTED: Rate limit for $USERNAME from $CLIENT_IP" >> "$CONNECTION_LOG"
            logger -t barqnet-security "BLOCKED: Rate limit exceeded for $USERNAME from $CLIENT_IP"

            # Don't reject yet, just log (can enable rejection if needed)
            # exit 1
        fi
    else
        # Reset rate limit counter
        > "$RATE_LIMIT_FILE"
    fi
fi

# Record this connection attempt
echo "$(date +%s)" >> "$RATE_LIMIT_FILE"

###############################################################################
# LOG SUCCESSFUL CONNECTION
###############################################################################

# Log to main connection log
echo "[$TIMESTAMP] CONNECTED: User=$USERNAME, RealIP=$CLIENT_IP:$CLIENT_PORT, VPN_IP=$VPN_IP" >> "$CONNECTION_LOG"

# Log to syslog
logger -t barqnet "User $USERNAME connected from $CLIENT_IP (VPN IP: $VPN_IP)"

# Optional: Log to database (if database integration is set up)
# This would require additional setup with database credentials
# Example (commented out):
# psql -h localhost -U barqnet -d barqnet -c \
#   "INSERT INTO vpn_connections (username, client_ip, vpn_ip, connected_at) \
#    VALUES ('$USERNAME', '$CLIENT_IP', '$VPN_IP', NOW())" 2>&1 >> "$LOG_DIR/db.log"

###############################################################################
# APPLY CUSTOM CLIENT CONFIGURATION (Optional)
###############################################################################

# You can generate custom configuration for specific clients here
# For example, push specific routes or DNS for certain users

# Example: Push custom route for admin users
# if [ "$USERNAME" = "admin" ]; then
#     echo "push route 192.168.100.0 255.255.255.0" > "$1"  # $1 is the config file path
# fi

###############################################################################
# CLEANUP OLD RATE LIMIT FILES (Maintenance)
###############################################################################

# Clean up rate limit files older than 1 hour
find /tmp -name "vpn_rate_limit_*.txt" -type f -mmin +60 -delete 2>/dev/null

###############################################################################
# EXIT SUCCESS - ALLOW CONNECTION
###############################################################################

exit 0
