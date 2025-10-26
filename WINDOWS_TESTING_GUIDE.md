# BarqNet Backend - Windows Testing Guide

## Overview

The BarqNet backend is written in Go which is cross-platform, but has some components designed for Linux/Unix production servers. This guide explains what will and won't work on Windows, and how to test the backend on Windows.

---

## Quick Answer: What Works on Windows?

### ✅ WILL WORK (Can Test on Windows)

1. **Go Backend Compilation** - Go is cross-platform
2. **API Server** - Management server will run and serve API endpoints
3. **Database Operations** - PostgreSQL client works on Windows
4. **Authentication Logic** - OTP, JWT, BCrypt all work
5. **API Endpoint Testing** - Can test all REST APIs
6. **Client Integration** - Desktop client (Electron) works on Windows

### ❌ WON'T WORK (Linux/Unix Only)

1. **OpenVPN Management** - Uses Unix sockets (`/var/run/openvpn/server.sock`)
2. **Bash Scripts** - 10 shell scripts (.sh files) need bash/WSL
3. **End-Node Server** - Designed for Linux OpenVPN servers
4. **User Disconnection** - Requires OpenVPN management interface (Unix sockets)
5. **CRL Refresh Scripts** - Uses bash, openssl, Linux paths

---

## What Your Colleague Can Test on Windows

### ✅ Primary Testing Focus: Management Server API

The **Management Server** is the API gateway that clients connect to. This can be fully tested on Windows.

```
┌─────────────────────────────────────────┐
│         WORKS ON WINDOWS                │
│                                         │
│  📱 Desktop Client (Electron/Windows)   │
│            ↓                            │
│  🖥️  Management API Server (Go)         │
│            ↓                            │
│  🗄️  PostgreSQL Database (Windows)      │
│                                         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│      LINUX/UNIX ONLY                    │
│                                         │
│  🖥️  End-Node VPN Server                │
│  🔧 OpenVPN + Management Interface      │
│  📜 Bash Scripts                        │
│                                         │
└─────────────────────────────────────────┘
```

---

## Windows Testing Setup

### Step 1: Install Prerequisites

#### 1.1 Install Go
```powershell
# Download from: https://go.dev/dl/
# Or use winget:
winget install GoLang.Go

# Verify:
go version
```

#### 1.2 Install PostgreSQL
```powershell
# Download from: https://www.postgresql.org/download/windows/
# Or use winget:
winget install PostgreSQL.PostgreSQL

# Verify:
psql --version
```

#### 1.3 Install Git
```powershell
winget install Git.Git
```

#### 1.4 Install Git Bash (Optional, for scripts)
```powershell
# Included with Git for Windows
# Allows running .sh scripts on Windows
```

---

### Step 2: Clone and Build

```powershell
# Clone repository
cd C:\Users\YourName\Projects
git clone https://github.com/LenoreWoW/ChameleonVpn.git
cd ChameleonVpn\barqnet-backend

# Download dependencies
go mod download

# Build Management Server (WILL WORK)
go build -o management.exe .\apps\management

# Build End-Node Server (WILL COMPILE but won't run fully)
go build -o endnode.exe .\apps\endnode
```

**Expected Result:**
- ✅ Both should compile successfully
- ✅ You'll get `management.exe` and `endnode.exe`

---

### Step 3: Set Up Database

```powershell
# Start PostgreSQL (if not already running)
# Usually auto-starts as Windows service

# Create database using PowerShell
$env:PGPASSWORD = "your_postgres_password"
psql -U postgres -c "CREATE DATABASE barqnet;"
psql -U postgres -c "CREATE USER barqnet WITH PASSWORD 'barqnet123';"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE barqnet TO barqnet;"
```

Or use Git Bash for the provided script:
```bash
# Open Git Bash
cd /c/Users/YourName/Projects/ChameleonVpn/barqnet-backend
bash scripts/setup-database.sh
```

---

### Step 4: Run Database Migrations

```powershell
cd migrations

# Set database connection
$env:DATABASE_URL = "postgres://barqnet:barqnet123@localhost/barqnet?sslmode=disable"

# Run migrations
go run run_migrations.go
```

**Expected Output:**
```
Connected to database successfully
Running migrations...
✓ Migration 002_add_phone_auth.sql
✓ Migration 003_add_statistics.sql
✓ Migration 004_add_locations.sql
All migrations completed successfully!
```

