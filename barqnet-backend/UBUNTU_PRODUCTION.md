# 🐧 BarqNet Backend - Ubuntu Production Deployment Guide

Complete guide for deploying BarqNet backend on Ubuntu 20.04+ servers.

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Manual Installation](#manual-installation)
3. [Service Management](#service-management)
4. [Monitoring & Logging](#monitoring--logging)
5. [Backup & Recovery](#backup--recovery)
6. [Security Hardening](#security-hardening)
7. [Troubleshooting](#troubleshooting)
8. [Maintenance](#maintenance)

---

## 🚀 Quick Start

### Automated Deployment

The fastest way to deploy on Ubuntu:

```bash
# 1. Download deployment script
wget https://raw.githubusercontent.com/yourusername/ChameleonVpn/main/barqnet-backend/deploy-ubuntu.sh

# 2. Make executable
chmod +x deploy-ubuntu.sh

# 3. Run as root
sudo ./deploy-ubuntu.sh
```

**What it does:**
- ✅ Installs all dependencies (Go, PostgreSQL, Redis, Nginx)
- ✅ Creates database and user
- ✅ Generates secure credentials
- ✅ Builds application
- ✅ Creates systemd services
- ✅ Configures Nginx reverse proxy
- ✅ Sets up SSL with Let's Encrypt
- ✅ Configures firewall

**Duration:** ~15-20 minutes

---

## 🔧 Manual Installation

If you prefer manual installation or need custom configuration:

### Step 1: System Requirements

**Minimum:**
- Ubuntu 20.04 LTS or later
- 2 CPU cores
- 4 GB RAM
- 20 GB SSD storage
- Public IP address

**Recommended:**
- Ubuntu 22.04 LTS
- 4 CPU cores
- 8 GB RAM
- 50 GB SSD storage
- Domain name with DNS configured

### Step 2: Install Dependencies

```bash
# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install essential packages
sudo apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    ufw \
    nginx \
    redis-server \
    certbot \
    python3-certbot-nginx \
    htop \
    vim
```

### Step 3: Install Go

```bash
# Download Go 1.21.5 (or latest)
cd /tmp
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz

# Install
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz

# Add to PATH
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh
source /etc/profile.d/go.sh

# Verify
go version
```

### Step 4: Install PostgreSQL 15

```bash
# Add PostgreSQL repository
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# Install
sudo apt-get update
sudo apt-get install -y postgresql-15 postgresql-contrib-15

# Verify
sudo systemctl status postgresql
```

### Step 5: Configure Database

```bash
# Generate secure password
DB_PASSWORD=$(openssl rand -base64 24)
echo "Database Password: $DB_PASSWORD"  # SAVE THIS!

# Create database
sudo -u postgres psql << EOF
CREATE USER barqnet WITH ENCRYPTED PASSWORD '${DB_PASSWORD}';
CREATE DATABASE barqnet OWNER barqnet;
GRANT ALL PRIVILEGES ON DATABASE barqnet TO barqnet;
\c barqnet
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
EOF
```

**Production PostgreSQL Configuration:**

Edit `/etc/postgresql/15/main/postgresql.conf`:

```conf
# Connection Settings
listen_addresses = 'localhost'
max_connections = 200

# Memory Settings
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 2621kB
min_wal_size = 1GB
max_wal_size = 4GB

# Logging
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_duration = off
log_lock_waits = on
```

Restart PostgreSQL:
```bash
sudo systemctl restart postgresql
```

### Step 6: Configure Redis

```bash
# Generate Redis password
REDIS_PASSWORD=$(openssl rand -base64 24)
echo "Redis Password: $REDIS_PASSWORD"  # SAVE THIS!

# Configure Redis
sudo sed -i "s/# requirepass foobared/requirepass ${REDIS_PASSWORD}/" /etc/redis/redis.conf
sudo sed -i "s/# maxmemory <bytes>/maxmemory 256mb/" /etc/redis/redis.conf
sudo sed -i "s/# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/" /etc/redis/redis.conf

# Restart Redis
sudo systemctl restart redis-server
sudo systemctl enable redis-server
```

### Step 7: Create Application User

```bash
# Create dedicated user
sudo useradd -r -s /bin/bash -d /opt/barqnet barqnet

# Create directory
sudo mkdir -p /opt/barqnet
sudo chown barqnet:barqnet /opt/barqnet
```

### Step 8: Deploy Application

```bash
# Clone repository
cd /opt/barqnet
sudo -u barqnet git clone https://github.com/yourusername/ChameleonVpn.git
cd ChameleonVpn/barqnet-backend

# Generate production secrets
JWT_SECRET=$(openssl rand -base64 48)
API_KEY=$(openssl rand -hex 32)

# Create .env file
sudo -u barqnet tee .env > /dev/null <<EOF
DB_NAME=barqnet
DB_USER=barqnet
DB_PASSWORD=${DB_PASSWORD}
DB_HOST=localhost
DB_PORT=5432
DB_SSLMODE=require

JWT_SECRET=${JWT_SECRET}
API_KEY=${API_KEY}
API_PORT=8080

REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_DB=0

ENVIRONMENT=production
EOF

# Build applications
sudo -u barqnet /usr/local/go/bin/go build -o bin/management ./apps/management
sudo -u barqnet /usr/local/go/bin/go build -o bin/endnode ./apps/endnode

# Run migrations
sudo -u postgres psql -d barqnet -f migrations/001_initial_schema.sql
sudo -u postgres psql -d barqnet -f migrations/006_add_active_column.sql
```

### Step 9: Create Systemd Services

**Management Service:**

```bash
sudo tee /etc/systemd/system/barqnet-management.service > /dev/null <<EOF
[Unit]
Description=BarqNet Management Server
After=network.target postgresql.service redis-server.service
Wants=postgresql.service redis-server.service

[Service]
Type=simple
User=barqnet
Group=barqnet
WorkingDirectory=/opt/barqnet/ChameleonVpn/barqnet-backend
EnvironmentFile=/opt/barqnet/ChameleonVpn/barqnet-backend/.env
ExecStart=/opt/barqnet/ChameleonVpn/barqnet-backend/bin/management
Restart=always
RestartSec=10

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/barqnet

# Limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
```

**Endnode Service:**

```bash
sudo tee /etc/systemd/system/barqnet-endnode.service > /dev/null <<EOF
[Unit]
Description=BarqNet Endnode Server
After=network.target postgresql.service redis-server.service
Wants=postgresql.service redis-server.service

[Service]
Type=simple
User=barqnet
Group=barqnet
WorkingDirectory=/opt/barqnet/ChameleonVpn/barqnet-backend
EnvironmentFile=/opt/barqnet/ChameleonVpn/barqnet-backend/.env
ExecStart=/opt/barqnet/ChameleonVpn/barqnet-backend/bin/endnode
Restart=always
RestartSec=10

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/barqnet

# Limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
```

**Enable and start services:**

```bash
sudo systemctl daemon-reload
sudo systemctl enable barqnet-management barqnet-endnode
sudo systemctl start barqnet-management barqnet-endnode
sudo systemctl status barqnet-management
```

### Step 10: Configure Nginx

```bash
# Create Nginx configuration
sudo tee /etc/nginx/sites-available/barqnet > /dev/null <<'EOF'
# Rate limiting
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/s;

server {
    listen 80;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        limit_req zone=api_limit burst=20 nodelay;
    }

    location ~ ^/(auth|api/auth) {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        limit_req zone=auth_limit burst=10 nodelay;
    }

    location /health {
        proxy_pass http://localhost:8080;
        access_log off;
    }
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/barqnet /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# Test and restart
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### Step 11: SSL Certificate (Let's Encrypt)

```bash
# Obtain certificate
sudo certbot --nginx -d api.yourdomain.com

# Auto-renewal is configured automatically
sudo certbot renew --dry-run
```

### Step 12: Firewall Configuration

```bash
# Enable firewall
sudo ufw --force enable

# Configure rules
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'

# Verify
sudo ufw status
```

---

## 🎛️ Service Management

### Basic Commands

```bash
# Start services
sudo systemctl start barqnet-management
sudo systemctl start barqnet-endnode

# Stop services
sudo systemctl stop barqnet-management
sudo systemctl stop barqnet-endnode

# Restart services
sudo systemctl restart barqnet-management
sudo systemctl restart barqnet-endnode

# Check status
sudo systemctl status barqnet-management
sudo systemctl status barqnet-endnode

# Enable on boot
sudo systemctl enable barqnet-management
sudo systemctl enable barqnet-endnode

# Disable on boot
sudo systemctl disable barqnet-management
sudo systemctl disable barqnet-endnode
```

### View Logs

```bash
# Real-time logs
sudo journalctl -u barqnet-management -f
sudo journalctl -u barqnet-endnode -f

# Last 100 lines
sudo journalctl -u barqnet-management -n 100

# Since specific time
sudo journalctl -u barqnet-management --since "1 hour ago"
sudo journalctl -u barqnet-management --since "2025-11-16 00:00:00"

# By priority (errors only)
sudo journalctl -u barqnet-management -p err

# Export logs
sudo journalctl -u barqnet-management --since today > management.log
```

---

## 📊 Monitoring & Logging

### System Monitoring

```bash
# Install monitoring tools
sudo apt-get install -y htop iotop nethogs

# CPU and memory
htop

# Disk I/O
sudo iotop

# Network usage
sudo nethogs

# Disk space
df -h

# Service status
systemctl status barqnet-*
```

### Application Monitoring

Create monitoring script `/opt/barqnet/monitor.sh`:

```bash
#!/bin/bash
# BarqNet Health Monitor

API_URL="http://localhost:8080"
LOG_FILE="/var/log/barqnet/monitor.log"

# Create log directory
mkdir -p /var/log/barqnet

# Health check
check_health() {
    response=$(curl -s -o /dev/null -w "%{http_code}" ${API_URL}/health)

    if [ "$response" == "200" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - HEALTHY" >> $LOG_FILE
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - UNHEALTHY (HTTP $response)" >> $LOG_FILE
        # Send alert (configure your alerting system)
        # send_alert "BarqNet backend is unhealthy"
        return 1
    fi
}

# Database connectivity
check_database() {
    if sudo -u postgres psql -d barqnet -c "SELECT 1" > /dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Database: OK" >> $LOG_FILE
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Database: FAILED" >> $LOG_FILE
        return 1
    fi
}

# Redis connectivity
check_redis() {
    if redis-cli ping > /dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Redis: OK" >> $LOG_FILE
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Redis: FAILED" >> $LOG_FILE
        return 1
    fi
}

# Run checks
check_health
check_database
check_redis
```

**Setup cron job:**

```bash
# Make executable
chmod +x /opt/barqnet/monitor.sh

# Add to crontab (every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/barqnet/monitor.sh") | crontab -
```

### Log Rotation

Create `/etc/logrotate.d/barqnet`:

```conf
/var/log/barqnet/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 barqnet barqnet
    sharedscripts
    postrotate
        systemctl reload barqnet-management barqnet-endnode > /dev/null 2>&1 || true
    endscript
}
```

---

## 💾 Backup & Recovery

### Database Backup

Create backup script `/opt/barqnet/backup-db.sh`:

```bash
#!/bin/bash
# Database Backup Script

BACKUP_DIR="/opt/barqnet/backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="barqnet"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
sudo -u postgres pg_dump $DB_NAME | gzip > $BACKUP_DIR/${DB_NAME}_${DATE}.sql.gz

# Keep only last 30 days
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete

echo "$(date '+%Y-%m-%d %H:%M:%S') - Database backup completed: ${DB_NAME}_${DATE}.sql.gz"
```

**Setup automated backups:**

```bash
chmod +x /opt/barqnet/backup-db.sh

# Daily backup at 2 AM
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/barqnet/backup-db.sh") | crontab -
```

### Restore Database

```bash
# Stop services
sudo systemctl stop barqnet-management barqnet-endnode

# Restore from backup
gunzip < /opt/barqnet/backups/barqnet_YYYYMMDD_HHMMSS.sql.gz | sudo -u postgres psql -d barqnet

# Start services
sudo systemctl start barqnet-management barqnet-endnode
```

### Configuration Backup

```bash
# Backup .env and configs
tar -czf /opt/barqnet/backups/config_$(date +%Y%m%d).tar.gz \
    /opt/barqnet/ChameleonVpn/barqnet-backend/.env \
    /etc/systemd/system/barqnet-*.service \
    /etc/nginx/sites-available/barqnet
```

---

## 🔒 Security Hardening

### SSH Security

Edit `/etc/ssh/sshd_config`:

```conf
# Disable root login
PermitRootLogin no

# Use SSH keys only
PasswordAuthentication no
PubkeyAuthentication yes

# Disable empty passwords
PermitEmptyPasswords no

# Change default port (optional)
Port 2222
```

Restart SSH:
```bash
sudo systemctl restart sshd
```

### Fail2Ban

```bash
# Install
sudo apt-get install -y fail2ban

# Configure
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/*error.log
EOF

# Start
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### Automatic Security Updates

```bash
# Install unattended-upgrades
sudo apt-get install -y unattended-upgrades

# Enable
sudo dpkg-reconfigure -plow unattended-upgrades
```

---

## 🔧 Troubleshooting

### Service Won't Start

```bash
# Check service status
sudo systemctl status barqnet-management

# Check logs
sudo journalctl -u barqnet-management -n 100 --no-pager

# Check environment variables
sudo -u barqnet env

# Verify binary exists
ls -la /opt/barqnet/ChameleonVpn/barqnet-backend/bin/management

# Test manually
cd /opt/barqnet/ChameleonVpn/barqnet-backend
sudo -u barqnet ./bin/management
```

### Database Connection Issues

```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Test connection
sudo -u postgres psql -d barqnet -c "SELECT version();"

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-15-main.log

# Verify credentials in .env
sudo -u barqnet cat /opt/barqnet/ChameleonVpn/barqnet-backend/.env | grep DB_
```

### High CPU/Memory Usage

```bash
# Check top processes
htop

# Check service resources
systemctl status barqnet-management

# Analyze logs for errors
sudo journalctl -u barqnet-management --since "1 hour ago" | grep -i error

# Database performance
sudo -u postgres psql -d barqnet -c "SELECT * FROM pg_stat_activity;"
```

### Nginx Issues

```bash
# Test configuration
sudo nginx -t

# Check logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/barqnet_error.log

# Restart Nginx
sudo systemctl restart nginx

# Check which process is using port 80/443
sudo lsof -i :80
sudo lsof -i :443
```

---

## 🛠️ Maintenance

### Updates

```bash
# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

# Update application
cd /opt/barqnet/ChameleonVpn
sudo -u barqnet git pull origin main
cd barqnet-backend
sudo -u barqnet /usr/local/go/bin/go build -o bin/management ./apps/management
sudo -u barqnet /usr/local/go/bin/go build -o bin/endnode ./apps/endnode

# Restart services
sudo systemctl restart barqnet-management barqnet-endnode
```

### Database Maintenance

```bash
# Vacuum (reclaim space)
sudo -u postgres psql -d barqnet -c "VACUUM ANALYZE;"

# Reindex
sudo -u postgres psql -d barqnet -c "REINDEX DATABASE barqnet;"

# Check database size
sudo -u postgres psql -d barqnet -c "SELECT pg_size_pretty(pg_database_size('barqnet'));"
```

### Clean Logs

```bash
# Clean old journal logs (keep 7 days)
sudo journalctl --vacuum-time=7d

# Clean old Nginx logs
sudo find /var/log/nginx -name "*.gz" -mtime +30 -delete
```

---

## 📞 Support

For issues or questions:
- Check logs: `sudo journalctl -u barqnet-management -f`
- Review documentation: `/opt/barqnet/ChameleonVpn/HAMAD_READ_THIS.md`
- Check deployment info: `/opt/barqnet/DEPLOYMENT_INFO.txt`

---

**Last Updated:** November 16, 2025
**Version:** 1.0
