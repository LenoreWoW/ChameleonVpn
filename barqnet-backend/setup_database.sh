#!/bin/bash

# BarqNet Database Setup Script
# This script sets up the PostgreSQL database with proper permissions

set -e  # Exit on error

echo "=========================================="
echo "BarqNet Database Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DB_NAME="barqnet"
DB_USER="barqnet"
DB_PASSWORD="barqnet123"

echo -e "${YELLOW}Step 1: Checking PostgreSQL installation...${NC}"
if ! command -v psql &> /dev/null; then
    echo -e "${RED}Error: PostgreSQL is not installed${NC}"
    echo "Install it with: sudo apt-get install postgresql postgresql-contrib"
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL is installed${NC}"
echo ""

echo -e "${YELLOW}Step 2: Checking PostgreSQL service...${NC}"
if ! sudo systemctl is-active --quiet postgresql; then
    echo "PostgreSQL is not running. Starting it..."
    sudo systemctl start postgresql
fi
echo -e "${GREEN}✓ PostgreSQL is running${NC}"
echo ""

echo -e "${YELLOW}Step 3: Creating database user '${DB_USER}'...${NC}"
sudo -u postgres psql -c "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
echo -e "${GREEN}✓ User '${DB_USER}' exists${NC}"
echo ""

echo -e "${YELLOW}Step 4: Creating database '${DB_NAME}'...${NC}"
sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw ${DB_NAME} || \
sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
echo -e "${GREEN}✓ Database '${DB_NAME}' exists${NC}"
echo ""

echo -e "${YELLOW}Step 5: Granting permissions...${NC}"
sudo -u postgres psql -d ${DB_NAME} <<EOF
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
GRANT USAGE ON SCHEMA public TO ${DB_USER};
GRANT CREATE ON SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${DB_USER};
ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};
EOF
echo -e "${GREEN}✓ Permissions granted${NC}"
echo ""

echo -e "${YELLOW}Step 6: Running database migrations...${NC}"
cd migrations
for migration in *.sql; do
    if [ -f "$migration" ]; then
        echo "  Running: $migration"
        sudo -u postgres psql -d ${DB_NAME} -f "$migration" -q
    fi
done
cd ..
echo -e "${GREEN}✓ Migrations complete${NC}"
echo ""

echo -e "${YELLOW}Step 7: Verifying database setup...${NC}"
sudo -u postgres psql -d ${DB_NAME} -c "\dt" | grep -q "users" && \
echo -e "${GREEN}✓ Tables created successfully${NC}" || \
echo -e "${RED}✗ Warning: Some tables may not exist${NC}"
echo ""

echo "=========================================="
echo -e "${GREEN}Database Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Connection details:"
echo "  Database: ${DB_NAME}"
echo "  User:     ${DB_USER}"
echo "  Password: ${DB_PASSWORD}"
echo "  Host:     localhost"
echo "  Port:     5432"
echo ""
echo "Export these environment variables:"
echo ""
echo "export DB_NAME=\"${DB_NAME}\""
echo "export DB_USER=\"${DB_USER}\""
echo "export DB_PASSWORD=\"${DB_PASSWORD}\""
echo "export DB_HOST=\"localhost\""
echo "export DB_SSLMODE=\"disable\""
echo "export JWT_SECRET=\"\$(openssl rand -base64 32)\""
echo ""
echo "Then run: ./management"
echo ""
