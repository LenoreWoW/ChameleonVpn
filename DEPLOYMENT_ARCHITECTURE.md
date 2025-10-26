# BarqNet - Deployment Architecture

## Overview

BarqNet uses a **client-server architecture** where clients connect to a centralized backend API server, which coordinates with distributed VPN servers.

---

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                         CLIENT DEVICES                            │
│                                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   macOS     │  │   Windows   │  │    Linux    │             │
│  │  Desktop    │  │   Desktop   │  │   Desktop   │             │
│  │  (Electron) │  │  (Electron) │  │  (Electron) │             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         │                │                │                      │
│  ┌──────┴────────────────┴────────────────┴──────┐              │
│  │              HTTPS REST API                    │              │
│  └───────────────────────┬────────────────────────┘              │
│                          │                                        │
│  ┌─────────────┐  ┌──────┴──────┐  ┌─────────────┐             │
│  │   iPhone    │  │    iPad     │  │   Android   │             │
│  │    (iOS)    │  │    (iOS)    │  │   Phone     │             │
│  │   Swift     │  │   Swift     │  │   Kotlin    │             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         │                │                │                      │
└─────────┼────────────────┼────────────────┼──────────────────────┘
          │                │                │
          └────────────────┼────────────────┘
                           │
                    HTTPS (Port 443)
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│                    UBUNTU SERVER (Backend)                        │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │          BarqNet Management API (Go)                       │  │
│  │                                                            │  │
│  │  • Authentication (OTP, JWT, BCrypt)                      │  │
│  │  • User Management                                        │  │
│  │  • VPN Configuration Generation                           │  │
│  │  • Statistics & Analytics                                 │  │
│  │  • Location Management                                    │  │
│  │                                                            │  │
│  │  Port: 8080 (internal) → 443 (HTTPS via nginx)           │  │
│  └────────────────────────┬───────────────────────────────────┘  │
│                           │                                       │
│  ┌────────────────────────▼───────────────────────────────────┐  │
│  │              PostgreSQL Database                          │  │
│  │                                                            │  │
│  │  • Users & Authentication                                 │  │
│  │  • VPN Servers & Locations                               │  │
│  │  • Statistics & Usage Data                               │  │
│  │  • Audit Logs                                            │  │
│  │                                                            │  │
│  │  Port: 5432 (localhost only)                             │  │
│  └────────────────────────┬───────────────────────────────────┘  │
│                           │                                       │
└───────────────────────────┼───────────────────────────────────────┘
                           │
            Manages VPN Servers ↓
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│              VPN END-NODE SERVERS (Ubuntu/Linux)                  │
│                                                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   VPN Server 1  │  │   VPN Server 2  │  │   VPN Server N  │  │
│  │   (New York)    │  │   (London)      │  │   (Tokyo)       │  │
│  │                 │  │                 │  │                 │  │
│  │ • OpenVPN       │  │ • OpenVPN       │  │ • OpenVPN       │  │
│  │ • EasyRSA PKI   │  │ • EasyRSA PKI   │  │ • EasyRSA PKI   │  │
│  │ • End-Node API  │  │ • End-Node API  │  │ • End-Node API  │  │
│  │                 │  │                 │  │                 │  │
│  │ Port: 1194 (UDP)│  │ Port: 1194 (UDP)│  │ Port: 1194 (UDP)│  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
            ▲                 ▲                 ▲
            │                 │                 │
            └─────────────────┴─────────────────┘
                   OpenVPN Connections
              (Encrypted VPN Tunnels - UDP 1194)
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
    ┌────┴─────┐      ┌────┴─────┐      ┌────┴─────┐
    │ Desktop  │      │   iOS    │      │ Android  │
    │  Client  │      │  Client  │      │  Client  │
    └──────────┘      └──────────┘      └──────────┘
