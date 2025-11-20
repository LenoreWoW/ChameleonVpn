# 🔒 BarqNet Production Security Checklist

**Version:** 1.0
**Last Updated:** 2025-11-20
**Status:** Pre-Production Security Review

---

## ✅ PRE-DEPLOYMENT CHECKLIST

### 🔴 CRITICAL (MUST BE COMPLETE)

- [x] **JWT Validation Fixed** - stats.go now properly validates JWT tokens
- [x] **OTP Exposure Fixed** - OTP codes no longer returned in API responses
- [x] **Server Credentials Protected** - Server passwords removed from API responses
- [ ] **JWT_SECRET Configured** - Minimum 32 characters, cryptographically random
- [ ] **Database Migrations Applied** - Run migration 005_add_performance_indexes.sql
- [ ] **SSL/TLS Certificates** - Valid certificates installed on all production servers
- [ ] **Environment Variables Set** - All required env vars configured (see below)
- [ ] **Security Testing Complete** - Penetration testing passed
- [ ] **Backup System Verified** - Database backups working and tested restore

### 🟡 HIGH PRIORITY (SHOULD BE COMPLETE)

- [x] **Rate Limiting Enabled** - API rate limiting now active
- [x] **CORS Restricted** - CORS configured for specific domains only
- [x] **Android Backup Disabled** - Sensitive data won't be backed up to cloud
- [ ] **Certificate Pinning Configured** - Production certificate pins set
- [ ] **Monitoring Enabled** - Application monitoring and alerting configured
- [ ] **Log Aggregation** - Centralized logging (ELK, Splunk, or similar)
- [ ] **DDoS Protection** - CloudFlare, AWS Shield, or similar configured
- [ ] **Database Connection Pooling** - Optimized for production load

### ⚠️ MEDIUM PRIORITY (RECOMMENDED)

- [x] **Generic Error Messages** - Internal errors not exposed to users
- [x] **Database Indexes Added** - Performance optimization indexes created
- [ ] **Security Headers Verified** - All security headers properly set
- [ ] **Session Management** - Token refresh and logout working correctly
- [ ] **Audit Logging** - Comprehensive audit trail enabled
- [ ] **Incident Response Plan** - Security incident procedures documented
- [ ] **Code Review Complete** - Security-focused code review performed

---

## 🔐 REQUIRED ENVIRONMENT VARIABLES

### Backend (Go)

```bash
# CRITICAL - Must be set
export JWT_SECRET="<STRONG_RANDOM_STRING_MIN_32_CHARS>"
export DB_HOST="<database_host>"
export DB_PORT="5432"
export DB_NAME="barqnet_production"
export DB_USER="barqnet_app"
export DB_PASSWORD="<STRONG_DATABASE_PASSWORD>"

# IMPORTANT - Should be set
export ENVIRONMENT="production"
export LOG_LEVEL="info"
export ENABLE_AUDIT_LOGGING="true"

# OTP Service (if using external provider)
export OTP_SERVICE_API_KEY="<your_otp_service_api_key>"
export OTP_SERVICE_URL="<otp_provider_url>"

# Rate Limiting (Redis recommended for production)
export REDIS_URL="redis://localhost:6379"
export RATE_LIMIT_ENABLED="true"

# CORS
export CORS_ALLOWED_ORIGINS="https://app.barqnet.com,https://admin.barqnet.com"

# Security
export ENABLE_HTTPS="true"
export TLS_CERT_PATH="/etc/ssl/certs/barqnet.crt"
export TLS_KEY_PATH="/etc/ssl/private/barqnet.key"
```

### Desktop Client (Electron)

```bash
export API_BASE_URL="https://api.barqnet.com"
export NODE_ENV="production"
export CERT_PINNING_ENABLED="true"
export CERT_PIN_PRIMARY="sha256/<YOUR_PRIMARY_CERT_PIN>"
export CERT_PIN_BACKUP="sha256/<YOUR_BACKUP_CERT_PIN>"
```

