# Certificate Pinning Testing Guide

## Overview

This guide provides step-by-step testing procedures to verify that certificate pinning is working correctly in the Desktop client.

## Prerequisites

- Desktop application built and ready to run
- OpenSSL installed (`openssl version`)
- Access to terminal/command line
- Test API server with HTTPS (or use a public API for testing)

## Test Suite

### Test 1: Verify Implementation is Integrated

**Purpose:** Ensure certificate pinning code is compiled and integrated.

**Steps:**
```bash
cd workvpn-desktop

# Run the automated test script
./test-certificate-pinning.sh
```

**Expected Output:**
```
✓ Build successful
✓ Certificate pinning file compiled
✓ Certificate pinning integrated in main process
✓ CERT_PIN_PRIMARY documented in .env.example
✓ CERT_PIN_BACKUP documented in .env.example
All Tests Passed! ✓
```

**Status:** ✅ PASS / ❌ FAIL

---

### Test 2: Extract Certificate Pins (Script Functionality)

**Purpose:** Verify the pin extraction script works correctly.

**Steps:**
```bash
# Test 1: Show help
./scripts/extract-cert-pins.sh --help

# Test 2: Show Let's Encrypt pins
./scripts/extract-cert-pins.sh --letsencrypt

# Test 3: Show DigiCert pins
./scripts/extract-cert-pins.sh --digicert

# Test 4: Extract from a public server (example)
./scripts/extract-cert-pins.sh --server google.com
```

**Expected Output for Let's Encrypt:**
```
Let's Encrypt R3 (Primary Intermediate):
sha256/jQJTbIh0grw0/1TkHSumWb+Fs0Ggogr621gT3PvPKG0=

Let's Encrypt E1 (ECDSA Intermediate):
sha256/VQYeFC8zhEDLrcyYYWBvPTfM5VWhTzfhEHQ9L5wBaB0=

ISRG Root X1 (Let's Encrypt Root):
sha256/C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=
```

**Expected Output for Server Extraction:**
```
✓ All required tools are available
Extracting pin from: google.com:443
✓ Pin extracted: sha256/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=
  Subject: CN=*.google.com
  Issuer: ...
  Expires: ...
```

**Status:** ✅ PASS / ❌ FAIL

---

### Test 3: Development Mode (Pinning Disabled)

**Purpose:** Verify certificate pinning is disabled for localhost in development.

**Configuration:**
```bash
# .env
API_BASE_URL=http://localhost:8080
CERT_PINNING_ENABLED=false
```

**Steps:**
1. Configure `.env` as above
2. Start the application
3. Check console output

**Expected Console Output:**
```
[AUTH] Certificate pinning skipped (not using HTTPS)
```

**Expected Behavior:**
- Application starts successfully
- No certificate pinning warnings
- Connections to localhost work

**Status:** ✅ PASS / ❌ FAIL

---

### Test 4: Production Mode with Fallback CA Pins

**Purpose:** Verify fallback CA pins are used when no specific pins configured.

**Configuration:**
```bash
# .env
API_BASE_URL=https://api.example.com
CERT_PINNING_ENABLED=true
CERT_PIN_PRIMARY=
CERT_PIN_BACKUP=
NODE_ENV=production
```

**Steps:**
1. Configure `.env` as above
2. Start the application
3. Check console output

**Expected Console Output:**
```
[AUTH] WARNING: No certificate pins configured!
[AUTH] Using fallback pins for common CAs (Let's Encrypt, DigiCert)
[AUTH] ✓ Certificate pinning enabled for api.example.com
[AUTH]   - Configured 5 certificate pin(s)
[AUTH] ⚠ Using fallback CA pins only - configure specific pins for maximum security
```