---

### Step 5: Configure Environment

Create `.env` file in `barqnet-backend/`:
```powershell
# PowerShell: Create .env file
@"
DATABASE_URL=postgres://barqnet:barqnet123@localhost/barqnet?sslmode=disable
JWT_SECRET=your-secret-key-change-in-production
PORT=8080

# OTP/SMS (Twilio) - Optional for testing
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+1234567890

# For testing without SMS:
ENABLE_OTP_CONSOLE=true
"@ | Out-File -FilePath .env -Encoding UTF8
```

---

### Step 6: Run Management Server

```powershell
# Set environment variables
$env:DATABASE_URL = "postgres://barqnet:barqnet123@localhost/barqnet?sslmode=disable"
$env:JWT_SECRET = "your-secret-key-change-in-production"
$env:PORT = "8080"

# Run management server
.\management.exe
```

**Expected Output:**
```
Starting BarqNet Management Server...
Database connected successfully
Server listening on :8080
```

---

## Testing the API

### Test 1: Health Check
```powershell
# PowerShell
Invoke-WebRequest -Uri http://localhost:8080/api/health -Method GET | Select-Object -ExpandProperty Content

# Or using curl (if installed)
curl http://localhost:8080/api/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "timestamp": 1234567890
}
```

### Test 2: Send OTP
```powershell
$body = @{
    phone_number = "+1234567890"
} | ConvertTo-Json

Invoke-WebRequest -Uri http://localhost:8080/api/auth/send-otp `
    -Method POST `
    -ContentType "application/json" `
    -Body $body | Select-Object -ExpandProperty Content
```

### Test 3: Verify OTP
```powershell
$body = @{
    phone_number = "+1234567890"
    code = "123456"
} | ConvertTo-Json

Invoke-WebRequest -Uri http://localhost:8080/api/auth/verify-otp `
    -Method POST `
    -ContentType "application/json" `
    -Body $body | Select-Object -ExpandProperty Content
```

### Test 4: Register User
```powershell
$body = @{
    phone_number = "+1234567890"
    password = "SecurePassword123!"
    verification_token = "your-token-from-verify-otp"
} | ConvertTo-Json

Invoke-WebRequest -Uri http://localhost:8080/api/auth/register `
    -Method POST `
    -ContentType "application/json" `
    -Body $body | Select-Object -ExpandProperty Content
```

### Test 5: Login
```powershell
$body = @{
    phone_number = "+1234567890"
    password = "SecurePassword123!"
} | ConvertTo-Json

Invoke-WebRequest -Uri http://localhost:8080/api/auth/login `
    -Method POST `
    -ContentType "application/json" `
    -Body $body | Select-Object -ExpandProperty Content
```

---

## What Cannot Be Tested on Windows

### 1. OpenVPN Management Interface

**Issue:** Uses Unix sockets (`/var/run/openvpn/server.sock`)

**File:** `apps/endnode/api/api.go` (lines 553-558)
```go
socketPaths := []string{
    "/var/run/openvpn/server.sock",
    "/var/run/openvpn-server/server.sock",
    "/run/openvpn/server.sock",
}
```

**Windows Alternative:** None - OpenVPN management interface requires Linux/Unix

**Impact:** Cannot test user disconnection feature on Windows

---

### 2. Bash Scripts

**Issue:** Windows doesn't natively run bash scripts

**Scripts that won't work:**
- `scripts/client-connect.sh` - Connection hooks
- `scripts/client-disconnect.sh` - Disconnection hooks
- `scripts/disconnect-user.sh` - User disconnection
- `scripts/refresh-crl.sh` - CRL refresh
- `scripts/setup-*.sh` - Setup scripts

**Windows Alternative:** Use Git Bash or WSL

```powershell
# Install WSL (Windows Subsystem for Linux)
wsl --install