### Mobile Clients

**iOS (Xcode Build Settings):**
- Set `API_BASE_URL` to production API
- Configure certificate pins in `APIClient.swift:178`

**Android (build.gradle):**
```gradle
buildConfigField "String", "API_BASE_URL", "\"https://api.barqnet.com\""
```
- Configure certificate pins in `ApiService.kt:77`

---

## 🔑 GENERATING SECURE SECRETS

### JWT Secret (Minimum 32 characters)

```bash
# Generate cryptographically secure JWT secret
openssl rand -base64 48

# Or using Python
python3 -c "import secrets; print(secrets.token_urlsafe(48))"

# Set it
export JWT_SECRET="<generated_secret>"
```

### Database Password

```bash
# Generate strong database password
openssl rand -base64 32

# Create database user
psql -U postgres -c "CREATE USER barqnet_app WITH PASSWORD '<generated_password>';"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE barqnet_production TO barqnet_app;"
```

### Certificate Pins

```bash
# Extract certificate pin from your production API server
openssl s_client -connect api.barqnet.com:443 < /dev/null 2>/dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  base64

# Result format: sha256/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=
```

---

## 🛡️ SECURITY HARDENING

### Database Security

```sql
-- Revoke public access
REVOKE ALL ON DATABASE barqnet_production FROM PUBLIC;

-- Create read-only user for reporting
CREATE USER barqnet_readonly WITH PASSWORD '<strong_password>';
GRANT CONNECT ON DATABASE barqnet_production TO barqnet_readonly;
GRANT USAGE ON SCHEMA public TO barqnet_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO barqnet_readonly;

-- Enable SSL connections only
ALTER SYSTEM SET ssl = on;
ALTER SYSTEM SET ssl_cert_file = '/etc/ssl/certs/postgresql.crt';
ALTER SYSTEM SET ssl_key_file = '/etc/ssl/private/postgresql.key';

-- Restart PostgreSQL
sudo systemctl restart postgresql
```

### Firewall Configuration

```bash
# Backend server (Ubuntu/Debian)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 8080/tcp  # API (if not behind reverse proxy)
sudo ufw enable

# Database server (separate host)
sudo ufw allow from <backend_server_ip> to any port 5432
sudo ufw enable
```

### Nginx Reverse Proxy (Recommended)

```nginx
# /etc/nginx/sites-available/barqnet-api
server {
    listen 443 ssl http2;
    server_name api.barqnet.com;

    ssl_certificate /etc/ssl/certs/barqnet.crt;
    ssl_certificate_key /etc/ssl/private/barqnet.key;

    # SSL Security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req zone=api burst=20 nodelay;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name api.barqnet.com;
    return 301 https://$server_name$request_uri;
}
```

---

## 🚀 DEPLOYMENT STEPS

### 1. Pre-Deployment Verification

```bash
# Test backend compilation
cd /Users/hassanalsahli/Desktop/go-hello-main
go build -o barqnet-server apps/management/main.go

# Run tests
go test ./...

# Verify environment variables
./scripts/verify-env.sh
```

### 2. Database Migration

```bash
# Backup current database
pg_dump -h localhost -U barqnet_app barqnet_production > backup_$(date +%Y%m%d_%H%M%S).sql

# Run migrations
psql -h localhost -U barqnet_app -d barqnet_production -f migrations/005_add_performance_indexes.sql

# Verify indexes created
psql -h localhost -U barqnet_app -d barqnet_production -c "\di"
```

### 3. Deploy Backend

```bash
# Build production binary
CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o barqnet-server apps/management/main.go

# Copy to production server
scp barqnet-server user@production-server:/opt/barqnet/

# SSH to production server
ssh user@production-server

# Create systemd service
sudo cat > /etc/systemd/system/barqnet.service << EOF
[Unit]
Description=BarqNet VPN Management Server
After=network.target postgresql.service

[Service]
Type=simple
User=barqnet
WorkingDirectory=/opt/barqnet
EnvironmentFile=/etc/barqnet/production.env
ExecStart=/opt/barqnet/barqnet-server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable barqnet
sudo systemctl start barqnet
sudo systemctl status barqnet
```

