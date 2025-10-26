# BarqNet Ubuntu Deployment Guide

## Overview

This guide explains how to deploy the complete BarqNet VPN infrastructure on Ubuntu servers. The deployment consists of two types of servers:

1. **Management Server** - Centralized API and database
2. **End-Node VPN Servers** - Distributed VPN servers in multiple locations

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    BARQNET INFRASTRUCTURE                    │
└─────────────────────────────────────────────────────────────┘

                    ┌─────────────────────┐
                    │  Management Server  │
                    │                     │
                    │  - PostgreSQL DB    │
                    │  - Management API   │
                    │  - Port 8080        │
                    └──────────┬──────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────▼────────┐   ┌────────▼───────┐   ┌────────▼───────┐
│  VPN Server 1  │   │  VPN Server 2  │   │  VPN Server N  │
│                │   │                │   │                │
│  - OpenVPN     │   │  - OpenVPN     │   │  - OpenVPN     │
│  - End-Node API│   │  - End-Node API│   │  - End-Node API│
│  - US-East     │   │  - EU-West     │   │  - Asia-Pacific│
│  - Port 1194   │   │  - Port 1194   │   │  - Port 1194   │
└────────────────┘   └────────────────┘   └────────────────┘
```

---

## Prerequisites

### Server Requirements

#### Management Server
- **OS:** Ubuntu 20.04 LTS or newer
- **RAM:** 2GB minimum, 4GB recommended
- **CPU:** 2 cores minimum
- **Storage:** 20GB minimum
- **Network:** Static IP or domain name
- **Ports:** 8080 (API), 5432 (PostgreSQL - internal only)

#### End-Node VPN Server
- **OS:** Ubuntu 20.04 LTS or newer
- **RAM:** 1GB minimum, 2GB recommended
- **CPU:** 1 core minimum, 2 cores recommended
- **Storage:** 10GB minimum
- **Network:** Public static IP address
- **Ports:** 1194 (OpenVPN), 8081 (End-Node API)

### Access Requirements
- Root or sudo access on all servers
- SSH access to all servers
- Internet connectivity on all servers

---

## Deployment Steps

### PART 1: Deploy Management Server

The Management Server is the central hub. **Deploy this first.**

#### Step 1: Prepare Ubuntu Server

```bash
# SSH into your Management Server
ssh user@management-server-ip

# Update system
sudo apt update && sudo apt upgrade -y

# Install git
sudo apt install -y git
```

#### Step 2: Download Deployment Scripts

```bash
# Clone repository
git clone https://github.com/LenoreWoW/ChameleonVpn.git
cd ChameleonVpn/deployment
```

#### Step 3: Run Deployment Script

```bash
# Make script executable
chmod +x ubuntu-deploy-management.sh

# Run deployment (as root)
sudo ./ubuntu-deploy-management.sh
```

**The script will automatically:**
1. Install PostgreSQL 14
2. Install Go 1.21
3. Create system user (`barqnet`)
4. Set up database with secure credentials
5. Build Management API
6. Run database migrations
7. Create systemd service
8. Configure firewall
9. Start the service

**Expected output:**
```
═══════════════════════════════════════════════════════════════
[SUCCESS] BarqNet Management Server Deployment Complete!
═══════════════════════════════════════════════════════════════

📍 Installation Details:
   - Installation Directory: /opt/barqnet
   - Configuration Directory: /etc/barqnet
   - API Port: 8080

🔐 Credentials (SAVE THESE!):
   - Database: barqnet
   - DB User: barqnet
   - DB Password: <randomly-generated>
```

#### Step 4: Save Credentials

**IMPORTANT:** The script generates secure random passwords. Save these:

```bash
# View credentials
sudo cat /etc/barqnet/CREDENTIALS.txt

# Copy them somewhere safe, then delete the file
sudo rm /etc/barqnet/CREDENTIALS.txt
```

#### Step 5: Verify Management Server

```bash
# Check service status
sudo systemctl status barqnet-management

# Test health endpoint
curl http://localhost:8080/api/health

