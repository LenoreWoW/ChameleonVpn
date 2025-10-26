# VPN Manager Production Deployment Guide

Comprehensive guide for deploying VPN Manager in production environments with enterprise-grade security and reliability.

## 🏗️ Production Architecture

### Recommended Production Setup

```
┌─────────────────────────────────────────────────────────────────┐
│                    Production Architecture                       │
├─────────────────────────────────────────────────────────────────┤
│  Load Balancer (HAProxy/Nginx)                                 │
│  ├─ SSL Termination                                            │
│  ├─ Rate Limiting                                             │
│  └─ Health Checks                                             │
├─────────────────────────────────────────────────────────────────┤
│  Management Servers (2x for HA)                               │
│  ├─ PostgreSQL Connection Pooling                            │
│  ├─ Redis Cache Layer                                         │
│  ├─ Web UI Dashboard                                          │
│  └─ API Gateway                                               │
├─────────────────────────────────────────────────────────────────┤
│  Database Cluster (PostgreSQL HA)                             │
│  ├─ Primary Database                                          │
│  ├─ Standby Replica                                           │
│  ├─ Automated Backups                                         │
│  └─ Point-in-Time Recovery                                    │
├─────────────────────────────────────────────────────────────────┤
│  End-Node Servers (Multiple)                                  │
│  ├─ OpenVPN Servers                                           │
│  ├─ EasyRSA PKI                                               │
│  ├─ Health Monitoring                                         │
│  └─ Local API Services                                        │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 System Requirements

### Minimum Requirements

**Management Server:**
- **CPU**: 2 cores, 2.4GHz
- **RAM**: 4GB
- **Storage**: 50GB SSD
- **Network**: 1Gbps
- **OS**: Ubuntu 20.04 LTS or CentOS 8

**Database Server:**
- **CPU**: 4 cores, 2.4GHz
- **RAM**: 8GB
- **Storage**: 100GB SSD (RAID 1)
- **Network**: 1Gbps
- **OS**: Ubuntu 20.04 LTS or CentOS 8

**End-Node Server:**
- **CPU**: 2 cores, 2.4GHz
- **RAM**: 2GB
- **Storage**: 20GB SSD
- **Network**: 1Gbps
- **OS**: Ubuntu 20.04 LTS or CentOS 8

### Recommended Production Requirements

**Management Server:**
- **CPU**: 4 cores, 3.0GHz
- **RAM**: 8GB
- **Storage**: 100GB NVMe SSD
- **Network**: 10Gbps
- **OS**: Ubuntu 22.04 LTS

**Database Server:**
- **CPU**: 8 cores, 3.0GHz
- **RAM**: 16GB
- **Storage**: 500GB NVMe SSD (RAID 10)
- **Network**: 10Gbps
- **OS**: Ubuntu 22.04 LTS

**End-Node Server:**
- **CPU**: 4 cores, 3.0GHz
- **RAM**: 4GB
- **Storage**: 50GB NVMe SSD
- **Network**: 10Gbps
- **OS**: Ubuntu 22.04 LTS

## 🚀 Deployment Options

### Option 1: Cloud Deployment (AWS/Azure/GCP)

#### AWS Deployment

**Infrastructure:**
```yaml
# terraform/main.tf
provider "aws" {
  region = "us-west-2"
}

# VPC and Networking
resource "aws_vpc" "vpnmanager" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "vpnmanager-vpc"
  }
}

# Management Server
resource "aws_instance" "management" {
  ami           = "ami-0c02fb55956c7d316" # Ubuntu 22.04 LTS
  instance_type = "t3.medium"
  
  vpc_security_group_ids = [aws_security_group.management.id]
  subnet_id              = aws_subnet.public.id
  
  user_data = file("scripts/cloud-init-management.sh")
  
  tags = {
    Name = "vpnmanager-management"
  }
}