```

---

## Deployment Locations

### ☁️ Backend (Ubuntu Server)

**What:** Management API Server + Database
**Where:** Cloud server (DigitalOcean, AWS, Linode, etc.)
**OS:** Ubuntu 20.04 LTS or newer
**Requirements:**
- Public IP address
- Domain name (e.g., api.barqnet.com)
- SSL certificate (Let's Encrypt)
- 2+ CPU cores
- 4+ GB RAM
- 40+ GB SSD

**Components:**
- BarqNet Management API (Go binary)
- PostgreSQL database
- Nginx reverse proxy (HTTPS)
- Firewall (UFW)

**Ports:**
- 443 (HTTPS) - Open to internet
- 80 (HTTP) - Open (redirects to HTTPS)
- 22 (SSH) - Open (restricted IPs)
- 8080 (API) - Localhost only
- 5432 (PostgreSQL) - Localhost only

---

### 🖥️ Desktop Clients

**What:** Electron application
**Where:** User's computers
**OS Support:**
- ✅ Windows 10/11 (x64)
- ✅ macOS 10.15+ (Intel + Apple Silicon)
- ✅ Linux (Ubuntu, Fedora, Debian, AppImage)

**Distribution:**
- **Windows:** `.exe` installer or `.msi`
- **macOS:** `.dmg` installer (signed + notarized)
- **Linux:** `.AppImage`, `.deb`, `.rpm`

**Installation Location:**
- Windows: `C:\Program Files\BarqNet\`
- macOS: `/Applications/BarqNet.app`
- Linux: `~/.local/share/BarqNet/` or `/opt/barqnet/`

**Config Storage:**
- Windows: `%APPDATA%\barqnet\`
- macOS: `~/Library/Application Support/barqnet/`
- Linux: `~/.config/barqnet/`

---

### 📱 iOS Clients

**What:** Native iOS app (Swift/SwiftUI)
**Where:** iPhones and iPads
**OS Support:**
- ✅ iOS 14.0+ (iPhone 6s and newer)
- ✅ iPadOS 14.0+ (all iPad models with iOS 14+)

**Distribution:**
- App Store (primary)
- TestFlight (beta testing)
- Enterprise distribution (if needed)

**Requirements:**
- Network Extension entitlement (VPN)
- Personal VPN capability
- Background modes (network authentication)

**Installation:**
- Installed via App Store
- Data stored in iOS Keychain (secure)
- VPN profile: Managed by Network Extension

---

### 📱 Android Clients

**What:** Native Android app (Kotlin/Jetpack Compose)
**Where:** Android phones and tablets
**OS Support:**
- ✅ Android 6.0+ (API 23+)
- ✅ Tablets and phones
- ✅ All Android devices (Samsung, Google Pixel, OnePlus, etc.)

**Distribution:**
- Google Play Store (primary)
- APK direct download (alternative)
- F-Droid (optional)

**Requirements:**
- VPN permission
- Foreground service permission
- Network access permission

**Installation:**
- Installed via Play Store or APK
- Data stored in EncryptedSharedPreferences
- VPN service: Android VpnService framework

---

### 🌍 VPN End-Node Servers

**What:** OpenVPN servers with End-Node API
**Where:** Cloud servers in multiple locations
**OS:** Ubuntu 20.04 LTS or newer

**Locations (Example):**
- 🇺🇸 New York, USA
- 🇬🇧 London, UK
- 🇯🇵 Tokyo, Japan
- 🇩🇪 Frankfurt, Germany
- 🇸🇬 Singapore
- 🇦🇺 Sydney, Australia

**Requirements (per server):**
- Public IP address
- Domain name (e.g., vpn-ny1.barqnet.com)
- 2+ CPU cores
- 2+ GB RAM
- 20+ GB SSD
- High bandwidth (1+ Gbps)

**Components:**
- OpenVPN server
- EasyRSA PKI
- BarqNet End-Node API (Go binary)
- Connection scripts

**Ports:**
- 1194 (UDP) - OpenVPN connections - Open to internet
- 22 (SSH) - SSH access - Restricted IPs
- 8081 (API) - End-Node API - Management server only

---

## Data Flow

### 1. User Registration Flow

```
Desktop Client (Windows)
  ↓ HTTPS
Management API (Ubuntu)
  ↓
PostgreSQL (Ubuntu)
  ↓ Store user data
Database (Ubuntu)
```

### 2. VPN Connection Flow

```
iOS Client (iPhone)
  ↓ HTTPS: Request VPN config