# Expected: {"status":"healthy","timestamp":...}
```

#### Step 6: Configure Twilio (Production OTP)

For production, you need to enable SMS/OTP via Twilio:

```bash
# Edit configuration
sudo nano /etc/barqnet/management-config.env

# Add/uncomment these lines:
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+1234567890

# Remove development bypass
# ENABLE_OTP_CONSOLE=true  <- Comment this out or remove

# Restart service
sudo systemctl restart barqnet-management
```

#### Step 7: Set Up SSL/HTTPS (Recommended)

For production, use nginx + Let's Encrypt:

```bash
# Install nginx and certbot
sudo apt install -y nginx certbot python3-certbot-nginx

# Configure nginx proxy
sudo nano /etc/nginx/sites-available/barqnet
```

Add:
```nginx
server {
    listen 80;
    server_name yourdomain.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/barqnet /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Get SSL certificate
sudo certbot --nginx -d yourdomain.com
```

**✅ Management Server is now ready!**

---

### PART 2: Deploy VPN End-Node Servers

Deploy one or more VPN servers in different locations.

#### Step 1: Prepare Ubuntu Server

```bash
# SSH into your VPN Server
ssh user@vpn-server-ip

# Update system
sudo apt update && sudo apt upgrade -y

# Install git
sudo apt install -y git
```

#### Step 2: Download Deployment Scripts

```bash
# Clone repository
git clone https://github.com/LenoreWoW/ChameleonVpn.git
cd ChameleonVpn/deployment
```

#### Step 3: Run Deployment Script

```bash
# Make script executable
chmod +x ubuntu-deploy-endnode.sh

# Run deployment (as root)
sudo ./ubuntu-deploy-endnode.sh
```

**The script will ask you for:**
1. **Server ID:** Unique identifier (e.g., `us-east-1`)
2. **Management Server URL:** Your Management Server (e.g., `http://192.168.1.100:8080`)
3. **API Key:** Shared secret for authentication
4. **Database credentials:** From Management Server deployment
5. **Server location:** Display name (e.g., `US-East`)

**The script will automatically:**
1. Install OpenVPN and Easy-RSA
2. Set up PKI and generate certificates
3. Configure OpenVPN server
4. Enable IP forwarding and NAT
5. Build End-Node API
6. Create systemd services
7. Register with Management Server
8. Start all services

**Expected output:**
```
═══════════════════════════════════════════════════════════════
[SUCCESS] BarqNet End-Node VPN Server Deployment Complete!
═══════════════════════════════════════════════════════════════

📍 Installation Details:
   - Server ID: us-east-1
   - Location: US-East
   - Public IP: 1.2.3.4
   - VPN Port: 1194
```

#### Step 4: Verify VPN Server

```bash
# Check OpenVPN status
sudo systemctl status openvpn@server

# Check End-Node API status
sudo systemctl status barqnet-endnode

# Test health endpoint
curl http://localhost:8081/health

# Expected: {"status":"healthy","server_id":"us-east-1"...}
```

#### Step 5: Repeat for Additional Locations

To deploy VPN servers in multiple locations:

1. Get another Ubuntu server (in a different location)
2. Run the same deployment script
3. Use a different **Server ID** (e.g., `eu-west-1`, `asia-pacific-1`)
4. Use the **same** Management Server URL and credentials

**Example locations:**
- `us-east-1` - New York / Virginia
- `us-west-1` - California / Oregon
- `eu-west-1` - Ireland / UK
- `eu-central-1` - Germany / Frankfurt
- `asia-pacific-1` - Singapore / Tokyo

**✅ VPN Servers are now ready!**

---

## Post-Deployment Configuration

### 1. Create User Accounts

From any machine with network access to Management Server:

```bash
# Register a new user
curl -X POST http://your-management-server:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+1234567890",
    "password": "SecurePassword123!",
    "verification_token": "token-from-otp-verify"
  }'
```

### 2. Generate VPN Configurations

VPN configurations are generated on-demand when users request them via the client apps.

### 3. Update Client Apps

Update your Desktop, iOS, and Android clients to use the production backend:

**Desktop (.env):**
```
API_BASE_URL=https://yourdomain.com
```

**iOS (Config.swift):**
```swift
static let apiBaseURL = "https://yourdomain.com"
```

**Android (ApiConfig.kt):**
```kotlin
const val BASE_URL = "https://yourdomain.com"
```

### 4. Enable Certificate Pinning (Production)

**Desktop:**
```bash
# Set certificate pins
export CERT_PIN_PRIMARY="sha256/PRIMARY_HASH_HERE"
export CERT_PIN_BACKUP="sha256/BACKUP_HASH_HERE"
```

**iOS and Android:** Update certificate pinning configuration in code.

---

## Service Management

### Management Server

```bash
# Start
sudo systemctl start barqnet-management

# Stop
sudo systemctl stop barqnet-management

# Restart
sudo systemctl restart barqnet-management

# Status
sudo systemctl status barqnet-management

# Logs
sudo journalctl -u barqnet-management -f

# Enable auto-start on boot (already done by script)
sudo systemctl enable barqnet-management
```

### VPN End-Node Server

```bash
# OpenVPN Service
sudo systemctl start openvpn@server
sudo systemctl stop openvpn@server
sudo systemctl status openvpn@server
sudo journalctl -u openvpn@server -f

# End-Node API Service
sudo systemctl start barqnet-endnode
sudo systemctl stop barqnet-endnode
sudo systemctl status barqnet-endnode
sudo journalctl -u barqnet-endnode -f
```

---

## Monitoring and Maintenance

### Check Active VPN Connections

```bash
# On VPN Server
sudo cat /var/log/openvpn/openvpn-status.log
```

### Database Backups

**Automated daily backups:**
```bash
# On Management Server
sudo crontab -e

# Add this line for daily backups at 2 AM
0 2 * * * /usr/bin/pg_dump -U barqnet barqnet | gzip > /backup/barqnet-$(date +\%Y\%m\%d).sql.gz
```

### CRL Refresh

Certificate Revocation List (CRL) is automatically refreshed daily by cron job on each VPN server.

**Manual refresh:**
```bash
# On VPN Server
sudo /opt/barqnet/refresh-crl.sh
```

### Log Rotation

Logs are automatically rotated by systemd journal. To manage:

```bash
# View log size
sudo journalctl --disk-usage

# Limit log size to 500MB
sudo journalctl --vacuum-size=500M

# Keep logs for 30 days only
sudo journalctl --vacuum-time=30d
```

---

## Troubleshooting

### Management Server Won't Start

**Error:** `Failed to connect to database`

**Solution:**
```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Start if needed
sudo systemctl start postgresql

# Check database exists
sudo -u postgres psql -l | grep barqnet

# Check credentials
sudo cat /etc/barqnet/management-config.env
```

---

### VPN Server Won't Start

**Error:** `Address already in use`

**Solution:**
```bash
# Check what's using port 1194
sudo netstat -tulpn | grep 1194

# Kill the process if needed
sudo killall openvpn

# Restart
sudo systemctl restart openvpn@server
```

---

### Clients Can't Connect to VPN

**Checklist:**
1. **Firewall:** Is port 1194/UDP open?
   ```bash
   sudo ufw status | grep 1194
   ```

2. **OpenVPN Running:**
   ```bash
   sudo systemctl status openvpn@server
   ```

3. **IP Forwarding Enabled:**
   ```bash
   sysctl net.ipv4.ip_forward
   # Should return: net.ipv4.ip_forward = 1
   ```

4. **NAT Configured:**
   ```bash
   sudo iptables -t nat -L POSTROUTING
   # Should show MASQUERADE rule
   ```

---

### End-Node Can't Connect to Management Server

**Error:** `Connection refused` or `Network error`

**Solution:**
```bash
# Test connectivity from VPN Server
curl http://management-server-ip:8080/api/health

# Check firewall on Management Server
sudo ufw status

# Check if Management API is running
sudo systemctl status barqnet-management
```

---

## Security Best Practices

### 1. Use Strong Passwords

The deployment scripts generate secure random passwords. **Never use weak passwords.**

### 2. Enable Firewall

UFW is configured automatically. Verify:
```bash
sudo ufw status
```

Should show:
- Port 22 (SSH) - ALLOW
- Port 8080 (Management API) - ALLOW
- Port 1194 (OpenVPN) - ALLOW
- Port 8081 (End-Node API) - ALLOW

### 3. Keep System Updated

```bash
# Update system regularly
sudo apt update && sudo apt upgrade -y

# Enable automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

### 4. Use SSL/TLS

Always use HTTPS in production with valid SSL certificates.

### 5. Limit SSH Access

```bash
# Disable password authentication, use keys only
sudo nano /etc/ssh/sshd_config

# Set:
PasswordAuthentication no
PubkeyAuthentication yes

# Restart SSH
sudo systemctl restart sshd
```

### 6. Regular Backups

- Daily database backups
- Weekly configuration backups
- Test restore procedures monthly

### 7. Monitor Logs

```bash
# Watch for suspicious activity
sudo journalctl -u barqnet-management -f
sudo journalctl -u openvpn@server -f
```

---

## Scaling

### Adding More VPN Servers

1. Deploy new Ubuntu server in desired location
2. Run `ubuntu-deploy-endnode.sh`
3. Use same Management Server URL and credentials
4. Choose unique Server ID and location name

### Load Balancing

For high availability:
1. Deploy multiple Management Servers
2. Use nginx or HAProxy for load balancing
3. Configure PostgreSQL replication

---

## Complete Deployment Checklist

### Management Server
- [ ] Ubuntu server prepared (20.04+)
- [ ] Deployment script executed successfully
- [ ] Credentials saved securely
- [ ] Service running and healthy
- [ ] Firewall configured
- [ ] SSL/HTTPS configured (production)
- [ ] Twilio configured (production OTP)
- [ ] Database backups configured
- [ ] Monitoring set up

### VPN End-Node Server(s)
- [ ] Ubuntu server prepared (20.04+)
- [ ] Deployment script executed successfully
- [ ] Server registered with Management Server
- [ ] OpenVPN service running
- [ ] End-Node API service running
- [ ] Firewall configured
- [ ] NAT and IP forwarding enabled
- [ ] VPN connections tested
- [ ] CRL refresh cron job active

### Client Applications
- [ ] Desktop app updated with production URL
- [ ] iOS app updated with production URL
- [ ] Android app updated with production URL
- [ ] Certificate pinning enabled (production)
- [ ] OTP bypass removed (production)
- [ ] Apps tested end-to-end

---

## Quick Reference Commands

### Deployment

```bash
# Management Server
sudo ./ubuntu-deploy-management.sh

# VPN Server
sudo ./ubuntu-deploy-endnode.sh
```

### Service Status

```bash
# All services
sudo systemctl status barqnet-management
sudo systemctl status barqnet-endnode
sudo systemctl status openvpn@server
sudo systemctl status postgresql
```

### Logs

```bash
# Real-time logs
sudo journalctl -u barqnet-management -f
sudo journalctl -u barqnet-endnode -f
sudo journalctl -u openvpn@server -f

# Recent logs
sudo journalctl -u barqnet-management -n 100
```

### Health Checks

```bash
# Management Server
curl http://localhost:8080/api/health

# VPN Server
curl http://localhost:8081/health

# OpenVPN Status
sudo cat /var/log/openvpn/openvpn-status.log
```

---

## Support

For issues or questions:

1. **Check logs:** `journalctl -u service-name -f`
2. **Review this guide:** All common issues are documented
3. **Check GitHub:** Issues and discussions
4. **Security issues:** Report privately

---

## Summary

**What you deployed:**
1. ✅ Management Server with PostgreSQL database and API
2. ✅ One or more VPN End-Node servers with OpenVPN
3. ✅ Automated systemd services for reliability
4. ✅ Firewall configuration for security
5. ✅ CRL refresh for certificate revocation
6. ✅ Complete monitoring and logging

**Next steps:**
1. Configure production OTP (Twilio)
2. Set up SSL/HTTPS
3. Update client apps with production URL
4. Create user accounts
5. Test VPN connections
6. Set up monitoring and alerts

**Your BarqNet VPN infrastructure is now ready for production use! 🚀**
