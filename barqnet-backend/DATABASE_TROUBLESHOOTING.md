# Database Troubleshooting Guide

This guide helps you fix common PostgreSQL issues with BarqNet backend.

---

## Quick Fix (Recommended)

Run the automated setup script:

```bash
cd barqnet-backend
./setup_database.sh
```

This will:
1. Check PostgreSQL installation
2. Create database and user
3. Grant all necessary permissions
4. Run migrations
5. Verify setup

---

## Error 1: "password authentication failed for user postgres"

**Cause**: Wrong password for postgres superuser

**Solution A - Use the barqnet user instead**:
```bash
# Create user and database with proper permissions
sudo -u postgres psql <<EOF
CREATE USER barqnet WITH PASSWORD 'barqnet123';
CREATE DATABASE barqnet OWNER barqnet;
GRANT ALL PRIVILEGES ON DATABASE barqnet TO barqnet;
EOF

# Then use these environment variables
export DB_USER="barqnet"
export DB_PASSWORD="barqnet123"
export DB_NAME="barqnet"
export DB_HOST="localhost"
export DB_SSLMODE="disable"
```

**Solution B - Find postgres password**:
```bash
# On Ubuntu, postgres user often has no password set
# You can connect without password as root:
sudo -u postgres psql

# Or set a password:
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'newpassword';"
```

---

## Error 2: "permission denied for schema public"

**Cause**: User exists but lacks permissions to create tables

**Solution - Grant permissions**:

```bash
# Run the fix_permissions.sql script
cd barqnet-backend
sudo -u postgres psql -d barqnet -f fix_permissions.sql
```

Or manually:

```bash
sudo -u postgres psql -d barqnet <<EOF
GRANT ALL PRIVILEGES ON DATABASE barqnet TO barqnet;
GRANT USAGE ON SCHEMA public TO barqnet;
GRANT CREATE ON SCHEMA public TO barqnet;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO barqnet;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO barqnet;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO barqnet;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO barqnet;
ALTER DATABASE barqnet OWNER TO barqnet;
EOF
```

---

## Error 3: "must be owner of table servers" or similar ownership errors

**Cause**: Tables were created by postgres user but barqnet user is trying to modify them

**Solution - Fix table ownership**:

```bash
# Quick fix - run the ownership fix script
cd barqnet-backend
sudo -u postgres psql -d barqnet -f fix_table_ownership.sql
```

Or manually:

```bash
sudo -u postgres psql -d barqnet <<EOF
-- Change ownership of all tables
DO \$\$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public')
    LOOP
        EXECUTE 'ALTER TABLE ' || quote_ident(r.tablename) || ' OWNER TO barqnet';
    END LOOP;

    FOR r IN (SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema = 'public')
    LOOP
        EXECUTE 'ALTER SEQUENCE ' || quote_ident(r.sequence_name) || ' OWNER TO barqnet';
    END LOOP;
END \$\$;
EOF
```

Then restart the backend:
```bash
./management
```

---

## Error 4: "database 'barqnet' does not exist"

**Solution**:
```bash
sudo -u postgres psql -c "CREATE DATABASE barqnet OWNER barqnet;"
```

---

## Error 5: "role 'barqnet' does not exist"

**Solution**:
```bash
sudo -u postgres psql -c "CREATE USER barqnet WITH PASSWORD 'barqnet123';"
```

---

## Error 6: "FATAL: Peer authentication failed"

**Cause**: PostgreSQL is configured to use peer authentication (Unix socket)

**Solution - Use TCP/IP connection**:

Edit `/etc/postgresql/*/main/pg_hba.conf`:

```bash
sudo nano /etc/postgresql/14/main/pg_hba.conf
```

Change this line:
```
local   all             all                                     peer
```

To:
```
local   all             all                                     md5
```

Then restart PostgreSQL:
```bash
sudo systemctl restart postgresql
```

---

## Complete Fresh Setup

If everything is broken, start from scratch:

```bash
# 1. Drop existing database (WARNING: deletes all data!)
sudo -u postgres psql -c "DROP DATABASE IF EXISTS barqnet;"
sudo -u postgres psql -c "DROP USER IF EXISTS barqnet;"

# 2. Create user with password
sudo -u postgres psql -c "CREATE USER barqnet WITH PASSWORD 'barqnet123';"

# 3. Create database owned by user
sudo -u postgres psql -c "CREATE DATABASE barqnet OWNER barqnet;"

# 4. Grant all permissions
sudo -u postgres psql -d barqnet <<EOF
GRANT ALL PRIVILEGES ON DATABASE barqnet TO barqnet;
GRANT ALL PRIVILEGES ON SCHEMA public TO barqnet;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO barqnet;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO barqnet;
EOF

# 5. Run migrations
cd barqnet-backend/migrations
for f in *.sql; do sudo -u postgres psql -d barqnet -f "$f"; done

# 6. Export environment variables
export DB_NAME="barqnet"
export DB_USER="barqnet"
export DB_PASSWORD="barqnet123"
export DB_HOST="localhost"
export DB_SSLMODE="disable"
export JWT_SECRET="$(openssl rand -base64 32)"

# 7. Start backend
cd ..
./management
```

---

## Verify Database Setup

Check if everything is working:

```bash
# 1. Check if user exists
sudo -u postgres psql -c "\du barqnet"

# 2. Check if database exists
sudo -u postgres psql -l | grep barqnet

# 3. Check if tables exist
sudo -u postgres psql -d barqnet -c "\dt"

# 4. Test connection with credentials
psql -U barqnet -d barqnet -h localhost -c "SELECT current_user, current_database();"
# Password: barqnet123
```

---

## Environment Variables Reference

Always set these before running the backend:

```bash
export DB_NAME="barqnet"
export DB_USER="barqnet"
export DB_PASSWORD="barqnet123"
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_SSLMODE="disable"
export JWT_SECRET="$(openssl rand -base64 32)"
```

Or create a `.env` file (don't commit to git!):

```bash
cat > barqnet-backend/.env <<EOF
DB_NAME=barqnet
DB_USER=barqnet
DB_PASSWORD=barqnet123
DB_HOST=localhost
DB_PORT=5432
DB_SSLMODE=disable
JWT_SECRET=$(openssl rand -base64 32)
EOF

# Then source it
source barqnet-backend/.env
```

---

## Check PostgreSQL Logs

If problems persist, check logs:

```bash
# Ubuntu/Debian
sudo tail -f /var/log/postgresql/postgresql-14-main.log

# Or use journalctl
sudo journalctl -u postgresql -f
```

---

## Common Checklist

✅ PostgreSQL is installed and running:
```bash
sudo systemctl status postgresql
```

✅ User `barqnet` exists:
```bash
sudo -u postgres psql -c "\du" | grep barqnet
```

✅ Database `barqnet` exists:
```bash
sudo -u postgres psql -l | grep barqnet
```

✅ User has permissions:
```bash
sudo -u postgres psql -d barqnet -c "\dp"
```

✅ Migrations have run:
```bash
sudo -u postgres psql -d barqnet -c "\dt"
# Should show: users, locations, vpn_servers, etc.
```

✅ Can connect with password:
```bash
psql -U barqnet -d barqnet -h localhost -c "SELECT 1;"
```

✅ Environment variables are set:
```bash
echo $DB_NAME $DB_USER $DB_PASSWORD
```

---

## Still Having Issues?

1. **Check the backend logs** - The error message will tell you exactly what's wrong

2. **Verify PostgreSQL version** - Backend requires PostgreSQL 12+
   ```bash
   psql --version
   ```

3. **Check disk space** - PostgreSQL needs space to create tables
   ```bash
   df -h
   ```

4. **Test basic PostgreSQL** - Can you connect at all?
   ```bash
   sudo -u postgres psql -c "SELECT version();"
   ```

5. **Read PostgreSQL logs** - Detailed error information
   ```bash
   sudo journalctl -u postgresql -n 50
   ```

---

## Production Notes

For production deployment:

1. **Use strong passwords**:
   ```bash
   export DB_PASSWORD="$(openssl rand -base64 32)"
   ```

2. **Enable SSL**:
   ```bash
   export DB_SSLMODE="require"
   ```

3. **Use environment files** instead of command-line exports

4. **Restrict network access** in `pg_hba.conf`

5. **Enable PostgreSQL logging** for audit trail

6. **Set up automated backups**:
   ```bash
   pg_dump -U barqnet barqnet > backup.sql
   ```

---

**Need more help?** Check the main deployment guide: `UBUNTU_DEPLOYMENT_GUIDE.md`
