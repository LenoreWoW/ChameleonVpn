# VPN Manager Security Guide

Comprehensive security documentation and best practices for the VPN Manager system.

## 🔒 Security Overview

VPN Manager implements enterprise-grade security measures to protect VPN infrastructure, user data, and system integrity.

## 🛡️ Security Architecture

### Multi-Layer Security Model

```
┌─────────────────────────────────────────────────────────────┐
│                    Security Layers                          │
├─────────────────────────────────────────────────────────────┤
│ 1. Network Security (Firewall, VPN, TLS)                   │
│ 2. Application Security (API Auth, Input Validation)        │
│ 3. Database Security (Encryption, Access Control)          │
│ 4. Certificate Security (PKI, CRL, Revocation)            │
│ 5. System Security (User Isolation, File Permissions)      │
│ 6. Monitoring Security (Audit Logs, Intrusion Detection)   │
└─────────────────────────────────────────────────────────────┘
```

## 🔐 Authentication & Authorization

### API Key Authentication

**Implementation:**
- Strong, randomly generated API keys (256-bit)
- Key rotation every 90 days
- Secure key storage and transmission
- Rate limiting per API key

**Configuration:**
```json
{
  "api_security": {
    "key_length": 256,
    "rotation_days": 90,
    "rate_limit": {
      "requests_per_minute": 100,
      "burst_limit": 200
    }
  }
}
```

### Database Access Control

**User Roles:**
- **vpnmanager**: Full database access
- **vpnmanager_readonly**: Read-only access
- **backup_user**: Backup-only access

**Implementation:**
```sql
-- Create role-based users
CREATE USER vpnmanager_readonly WITH PASSWORD 'secure_password';
CREATE USER backup_user WITH PASSWORD 'secure_password';

-- Grant appropriate permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO vpnmanager_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup_user;
```

## 🔒 Network Security

### Firewall Configuration

**UFW Rules:**
```bash
# Default deny all
ufw default deny incoming
ufw default deny outgoing

# Allow essential services
ufw allow ssh
ufw allow 5432/tcp  # PostgreSQL
ufw allow 8080/tcp  # Management API
ufw allow 1194/udp  # OpenVPN

# Allow specific management access
ufw allow from 192.168.1.0/24 to any port 8080
ufw allow from 10.0.0.0/8 to any port 5432
```

### TLS/SSL Configuration

**PostgreSQL SSL:**
```postgresql
# postgresql.conf
ssl = on
ssl_cert_file = '/etc/ssl/certs/server.crt'
ssl_key_file = '/etc/ssl/private/server.key'
ssl_ca_file = '/etc/ssl/certs/ca.crt'
```

**API HTTPS:**
```json
{
  "tls": {
    "enabled": true,
    "cert_file": "/etc/ssl/certs/api.crt",
    "key_file": "/etc/ssl/private/api.key",
    "min_version": "1.2"
  }
}
```

## 🗄️ Database Security

### Encryption at Rest

**PostgreSQL Encryption:**
```postgresql
-- Enable transparent data encryption
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Encrypt sensitive columns
ALTER TABLE users ADD COLUMN encrypted_password BYTEA;
UPDATE users SET encrypted_password = pgp_sym_encrypt(password, 'encryption_key');
```

### Connection Security

**SSL/TLS Configuration:**
```postgresql
# pg_hba.conf
hostssl vpnmanager vpnmanager 192.168.1.0/24 md5
hostssl vpnmanager vpnmanager_readonly 192.168.1.0/24 md5
```

### Backup Security

**Encrypted Backups:**
```bash
#!/bin/bash
# Secure backup script
BACKUP_FILE="/opt/backups/vpnmanager_$(date +%Y%m%d_%H%M%S).sql"
ENCRYPTED_FILE="${BACKUP_FILE}.gpg"

# Create encrypted backup
pg_dump -h localhost -U vpnmanager vpnmanager | \
gpg --symmetric --cipher-algo AES256 --output "$ENCRYPTED_FILE"

# Remove unencrypted backup
rm -f "$BACKUP_FILE"

# Set secure permissions
chmod 600 "$ENCRYPTED_FILE"
chown vpnmanager:vpnmanager "$ENCRYPTED_FILE"
```

