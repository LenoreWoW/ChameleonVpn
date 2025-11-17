# Database Setup Clarification

## Issue Found:
Your colleague created the database as **vpnmanager** but documentation shows **barqnet**.

## Both are fine! Just need to match:

### Option A: Use 'vpnmanager' (What your colleague did)

**.env configuration:**
```bash
DB_NAME=vpnmanager
DB_USER=vpnmanager
DB_PASSWORD=your_actual_password
```

**PostgreSQL setup (already done):**
```sql
CREATE DATABASE vpnmanager;
CREATE USER vpnmanager WITH ENCRYPTED PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE vpnmanager TO vpnmanager;
```

### Option B: Use 'barqnet' (Original documentation)

**.env configuration:**
```bash
DB_NAME=barqnet
DB_USER=barqnet
DB_PASSWORD=your_actual_password
```

**PostgreSQL setup:**
```sql
CREATE DATABASE barqnet;
CREATE USER barqnet WITH ENCRYPTED PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE barqnet TO barqnet;
```

---

## ✅ What Your Colleague Needs to Do:

1. **Copy `.env.example` to `.env`:**
   ```bash
   cd ~/ChameleonVpn/barqnet-backend
   cp .env.example .env
   ```

2. **Edit `.env` to match the database they created:**
   ```bash
   nano .env

   # Update these lines:
   DB_NAME=vpnmanager
   DB_USER=vpnmanager
   DB_PASSWORD=<their_actual_password>
   ```

3. **Generate secure secrets:**
   ```bash
   # Generate JWT secret
   openssl rand -base64 48

   # Generate API key
   openssl rand -hex 32

   # Add these to .env:
   JWT_SECRET=<paste_jwt_secret_here>
   API_KEY=<paste_api_key_here>
   ```

4. **Test database connection:**
   ```bash
   # Should connect without errors:
   psql -U vpnmanager -d vpnmanager -h localhost
   # Enter password when prompted
   # Type \q to quit
   ```

5. **Run migrations:**
   ```bash
   cd ~/ChameleonVpn/barqnet-backend
   ./migrate.sh up
   ```

6. **Build and run:**
   ```bash
   go mod tidy
   go build -o management ./apps/management
   go build -o vpn ./apps/vpn
   go build -o end-node ./apps/end-node

   # Start management service:
   ./management
   ```

---

## Quick Verification:

```bash
# Check database exists:
psql -U postgres -c "\l" | grep vpnmanager

# Check user exists:
psql -U postgres -c "\du" | grep vpnmanager

# Test connection:
psql -U vpnmanager -d vpnmanager -h localhost -c "SELECT version();"
```

All good? Backend should work! ✅
