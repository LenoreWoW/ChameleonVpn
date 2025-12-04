#!/bin/bash
###############################################################################
# Quick rebuild script for end-node after health check fix
###############################################################################

set -e

echo "🔧 Rebuilding end-node with health check fix..."

# Navigate to end-node directory
cd /opt/barqnet/apps/endnode || cd ~/ChameleonVpn/barqnet-backend/apps/endnode

# Pull latest changes if using git
if [ -d ".git" ]; then
    echo "📥 Pulling latest changes..."
    git pull
fi

# Build the end-node
echo "🔨 Building end-node binary..."
go build -o endnode main.go

# Stop the service
echo "⏸️  Stopping end-node service..."
sudo systemctl stop vpnmanager-endnode 2>/dev/null || sudo systemctl stop barqnet-endnode 2>/dev/null || true

# Copy binary to installation directory
echo "📦 Installing new binary..."
sudo cp endnode /opt/barqnet/bin/endnode 2>/dev/null || sudo cp endnode /usr/local/bin/barqnet-endnode 2>/dev/null || true

# Restart the service
echo "▶️  Starting end-node service..."
sudo systemctl start vpnmanager-endnode 2>/dev/null || sudo systemctl start barqnet-endnode 2>/dev/null || true

# Check status
echo "✅ Checking service status..."
sudo systemctl status vpnmanager-endnode --no-pager -l || sudo systemctl status barqnet-endnode --no-pager -l || true

echo ""
echo "🎉 End-node rebuilt successfully!"
echo ""
echo "Monitor logs with:"
echo "  sudo journalctl -u vpnmanager-endnode -f"
echo "  OR"
echo "  sudo journalctl -u barqnet-endnode -f"