## 🔑 Certificate Security

### PKI Security

**EasyRSA Security Configuration:**
```bash
# /opt/vpnmanager/easyrsa/vars
export KEY_SIZE=4096
export CA_EXPIRE=3650
export KEY_EXPIRE=365
export KEY_COUNTRY="US"
export KEY_PROVINCE="CA"
export KEY_CITY="SanFrancisco"
export KEY_ORG="VPN Manager"
export KEY_EMAIL="admin@vpnmanager.local"
export KEY_OU="VPN Manager"
export KEY_NAME="VPN Manager CA"

# Security settings
export EASYRSA_BATCH=1
export EASYRSA_PKI="/opt/vpnmanager/easyrsa/pki"
export EASYRSA_OPENSSL="openssl"
```

### Certificate Revocation

**CRL Management:**
```bash
# Automatic CRL updates
#!/bin/bash
# Update CRL every hour
cd /opt/vpnmanager/easyrsa
./easyrsa gen-crl
cp pki/crl.pem /etc/openvpn/crl.pem
systemctl reload openvpn@server
```

### Key Storage Security

**File Permissions:**
```bash
# Set secure permissions
chmod 600 /opt/vpnmanager/easyrsa/pki/private/*
chmod 644 /opt/vpnmanager/easyrsa/pki/issued/*
chmod 644 /opt/vpnmanager/easyrsa/pki/ca.crt
chmod 644 /etc/openvpn/crl.pem

# Set ownership
chown -R vpnmanager:vpnmanager /opt/vpnmanager/easyrsa/
chown root:root /etc/openvpn/crl.pem
```

## 🔍 Input Validation & Sanitization

### API Input Validation

**Username Validation:**
```go
func validateUsername(username string) error {
    // Length check
    if len(username) < 3 || len(username) > 32 {
        return errors.New("username must be 3-32 characters")
    }
    
    // Character validation (alphanumeric and underscore only)
    matched, _ := regexp.MatchString("^[a-zA-Z0-9_]+$", username)
    if !matched {
        return errors.New("username must contain only alphanumeric characters and underscores")
    }
    
    // Reserved names
    reserved := []string{"admin", "root", "system", "vpnmanager"}
    for _, reserved := range reserved {
        if strings.EqualFold(username, reserved) {
            return errors.New("username is reserved")
        }
    }
    
    return nil
}
```

**SQL Injection Prevention:**
```go
// Use parameterized queries
func (um *UserManager) GetUser(username string) (*User, error) {
    query := `SELECT id, username, created_at, active, server_id 
              FROM users WHERE username = $1`
    
    var user User
    err := um.db.conn.QueryRow(query, username).Scan(
        &user.ID, &user.Username, &user.CreatedAt, 
        &user.Active, &user.ServerID,
    )
    return &user, err
}
```

### XSS Prevention

**Output Sanitization:**
```go
func sanitizeOutput(input string) string {
    // HTML escape
    input = html.EscapeString(input)
    
    // Remove script tags
    re := regexp.MustCompile(`<script[^>]*>.*?</script>`)
    input = re.ReplaceAllString(input, "")
    
    return input
}
```

## 📊 Audit Logging

### Comprehensive Audit Trail

**Audit Log Schema:**
```sql
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    action VARCHAR(255) NOT NULL,
    username VARCHAR(255),
    details TEXT,
    ip_address INET,
    server_id VARCHAR(255) NOT NULL,
    user_agent TEXT,
    session_id VARCHAR(255)
);
```

