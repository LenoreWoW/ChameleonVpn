# Token Revocation System - Deployment Checklist

## Quick Start

1. Apply database migration: `psql -f migrations/005_add_token_blacklist.sql`
2. Deploy backend code: `go build && systemctl restart barqnet-backend`
3. Setup cleanup job: `systemctl enable token-cleanup.timer`
4. Run tests: `./test-token-revocation.sh`
5. Integrate clients: Update logout functions to call `/v1/auth/revoke`

## Pre-Deployment Checklist

### Code Review
- [ ] Review migration: `migrations/005_add_token_blacklist.sql`
- [ ] Review blacklist package: `pkg/shared/token_blacklist.go`
- [ ] Review JWT updates: `pkg/shared/jwt.go`
- [ ] Review auth endpoints: `apps/management/api/auth.go`
- [ ] Review cleanup job: `cmd/token-cleanup/main.go`

### Testing
- [ ] Run unit tests: `go test ./pkg/shared -v`
- [ ] Run integration test: `./test-token-revocation.sh`
- [ ] Test cleanup job: `go run cmd/token-cleanup/main.go --dry-run`
- [ ] Verify endpoints with curl
- [ ] Load test revocation endpoint

### Database Preparation
- [ ] Backup production database
- [ ] Test migration on staging database
- [ ] Verify no conflicts with existing schema
- [ ] Check PostgreSQL version (>= 12 required)
- [ ] Verify disk space for new tables/indexes

## Deployment Timeline

| Task | Duration | Status |
|------|----------|--------|
| Database Migration | 5 min | ⬜ |
| Backend Deployment | 10 min | ⬜ |
| Endpoint Verification | 5 min | ⬜ |
| Cleanup Job Setup | 10 min | ⬜ |
| Monitoring Setup | 15 min | ⬜ |
| Client Integration | 2-4 hours/platform | ⬜ |
| Testing & Verification | 30 min | ⬜ |
| **Total** | **1-5 hours** | ⬜ |

## Step-by-Step Deployment

### Step 1: Database Migration (5 minutes)

```bash
# Apply migration
psql -U postgres -d barqnet -f migrations/005_add_token_blacklist.sql

# Verify
psql -U postgres -d barqnet -c "\dt token_blacklist"
psql -U postgres -d barqnet -c "SELECT * FROM v_blacklist_statistics;"
```

### Step 2: Deploy Backend (10 minutes)

```bash
cd /opt/barqnet-backend
git pull origin main
go build -o barqnet-backend ./cmd/server
sudo systemctl restart barqnet-backend
journalctl -u barqnet-backend -f
```

### Step 3: Verify Endpoints (5 minutes)

```bash
./test-token-revocation.sh
```

### Step 4: Setup Cleanup Job (10 minutes)

```bash
# Build cleanup binary
go build -o token-cleanup ./cmd/token-cleanup

# Install systemd timer
sudo cp token-cleanup.service /etc/systemd/system/
sudo cp token-cleanup.timer /etc/systemd/system/
sudo systemctl enable token-cleanup.timer
sudo systemctl start token-cleanup.timer
```

### Step 5: Monitoring (15 minutes)

Create Grafana dashboard or setup alerts for:
- Revocations per hour
- Active blacklist entries
- Expired entries awaiting cleanup
- Failed revocation attempts

## Post-Deployment Verification

- [ ] All 7 tests in test script pass
- [ ] Migration recorded in schema_migrations table
- [ ] Endpoints respond correctly (200 or 401)
- [ ] Cleanup job runs successfully
- [ ] Statistics view shows data
- [ ] No errors in application logs

## Success Criteria

✅ Migration applied successfully
✅ Backend deploys without errors
✅ All endpoints respond correctly
✅ Test script passes (7/7)
✅ Cleanup job scheduled
✅ Monitoring configured
✅ No performance degradation

## Rollback Procedure

If critical issues occur:

```bash
# 1. Stop backend
sudo systemctl stop barqnet-backend

# 2. Revert code
git checkout HEAD~1
go build -o barqnet-backend ./cmd/server

# 3. Rollback database (optional, loses revocation data)
psql -U postgres -d barqnet -c "
DROP TABLE IF EXISTS token_revocation_stats CASCADE;
DROP TABLE IF EXISTS token_blacklist CASCADE;
"

# 4. Restart
sudo systemctl start barqnet-backend
```

## Support

- **Documentation**: `TOKEN_REVOCATION_SYSTEM.md`
- **API Reference**: `REVOCATION_ENDPOINTS_REFERENCE.md`
- **Implementation Summary**: `IMPLEMENTATION_SUMMARY_TOKEN_REVOCATION.md`

---

**Deployment Date**: _______________
**Deployed By**: _______________
**Verified By**: _______________
