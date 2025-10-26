#!/bin/bash
###############################################################################
# OpenVPN Client Disconnect Script
#
# Purpose: Called by OpenVPN when a client disconnects
# Context: Runs with environment variables set by OpenVPN
#
# Available Environment Variables:
#   $common_name      - Client certificate common name (username)
#   $trusted_ip       - Client's real IP address
#   $trusted_port     - Client's real port
#   $ifconfig_pool_remote_ip - VPN IP that was assigned to client
#   $time_unix        - Unix timestamp of when client connected
#   $time_duration    - Connection duration in seconds
#   $bytes_received   - Total bytes received from client
#   $bytes_sent       - Total bytes sent to client
#
# Exit Codes: Not checked by OpenVPN (this is just logging)
###############################################################################

set -u  # Exit on undefined variable

# Extract client information from OpenVPN environment variables
USERNAME="${common_name:-unknown}"
CLIENT_IP="${trusted_ip:-unknown}"
CLIENT_PORT="${trusted_port:-unknown}"
VPN_IP="${ifconfig_pool_remote_ip:-unknown}"
DURATION="${time_duration:-0}"
BYTES_RECV="${bytes_received:-0}"
BYTES_SENT="${bytes_sent:-0}"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# Log directory
LOG_DIR="/var/log/vpnmanager"
mkdir -p "$LOG_DIR" 2>/dev/null

# Main connection log
CONNECTION_LOG="$LOG_DIR/connections.log"

# Statistics log
STATS_LOG="$LOG_DIR/statistics.log"

###############################################################################
# CALCULATE HUMAN-READABLE VALUES
###############################################################################

# Convert bytes to human-readable format
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$((bytes / 1024))KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

# Convert duration to human-readable format
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if [ $hours -gt 0 ]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [ $minutes -gt 0 ]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

DURATION_HUMAN=$(format_duration $DURATION)
BYTES_RECV_HUMAN=$(format_bytes $BYTES_RECV)
BYTES_SENT_HUMAN=$(format_bytes $BYTES_SENT)

###############################################################################
# LOG DISCONNECTION
###############################################################################

# Detailed log entry
echo "[$TIMESTAMP] DISCONNECTED: User=$USERNAME, IP=$CLIENT_IP:$CLIENT_PORT, Duration=$DURATION_HUMAN, Down=$BYTES_RECV_HUMAN, Up=$BYTES_SENT_HUMAN" >> "$CONNECTION_LOG"

# Statistics log (easier to parse for analytics)
echo "[$TIMESTAMP]|$USERNAME|$CLIENT_IP|$VPN_IP|$DURATION|$BYTES_RECV|$BYTES_SENT" >> "$STATS_LOG"

# Log to syslog
logger -t vpnmanager "User $USERNAME disconnected after $DURATION_HUMAN (Down: $BYTES_RECV_HUMAN, Up: $BYTES_SENT_HUMAN)"

###############################################################################
# STORE STATISTICS IN DATABASE (Optional)
###############################################################################

# If you have database integration set up, you can store detailed statistics here
# This is commented out by default - uncomment and configure if needed

# Example (requires database setup):
# psql -h localhost -U vpnmanager -d barqnet -c \
#   "INSERT INTO vpn_statistics (username, client_ip, vpn_ip, duration_seconds, bytes_received, bytes_sent, disconnected_at) \
#    VALUES ('$USERNAME', '$CLIENT_IP', '$VPN_IP', $DURATION, $BYTES_RECV, $BYTES_SENT, NOW())" \
#   2>&1 >> "$LOG_DIR/db.log"

###############################################################################
# GENERATE USAGE ALERTS (Optional)
###############################################################################

# Alert if suspicious high data transfer (possible data exfiltration)
ALERT_THRESHOLD=$((10 * 1024 * 1024 * 1024))  # 10GB

TOTAL_BYTES=$((BYTES_RECV + BYTES_SENT))
if [ $TOTAL_BYTES -gt $ALERT_THRESHOLD ]; then
    TOTAL_HUMAN=$(format_bytes $TOTAL_BYTES)
    echo "[$TIMESTAMP] ALERT: High data transfer - User=$USERNAME, Total=$TOTAL_HUMAN" >> "$LOG_DIR/alerts.log"
    logger -t vpnmanager-alert "High data transfer: $USERNAME transferred $TOTAL_HUMAN"

    # Optional: Send email alert (requires mail setup)
    # echo "User $USERNAME transferred $TOTAL_HUMAN in $DURATION_HUMAN" | \
    #   mail -s "VPN High Data Transfer Alert" admin@example.com
fi

# Alert if very long connection (possible compromised account)
LONG_CONNECTION_THRESHOLD=$((24 * 3600))  # 24 hours

if [ $DURATION -gt $LONG_CONNECTION_THRESHOLD ]; then
    echo "[$TIMESTAMP] ALERT: Long connection - User=$USERNAME, Duration=$DURATION_HUMAN" >> "$LOG_DIR/alerts.log"
    logger -t vpnmanager-alert "Long connection: $USERNAME connected for $DURATION_HUMAN"
fi

###############################################################################
# CLEANUP TEMPORARY FILES
###############################################################################

# Remove rate limit tracking for this IP
RATE_LIMIT_FILE="/tmp/vpn_rate_limit_${CLIENT_IP//\./_}.txt"
rm -f "$RATE_LIMIT_FILE" 2>/dev/null

# Clean up any user-specific temporary files
USER_TEMP_DIR="/tmp/vpn_${USERNAME}"
rm -rf "$USER_TEMP_DIR" 2>/dev/null

###############################################################################
# LOG ROTATION (Maintenance)
###############################################################################

# Rotate logs if they get too large (>100MB)
rotate_log_if_large() {
    local logfile="$1"
    local max_size=$((100 * 1024 * 1024))  # 100MB

    if [ -f "$logfile" ]; then
        local size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null || echo 0)

        if [ $size -gt $max_size ]; then
            mv "$logfile" "$logfile.$(date +%Y%m%d-%H%M%S)"
            gzip "$logfile".* 2>/dev/null &
        fi
    fi
}

rotate_log_if_large "$CONNECTION_LOG"
rotate_log_if_large "$STATS_LOG"

###############################################################################
# EXIT
###############################################################################

exit 0
