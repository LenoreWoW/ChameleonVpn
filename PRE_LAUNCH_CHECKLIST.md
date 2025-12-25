# Pre-Launch Checklist: Backend + iOS

**Goal:** Get Backend and iOS to production as fast as possible

---

## ✅ Fixes Already Applied

### Backend
- [x] **CORS** - Changed from `*` wildcard to configurable origins via `ALLOWED_ORIGINS` env var
- [x] **Database Table** - Fixed `auth_users` → `users` in auth.go line 275
- [x] **Health Check** - Enhanced to include database connectivity check with latency

### iOS  
- [x] **Certificate Pinning** - Added configuration infrastructure with clear production setup guide
- [x] **Info.plist** - Added configuration keys for xcconfig integration

---

## 🔧 Pre-Launch Configuration Required

### 1. Backend Environment Variables

Create or update your `.env` file or deployment configuration:

```bash
# Required for production
JWT_SECRET=your-strong-32-character-secret-here  # MUST be at least 32 chars

# CORS: Comma-separated list of allowed origins
ALLOWED_ORIGINS=https://app.barqnet.com,https://admin.barqnet.com

# Email service (for OTP)
EMAIL_SERVICE_MODE=resend
RESEND_API_KEY=re_your_api_key_here
RESEND_FROM_EMAIL=noreply@barqnet.com

# Database
DATABASE_URL=postgres://user:pass@host:5432/dbname

# Server identification
SERVER_ID=management-prod-01
```

### 2. iOS Certificate Pins

**Generate your certificate pins:**
```bash
# Run this command to get your server's certificate pin:
openssl s_client -connect api.barqnet.com:443 < /dev/null 2>/dev/null | \
  openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | base64
```

**Update `APIClient.swift` (around line 227):**
```swift
#if !DEBUG
pins = [
    "sha256/YOUR_ACTUAL_PIN_FROM_ABOVE=",    // Primary
    "sha256/YOUR_BACKUP_PIN="                 // Backup (for rotation)
]
#endif
```

### 3. iOS Production Configuration

**Update `Configuration/Production.xcconfig`:**
```
API_BASE_URL = https://api.barqnet.com
ENVIRONMENT_NAME = Production
ENABLE_DEBUG_LOGGING = NO
ENABLE_CERTIFICATE_PINNING = YES
API_TIMEOUT_INTERVAL = 30
```

### 4. Database Migrations

Ensure all migrations are applied:
```bash
cd barqnet-backend
psql -U vpnmanager -d vpnmanager -c "SELECT version FROM schema_migrations ORDER BY applied_at;"

# Should show 8 migrations:
# 001_initial_schema
# 002_add_phone_auth
# 003_add_statistics
# 004_add_locations
# 005_add_token_blacklist
# 006_add_active_column
# 007_migrate_to_email_auth
# 008_fix_audit_log_schema
```

---

## 🧪 Pre-Launch Testing

### Backend Tests

```bash
# 1. Health check (should return healthy with DB status)
curl https://api.barqnet.com/health

# Expected response:
{
  "status": "healthy",
  "checks": {
    "database": { "status": "healthy", "latency_ms": 5 }
  }
}

# 2. Test CORS (should set proper origin header)
curl -H "Origin: https://app.barqnet.com" \
     -I https://api.barqnet.com/v1/auth/login

# Should include: Access-Control-Allow-Origin: https://app.barqnet.com

# 3. Test blocked CORS origin
curl -H "Origin: https://evil.com" \
     -I https://api.barqnet.com/v1/auth/login

# Should NOT include Access-Control-Allow-Origin header

# 4. Test authentication
curl -X POST https://api.barqnet.com/v1/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'
```

### iOS Tests

1. **Build for Release:**
   - Xcode → Product → Archive
   - Verify it uses Production.xcconfig

2. **Test VPN Connection:**
   - Import .ovpn file
   - Connect to VPN
   - Verify traffic is encrypted (check IP changes)

3. **Test Authentication:**
   - Create new account with email
   - Verify OTP is received
   - Login with credentials
   - Verify token refresh works

4. **Certificate Pinning Test:**
   - With correct pins: connection succeeds
   - With wrong pins: connection fails (test by temporarily changing pin)

---

## 📱 App Store Submission Checklist

### Required for iOS App Store:

- [ ] App icons for all sizes (Assets.xcassets)
- [ ] Privacy Policy URL
- [ ] App description and keywords
- [ ] Screenshots for all device sizes
- [ ] VPN entitlement properly configured
- [ ] Network Extension capability enabled
- [ ] Code signing with distribution certificate

### Info.plist Required Keys:

```xml
<!-- Already present -->
<key>NSFaceIDUsageDescription</key>
<string>BarqNet uses Face ID to quickly connect to your VPN</string>

<!-- May need to add for VPN -->
<key>UIBackgroundModes</key>
<array>
    <string>network-authentication</string>
</array>
```

### Entitlements (WorkVPN.entitlements):

```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.barqnet.ios</string>
</array>
```

---

## 🚀 Deployment Steps

### Backend

```bash
# 1. Set environment variables (see section 1 above)

# 2. Build
cd barqnet-backend
go build -o management ./apps/management

# 3. Run
./management

# Or with Docker/systemd as appropriate for your infrastructure
```

### iOS

1. Open `WorkVPN.xcworkspace` in Xcode
2. Select "Release" build configuration  
3. Product → Archive
4. Distribute to App Store or TestFlight

---

## ⚠️ Known Limitations (Post-Launch)

These items are noted for future improvement but don't block launch:

### OpenVPNAdapter Library
- **Status:** Archived March 2022, but stable and working
- **Risk:** No security updates from maintainer
- **Mitigation:** OpenVPN core is stable; monitor for issues
- **Future:** Consider migrating to TunnelKit when time permits

### Singleton Architecture (iOS)
- **Impact:** Makes unit testing difficult
- **Risk:** Low - doesn't affect production functionality
- **Future:** Refactor to dependency injection in next major version

### Desktop & Android
- **Status:** Not included in this launch
- **Future:** Migrate to React Native for unified mobile codebase

---

## 📞 Launch Day Support

### Monitoring

1. **Backend Logs:**
   ```bash
   tail -f /var/log/vpnmanager/management-audit.log
   ```

2. **Database Connections:**
   ```sql
   SELECT COUNT(*) FROM pg_stat_activity WHERE datname = 'vpnmanager';
   ```

3. **API Response Times:**
   - Monitor `/health` endpoint latency
   - Alert if database latency > 100ms

### Rollback Plan

**Backend:**
```bash
# If issues, revert to previous binary
cp management.backup management
systemctl restart vpnmanager
```

**iOS:**
- TestFlight: Release previous build
- App Store: Submit expedited review request

---

## ✅ Final Checklist

Before going live, verify:

- [ ] JWT_SECRET is a strong, unique 32+ character secret
- [ ] ALLOWED_ORIGINS is set to production domains only
- [ ] Certificate pins are generated and configured
- [ ] All 8 database migrations applied
- [ ] Email service (Resend) is configured and tested
- [ ] Health check returns "healthy" with DB status
- [ ] iOS app builds in Release configuration
- [ ] VPN connection works end-to-end
- [ ] Authentication flow works (register → OTP → login)
- [ ] Rate limiting is working (test with multiple rapid requests)

---

*Last updated: December 25, 2025*