# Database Server
resource "aws_db_instance" "postgres" {
  identifier = "vpnmanager-db"
  
  engine         = "postgres"
  engine_version = "14.7"
  instance_class = "db.t3.medium"
  
  allocated_storage     = 100
  max_allocated_storage = 1000
  storage_type          = "gp3"
  storage_encrypted     = true
  
  db_name  = "vpnmanager"
  username = "vpnmanager"
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.database.id]
  db_subnet_group_name   = aws_db_subnet_group.vpnmanager.name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = false
  deletion_protection = true
}
```

#### Azure Deployment

**Infrastructure:**
```yaml
# azure/main.bicep
param location string = resourceGroup().location
param adminUsername string = 'vpnmanager'
param adminPassword string

// Management Server
resource managementVM 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: 'vpnmanager-management'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: 'management'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: managementNIC.id
        }
      ]
    }
  }
}
```

### Option 2: On-Premises Deployment

#### Physical Server Setup

**Hardware Requirements:**
- **Rack Servers**: Dell PowerEdge or HP ProLiant
- **Network**: 10Gbps switches with VLAN support
- **Storage**: NVMe SSDs with RAID 10
- **Power**: UPS with 4-hour runtime
- **Cooling**: Redundant cooling systems

**Network Configuration:**
```bash
# Network interfaces
# Management Network: 192.168.1.0/24
# Database Network: 192.168.2.0/24
# VPN Network: 10.8.0.0/16
# Monitoring Network: 192.168.3.0/24
```

### Option 3: Hybrid Cloud Deployment

**Architecture:**
- **Management**: On-premises or cloud
- **Database**: Cloud (AWS RDS/Azure Database)
- **End-Nodes**: Distributed across cloud and on-premises

## 🔒 Security Hardening

### System Hardening

#### 1. Operating System Hardening

```bash
#!/bin/bash
# system_hardening.sh

# Update system
apt update && apt upgrade -y

# Install security tools
apt install -y fail2ban ufw aide lynis

# Configure fail2ban
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl enable fail2ban
systemctl start fail2ban

# Configure UFW firewall
ufw --force enable
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow ssh

# Allow VPN Manager ports
ufw allow 8080/tcp  # Management API
ufw allow 1194/udp  # OpenVPN
ufw allow 5432/tcp  # PostgreSQL

# Configure AIDE for file integrity monitoring
aide --init
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Set up automated security scanning
cat > /etc/cron.daily/security-scan << 'EOF'
#!/bin/bash
# Run security scan
lynis audit system --quick

# Check file integrity
aide --check

# Check for failed login attempts
grep "Failed password" /var/log/auth.log | tail -10
EOF

chmod +x /etc/cron.daily/security-scan
```

#### 2. Database Security

```bash
#!/bin/bash
# database_security.sh

# Configure PostgreSQL SSL
cat >> /etc/postgresql/14/main/postgresql.conf << 'EOF'
# SSL Configuration
ssl = on
ssl_cert_file = '/etc/ssl/certs/postgresql.crt'
ssl_key_file = '/etc/ssl/private/postgresql.key'
ssl_ca_file = '/etc/ssl/certs/ca.crt'
ssl_min_protocol_version = 'TLSv1.2'
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'

# Security Settings
password_encryption = scram-sha-256
log_connections = on
log_disconnections = on
log_statement = 'all'
log_min_duration_statement = 1000
EOF

# Configure pg_hba.conf
cat >> /etc/postgresql/14/main/pg_hba.conf << 'EOF'
# VPN Manager connections
hostssl vpnmanager vpnmanager 192.168.1.0/24 scram-sha-256
hostssl vpnmanager vpnmanager_readonly 192.168.1.0/24 scram-sha-256
EOF

# Restart PostgreSQL
systemctl restart postgresql
```

#### 3. Application Security

```bash
#!/bin/bash
# application_security.sh

# Create dedicated user
useradd -r -s /bin/false -d /opt/vpnmanager vpnmanager

# Set up secure directories
mkdir -p /opt/vpnmanager/{config,logs,backups}
mkdir -p /var/log/vpnmanager

# Set secure permissions
chown -R vpnmanager:vpnmanager /opt/vpnmanager
chown -R vpnmanager:vpnmanager /var/log/vpnmanager

