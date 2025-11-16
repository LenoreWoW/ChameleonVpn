#!/bin/bash
#
# BarqNet Backend - Ubuntu Server Deployment Script
#
# This script automates the deployment of BarqNet backend on Ubuntu 20.04+ servers
# Run as root or with sudo privileges
#
# Usage:
#   sudo ./deploy-ubuntu.sh
#

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="barqnet"
APP_USER="barqnet"
APP_DIR="/opt/barqnet"
GO_VERSION="1.21.5"
POSTGRES_VERSION="15"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}BarqNet Backend - Ubuntu Deployment${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: Please run as root or with sudo${NC}"
    exit 1
fi

# Detect Ubuntu version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    echo -e "${GREEN}Detected: $OS $VER${NC}"
else
    echo -e "${RED}ERROR: Cannot detect OS version${NC}"
    exit 1
fi

# Verify Ubuntu
if [[ ! "$OS" =~ "Ubuntu" ]]; then
    echo -e "${RED}ERROR: This script is designed for Ubuntu${NC}"
    exit 1
fi

# Step 1: System Update
echo -e "\n${BLUE}[1/10] Updating system packages...${NC}"
apt-get update
apt-get upgrade -y

# Step 2: Install Dependencies
echo -e "\n${BLUE}[2/10] Installing system dependencies...${NC}"
apt-get install -y \
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
    vim \
    jq

# Step 3: Install Go
echo -e "\n${BLUE}[3/10] Installing Go ${GO_VERSION}...${NC}"
if command -v go &> /dev/null; then
    CURRENT_GO=$(go version | awk '{print $3}' | sed 's/go//')
    echo -e "${YELLOW}Go $CURRENT_GO already installed${NC}"
else
    cd /tmp
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    rm -rf /usr/local/go
    tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"

    # Add Go to PATH for all users
    echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh
    export PATH=$PATH:/usr/local/go/bin

    echo -e "${GREEN}Go ${GO_VERSION} installed successfully${NC}"
fi

# Step 4: Install PostgreSQL
echo -e "\n${BLUE}[4/10] Installing PostgreSQL ${POSTGRES_VERSION}...${NC}"
if command -v psql &> /dev/null; then
    echo -e "${YELLOW}PostgreSQL already installed${NC}"
else
    # Add PostgreSQL repository
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    apt-get update
    apt-get install -y postgresql-${POSTGRES_VERSION} postgresql-contrib-${POSTGRES_VERSION}

    echo -e "${GREEN}PostgreSQL ${POSTGRES_VERSION} installed successfully${NC}"
fi

# Step 5: Configure PostgreSQL
echo -e "\n${BLUE}[5/10] Configuring PostgreSQL...${NC}"

# Generate secure database password
DB_PASSWORD=$(openssl rand -base64 24)

# Create database and user
sudo -u postgres psql << EOF
-- Create user
CREATE USER ${APP_NAME} WITH ENCRYPTED PASSWORD '${DB_PASSWORD}';

-- Create database
CREATE DATABASE ${APP_NAME} OWNER ${APP_NAME};

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE ${APP_NAME} TO ${APP_NAME};

-- Enable required extensions
\c ${APP_NAME}
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
EOF

echo -e "${GREEN}PostgreSQL database '${APP_NAME}' created${NC}"
echo -e "${YELLOW}Database password: ${DB_PASSWORD}${NC}"
echo -e "${YELLOW}SAVE THIS PASSWORD - you'll need it for .env configuration${NC}"

# Configure PostgreSQL for production
PG_CONF="/etc/postgresql/${POSTGRES_VERSION}/main/postgresql.conf"
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" $PG_CONF
sed -i "s/max_connections = 100/max_connections = 200/" $PG_CONF
sed -i "s/shared_buffers = 128MB/shared_buffers = 256MB/" $PG_CONF

systemctl restart postgresql
echo -e "${GREEN}PostgreSQL configured for production${NC}"

# Step 6: Configure Redis
echo -e "\n${BLUE}[6/10] Configuring Redis...${NC}"

# Generate secure Redis password
REDIS_PASSWORD=$(openssl rand -base64 24)

# Configure Redis
REDIS_CONF="/etc/redis/redis.conf"
sed -i "s/# requirepass foobared/requirepass ${REDIS_PASSWORD}/" $REDIS_CONF
sed -i "s/# maxmemory <bytes>/maxmemory 256mb/" $REDIS_CONF
sed -i "s/# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/" $REDIS_CONF

systemctl restart redis-server
systemctl enable redis-server

echo -e "${GREEN}Redis configured with authentication${NC}"
echo -e "${YELLOW}Redis password: ${REDIS_PASSWORD}${NC}"
echo -e "${YELLOW}SAVE THIS PASSWORD - you'll need it for .env configuration${NC}"

# Step 7: Create Application User
echo -e "\n${BLUE}[7/10] Creating application user...${NC}"
if id "$APP_USER" &>/dev/null; then
    echo -e "${YELLOW}User $APP_USER already exists${NC}"
else
    useradd -r -s /bin/bash -d $APP_DIR $APP_USER
    echo -e "${GREEN}User $APP_USER created${NC}"
fi

# Step 8: Clone Repository and Build
echo -e "\n${BLUE}[8/10] Setting up application...${NC}"

# Create app directory
mkdir -p $APP_DIR
cd $APP_DIR

# Prompt for repository
echo -e "${YELLOW}Enter your repository URL (or press Enter to skip):${NC}"
read REPO_URL

if [ ! -z "$REPO_URL" ]; then
    # Clone repository
    if [ -d "ChameleonVpn" ]; then
        echo -e "${YELLOW}Repository already exists, pulling latest...${NC}"
        cd ChameleonVpn
        git pull origin main
    else
        git clone $REPO_URL
        cd ChameleonVpn
    fi

    cd barqnet-backend
else
    echo -e "${YELLOW}Skipping repository clone. Place your code in: $APP_DIR/ChameleonVpn/barqnet-backend${NC}"
fi

# Generate production secrets
JWT_SECRET=$(openssl rand -base64 48)
API_KEY=$(openssl rand -hex 32)

# Create .env file
cat > $APP_DIR/ChameleonVpn/barqnet-backend/.env <<EOF
# Database Configuration
DB_NAME=${APP_NAME}
DB_USER=${APP_NAME}
DB_PASSWORD=${DB_PASSWORD}
DB_HOST=localhost
DB_PORT=5432
DB_SSLMODE=require

# JWT Configuration
JWT_SECRET=${JWT_SECRET}

# API Configuration
API_KEY=${API_KEY}
API_PORT=8080

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_DB=0

# Environment
ENVIRONMENT=production
EOF

echo -e "${GREEN}.env file created with production settings${NC}"

# Build application
if [ -f "$APP_DIR/ChameleonVpn/barqnet-backend/go.mod" ]; then
    cd $APP_DIR/ChameleonVpn/barqnet-backend

    echo -e "${BLUE}Building management server...${NC}"
    /usr/local/go/bin/go build -o bin/management ./apps/management

    echo -e "${BLUE}Building endnode server...${NC}"
    /usr/local/go/bin/go build -o bin/endnode ./apps/endnode

    echo -e "${GREEN}Applications built successfully${NC}"
else
    echo -e "${YELLOW}Source code not found. Build manually after placing code.${NC}"
fi

# Set ownership
chown -R $APP_USER:$APP_USER $APP_DIR

# Step 9: Create Systemd Services
echo -e "\n${BLUE}[9/10] Creating systemd services...${NC}"

# Management service
cat > /etc/systemd/system/barqnet-management.service <<EOF
[Unit]
Description=BarqNet Management Server
After=network.target postgresql.service redis-server.service
Wants=postgresql.service redis-server.service

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}/ChameleonVpn/barqnet-backend
EnvironmentFile=${APP_DIR}/ChameleonVpn/barqnet-backend/.env
ExecStart=${APP_DIR}/ChameleonVpn/barqnet-backend/bin/management
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${APP_DIR}

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