**Expected Behavior:**
- Certificate pinning is enabled
- Uses well-known CA pins (Let's Encrypt, DigiCert)
- Warning about using fallback pins
- Connections to servers with Let's Encrypt or DigiCert certificates work

**Status:** ✅ PASS / ❌ FAIL

---

### Test 5: Production Mode with Specific Pins (Valid)

**Purpose:** Verify certificate pinning works with correct pins.

**Setup:**
```bash
# Extract pin from your API server
./scripts/extract-cert-pins.sh --server api.example.com

# Note the extracted pin
```

**Configuration:**
```bash
# .env
API_BASE_URL=https://api.example.com
CERT_PINNING_ENABLED=true
CERT_PIN_PRIMARY=sha256/YOUR_EXTRACTED_PIN_HERE
CERT_PIN_BACKUP=sha256/jQJTbIh0grw0/1TkHSumWb+Fs0Ggogr621gT3PvPKG0=
NODE_ENV=production
```

**Steps:**
1. Extract pin from your API server
2. Configure `.env` with extracted pin
3. Start the application
4. Make an API request (e.g., login)

**Expected Console Output:**
```
[AUTH] Primary certificate pin configured
[AUTH] Backup certificate pin configured
[AUTH] ✓ Certificate pinning enabled for api.example.com
[AUTH]   - Configured 2 certificate pin(s)
[CERT-PIN] Verifying certificate for api.example.com...
[CERT-PIN] ✓ Certificate validated for api.example.com
```

**Expected Behavior:**
- Application starts successfully
- Certificate validation succeeds
- API requests work normally
- No security errors

**Status:** ✅ PASS / ❌ FAIL

---

### Test 6: Production Mode with Invalid Pins (Security Test)

**Purpose:** Verify certificate pinning rejects invalid pins.

**Configuration:**
```bash
# .env
API_BASE_URL=https://api.example.com
CERT_PINNING_ENABLED=true
CERT_PIN_PRIMARY=sha256/INVALID_PIN_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
CERT_PIN_BACKUP=sha256/INVALID_PIN_BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=
NODE_ENV=production
```

**Steps:**
1. Configure `.env` with incorrect pins
2. Start the application
3. Make an API request

**Expected Console Output:**
```
[AUTH] Primary certificate pin configured
[AUTH] Backup certificate pin configured
[AUTH] ✓ Certificate pinning enabled for api.example.com
[CERT-PIN] Verifying certificate for api.example.com...
[CERT-PIN] ✗ CERTIFICATE PINNING FAILED for api.example.com
[CERT-PIN] This could indicate a MITM attack!
[CERT-PIN] Expected one of: sha256/INVALID_PIN_AAAAAAA...
[AUTH] Security error: Server certificate verification failed
```

**Expected Behavior:**
- Application starts
- Certificate validation **FAILS**
- API requests are **REJECTED**
- Security error displayed to user
- Connection refused

**Status:** ✅ PASS / ❌ FAIL

---

### Test 7: Pinning Disabled via Environment Variable

**Purpose:** Verify pinning can be disabled via CERT_PINNING_ENABLED.

**Configuration:**
```bash
# .env
API_BASE_URL=https://api.example.com
CERT_PINNING_ENABLED=false
CERT_PIN_PRIMARY=sha256/SOME_PIN
CERT_PIN_BACKUP=sha256/ANOTHER_PIN
```

**Steps:**
1. Configure `.env` as above
2. Start the application
3. Check console output

**Expected Console Output:**
```
[AUTH] Certificate pinning DISABLED via CERT_PINNING_ENABLED=false
[AUTH] WARNING: Running without certificate pinning is insecure in production
```

**Expected Behavior:**
- Certificate pinning is completely disabled
- Warning about insecure mode
- All connections work (no pin validation)

**Status:** ✅ PASS / ❌ FAIL

---

### Test 8: Certificate Rotation Simulation

**Purpose:** Verify backup pins work during certificate rotation.

**Configuration (Before Rotation):**
```bash
# .env
CERT_PIN_PRIMARY=sha256/OLD_CERTIFICATE_PIN
CERT_PIN_BACKUP=sha256/NEW_CERTIFICATE_PIN
```

**Steps:**
1. Configure with old primary + new backup
2. Start application and verify connection works
3. Server rotates certificate to new one
4. Restart application
5. Verify connection still works (using backup pin)

**Expected Behavior:**
- Before rotation: Primary pin matches, connection works
- After rotation: Backup pin matches, connection works
- No downtime during rotation

**Status:** ✅ PASS / ❌ FAIL

---

### Test 9: Extract Pins from Common Public APIs

**Purpose:** Verify script works with real-world certificates.

**Steps:**
```bash
# Test with various public APIs
./scripts/extract-cert-pins.sh --server api.github.com
./scripts/extract-cert-pins.sh --server www.cloudflare.com
./scripts/extract-cert-pins.sh --server www.google.com
```

**Expected Output (for each):**
```
✓ All required tools are available
Extracting pin from: api.github.com:443
✓ Pin extracted: sha256/XXXXX...
  Subject: CN=*.github.com
  Issuer: C=US, O=DigiCert Inc, CN=...
  Expires: ...
sha256/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=
```

**Status:** ✅ PASS / ❌ FAIL

---

### Test 10: Localhost Development Bypass

**Purpose:** Verify localhost/127.0.0.1 bypass in development mode.

**Configuration:**
```bash
# .env
API_BASE_URL=https://localhost:8080
CERT_PINNING_ENABLED=true
NODE_ENV=development
```

**Steps:**
1. Configure `.env` as above
2. Start the application
3. Check console output

**Expected Console Output:**
```
[CERT-PIN] Allowing localhost connection (development mode)
```

or

```
[CERT-PIN] Allowing 127.0.0.1 connection (development mode)
```

**Expected Behavior:**
- Localhost connections bypass pinning
- No certificate validation for localhost
- Application works normally in development

**Status:** ✅ PASS / ❌ FAIL

---

## Test Results Summary

| Test | Status | Notes |
|------|--------|-------|
| 1. Implementation Integration | ⬜ | |
| 2. Script Functionality | ⬜ | |
| 3. Development Mode | ⬜ | |
| 4. Fallback CA Pins | ⬜ | |
| 5. Valid Pins (Success) | ⬜ | |
| 6. Invalid Pins (Rejection) | ⬜ | |
| 7. Disabled via Env Var | ⬜ | |
| 8. Certificate Rotation | ⬜ | |
| 9. Public API Extraction | ⬜ | |
| 10. Localhost Bypass | ⬜ | |

**Overall Status:** ⬜ PENDING / ✅ ALL PASSED / ❌ FAILED

---

## Troubleshooting Test Failures

### Test 1 Failed (Build Issues)

**Check:**
- TypeScript compilation errors
- Missing dependencies
- Build configuration

**Fix:**
```bash
npm install
npm run build
```

### Test 2 Failed (Script Not Working)

**Check:**
- Script has execute permissions
- OpenSSL is installed
- Network connectivity

**Fix:**
```bash
chmod +x scripts/extract-cert-pins.sh
which openssl  # Should show path
```

### Test 5 Failed (Valid Pins Rejected)

**Check:**
- Pin format is correct (`sha256/` prefix)
- Pin extracted from correct server
- Certificate has not been rotated

**Fix:**
```bash
# Re-extract pin
./scripts/extract-cert-pins.sh --server api.example.com

# Verify format
echo "sha256/YOUR_PIN_HERE"
```

### Test 6 Failed (Invalid Pins Accepted)

**Critical Security Issue!**

**Check:**
- Certificate pinning is actually enabled
- Pins are being validated
- No bypass code in production

**Fix:**
- Review implementation in `service.ts`
- Verify `CERT_PINNING_ENABLED=true`
- Check console logs for pinning status

---

## Production Pre-Launch Checklist

Before deploying to production, ensure:

- [ ] All 10 tests pass successfully
- [ ] Pin extraction script works
- [ ] Invalid pins are rejected (Test 6)
- [ ] Valid pins are accepted (Test 5)
- [ ] Fallback pins work for common CAs
- [ ] Documentation is complete
- [ ] Certificate rotation procedure is documented
- [ ] Monitoring is set up for pinning failures
- [ ] Team is trained on certificate rotation
- [ ] Calendar reminders set for cert expiration (30 days before)

---

## Continuous Testing

### Weekly Tests

- Run Test 1 (Integration) after any code changes
- Run Test 2 (Script) to ensure tools are working

### Monthly Tests

- Run Test 5 (Valid Pins) to ensure production certificates still valid
- Check certificate expiration dates

### Before Certificate Rotation

- Run Test 8 (Rotation Simulation) in staging
- Verify backup pins are configured correctly
- Test with both old and new certificates

---

## Automated Testing

Consider adding these tests to your CI/CD pipeline:

```yaml
# Example GitHub Actions
name: Certificate Pinning Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install dependencies
        run: npm install
      - name: Build
        run: npm run build
      - name: Run certificate pinning tests
        run: ./test-certificate-pinning.sh
      - name: Test pin extraction script
        run: |
          chmod +x scripts/extract-cert-pins.sh
          ./scripts/extract-cert-pins.sh --letsencrypt
          ./scripts/extract-cert-pins.sh --digicert
```

---

## Security Testing

### Penetration Testing Scenarios

1. **MITM Attack Simulation**
   - Use proxy with fake certificate
   - Verify connection is rejected
   - Check for proper error messages

2. **Certificate Spoofing**
   - Create self-signed certificate for API domain
   - Attempt connection
   - Verify rejection

3. **CA Compromise Simulation**
   - Use certificate from unauthorized CA
   - Verify rejection even with valid chain

### Expected Security Posture

- ✅ Rejects forged certificates
- ✅ Rejects unauthorized CAs
- ✅ Logs security violations
- ✅ Fails securely (reject on error)
- ✅ No bypass in production

---

## Reporting Issues

If any test fails:

1. Document the failure (console logs, error messages)
2. Note the configuration used
3. Record expected vs actual behavior
4. Check troubleshooting section
5. Review implementation code
6. Report to development team with details

---

## Next Steps After Testing

1. ✅ All tests pass → Proceed to production
2. ⚠️ Some tests fail → Fix issues and re-test
3. ❌ Critical tests fail (6, 5) → Do not deploy

**Critical Tests (Must Pass):**
- Test 5: Valid pins accepted
- Test 6: Invalid pins rejected

**Important Tests (Should Pass):**
- Test 1: Integration
- Test 4: Fallback CA pins

**Optional Tests (Nice to Have):**
- Test 8: Rotation simulation
- Test 9: Public API extraction