# Configuration files
chmod 600 /opt/vpnmanager/config/*.json
chmod 640 /var/log/vpnmanager/*.log

# Create systemd service with security settings
cat > /etc/systemd/system/vpnmanager-management.service << 'EOF'
[Unit]
Description=VPN Manager Management Server
After=network.target postgresql.service

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

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vpnmanager-management
```

### Network Security

#### 1. Firewall Configuration

```bash
#!/bin/bash
# firewall_setup.sh

# Configure UFW with strict rules
ufw --force reset
ufw default deny incoming
ufw default deny outgoing

# Allow essential outbound connections
ufw allow out 53/udp    # DNS
ufw allow out 80/tcp    # HTTP
ufw allow out 443/tcp   # HTTPS
ufw allow out 123/udp    # NTP

# Allow SSH (restrict to management network)
ufw allow from 192.168.1.0/24 to any port 22

# Allow VPN Manager services
ufw allow from 192.168.1.0/24 to any port 8080  # Management API
ufw allow from 192.168.2.0/24 to any port 5432  # PostgreSQL
ufw allow 1194/udp  # OpenVPN

# Allow health checks
ufw allow from 192.168.3.0/24 to any port 8080

# Enable logging
ufw logging on

# Enable UFW
ufw --force enable
```

#### 2. VPN Security

```bash
#!/bin/bash
# vpn_security.sh

# Configure OpenVPN with security settings
cat > /etc/openvpn/server.conf << 'EOF'
# Basic Configuration
port 1194
proto udp
dev tun

# Security Settings
cipher AES-256-GCM
auth SHA256
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384

# Certificate Configuration
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-crypt tls-crypt.key
crl-verify crl.pem

# Network Configuration
server 10.8.0.0 255.255.0.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"

# Security Features
keepalive 10 120
explicit-exit-notify 1
remote-cert-tls client
verify-client-cert require

# Logging
status openvpn-status.log
verb 3
mute 20

# Performance
sndbuf 393216
rcvbuf 393216
push "sndbuf 393216"
push "rcvbuf 393216"
EOF

# Set secure permissions
chmod 600 /etc/openvpn/server.key
chmod 600 /etc/openvpn/tls-crypt.key
chmod 644 /etc/openvpn/server.crt
chmod 644 /etc/openvpn/ca.crt
chmod 644 /etc/openvpn/crl.pem
```

## 📊 Monitoring & Logging

### 1. Centralized Logging

```bash
#!/bin/bash
# logging_setup.sh

# Install ELK Stack (Elasticsearch, Logstash, Kibana)
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-7.x.list

apt update
apt install -y elasticsearch logstash kibana

# Configure Elasticsearch
cat > /etc/elasticsearch/elasticsearch.yml << 'EOF'
cluster.name: vpnmanager
node.name: vpnmanager-node-1
network.host: 192.168.1.100
discovery.seed_hosts: ["192.168.1.100"]
cluster.initial_master_nodes: ["vpnmanager-node-1"]
EOF

# Configure Logstash
cat > /etc/logstash/conf.d/vpnmanager.conf << 'EOF'
input {
  beats {
    port => 5044
  }
}

filter {
  if [fields][service] == "vpnmanager" {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:message}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["localhost:9200"]
    index => "vpnmanager-%{+YYYY.MM.dd}"
  }
}
EOF

# Start services
systemctl enable elasticsearch logstash kibana
systemctl start elasticsearch logstash kibana
```

### 2. Health Monitoring

```bash
#!/bin/bash
# monitoring_setup.sh

# Install Prometheus and Grafana
wget https://github.com/prometheus/prometheus/releases/download/v2.40.0/prometheus-2.40.0.linux-amd64.tar.gz
tar xzf prometheus-2.40.0.linux-amd64.tar.gz
mv prometheus-2.40.0.linux-amd64 /opt/prometheus

# Configure Prometheus
cat > /opt/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'vpnmanager-management'
    static_configs:
      - targets: ['192.168.1.100:8080']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'vpnmanager-endnodes'
    static_configs:
      - targets: ['192.168.1.101:8080', '192.168.1.102:8080']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'postgresql'
    static_configs:
      - targets: ['192.168.2.100:5432']
    scrape_interval: 30s
EOF

# Create systemd service
cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus
After=network.target

[Service]
Type=simple
User=prometheus
Group=prometheus
WorkingDirectory=/opt/prometheus
ExecStart=/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus
```

### 3. Alerting

```bash
#!/bin/bash
# alerting_setup.sh

# Install Alertmanager
wget https://github.com/prometheus/alertmanager/releases/download/v0.25.0/alertmanager-0.25.0.linux-amd64.tar.gz
tar xzf alertmanager-0.25.0.linux-amd64.tar.gz
mv alertmanager-0.25.0.linux-amd64 /opt/alertmanager

# Configure Alertmanager
cat > /opt/alertmanager/alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@vpnmanager.local'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  email_configs:
  - to: 'admin@vpnmanager.local'
    subject: 'VPN Manager Alert: {{ .GroupLabels.alertname }}'
    body: |
      {{ range .Alerts }}
      Alert: {{ .Annotations.summary }}
      Description: {{ .Annotations.description }}
      {{ end }}
EOF

# Create systemd service
cat > /etc/systemd/system/alertmanager.service << 'EOF'
[Unit]
Description=Alertmanager
After=network.target

[Service]
Type=simple
User=prometheus
Group=prometheus
WorkingDirectory=/opt/alertmanager
ExecStart=/opt/alertmanager/alertmanager --config.file=/opt/alertmanager/alertmanager.yml

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable alertmanager
systemctl start alertmanager
```

## 🔄 Backup & Recovery

### 1. Database Backups

```bash
#!/bin/bash
# backup_database.sh

# Create backup directory
mkdir -p /opt/backups/postgresql

# Create backup script
cat > /opt/backups/backup_postgresql.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/backups/postgresql"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/vpnmanager_$DATE.sql"
ENCRYPTED_FILE="$BACKUP_FILE.gpg"

# Create backup
pg_dump -h localhost -U vpnmanager vpnmanager > "$BACKUP_FILE"

# Encrypt backup
gpg --symmetric --cipher-algo AES256 --output "$ENCRYPTED_FILE" "$BACKUP_FILE"

# Remove unencrypted backup
rm -f "$BACKUP_FILE"

# Set secure permissions
chmod 600 "$ENCRYPTED_FILE"
chown vpnmanager:vpnmanager "$ENCRYPTED_FILE"

# Keep only last 30 days of backups
find "$BACKUP_DIR" -name "*.gpg" -mtime +30 -delete

# Upload to S3 (if using AWS)
# aws s3 cp "$ENCRYPTED_FILE" s3://vpnmanager-backups/
EOF

chmod +x /opt/backups/backup_postgresql.sh

# Schedule daily backups
echo "0 2 * * * /opt/backups/backup_postgresql.sh" | crontab -u vpnmanager -
```

### 2. Configuration Backups

```bash
#!/bin/bash
# backup_config.sh

# Create configuration backup script
cat > /opt/backups/backup_config.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/backups/config"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/vpnmanager_config_$DATE.tar.gz"

# Create backup
tar -czf "$BACKUP_FILE" \
    /opt/vpnmanager/config \
    /etc/openvpn \
    /opt/vpnmanager/easyrsa/pki \
    /etc/ssl/certs \
    /etc/ssl/private

# Set secure permissions
chmod 600 "$BACKUP_FILE"
chown vpnmanager:vpnmanager "$BACKUP_FILE"

# Keep only last 30 days of backups
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete
EOF

chmod +x /opt/backups/backup_config.sh

# Schedule weekly backups
echo "0 3 * * 0 /opt/backups/backup_config.sh" | crontab -u vpnmanager -
```

### 3. Disaster Recovery

```bash
#!/bin/bash
# disaster_recovery.sh

# Database recovery
restore_database() {
    local backup_file="$1"
    
    # Decrypt backup
    gpg --decrypt "$backup_file" > "/tmp/restore.sql"
    
    # Restore database
    psql -h localhost -U vpnmanager -d vpnmanager < "/tmp/restore.sql"
    
    # Clean up
    rm -f "/tmp/restore.sql"
}

# Configuration recovery
restore_config() {
    local backup_file="$1"
    
    # Extract backup
    tar -xzf "$backup_file" -C /
    
    # Restart services
    systemctl restart vpnmanager-management
    systemctl restart vpnmanager-endnode
    systemctl restart openvpn@server
}

# Full system recovery
full_recovery() {
    echo "Starting full system recovery..."
    
    # Restore database
    restore_database "/opt/backups/postgresql/vpnmanager_latest.sql.gpg"
    
    # Restore configuration
    restore_config "/opt/backups/config/vpnmanager_config_latest.tar.gz"
    
    # Verify services
    systemctl status vpnmanager-management
    systemctl status vpnmanager-endnode
    systemctl status openvpn@server
    
    echo "Recovery completed"
}
```

## 🚀 Deployment Automation

### 1. Ansible Playbooks

```yaml
# ansible/playbooks/deploy-management.yml
---
- name: Deploy VPN Manager Management Server
  hosts: management_servers
  become: yes
  vars:
    vpnmanager_version: "1.0.0"
    database_host: "{{ database_servers[0] }}"
    api_key: "{{ vault_api_key }}"
  
  tasks:
    - name: Update system packages
      apt:
        update_cache: yes
        upgrade: dist
    
    - name: Install dependencies
      apt:
        name:
          - postgresql-client
          - ufw
          - fail2ban
          - aide
        state: present
    
    - name: Create vpnmanager user
      user:
        name: vpnmanager
        system: yes
        shell: /bin/false
        home: /opt/vpnmanager
        create_home: yes
    
    - name: Download VPN Manager binary
      get_url:
        url: "https://github.com/vpnmanager/releases/download/v{{ vpnmanager_version }}/vpnmanager-management"
        dest: "/opt/vpnmanager/bin/vpnmanager-management"
        mode: '0755'
    
    - name: Create configuration
      template:
        src: management-config.json.j2
        dest: /opt/vpnmanager/config/management-config.json
        owner: vpnmanager
        group: vpnmanager
        mode: '0600'
    
    - name: Create systemd service
      template:
        src: vpnmanager-management.service.j2
        dest: /etc/systemd/system/vpnmanager-management.service
        mode: '0644'
    
    - name: Configure firewall
      ufw:
        rule: allow
        port: "8080"
        proto: tcp
    
    - name: Enable and start service
      systemd:
        name: vpnmanager-management
        enabled: yes
        state: started
        daemon_reload: yes
```

### 2. Docker Compose

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  postgres:
    image: postgres:14
    environment:
      POSTGRES_DB: vpnmanager
      POSTGRES_USER: vpnmanager
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./ssl/postgresql.crt:/etc/ssl/certs/postgresql.crt:ro
      - ./ssl/postgresql.key:/etc/ssl/private/postgresql.key:ro
    command: >
      postgres
      -c ssl=on
      -c ssl_cert_file=/etc/ssl/certs/postgresql.crt
      -c ssl_key_file=/etc/ssl/private/postgresql.key
    networks:
      - vpnmanager_network
    restart: unless-stopped

  management:
    image: vpnmanager/management:latest
    environment:
      DB_HOST: postgres
      DB_USER: vpnmanager
      DB_PASSWORD: ${DB_PASSWORD}
      DB_NAME: vpnmanager
      API_KEY: ${API_KEY}
    volumes:
      - ./config:/opt/vpnmanager/config:ro
      - ./logs:/var/log/vpnmanager
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    networks:
      - vpnmanager_network
    restart: unless-stopped

  endnode:
    image: vpnmanager/endnode:latest
    environment:
      MANAGEMENT_URL: http://management:8080
      API_KEY: ${API_KEY}
      SERVER_ID: ${SERVER_ID}
    volumes:
      - ./config:/opt/vpnmanager/config:ro
      - ./logs:/var/log/vpnmanager
      - ./easyrsa:/opt/vpnmanager/easyrsa
      - ./openvpn:/etc/openvpn
    ports:
      - "8080:8080"
      - "1194:1194/udp"
    depends_on:
      - management
    networks:
      - vpnmanager_network
    restart: unless-stopped

volumes:
  postgres_data:

networks:
  vpnmanager_network:
    driver: bridge
```

### 3. Kubernetes Deployment

```yaml
# k8s/management-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vpnmanager-management
  labels:
    app: vpnmanager-management
spec:
  replicas: 2
  selector:
    matchLabels:
      app: vpnmanager-management
  template:
    metadata:
      labels:
        app: vpnmanager-management
    spec:
      containers:
      - name: management
        image: vpnmanager/management:latest
        ports:
        - containerPort: 8080
        env:
        - name: DB_HOST
          value: "postgres-service"
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: vpnmanager-secrets
              key: db-user
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: vpnmanager-secrets
              key: db-password
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: vpnmanager-secrets
              key: api-key
        volumeMounts:
        - name: config
          mountPath: /opt/vpnmanager/config
          readOnly: true
        - name: logs
          mountPath: /var/log/vpnmanager
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: vpnmanager-config
      - name: logs
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: vpnmanager-management-service
spec:
  selector:
    app: vpnmanager-management
  ports:
  - port: 8080
    targetPort: 8080
  type: LoadBalancer
```

## 📋 Production Checklist

### Pre-Deployment

- [ ] **Hardware**: Verify system requirements
- [ ] **Network**: Configure network topology
- [ ] **Security**: Implement security hardening
- [ ] **Monitoring**: Set up monitoring and alerting
- [ ] **Backups**: Configure backup systems
- [ ] **Documentation**: Update operational procedures

### Deployment

- [ ] **Database**: Deploy and configure PostgreSQL
- [ ] **Management**: Deploy management servers
- [ ] **End-Nodes**: Deploy end-node servers
- [ ] **Load Balancer**: Configure load balancing
- [ ] **SSL/TLS**: Configure certificates
- [ ] **Firewall**: Configure network security

### Post-Deployment

- [ ] **Testing**: Run comprehensive tests
- [ ] **Monitoring**: Verify monitoring systems
- [ ] **Backups**: Test backup and recovery
- [ ] **Security**: Run security scans
- [ ] **Performance**: Load testing
- [ ] **Documentation**: Update runbooks

### Ongoing Operations

- [ ] **Updates**: Schedule security updates
- [ ] **Monitoring**: Review monitoring alerts
- [ ] **Backups**: Verify backup integrity
- [ ] **Security**: Regular security audits
- [ ] **Performance**: Monitor system performance
- [ ] **Capacity**: Plan for growth

## 🆘 Troubleshooting

### Common Issues

#### Database Connection Issues
```bash
# Check PostgreSQL status
systemctl status postgresql

# Test connection
psql -h localhost -U vpnmanager -d vpnmanager -c "SELECT 1;"

# Check logs
journalctl -u postgresql -f
```

#### Service Startup Issues
```bash
# Check service status
systemctl status vpnmanager-management

# Check logs
journalctl -u vpnmanager-management -f

# Check configuration
/opt/vpnmanager/bin/vpnmanager-management --config-check
```

#### Network Issues
```bash
# Check firewall
ufw status

# Test connectivity
telnet management-server 8080
telnet database-server 5432

# Check DNS
nslookup management-server
```

### Performance Issues

#### High CPU Usage
```bash
# Check processes
top -p $(pgrep vpnmanager)

# Check system resources
htop
iostat -x 1
```

#### Memory Issues
```bash
# Check memory usage
free -h
ps aux --sort=-%mem | head

# Check for memory leaks
valgrind --tool=memcheck /opt/vpnmanager/bin/vpnmanager-management
```

#### Network Performance
```bash
# Check network statistics
netstat -i
ss -tuln

# Test network performance
iperf3 -c target-server
```

---

**VPN Manager Production Deployment** - Enterprise-grade deployment for mission-critical VPN infrastructure.