# Endnode service
cat > /etc/systemd/system/barqnet-endnode.service <<EOF
[Unit]
Description=BarqNet Endnode Server
After=network.target postgresql.service redis-server.service
Wants=postgresql.service redis-server.service

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}/ChameleonVpn/barqnet-backend
EnvironmentFile=${APP_DIR}/ChameleonVpn/barqnet-backend/.env
ExecStart=${APP_DIR}/ChameleonVpn/barqnet-backend/bin/endnode
Restart=always
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${APP_DIR}

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

echo -e "${GREEN}Systemd services created${NC}"

# Step 10: Configure Nginx
echo -e "\n${BLUE}[10/10] Configuring Nginx reverse proxy...${NC}"

# Prompt for domain
echo -e "${YELLOW}Enter your domain name (e.g., api.example.com):${NC}"
read DOMAIN_NAME

if [ ! -z "$DOMAIN_NAME" ]; then
    cat > /etc/nginx/sites-available/${APP_NAME} <<EOF
# BarqNet Backend Nginx Configuration

# Rate limiting
limit_req_zone \$binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone \$binary_remote_addr zone=auth_limit:10m rate=5r/s;

# Management Server (API)
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_NAME};

    # Redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN_NAME};

    # SSL Configuration (managed by certbot)
    # ssl_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Client body size limit (for file uploads)
    client_max_body_size 10M;

    # Timeouts
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # API endpoints
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;

        # Proxy headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Rate limiting
        limit_req zone=api_limit burst=20 nodelay;
    }

    # Authentication endpoints (stricter rate limiting)
    location ~ ^/(auth|api/auth) {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Stricter rate limiting for auth
        limit_req zone=auth_limit burst=10 nodelay;
    }

    # Health check endpoint (no rate limiting)
    location /health {
        proxy_pass http://localhost:8080;
        access_log off;
    }

    # Logging
    access_log /var/log/nginx/${APP_NAME}_access.log;
    error_log /var/log/nginx/${APP_NAME}_error.log;
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/${APP_NAME} /etc/nginx/sites-enabled/

    # Remove default site
    rm -f /etc/nginx/sites-enabled/default

    # Test nginx configuration
    nginx -t

    # Restart nginx
    systemctl restart nginx
    systemctl enable nginx

    echo -e "${GREEN}Nginx configured for ${DOMAIN_NAME}${NC}"

    # Prompt for SSL certificate
    echo -e "${YELLOW}Would you like to obtain an SSL certificate with Let's Encrypt? (y/n)${NC}"
    read SETUP_SSL

    if [ "$SETUP_SSL" = "y" ] || [ "$SETUP_SSL" = "Y" ]; then
        echo -e "${BLUE}Obtaining SSL certificate...${NC}"
        certbot --nginx -d ${DOMAIN_NAME} --non-interactive --agree-tos --email admin@${DOMAIN_NAME}
        echo -e "${GREEN}SSL certificate obtained and configured${NC}"
    fi
