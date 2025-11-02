# 🌍 BARQNET VPN - DUAL-REGION DEPLOYMENT (Qatar & Amsterdam)

## Executive Summary

This document outlines two infrastructure deployment plans for BarqNet VPN with primary data centers in **Qatar (Doha)** and **Amsterdam (Netherlands)**. Both plans provide full geographic redundancy, automatic failover, and optimized latency for global users.

- **Plan A:** Small deployment for up to 200 concurrent users
- **Plan B:** Full-scale deployment for up to 80,000 concurrent users

---

## 📋 PLAN A: SMALL DEPLOYMENT (Up to 200 Users)

### **Geographic Distribution Strategy**

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  QATAR DATA CENTER (Primary)          AMSTERDAM DATA CENTER (DR)    │
│  ┌────────────────────────────┐      ┌────────────────────────────┐│
│  │  Management & Database     │      │  Management Standby        ││
│  │  ┌──────────┐ ┌──────────┐│      │  ┌──────────────────────┐  ││
│  │  │ Backend  │ │PostgreSQL││◄─────┼─►│  Database Replica    │  ││
│  │  │ (Active) │ │ (Master) ││      │  │  (Read-only sync)    │  ││
│  │  └──────────┘ └──────────┘│      │  └──────────────────────┘  ││
│  └────────────────────────────┘      └────────────────────────────┘│
│                                                                      │
│  ┌────────────────────────────┐      ┌────────────────────────────┐│
│  │  VPN Server Pool (Qatar)   │      │  VPN Server Pool (EU)      ││
│  │  ┌────────┐  ┌────────┐   │      │  ┌────────┐                ││
│  │  │ VPN-Q1 │  │ VPN-Q2 │   │      │  │ VPN-EU1│                ││
│  │  │100 users│  │100 users│   │      │  │100 users│                ││
│  │  └────────┘  └────────┘   │      │  └────────┘                ││
│  └────────────────────────────┘      └────────────────────────────┘│
│                                                                      │
│  Coverage: Middle East, Asia,        Coverage: Europe, Africa,     │
│           South Asia                           Russia              │
└─────────────────────────────────────────────────────────────────────┘
```

### **Infrastructure Architecture**

#### **QATAR DATA CENTER (Primary)**

**Location:** Doha, Qatar (Middle East Hub)

**1x Management & Database Server:**
- **CPU:** 8 cores (Intel Xeon Silver 4214 or AMD EPYC 7232P)
- **RAM:** 16GB DDR4 ECC
- **Storage:**
  - OS: 100GB NVMe (RAID 1)
  - Database: 200GB NVMe (RAID 10)
  - Backups: 500GB SSD
- **Network:** 2x 1Gbps NICs (bonded for redundancy)
- **OS:** Ubuntu 22.04 LTS Server
- **Services:**
  - PostgreSQL 14 (Master)
  - Go Management API (port 8080)
  - Nginx (SSL termination)
  - Real-time replication to Amsterdam

**2x VPN Servers (Qatar):**
- **CPU:** 4 cores each (Intel Xeon or AMD EPYC)
- **RAM:** 8GB DDR4 ECC each
- **Storage:** 80GB NVMe (RAID 1) each
- **Network:** 2x 1Gbps NICs (bonded) each
- **OS:** Ubuntu 22.04 LTS Server
- **Services:**
  - OpenVPN server (port 1194 UDP)
  - Go End-Node API (port 8081)
  - Easy-RSA (certificate management)
- **Capacity:** 100 concurrent users each

---

#### **AMSTERDAM DATA CENTER (Disaster Recovery + EU Users)**

**Location:** Amsterdam, Netherlands (European Hub)

**1x Management Standby Server:**
- **CPU:** 8 cores
- **RAM:** 16GB DDR4 ECC
- **Storage:**
  - OS: 100GB NVMe (RAID 1)
  - Database: 200GB NVMe (RAID 10)
- **Network:** 2x 1Gbps NICs (bonded)
- **OS:** Ubuntu 22.04 LTS Server
- **Services:**
  - PostgreSQL 14 (Streaming Replica)
  - Go Management API (Standby mode)
  - Automatic failover capability

**1x VPN Server (Amsterdam):**
- **CPU:** 4 cores
- **RAM:** 8GB DDR4 ECC
- **Storage:** 80GB NVMe (RAID 1)
- **Network:** 2x 1Gbps NICs
- **OS:** Ubuntu 22.04 LTS Server
- **Services:** OpenVPN server (port 1194 UDP)
- **Capacity:** 100 concurrent users

---

### **Network Architecture**

#### **Inter-Region Connectivity**

```
Qatar Data Center                     Amsterdam Data Center
┌─────────────────┐                  ┌─────────────────┐
│  10.10.0.0/16   │   VPN Tunnel    │  10.20.0.0/16   │
│                 │  (Encrypted)     │                 │
│  Management:    │◄────────────────►│  Management:    │
│  10.10.1.10     │  IPSec/WireGuard│  10.20.1.10     │
│                 │                  │                 │
│  Database:      │◄────────────────►│  Database:      │
│  10.10.2.10     │                  │  10.20.2.10     │
│                 │                  │                 │
│  VPN Servers:   │                  │  VPN Servers:   │
│  10.10.3.x      │                  │  10.20.3.x      │
└─────────────────┘                  └─────────────────┘
```

**VPN Tunnel Requirements:**
- **Type:** Site-to-Site IPSec or WireGuard
- **Bandwidth:** 500 Mbps minimum
- **Latency:** < 100ms (Qatar ↔ Amsterdam)
- **Encryption:** AES-256-GCM
- **Redundancy:** Dual tunnels (active/standby)

#### **Public IP Allocation**

**Qatar:**
- Management API: 1 static public IP
- VPN-Qatar-1: 1 static public IP
- VPN-Qatar-2: 1 static public IP

**Amsterdam:**
- Management API: 1 static public IP
- VPN-EU-1: 1 static public IP

**Total Required:** 5 static public IPs

---

### **Geographic User Routing**

#### **Intelligent Region Selection**

| User Location | Qatar Latency | Amsterdam Latency | Best Choice |
|---------------|---------------|-------------------|-------------|
| Dubai, UAE | 5-10ms | 120ms | Qatar |
| Riyadh, Saudi | 15-20ms | 130ms | Qatar |
| Mumbai, India | 50-60ms | 150ms | Qatar |
| Singapore | 80-90ms | 180ms | Qatar |
| London, UK | 140ms | 5-10ms | Amsterdam |
| Paris, France | 150ms | 10-15ms | Amsterdam |
| Frankfurt, Germany | 145ms | 5-10ms | Amsterdam |
| Cairo, Egypt | 80ms | 60ms | Amsterdam* |
| Moscow, Russia | 110ms | 50ms | Amsterdam |

*Note: Egypt can use either region depending on load

---

### **Bandwidth Requirements**

**Qatar Data Center:**
- **Internet Uplink:** 2 Gbps (redundant)
- **Average Load:** 500 Mbps
- **Peak Load:** 1.2 Gbps
- **Monthly Traffic:** 10TB

**Amsterdam Data Center:**
- **Internet Uplink:** 2 Gbps (redundant)
- **Average Load:** 300 Mbps
- **Peak Load:** 800 Mbps
- **Monthly Traffic:** 5TB

---

### **Failover & High Availability**

```
NORMAL OPERATION:
Qatar (Primary)              Amsterdam (Standby)
┌─────────────┐             ┌─────────────┐
│ Management  │─Replicate──►│ Management  │
│ (Active)    │             │ (Standby)   │
│ DB Master   │─Stream─────►│ DB Replica  │
└─────────────┘             └─────────────┘