**Audit Logging Implementation:**
```go
func (api *ManagementAPI) logAudit(action, username, details, ipAddress string) {
    query := `
        INSERT INTO audit_log (action, username, details, ip_address, server_id)
        VALUES ($1, $2, $3, $4, $5)
    `
    
    _, err := api.manager.db.conn.Exec(query, action, username, details, ipAddress, "management-server")
    if err != nil {
        log.Printf("Failed to log audit: %v", err)
    }
}
```

### Security Monitoring

**Failed Login Attempts:**
```sql
-- Monitor failed authentication attempts
SELECT ip_address, COUNT(*) as attempts
FROM audit_log 
WHERE action = 'authentication_failed' 
  AND timestamp > NOW() - INTERVAL '1 hour'
GROUP BY ip_address
HAVING COUNT(*) > 5;
```

**Suspicious Activity:**
```sql
-- Monitor suspicious activities
SELECT username, action, COUNT(*) as frequency
FROM audit_log 
WHERE timestamp > NOW() - INTERVAL '24 hours'
  AND action IN ('user_created', 'user_deleted', 'endnode_registered')
GROUP BY username, action
HAVING COUNT(*) > 10;
```

## 🚨 Intrusion Detection

### Security Monitoring Script

```bash
#!/bin/bash
# security_monitor.sh

# Monitor failed login attempts
FAILED_ATTEMPTS=$(grep "authentication_failed" /var/log/vpnmanager/audit.log | \
    grep "$(date '+%Y-%m-%d %H')" | wc -l)

if [ "$FAILED_ATTEMPTS" -gt 10 ]; then
    echo "ALERT: High number of failed login attempts: $FAILED_ATTEMPTS"
    # Send alert to admin
    echo "High number of failed login attempts detected" | \
        mail -s "Security Alert" admin@company.com
fi

# Monitor unusual API activity
API_REQUESTS=$(grep "api_request" /var/log/vpnmanager/audit.log | \
    grep "$(date '+%Y-%m-%d %H')" | wc -l)

if [ "$API_REQUESTS" -gt 1000 ]; then
    echo "ALERT: High API request volume: $API_REQUESTS"
fi
```

### Automated Security Responses

**Rate Limiting:**
```go
type RateLimiter struct {
    requests map[string][]time.Time
    limit    int
    window  time.Duration
}

func (rl *RateLimiter) IsAllowed(ip string) bool {
    now := time.Now()
    cutoff := now.Add(-rl.window)
    
    // Clean old requests
    requests := rl.requests[ip]
    for i, reqTime := range requests {
        if reqTime.After(cutoff) {
            rl.requests[ip] = requests[i:]
            break
        }
    }
    
    // Check limit
    if len(rl.requests[ip]) >= rl.limit {
        return false
    }
    
    // Add current request
    rl.requests[ip] = append(rl.requests[ip], now)
    return true
}
```

## 🔧 System Security

### User Isolation

**Service User Configuration:**
```bash
# Create dedicated user
useradd -r -s /bin/false -d /opt/vpnmanager vpnmanager

# Set secure home directory
chown -R vpnmanager:vpnmanager /opt/vpnmanager
chmod 755 /opt/vpnmanager
chmod 700 /opt/vpnmanager/config
chmod 600 /opt/vpnmanager/config/*.json
```

### File System Security

**Secure File Permissions:**
```bash
# Configuration files
chmod 600 /opt/vpnmanager/config/*.json
chown vpnmanager:vpnmanager /opt/vpnmanager/config/*.json

# Certificate files
chmod 600 /opt/vpnmanager/easyrsa/pki/private/*
chmod 644 /opt/vpnmanager/easyrsa/pki/issued/*
chmod 644 /opt/vpnmanager/easyrsa/pki/ca.crt

# Log files
chmod 640 /var/log/vpnmanager/*.log
chown vpnmanager:vpnmanager /var/log/vpnmanager/*.log
```

### Process Security

**Systemd Security Settings:**
```ini
[Unit]
Description=VPN Manager Management Server
After=network.target

[Service]
Type=simple
User=vpnmanager
Group=vpnmanager
WorkingDirectory=/opt/vpnmanager
ExecStart=/opt/vpnmanager/bin/vpnmanager-management

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/vpnmanager /var/log/vpnmanager
RestrictSUIDSGID=true
RestrictRealtime=true
RestrictNamespaces=true

[Install]
WantedBy=multi-user.target
```

