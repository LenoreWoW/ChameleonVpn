#!/bin/bash
###############################################################################
# BarqNet VPN User Disconnect Script
#
# Purpose: Disconnects a specific VPN user from all active sessions
# Usage: ./disconnect-user.sh <username>
#
# This script attempts to disconnect a user via the OpenVPN management interface
# by trying multiple possible socket locations.
#
# Exit Codes:
#   0 - User successfully disconnected
#   1 - Invalid arguments
#   2 - Management interface not available
#   3 - User not found in active connections
#   4 - Disconnect command failed
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Check if username provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <username>" >&2
    echo "Example: $0 alice" >&2
    exit 1
fi

USERNAME="$1"

# Validate username (alphanumeric and underscore only)
if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "Error: Invalid username format. Only alphanumeric and underscore allowed." >&2
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempting to disconnect user: $USERNAME"

# Try multiple possible socket paths (different distros use different locations)
SOCKET_PATHS=(
    "/var/run/openvpn/server.sock"
    "/var/run/openvpn-server/server.sock"
    "/run/openvpn/server.sock"
    "/var/run/openvpn/server-tcp.sock"
    "/var/run/openvpn/server-udp.sock"
)

# Function to check if user is connected
check_user_connected() {
    local socket="$1"
    local username="$2"

    # Send status command and grep for username
    echo "status" | nc -U "$socket" 2>/dev/null | grep -q "$username"
    return $?
}

# Function to disconnect user via socket
disconnect_via_socket() {
    local socket="$1"
    local username="$2"

    echo "  Trying socket: $socket"

    # Check if socket exists
    if [ ! -S "$socket" ]; then
        echo "  Socket does not exist: $socket"
        return 1
    fi

    # Check if user is connected
    if ! check_user_connected "$socket" "$username"; then
        echo "  User $username not found in active connections on this socket"
        return 3
    fi

    # Send kill command
    echo "kill $username" | nc -U "$socket" 2>/dev/null > /tmp/disconnect_output_$$.txt
    local nc_exit=$?

    if [ $nc_exit -ne 0 ]; then
        echo "  Failed to send kill command (nc exit code: $nc_exit)"
        rm -f /tmp/disconnect_output_$$.txt
        return 4
    fi

    # Check command output
    local output=$(cat /tmp/disconnect_output_$$.txt)
    rm -f /tmp/disconnect_output_$$.txt

    echo "  Management interface response: $output"

    if echo "$output" | grep -qi "SUCCESS\|killed"; then
        echo "  ✅ User $username disconnected successfully"
        return 0
    elif echo "$output" | grep -qi "ERROR"; then
        echo "  ❌ Disconnect failed: $output"
        return 4
    else
        echo "  ⚠️  Uncertain result: $output"
        # Wait and verify
        sleep 1
        if ! check_user_connected "$socket" "$username"; then
            echo "  ✅ Verified: User no longer connected"
            return 0
        else
            echo "  ❌ User still connected after disconnect attempt"
            return 4
        fi
    fi
}

# Try each socket path
DISCONNECTED=false
for socket in "${SOCKET_PATHS[@]}"; do
    if disconnect_via_socket "$socket" "$USERNAME"; then
        DISCONNECTED=true
        break
    fi
done

# Final status
if [ "$DISCONNECTED" = true ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: User $USERNAME disconnected"

    # Log to syslog if available
    if command -v logger &> /dev/null; then
        logger -t barqnet "User $USERNAME disconnected from VPN"
    fi

    # Log to file
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] User $USERNAME disconnected" >> /var/log/barqnet/disconnections.log 2>/dev/null || true

    exit 0
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FAILED: Could not disconnect user $USERNAME"
    echo "Possible reasons:"
    echo "  1. OpenVPN management interface not enabled"
    echo "  2. Socket path incorrect for your setup"
    echo "  3. User not currently connected"
    echo "  4. Permission denied accessing socket"
    echo ""
    echo "To enable management interface, add to /etc/openvpn/server.conf:"
    echo "  management /var/run/openvpn/server.sock unix"
    echo "  management-client-auth"
    echo ""
    echo "Then restart OpenVPN: systemctl restart openvpn@server"

    exit 2
fi