FAILOVER SCENARIO (Qatar Down):
Qatar (Offline)             Amsterdam (Promoted)
┌─────────────┐             ┌─────────────┐
│ Management  │             │ Management  │
│ (Down)      │             │ (ACTIVE)    │
│ DB Master   │             │ DB Master   │
│ (Down)      │             │ (Promoted)  │
└─────────────┘             └─────────────┘
```

**Failover Capabilities:**
- **Automatic Detection:** 30 seconds
- **Failover Time:** 2 minutes (DNS TTL + promotion)
- **Data Loss:** Zero (streaming replication)
- **Manual Override:** Available via CLI

---

### **Hardware Summary - Plan A**

| Location | Server Type | Quantity | CPU | RAM | Storage |
|----------|-------------|----------|-----|-----|---------|
| **Qatar** | Management + DB | 1 | 8 cores | 16GB | 800GB |
| **Qatar** | VPN Servers | 2 | 4 cores | 8GB | 80GB |
| **Amsterdam** | Management Standby | 1 | 8 cores | 16GB | 300GB |
| **Amsterdam** | VPN Server | 1 | 4 cores | 8GB | 80GB |
| **TOTAL** | **All** | **5** | **28 cores** | **56GB** | **1.34TB** |

---

### **Power & Cooling Requirements - Plan A**

**Qatar Data Center:**
- **Power:** 3kW total
- **Cooling:** Standard rack cooling (5kW capacity)
- **UPS:** 5kVA (15 minutes runtime)
- **Rack Space:** 1 standard rack (42U) - 14U used

**Amsterdam Data Center:**
- **Power:** 2kW total
- **Cooling:** Standard rack cooling (5kW capacity)
- **UPS:** 5kVA (15 minutes runtime)
- **Rack Space:** 1 standard rack (42U) - 10U used

---

## 📋 PLAN B: FULL-SCALE DEPLOYMENT (Up to 80,000 Users)

### **Geographic Distribution Strategy**

```
┌──────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│  QATAR PRIMARY DATA CENTER            AMSTERDAM PRIMARY DATA CENTER       │
│  (50% capacity - 40,000 users)        (50% capacity - 40,000 users)     │
│                                                                           │
│  ┌──────────────────────────────┐    ┌──────────────────────────────┐   │
│  │  MANAGEMENT CLUSTER (2)      │    │  MANAGEMENT CLUSTER (2)      │   │
│  │  ┌─────────┐  ┌─────────┐   │◄──►│  ┌─────────┐  ┌─────────┐   │   │
│  │  │ Mgmt-Q1 │  │ Mgmt-Q2 │   │    │  │ Mgmt-E1 │  │ Mgmt-E2 │   │   │
│  │  │ Active  │  │ Active  │   │    │  │ Active  │  │ Active  │   │   │
│  │  └─────────┘  └─────────┘   │    │  └─────────┘  └─────────┘   │   │
│  └──────────────────────────────┘    └──────────────────────────────┘   │
│                                                                           │
│  ┌──────────────────────────────┐    ┌──────────────────────────────┐   │
│  │  DATABASE CLUSTER (3)        │    │  DATABASE CLUSTER (3)        │   │
│  │  ┌────────┐  ┌──────────┐   │◄──►│  ┌────────┐  ┌──────────┐   │   │
│  │  │Master-Q│  │Replica-Q1│   │    │  │Master-E│  │Replica-E1│   │   │
│  │  │(Write) │  │Replica-Q2│   │    │  │(Write) │  │Replica-E2│   │   │
│  │  └────────┘  └──────────┘   │    │  └────────┘  └──────────┘   │   │
│  └──────────────────────────────┘    └──────────────────────────────┘   │
│                                                                           │
│  ┌──────────────────────────────┐    ┌──────────────────────────────┐   │
│  │  VPN SERVER POOL (25)        │    │  VPN SERVER POOL (25)        │   │
│  │  ┌────┐ ┌────┐ ┌────┐        │    │  ┌────┐ ┌────┐ ┌────┐        │   │
│  │  │VPN │ │VPN │ │... │        │    │  │VPN │ │VPN │ │... │        │   │
│  │  │ Q1 │ │ Q2 │ │Q25 │        │    │  │ E1 │ │ E2 │ │E25 │        │   │
│  │  └────┘ └────┘ └────┘        │    │  └────┘ └────┘ └────┘        │   │
│  │  1600 users each              │    │  1600 users each              │   │
│  └──────────────────────────────┘    └──────────────────────────────┘   │
│                                                                           │
│  ┌──────────────────────────────┐    ┌──────────────────────────────┐   │
│  │  MONITORING CLUSTER (2)      │    │  MONITORING CLUSTER (2)      │   │
│  │  ┌──────────┐  ┌─────────┐  │    │  ┌──────────┐  ┌─────────┐  │   │
│  │  │Prometheus│  │ Grafana │  │    │  │Prometheus│  │ Grafana │  │   │
│  │  │  + ELK   │  │Dashboard│  │    │  │  + ELK   │  │Dashboard│  │   │
│  │  └──────────┘  └─────────┘  │    │  └──────────┘  └─────────┘  │   │
│  └──────────────────────────────┘    └──────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────┘
```

---

### **Server Specifications**

#### **Management Cluster (2 servers per region)**
- **CPU:** 16 cores (Intel Xeon Gold 6226R or AMD EPYC 7302P)
- **RAM:** 64GB DDR4 ECC
- **Storage:**
  - OS: 200GB NVMe (RAID 1)
  - Cache: 500GB NVMe
- **Network:** 2x 10Gbps NICs (bonded)
- **OS:** Ubuntu 22.04 LTS Server

**Configuration:**
- 2 Active (load balanced via HAProxy)
- HAProxy for load balancing
- Keepalived for VIP management

---

#### **Database Cluster (3 servers per region)**
- **CPU:** 24 cores (Intel Xeon Platinum 8260 or AMD EPYC 7402P)
- **RAM:** 128GB DDR4 ECC
- **Storage:**
  - OS: 200GB NVMe (RAID 1)
  - Database: 2TB NVMe (RAID 10)
  - WAL/Logs: 500GB NVMe
- **Network:** 2x 10Gbps NICs (bonded)
- **OS:** Ubuntu 22.04 LTS Server

**Configuration:**
- 1 Master (write operations)
- 2 Read Replicas (read operations)
- PostgreSQL 14+ with streaming replication
- PgBouncer for connection pooling
- Multi-master replication between regions

---

#### **VPN End-Node Servers (25 servers per region)**

- **CPU:** 16 cores (Intel Xeon Gold or AMD EPYC 7302P)
- **RAM:** 32GB DDR4 ECC
- **Storage:** 200GB NVMe (RAID 1)
- **Network:** 2x 10Gbps NICs (bonded)
- **OS:** Ubuntu 22.04 LTS Server

**Services Running:**
- OpenVPN server (port 1194 UDP)
- Go End-Node API (port 8081)
- Easy-RSA (certificate management)
- Traffic monitoring

**Capacity per VPN Server:**
- **Concurrent connections:** 1,600 users
- **Throughput:** Up to 8 Gbps aggregate
- **CPU headroom:** 40% for peaks

---

#### **Monitoring & Logging Cluster (2 servers per region)**
- **CPU:** 12 cores each
- **RAM:** 48GB each
- **Storage:** 2TB SSD each (RAID 10)
- **Network:** 2x 10Gbps NICs
- **OS:** Ubuntu 22.04 LTS Server

**Services:**
1. **Prometheus Server** - Metrics collection
2. **Grafana Server** - Visualization dashboards
3. **ELK Stack** - Log aggregation (Elasticsearch, Logstash, Kibana)

---

### **Multi-Master Database Architecture**

```
Qatar Database Cluster                Amsterdam Database Cluster
┌──────────────────────┐             ┌──────────────────────┐
│  ┌────────────────┐ │             │  ┌────────────────┐ │
│  │  Master-Qatar  │◄├─────Sync───►│  │  Master-EU     │ │
│  │  (Read/Write)  │ │ (Bidirect.) │  │  (Read/Write)  │ │
│  └────────┬───────┘ │             │  └────────┬───────┘ │
│    ┌──────┴──────┐  │             │    ┌──────┴──────┐  │
│  ┌─▼───┐    ┌───▼┐ │             │  ┌─▼───┐    ┌───▼┐ │
│  │Rep-1│    │Rep-2│ │             │  │Rep-1│    │Rep-2│ │
│  └─────┘    └─────┘ │             │  └─────┘    └─────┘ │
└──────────────────────┘             └──────────────────────┘
```

**Multi-Master Configuration:**
- **Replication:** Bidirectional with conflict resolution
- **Write Distribution:**
  - Qatar master: Handles ME/Asia users (50%)
  - Amsterdam master: Handles EU/RU/AF users (50%)
- **Conflict Resolution:** Last-write-wins with timestamp
- **Replication Lag:** < 100ms average
- **Failover:** Either master can take 100% load

---

### **Inter-Region Network**

```
┌──────────────────────────────────────────────────────────────┐
│           DUAL REDUNDANT VPN TUNNELS                          │
│                                                               │
│  Qatar Data Center          Encrypted Tunnels          Amsterdam DC
│  ┌──────────────┐          ════════════════          ┌──────────────┐
│  │  Gateway-Q1  │◄═══ Primary IPSec Tunnel ════════►│  Gateway-E1  │
│  │  (Primary)   │     10Gbps / AES-256              │  (Primary)   │
│  └──────────────┘                                     └──────────────┘
│        │                                                     │
│  ┌─────▼────────┐                                     ┌─────▼────────┐
│  │  Gateway-Q2  │◄═ Secondary WireGuard Tunnel ═════►│  Gateway-E2  │
│  │  (Secondary) │     10Gbps / ChaCha20-Poly1305    │  (Secondary) │
│  └──────────────┘                                     └──────────────┘
│                                                               │
│  Automatic Failover: < 5 seconds                            │
│  Load Balancing: ECMP (Equal-Cost Multi-Path)              │
│  Bandwidth: 20Gbps total (10Gbps per tunnel)                │
│  Latency: 80-100ms Qatar ↔ Amsterdam                        │
└──────────────────────────────────────────────────────────────┘
```

**Tunnel Specifications:**
- **Primary:** IPSec (IKEv2) with AES-256-GCM
- **Secondary:** WireGuard with ChaCha20-Poly1305
- **MTU:** 1400 bytes (to avoid fragmentation)
- **Keep-alive:** 10 seconds
- **Routing Protocol:** BGP with automatic failover

---

### **Geographic Load Distribution**

#### **Qatar Coverage (40,000 users):**
- **Middle East:** 20,000 users (UAE, Saudi, Kuwait, Qatar, Oman, Iraq, Jordan, Lebanon, Bahrain)
- **South Asia:** 12,000 users (India, Pakistan, Bangladesh, Sri Lanka, Nepal)
- **East/Southeast Asia:** 8,000 users (China, Japan, Korea, Singapore, Malaysia, Thailand, Indonesia, Philippines)

#### **Amsterdam Coverage (40,000 users):**
- **Europe:** 25,000 users (UK, Germany, France, Netherlands, Spain, Italy, Poland, Sweden, all EU)
- **Russia & CIS:** 8,000 users (Russia, Ukraine, Kazakhstan, Belarus, Azerbaijan)
- **Africa:** 5,000 users (Egypt, South Africa, Nigeria, Kenya, Morocco)
- **Americas (Fallback):** 2,000 users (North and South America)

---

### **Bandwidth Requirements**

**Per Region:**
- **Total Capacity:** 25 VPN servers × 8Gbps = 200 Gbps theoretical
- **Realistic Usage:** 40% utilization = 80 Gbps sustained
- **Internet Uplink:** 20 Gbps (dual 10Gbps links)
- **Peak Hours:** 15 Gbps sustained, 20 Gbps burst
- **Monthly Traffic:** 15 PB (petabytes) per region
- **Per User Average:** 375 GB/month

**Inter-Region Bandwidth:**
- **Qatar ↔ Amsterdam:** 20 Gbps (database sync, monitoring, failover)
- **Average Usage:** 5 Gbps (database replication, metrics)
- **Peak Usage:** 15 Gbps (during failover or bulk sync)

---

### **Failover Scenarios**

#### **Scenario 1: Qatar Data Center Total Failure**

**Timeline:**
- T+0: Monitoring detects Qatar offline
- T+30s: Automated alerts triggered
- T+60s: Amsterdam DB promoted to master
- T+90s: DNS updated to point all users to Amsterdam
- T+5min: All users reconnected to Amsterdam

**Performance Impact:**
- Amsterdam VPN servers running at 80% capacity (40K→80K users)
- Acceptable latency increase for ME/Asia users (10ms→140ms)

---

#### **Scenario 2: Inter-Region Link Failure**

**Behavior:**
- Both data centers continue operating independently
- Each DB master handles writes for its region
- Database sync queued, resumes when link restored
- Users unaffected (using nearest data center anyway)
- Conflict resolution applied when link restored

---

### **Hardware Summary - Plan B**

| Location | Component | Qty | CPU/Unit | RAM/Unit | Storage/Unit |
|----------|-----------|-----|----------|----------|--------------|
| **Qatar** | Management | 2 | 16 cores | 64GB | 700GB NVMe |
| **Qatar** | Database | 3 | 24 cores | 128GB | 2.7TB NVMe |
| **Qatar** | VPN Servers | 25 | 16 cores | 32GB | 200GB NVMe |
| **Qatar** | Monitoring | 2 | 12 cores | 48GB | 2TB SSD |
| **Qatar** | Load Balancer | 1 | 8 cores | 32GB | 200GB SSD |
| **Amsterdam** | Management | 2 | 16 cores | 64GB | 700GB NVMe |
| **Amsterdam** | Database | 3 | 24 cores | 128GB | 2.7TB NVMe |
| **Amsterdam** | VPN Servers | 25 | 16 cores | 32GB | 200GB NVMe |
| **Amsterdam** | Monitoring | 2 | 12 cores | 48GB | 2TB SSD |
| **Amsterdam** | Load Balancer | 1 | 8 cores | 32GB | 200GB SSD |
| **TOTALS** | **66** | **1,388 cores** | **5.92TB** | **29.8TB** |

---

### **Power & Cooling Requirements - Plan B**

**Per Region:**
- **Total Power:** 120kW (includes 30% overhead)
- **Cooling:** 140kW (precision air conditioning)
- **UPS:** 200kVA (30 minutes runtime)
- **Generator:** 250kVA diesel (8 hours fuel, 24 hours with refill)
- **Rack Space:** 4 racks (42U each) = 168U total

---

## 📊 COMPARISON SUMMARY

| Metric | Plan A (200 users) | Plan B (80,000 users) |
|--------|-------------------|---------------------|
| **Total Servers** | 5 (Q:3, A:2) | 66 (Q:33, A:33) |
| **Management** | 2 (1 per region) | 4 (2 per region) |
| **Database** | 2 (1M + 1R) | 6 (2M + 4R) |
| **VPN Servers** | 3 (Q:2, A:1) | 50 (Q:25, A:25) |
| **Total CPU Cores** | 28 | 1,388 |
| **Total RAM** | 56GB | 5.92TB |
| **Total Storage** | 1.34TB | 29.8TB |
| **Bandwidth/Region** | 2 Gbps | 20 Gbps |
| **Monthly Traffic/Region** | 7.5TB | 15PB |
| **Public IPs** | 5 | 53 |
| **Power/Region** | 3kW | 120kW |
| **Rack Space/Region** | 0.5 rack | 4 racks |
| **Inter-Region Link** | 500Mbps VPN | 20Gbps dual tunnel |
| **Failover Capability** | Manual (15min) | Automatic (<5min) |
| **Geographic Redundancy** | Yes | Full HA |

---

## 🚀 DEPLOYMENT RECOMMENDATIONS

### **For Initial Launch (0-500 users):**
- Start with Plan A configuration
- Can upgrade to Plan B as user base grows
- Estimated setup time: 1-2 weeks

### **For Enterprise Deployment (5,000+ users):**
- Deploy Plan B from the start
- Allows for growth without major infrastructure changes
- Estimated setup time: 4-6 weeks

### **Phased Approach:**
1. **Phase 1:** Deploy Qatar primary + Amsterdam DR (Plan A)
2. **Phase 2:** Add more VPN servers as user count increases
3. **Phase 3:** Upgrade to full Plan B when approaching 5,000 users

---

## 📝 NEXT STEPS

1. **Site Selection:** Confirm specific data center facilities in Qatar and Amsterdam
2. **Hardware Procurement:** 4-8 week lead time for servers
3. **Network Setup:** Coordinate with ISPs for public IPs and bandwidth
4. **Deployment:** Use automated deployment scripts (see `deployment/` directory)
5. **Testing:** 2-week testing and validation period
6. **Go-Live:** Gradual rollout with monitoring

---

**Document Version:** 1.0
**Last Updated:** 2025-10-30
**Author:** BarqNet Infrastructure Team
**Contact:** For questions about this deployment, see `HAMAD_READ_THIS.md`
