# Fix: Empty Certificates in OVPN Files

## Problem
OVPN files are being created but have empty certificate sections, causing "static key parse error" in OpenVPN clients.

## Root Cause
EasyRSA is not initialized on the end-node server. The certificate generation fails and falls back to empty certificates.

## Solution - Run on End-Node Server

### Step 1: Copy Setup Script to End-Node Server

```bash
# Copy the setup script to your end-node server
scp barqnet-backend/scripts/setup-easyrsa.sh root@192.168.10.248:/tmp/
```

### Step 2: Run EasyRSA Setup on End-Node

```bash
# SSH to your end-node server
ssh root@192.168.10.248

# Make script executable
chmod +x /tmp/setup-easyrsa.sh

# Run the setup script (requires root)
sudo /tmp/setup-easyrsa.sh
```

This script will:
- ✅ Install `easy-rsa` and `openssl` packages
- ✅ Set up EasyRSA at `/opt/vpnmanager/easyrsa`
- ✅ Initialize PKI (Public Key Infrastructure)
- ✅ Build CA (Certificate Authority)
- ✅ Generate TLS auth key
- ✅ Create server certificate
- ✅ Set proper permissions
- ✅ Test certificate generation

### Step 3: Fix TLS-Crypt Key Path

The code expects the TLS-crypt key at `/etc/openvpn/tls-crypt.key` but the setup script creates it at `/opt/vpnmanager/easyrsa/pki/ta.key`.

```bash
# Create directory
sudo mkdir -p /etc/openvpn

# Copy or symlink the key
sudo cp /opt/vpnmanager/easyrsa/pki/ta.key /etc/openvpn/tls-crypt.key

# Or create a symlink
# sudo ln -s /opt/vpnmanager/easyrsa/pki/ta.key /etc/openvpn/tls-crypt.key

# Set permissions
sudo chmod 600 /etc/openvpn/tls-crypt.key
```

### Step 4: Verify EasyRSA Setup

```bash
# Check if EasyRSA is installed
ls -la /opt/vpnmanager/easyrsa/

# Check if PKI is initialized
ls -la /opt/vpnmanager/easyrsa/pki/

# Check if CA exists
ls -la /opt/vpnmanager/easyrsa/pki/ca.crt

# Check if TLS-crypt key exists
ls -la /etc/openvpn/tls-crypt.key

# Test certificate generation manually
cd /opt/vpnmanager/easyrsa
./easyrsa gen-req testuser nopass
./easyrsa sign-req client testuser

# Check if certificates were created
ls -la pki/issued/testuser.crt
ls -la pki/private/testuser.key
```

### Step 5: Restart End-Node Server

```bash
# Restart the end-node service
sudo systemctl restart endnode
# Or if running manually:
# Kill the endnode process and restart it
```

### Step 6: Test OVPN Generation

Now test from iOS app or curl:

```bash
# From management server, trigger OVPN creation
curl -X POST http://192.168.10.248:8081/api/ovpn/create \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser2",
    "port": 1194,
    "protocol": "udp",
    "server_id": "server-1",
    "server_ip": "192.168.10.248",
    "cert_data": {
      "ca": "",
      "cert": "",
      "key": "",
      "ta": ""
    }
  }'

# Check if OVPN file was created with certificates
cat /opt/vpnmanager/clients/testuser2.ovpn
```

The OVPN file should now have:
- ✅ `<ca>` section with CA certificate
- ✅ `<cert>` section with client certificate
- ✅ `<key>` section with private key
- ✅ `<tls-crypt>` section with TLS-crypt key

### Step 7: Check End-Node Logs

If it still fails, check the logs:

```bash
# Check end-node logs for certificate generation errors
journalctl -u endnode -f

# Or if running manually, check the console output
# Look for messages like:
# "✅ Certificate request generated successfully"
# "✅ Certificate signed successfully"
# "✅ CA certificate loaded (XXXX bytes)"
# "✅ Client certificate loaded (XXXX bytes)"
# "✅ Client private key loaded (XXXX bytes)"
# "✅ TLS-crypt key loaded (XXXX bytes)"
```

## Quick Verification Checklist

- [ ] EasyRSA installed at `/opt/vpnmanager/easyrsa`
- [ ] PKI initialized at `/opt/vpnmanager/easyrsa/pki`
- [ ] CA certificate exists: `/opt/vpnmanager/easyrsa/pki/ca.crt`
- [ ] TLS-crypt key exists: `/etc/openvpn/tls-crypt.key`
- [ ] End-node server restarted
- [ ] Test OVPN generation creates files with certificates
- [ ] iOS app can download and import VPN config

## Troubleshooting

### Error: "EasyRSA not found"
```bash
# Install easy-rsa
sudo apt-get update
sudo apt-get install -y easy-rsa openssl
```

### Error: "PKI directory not found"
```bash
# Initialize PKI
cd /opt/vpnmanager/easyrsa
./easyrsa init-pki
./easyrsa build-ca nopass
```

### Error: "Failed to read TLS-crypt key"
```bash
# Generate TLS-crypt key
openvpn --genkey --secret /etc/openvpn/tls-crypt.key
chmod 600 /etc/openvpn/tls-crypt.key
```

### Permissions Issues
```bash
# Fix ownership
sudo chown -R vpnmanager:vpnmanager /opt/vpnmanager/easyrsa

# Fix permissions
sudo chmod 755 /opt/vpnmanager/easyrsa
sudo chmod 700 /opt/vpnmanager/easyrsa/pki
sudo chmod 600 /opt/vpnmanager/easyrsa/pki/private/*
sudo chmod 644 /opt/vpnmanager/easyrsa/pki/ca.crt
```

## After Setup Complete

Once EasyRSA is properly set up:
1. New users registering will automatically get OVPN files with valid certificates
2. No manual certificate generation needed
3. Certificates are unique per user
4. iOS app can successfully import and use VPN configs

---

**Status**: This is a one-time setup required on the end-node server. After completion, certificate generation will work automatically for all future users.