Management API (Ubuntu)
  ↓ Query available servers
PostgreSQL (Ubuntu)
  ↓ Return server: vpn-ny1.barqnet.com
Management API (Ubuntu)
  ↓ Generate .ovpn file with certificates
iOS Client (iPhone)
  ↓ OpenVPN UDP 1194: Connect to VPN
VPN Server NY1 (Ubuntu)
  ↓ Establish encrypted tunnel
iOS Client (iPhone)
  ↓ All internet traffic through VPN
Internet
```

### 3. Statistics Collection Flow

```
VPN Server (Ubuntu)
  ↓ Report connection stats
End-Node API (Ubuntu)
  ↓ HTTPS
Management API (Ubuntu)
  ↓ Store stats
PostgreSQL (Ubuntu)
  ↓ Query stats
Management API (Ubuntu)
  ↓ HTTPS
Android Client (Phone)
  ↓ Display to user
User
```

---

## Build and Distribution Strategy

### Desktop Client

**Build Once, Distribute Everywhere:**
```bash
# Build on CI/CD server (GitHub Actions)
npm run build:all

# Produces:
- BarqNet-Setup-1.0.0.exe       (Windows)
- BarqNet-1.0.0-mac.dmg         (macOS Intel)
- BarqNet-1.0.0-arm64-mac.dmg   (macOS Apple Silicon)
- BarqNet-1.0.0.AppImage        (Linux)
- barqnet_1.0.0_amd64.deb       (Debian/Ubuntu)
- barqnet-1.0.0.x86_64.rpm      (Fedora/RHEL)
```

**Distribution:**
- GitHub Releases (all platforms)
- Direct download from website
- Auto-update via electron-updater

---

### iOS Client

**Build on macOS:**
```bash
# Requires:
- Xcode 14+
- macOS 12+
- Apple Developer Account ($99/year)

# Build:
xcodebuild archive -workspace BarqNet.xcworkspace -scheme BarqNet
xcodebuild -exportArchive -archivePath build/BarqNet.xcarchive -exportPath build/

# Upload to App Store:
xcrun altool --upload-app --type ios --file build/BarqNet.ipa
```

**Distribution:**
- App Store (primary)
- TestFlight (beta)

---

### Android Client

**Build Anywhere:**
```bash
# Can build on Windows, macOS, or Linux
cd barqnet-android
./gradlew assembleRelease