else
    echo -e "${YELLOW}Skipping Nginx configuration. Configure manually later.${NC}"
fi

# Configure Firewall
echo -e "\n${BLUE}Configuring firewall...${NC}"
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw status

echo -e "${GREEN}Firewall configured${NC}"

# Create deployment summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

cat > $APP_DIR/DEPLOYMENT_INFO.txt <<EOF
BarqNet Backend Deployment Information
Generated: $(date)

SERVER INFORMATION:
- OS: $OS $VER
- Application Directory: $APP_DIR
- Application User: $APP_USER

DATABASE:
- PostgreSQL Version: ${POSTGRES_VERSION}
- Database Name: ${APP_NAME}
- Database User: ${APP_NAME}
- Database Password: ${DB_PASSWORD}

REDIS:
- Redis Password: ${REDIS_PASSWORD}

API CREDENTIALS:
- JWT Secret: ${JWT_SECRET}
- API Key: ${API_KEY}

SERVICES:
- Management Service: barqnet-management.service
- Endnode Service: barqnet-endnode.service

COMMANDS:
# Start services
sudo systemctl start barqnet-management
sudo systemctl start barqnet-endnode

# Check status
sudo systemctl status barqnet-management
sudo systemctl status barqnet-endnode

# View logs
sudo journalctl -u barqnet-management -f
sudo journalctl -u barqnet-endnode -f

# Restart services
sudo systemctl restart barqnet-management
sudo systemctl restart barqnet-endnode

# Enable on boot
sudo systemctl enable barqnet-management
sudo systemctl enable barqnet-endnode

NEXT STEPS:
1. Run database migrations:
   cd $APP_DIR/ChameleonVpn/barqnet-backend
   sudo -u postgres psql -d ${APP_NAME} -f migrations/001_initial_schema.sql
   sudo -u postgres psql -d ${APP_NAME} -f migrations/006_add_active_column.sql

2. Start the services:
   sudo systemctl start barqnet-management
   sudo systemctl start barqnet-endnode

3. Verify services are running:
   curl http://localhost:8080/health

4. Check logs for any errors:
   sudo journalctl -u barqnet-management -f

SECURITY NOTES:
- All passwords are randomly generated and stored in .env
- Services run as unprivileged user: ${APP_USER}
- Firewall (ufw) is enabled
- SSL/TLS certificates configured via Let's Encrypt (if selected)

BACKUP THIS FILE - It contains all your credentials!
EOF

# Secure the credentials file
chmod 600 $APP_DIR/DEPLOYMENT_INFO.txt
chown $APP_USER:$APP_USER $APP_DIR/DEPLOYMENT_INFO.txt

echo -e "\n${YELLOW}========================================"
echo -e "IMPORTANT - SAVE THESE CREDENTIALS:"
echo -e "========================================${NC}"
echo -e "Database Password: ${GREEN}${DB_PASSWORD}${NC}"
echo -e "Redis Password: ${GREEN}${REDIS_PASSWORD}${NC}"
echo -e "JWT Secret: ${GREEN}${JWT_SECRET}${NC}"
echo -e "API Key: ${GREEN}${API_KEY}${NC}"
echo -e ""
echo -e "${YELLOW}All credentials saved to: ${GREEN}$APP_DIR/DEPLOYMENT_INFO.txt${NC}"
echo -e ""
echo -e "${BLUE}Next Steps:${NC}"
echo -e "1. Run database migrations"
echo -e "2. Start services: ${GREEN}sudo systemctl start barqnet-management barqnet-endnode${NC}"
echo -e "3. Check status: ${GREEN}sudo systemctl status barqnet-management${NC}"
echo -e "4. View logs: ${GREEN}sudo journalctl -u barqnet-management -f${NC}"
echo -e ""
echo -e "${GREEN}Deployment script completed successfully!${NC}"