## 🔄 Security Updates

### Automated Security Updates

**Update Script:**
```bash
#!/bin/bash
# security_updates.sh

# Update system packages
apt update && apt upgrade -y

# Update Go dependencies
cd /opt/vpnmanager
go mod tidy
go mod download

# Rebuild applications
go build -o bin/vpnmanager-management apps/management/main.go
go build -o bin/vpnmanager-endnode apps/endnode/main.go

# Restart services
systemctl restart vpnmanager-management
systemctl restart vpnmanager-endnode
```

### Security Scanning

**Vulnerability Scanning:**
```bash
#!/bin/bash
# security_scan.sh

# Scan for vulnerabilities
nmap -sV -sC -O localhost

# Check for open ports
netstat -tulpn | grep LISTEN

# Check file permissions
find /opt/vpnmanager -type f -perm /o+w
find /opt/vpnmanager -type f -perm /o+r
```

## 📋 Security Checklist

### Pre-Deployment Security

- [ ] **API Keys**: Generate strong, unique API keys
- [ ] **Database**: Configure SSL/TLS connections
- [ ] **Firewall**: Configure UFW rules
- [ ] **Certificates**: Generate strong PKI certificates
- [ ] **Users**: Create dedicated service users
- [ ] **Permissions**: Set secure file permissions
- [ ] **Backups**: Configure encrypted backups

### Runtime Security

- [ ] **Monitoring**: Enable audit logging
- [ ] **Rate Limiting**: Configure API rate limits
- [ ] **Updates**: Schedule security updates
- [ ] **Scanning**: Regular vulnerability scans
- [ ] **Logs**: Monitor security logs
- [ ] **Access**: Review user access regularly

### Incident Response

- [ ] **Detection**: Monitor for security events
- [ ] **Response**: Automated security responses
- [ ] **Isolation**: Isolate compromised systems
- [ ] **Recovery**: Restore from secure backups
- [ ] **Analysis**: Post-incident analysis
- [ ] **Improvement**: Update security measures

## 🚨 Security Incident Response

### Incident Classification

**Level 1 - Low Risk:**
- Failed login attempts
- Unusual API usage patterns
- Minor configuration issues

**Level 2 - Medium Risk:**
- Multiple failed authentication attempts
- Unauthorized access attempts
- System performance degradation

**Level 3 - High Risk:**
- Successful unauthorized access
- Data breach indicators
- System compromise

### Response Procedures

**Immediate Response:**
1. **Isolate** affected systems
2. **Preserve** evidence and logs
3. **Notify** security team
4. **Document** incident details

**Investigation:**
1. **Analyze** logs and evidence
2. **Identify** attack vectors
3. **Assess** damage scope
4. **Determine** root cause

**Recovery:**
1. **Patch** vulnerabilities
2. **Update** security measures
3. **Restore** from backups
4. **Verify** system integrity

**Post-Incident:**
1. **Document** lessons learned
2. **Update** security procedures
3. **Train** staff on new threats
4. **Improve** security posture

## 📚 Security Resources

### Security Tools
- **Nmap**: Network scanning and security auditing
- **Fail2ban**: Intrusion prevention system
- **AIDE**: File integrity monitoring
- **Lynis**: Security auditing tool
- **ClamAV**: Antivirus scanning

### Security Standards
- **OWASP**: Web application security
- **NIST**: Cybersecurity framework
- **ISO 27001**: Information security management
- **PCI DSS**: Payment card industry security

### Security Training
- **Security Awareness**: Regular staff training
- **Incident Response**: Response procedure training
- **Threat Intelligence**: Stay updated on threats
- **Best Practices**: Continuous security education

---

**VPN Manager Security** - Enterprise-grade security for VPN infrastructure.