# Produces:
- app-release.apk  (direct install)
- app-release.aab  (Play Store bundle)
```

**Distribution:**
- Google Play Store (primary)
- APK download (alternative)

---

## Deployment Checklist

### ☁️ Backend Server Setup

**1. Provision Ubuntu Server**
- [ ] Create cloud server (2+ cores, 4+ GB RAM)
- [ ] Assign public IP
- [ ] Configure DNS (api.barqnet.com → IP)
- [ ] Set up SSH key authentication
- [ ] Configure firewall (UFW)

**2. Install Dependencies**
```bash
sudo apt update
sudo apt install -y postgresql nginx certbot python3-certbot-nginx go-1.21
```

**3. Setup Database**
```bash
sudo -u postgres createuser barqnet
sudo -u postgres createdb barqnet
cd /opt/barqnet/barqnet-backend/migrations
go run run_migrations.go
```

**4. Deploy Backend**
```bash
cd /opt/barqnet/barqnet-backend
go build -o /usr/local/bin/barqnet-management ./apps/management
sudo systemctl enable barqnet-management
sudo systemctl start barqnet-management
```

**5. Configure Nginx**
```nginx
server {
    listen 443 ssl http2;
    server_name api.barqnet.com;

    ssl_certificate /etc/letsencrypt/live/api.barqnet.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.barqnet.com/privkey.pem;

    location /api/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**6. Get SSL Certificate**
```bash
sudo certbot --nginx -d api.barqnet.com
```

---

### 🖥️ Desktop Client Deployment

**1. Build Installers**
```bash
cd workvpn-desktop
npm install
npm run build:all
```

**2. Code Sign**
- [ ] Windows: Sign with EV certificate
- [ ] macOS: Sign + notarize with Apple Developer cert
- [ ] Linux: No signing required

**3. Distribute**
- [ ] Upload to GitHub Releases
- [ ] Update website download links
- [ ] Configure auto-updater

---

### 📱 iOS Client Deployment

**1. Prepare App**
- [ ] Update version number
- [ ] Set bundle ID: `com.barqnet.ios`
- [ ] Configure capabilities (VPN, Keychain)
- [ ] Add privacy descriptions

**2. Build Archive**
```bash
xcodebuild archive -workspace BarqNet.xcworkspace -scheme BarqNet
```

**3. TestFlight Beta**
- [ ] Upload to App Store Connect
- [ ] Add beta testers
- [ ] Collect feedback (3-5 days)

**4. App Store Release**
- [ ] Submit for review
- [ ] Wait for approval (1-3 days)
- [ ] Release to production

---

### 📱 Android Client Deployment

**1. Build Release**
```bash
cd workvpn-android
./gradlew bundleRelease
```

**2. Sign APK/AAB**
- [ ] Generate upload key
- [ ] Enable Play App Signing
- [ ] Sign with upload key

**3. Play Store Beta**
- [ ] Upload to Play Console
- [ ] Internal testing (2-3 days)
- [ ] Closed alpha (5-7 days)

**4. Production Release**
- [ ] Promote to production
- [ ] Staged rollout (10% → 50% → 100%)
- [ ] Monitor crash reports

---

## Network Requirements

### Client Requirements (All Platforms)
- Internet connection (any speed)
- HTTPS access (port 443)
- UDP port 1194 (for VPN connection)
- No proxy required (works through corporate proxies)

### Server Requirements (Backend)
- Static public IP address
- Ports 80, 443 open to internet
- Reverse DNS configured
- SSL certificate (Let's Encrypt)

### VPN Server Requirements (End-Nodes)
- Static public IP address
- Port 1194 UDP open to internet
- High bandwidth (1+ Gbps recommended)
- Low latency to target regions

---

## Security Considerations

### Client Security
- ✅ All passwords hashed (BCrypt/PBKDF2)
- ✅ All API calls use HTTPS
- ✅ Certificate pinning (prevents MITM)
- ✅ Secure storage (Keychain/EncryptedSharedPreferences)
- ✅ JWT token authentication
- ✅ Auto token refresh

### Server Security
- ✅ Firewall configured (UFW)
- ✅ SSH key-only authentication
- ✅ Fail2ban for brute force protection
- ✅ Regular security updates
- ✅ Database localhost-only access
- ✅ Audit logging enabled

### VPN Security
- ✅ OpenVPN with AES-256-GCM encryption
- ✅ TLS 1.3 for control channel
- ✅ Certificate-based authentication
- ✅ Kill switch (blocks traffic if VPN drops)
- ✅ DNS leak protection
- ✅ IPv6 leak protection

---

## Summary

| Component | OS | Location | Purpose |
|-----------|-----|----------|---------|
| **Management API** | Ubuntu Server | Cloud (DigitalOcean/AWS) | Authentication, user management, config generation |
| **PostgreSQL** | Ubuntu Server | Same as Management API | Data storage |
| **VPN Servers** | Ubuntu Server | Multiple cloud locations | OpenVPN tunnels |
| **Desktop Client** | Windows/macOS/Linux | User's computer | User interface, VPN connection |
| **iOS Client** | iOS 14+ | User's iPhone/iPad | User interface, VPN connection |
| **Android Client** | Android 6+ | User's phone/tablet | User interface, VPN connection |

**Key Points:**
1. ✅ **Backend runs on Ubuntu** - Central server with API and database
2. ✅ **Clients run on user devices** - Windows, macOS, Linux, iOS, Android
3. ✅ **VPN servers run on Ubuntu** - Distributed OpenVPN servers in multiple locations
4. ✅ **Communication:** Clients → HTTPS → Management API → PostgreSQL
5. ✅ **VPN Connection:** Clients → OpenVPN UDP → VPN Server → Internet

**Your colleague can:**
- Test Management API on Windows (development)
- Deploy Management API on Ubuntu (production)
- Distribute clients for all supported platforms