# Then run scripts in WSL:
wsl bash scripts/setup-database.sh
```

---

### 3. End-Node Server Full Functionality

**Issue:** End-Node server integrates with OpenVPN which is Linux-focused

**What won't work:**
- OpenVPN certificate generation
- VPN tunnel management
- User disconnection
- CRL management

**What will work:**
- API endpoints (basic testing)
- Database operations
- Configuration management

---

## Recommended Windows Testing Workflow

### ✅ What to Test on Windows:

1. **Management API Server**
   - All authentication endpoints
   - User registration/login
   - JWT token generation
   - Database operations
   - API error handling

2. **Database Layer**
   - Migrations
   - User CRUD operations
   - Statistics queries
   - Audit logging

3. **Desktop Client Integration**
   - Client can connect to API
   - Authentication flow works
   - VPN config download (file only, not connection)

### ⏭️ What to Test on Linux (Later):

1. **End-Node VPN Server**
   - OpenVPN integration
   - Certificate management
   - User disconnection
   - CRL refresh

2. **Production Scripts**
   - Connection hooks
   - Monitoring
   - Automated tasks

---

## Using WSL for Full Testing

If you need to test Linux-specific features:

### Install WSL
```powershell
wsl --install
wsl --install -d Ubuntu
```

### Set Up in WSL
```bash
# In WSL Ubuntu terminal
cd /mnt/c/Users/YourName/Projects/ChameleonVpn

# Install dependencies
sudo apt update
sudo apt install -y postgresql-client openvpn easy-rsa

# Run Linux-specific scripts
cd barqnet-backend
bash scripts/setup-database.sh
bash scripts/setup-easyrsa.sh
```

---

## Common Windows Issues and Solutions

### Issue 1: "go: command not found"
**Solution:**
```powershell
# Restart terminal or refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Verify:
go version
```

### Issue 2: PostgreSQL Connection Failed
**Solution:**
```powershell
# Check PostgreSQL service
Get-Service -Name postgresql*

# Start if stopped
Start-Service postgresql-x64-14

# Test connection
psql -U postgres -d barqnet
```

### Issue 3: Permission Denied on Scripts
**Solution:**
```powershell
# Use Git Bash instead of PowerShell
"C:\Program Files\Git\bin\bash.exe" scripts/setup-database.sh

# Or use WSL
wsl bash scripts/setup-database.sh
```

### Issue 4: Build Errors
**Solution:**
```powershell
# Clean and rebuild
go clean
go mod tidy
go build .\apps\management
```

---

## Production Deployment Note

**Important:** While you can develop and test the Management API on Windows, **production deployment should be on Linux** because:

1. End-Node servers require Linux + OpenVPN
2. Bash scripts are production-critical
3. Unix sockets for VPN management
4. Better performance and security on Linux
5. All documentation assumes Linux deployment

**Recommended Production Environment:**
- Ubuntu 20.04 LTS or newer
- Debian 11 or newer
- CentOS 8 / Rocky Linux 8

---

## Testing Checklist

### ✅ Windows Testing (Management API)
- [ ] Go compilation succeeds
- [ ] PostgreSQL connection works
- [ ] Database migrations run successfully
- [ ] Management server starts without errors
- [ ] Health check endpoint responds
- [ ] OTP send/verify works
- [ ] User registration works
- [ ] User login works
- [ ] JWT tokens generate correctly
- [ ] API errors handled properly
- [ ] Desktop client can connect

### ⏭️ Linux Testing (End-Node + Scripts)
- [ ] End-Node server starts
- [ ] OpenVPN integration works
- [ ] Certificate generation works
- [ ] User disconnection works
- [ ] CRL refresh works
- [ ] Connection hooks work
- [ ] Monitoring scripts work

---

## Getting Help

If you encounter issues:

1. Check logs:
   ```powershell
   # Management server logs to console
   # Check for error messages
   ```

2. Verify database:
   ```powershell
   psql -U barqnet -d barqnet -c "SELECT * FROM users;"
   ```

3. Check Go environment:
   ```powershell
   go env
   ```

4. Review documentation:
   - `barqnet-backend/README.md` - Main documentation
   - `barqnet-backend/API_DOCUMENTATION.md` - API reference
   - `DEPLOYMENT_CHECKLIST.md` - Production deployment

---

## Summary

**What Works on Windows:**
- ✅ Management API Server (fully functional)
- ✅ Database operations
- ✅ Authentication testing
- ✅ Desktop client integration testing

**What Doesn't Work on Windows:**
- ❌ End-Node VPN server (full functionality)
- ❌ OpenVPN management
- ❌ Bash scripts (without WSL/Git Bash)
- ❌ User disconnection via management interface

**Recommendation:**
- Use Windows for **Management API development and testing**
- Use Linux/WSL for **End-Node server and production scripts**
- Deploy to **Linux servers for production**

**Your colleague can successfully test the core API functionality on Windows, which is the most important part for client integration!**
