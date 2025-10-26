#!/bin/bash
###############################################################################
# CRL (Certificate Revocation List) Refresh Script
#
# Purpose: Regenerates the CRL from EasyRSA and signals OpenVPN to reload it
#          without disconnecting active clients
#
# Usage: Run manually or via cron
# Cron Example: */15 * * * * /opt/vpnmanager/scripts/refresh-crl.sh
#
# This script should run every 15-30 minutes to ensure revoked certificates
# are blocked as soon as possible.
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Configuration
EASYRSA_DIR="/opt/vpnmanager/easyrsa"
EASYRSA_BIN="$EASYRSA_DIR/easyrsa"
CRL_SOURCE="$EASYRSA_DIR/pki/crl.pem"
CRL_DEST="/etc/openvpn/crl.pem"
LOG_FILE="/var/log/vpnmanager/crl.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

# Function to log messages
log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

# Function to log errors
log_error() {
    echo "[$TIMESTAMP] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

###############################################################################
# STEP 1: Verify EasyRSA is available
###############################################################################

if [ ! -f "$EASYRSA_BIN" ]; then
    log_error "EasyRSA not found at $EASYRSA_BIN"
    exit 1
fi

if [ ! -d "$EASYRSA_DIR/pki" ]; then
    log_error "EasyRSA PKI directory not found at $EASYRSA_DIR/pki"
    exit 1
fi

log "Starting CRL refresh..."

###############################################################################
# STEP 2: Generate new CRL
###############################################################################

cd "$EASYRSA_DIR" || {
    log_error "Failed to change directory to $EASYRSA_DIR"
    exit 1
}

# Set environment variables for batch mode
export EASYRSA_BATCH=1
export EASYRSA_PKI="$EASYRSA_DIR/pki"

# Generate CRL
log "Generating CRL..."
if "$EASYRSA_BIN" gen-crl >> "$LOG_FILE" 2>&1; then
    log "CRL generated successfully"
else
    log_error "Failed to generate CRL"
    exit 1
fi

# Verify CRL was created
if [ ! -f "$CRL_SOURCE" ]; then
    log_error "CRL file not found at $CRL_SOURCE after generation"
    exit 1
fi

###############################################################################
# STEP 3: Validate CRL
###############################################################################

log "Validating CRL..."

# Check CRL is valid using openssl
if ! openssl crl -in "$CRL_SOURCE" -noout -text > /dev/null 2>&1; then
    log_error "Generated CRL is invalid"
    exit 1
fi

# Get CRL information
CRL_INFO=$(openssl crl -in "$CRL_SOURCE" -noout -text 2>/dev/null)
REVOKED_COUNT=$(echo "$CRL_INFO" | grep -c "Serial Number:" || echo "0")
NEXT_UPDATE=$(echo "$CRL_INFO" | grep "Next Update:" | sed 's/.*Next Update: //')

log "CRL validation successful - Revoked certificates: $REVOKED_COUNT"
log "CRL valid until: $NEXT_UPDATE"

###############################################################################
# STEP 4: Backup current CRL (if exists)
###############################################################################

if [ -f "$CRL_DEST" ]; then
    BACKUP_FILE="${CRL_DEST}.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$CRL_DEST" "$BACKUP_FILE" 2>/dev/null || true
    log "Current CRL backed up to $BACKUP_FILE"

    # Keep only last 5 backups
    find "$(dirname "$CRL_DEST")" -name "crl.pem.backup.*" -type f | \
        sort -r | tail -n +6 | xargs rm -f 2>/dev/null || true
fi

###############################################################################
# STEP 5: Copy CRL to OpenVPN directory
###############################################################################

log "Copying CRL to OpenVPN directory..."

if cp "$CRL_SOURCE" "$CRL_DEST"; then
    log "CRL copied to $CRL_DEST successfully"
else
    log_error "Failed to copy CRL to $CRL_DEST"
    exit 1
fi

# Set proper permissions
chmod 644 "$CRL_DEST" 2>/dev/null || true
chown root:root "$CRL_DEST" 2>/dev/null || true

###############################################################################
# STEP 6: Signal OpenVPN to reload CRL
###############################################################################

log "Signaling OpenVPN to reload CRL..."

# SIGUSR1 causes OpenVPN to reload config without dropping connections
# This is safe and will not disconnect active users
if pkill -SIGUSR1 openvpn; then
    log "OpenVPN signaled to reload CRL successfully"
else
    log_error "Failed to signal OpenVPN (may not be running)"
    # Don't exit with error - OpenVPN might not be running, which is OK
fi

# Alternative: Use systemctl reload if available
if systemctl is-active --quiet openvpn@server 2>/dev/null; then
    systemctl reload openvpn@server >> "$LOG_FILE" 2>&1 || true
    log "OpenVPN service reload triggered"
fi

###############################################################################
# STEP 7: Verify OpenVPN is using the new CRL
###############################################################################

log "Verifying OpenVPN CRL usage..."

# Check OpenVPN logs for CRL-related messages
if journalctl -u openvpn@server --since "1 minute ago" 2>/dev/null | grep -qi "crl"; then
    log "OpenVPN CRL reload confirmed in logs"
else
    log "No CRL reload message found in logs (may take a moment)"
fi

# Compare source and destination CRL to ensure they match
if diff -q "$CRL_SOURCE" "$CRL_DEST" > /dev/null 2>&1; then
    log "CRL files match - refresh successful"
else
    log_error "CRL files do not match - refresh may have failed"
    exit 1
fi

###############################################################################
# STEP 8: Log statistics
###############################################################################

# Get file size
CRL_SIZE=$(stat -f%z "$CRL_DEST" 2>/dev/null || stat -c%s "$CRL_DEST" 2>/dev/null || echo "unknown")

# Get last modification time
CRL_MTIME=$(stat -f%Sm -t "%Y-%m-%d %H:%M:%S" "$CRL_DEST" 2>/dev/null || \
            stat -c%y "$CRL_DEST" 2>/dev/null | cut -d. -f1 || echo "unknown")

log "CRL refresh complete - Size: ${CRL_SIZE} bytes, Modified: $CRL_MTIME"

# Log to syslog
logger -t vpnmanager-crl "CRL refreshed successfully ($REVOKED_COUNT revoked certificates)"

###############################################################################
# STEP 9: Send alerts if configured (optional)
###############################################################################

# If there are newly revoked certificates, you might want to alert administrators
# This is commented out by default

# if [ $REVOKED_COUNT -gt 0 ]; then
#     # Example: Send email
#     # echo "CRL updated with $REVOKED_COUNT revoked certificates" | \
#     #   mail -s "VPN CRL Update" admin@example.com
#
#     # Example: Post to Slack webhook
#     # curl -X POST -H 'Content-type: application/json' \
#     #   --data "{\"text\":\"VPN CRL updated: $REVOKED_COUNT revoked certificates\"}" \
#     #   https://hooks.slack.com/services/YOUR/WEBHOOK/URL
# fi

###############################################################################
# STEP 10: Cleanup old logs
###############################################################################

# Rotate CRL log if it gets too large (>10MB)
LOG_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10MB

if [ $LOG_SIZE -gt $MAX_LOG_SIZE ]; then
    mv "$LOG_FILE" "$LOG_FILE.$(date +%Y%m%d-%H%M%S)"
    gzip "$LOG_FILE".* 2>/dev/null &
    log "CRL log rotated due to size"
fi

###############################################################################
# EXIT SUCCESS
###############################################################################

exit 0