### 4. Deploy Clients

**Desktop (Electron):**
```bash
cd workvpn-desktop
npm run build
npm run package
# Distribute .dmg (macOS) or .exe (Windows)
```

**iOS:**
```bash
cd workvpn-ios
# Archive in Xcode
# Upload to App Store Connect
```

**Android:**
```bash
cd workvpn-android
./gradlew assembleRelease
# Sign APK and upload to Google Play Console
```

---

## 📊 POST-DEPLOYMENT VERIFICATION

### Health Checks

```bash
# Backend API health
curl -I https://api.barqnet.com/health

# Database connectivity
curl https://api.barqnet.com/v1/auth/health

# SSL/TLS verification
openssl s_client -connect api.barqnet.com:443 -servername api.barqnet.com
```

### Security Verification

```bash
# Test rate limiting
for i in {1..100}; do curl https://api.barqnet.com/v1/auth/login; done

# Verify CORS
curl -H "Origin: https://evil.com" -I https://api.barqnet.com/v1/auth/login

# Test JWT validation
curl -H "Authorization: Bearer invalid_token" https://api.barqnet.com/vpn/status
```

### Monitoring Setup

```bash
# Install monitoring agents
# - Prometheus + Grafana
# - Datadog
# - New Relic
# - Your preferred monitoring solution

# Key metrics to monitor:
# - API response times
# - Error rates (4xx, 5xx)
# - Active VPN connections
# - Database query performance
# - CPU/Memory usage
# - Failed authentication attempts
```

---

## 🚨 INCIDENT RESPONSE

### Security Incident Procedure

1. **Detect** - Monitoring alerts trigger
2. **Isolate** - Take affected systems offline if needed
3. **Investigate** - Review logs, identify attack vector
4. **Remediate** - Patch vulnerability, restore from backup if needed
5. **Report** - Document incident, notify stakeholders
6. **Review** - Post-mortem, update procedures

### Emergency Contacts

```
Security Team Lead: <email>
DevOps On-Call: <phone>
Database Admin: <email>
CTO/Technical Lead: <email>
```

### Rollback Procedure

```bash
# Stop current service
sudo systemctl stop barqnet

# Restore previous version
sudo cp /opt/barqnet/barqnet-server.backup /opt/barqnet/barqnet-server

# Restore database if needed
psql -h localhost -U barqnet_app barqnet_production < backup_YYYYMMDD_HHMMSS.sql

# Restart service
sudo systemctl start barqnet
```

---

## 📝 FINAL CHECKLIST BEFORE GO-LIVE

- [ ] All CRITICAL items completed
- [ ] All HIGH priority items completed
- [ ] Environment variables set and verified
- [ ] SSL certificates installed and valid
- [ ] Database migrations applied
- [ ] Backups configured and tested
- [ ] Monitoring and alerting active
- [ ] Load testing completed
- [ ] Security testing passed
- [ ] Incident response plan reviewed
- [ ] Team trained on deployment procedures
- [ ] Rollback procedure tested
- [ ] Documentation up-to-date
- [ ] Stakeholders notified of go-live time

---

**🎯 You are ready for production deployment when ALL items above are checked!**

---

## 📞 Support & Maintenance

**Regular Security Tasks:**
- Weekly: Review audit logs
- Monthly: Security patch updates
- Quarterly: Penetration testing
- Annually: Full security audit

**Maintenance Windows:**
- Schedule: Every Sunday 2 AM - 4 AM UTC
- Duration: 2 hours maximum
- Notification: 48 hours advance notice

---

*Document Last Updated: 2025-11-20*
*Next Review Date: 2026-02-20*
