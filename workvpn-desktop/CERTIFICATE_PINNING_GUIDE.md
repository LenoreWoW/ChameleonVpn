# Certificate Pinning Implementation Guide

## Overview

Certificate pinning is now **ENABLED** in the Desktop client to protect against Man-in-the-Middle (MITM) attacks. This guide explains how certificate pinning works, how to configure it, and how to manage certificate rotation.

## Status: PRODUCTION READY ✅

Certificate pinning is fully implemented and active for all HTTPS API connections.

## What is Certificate Pinning?

Certificate pinning validates that the server's SSL/TLS certificate matches a known, trusted certificate (or its public key hash). This prevents attackers from intercepting HTTPS traffic even if they compromise a Certificate Authority (CA) or install a rogue root certificate on the device.

### How It Works

1. **Pin Extraction**: Extract SHA-256 hash of the server's public key
2. **Configuration**: Store the pin in the application configuration
3. **Validation**: During HTTPS connection, validate the server's certificate against known pins
4. **Rejection**: If no pins match, reject the connection to prevent MITM attacks

## Implementation Architecture

### Files Modified

1. **`src/main/auth/service.ts`** - Certificate pinning enabled in AuthService
2. **`src/main/security/init-certificate-pinning.ts`** - Global certificate pinning initialization
3. **`.env.example`** - Configuration documentation with real CA pins
4. **`scripts/extract-cert-pins.sh`** - Helper script to extract pins from certificates

### Certificate Pinning Flow

```
Application Start
    ↓
Initialize Certificate Pinning (main/index.ts)
    ↓
Load Environment Config (CERT_PIN_PRIMARY, CERT_PIN_BACKUP)
    ↓
Configure Electron Session Certificate Validation
    ↓
AuthService Initialization
    ↓
Add API Hostname Pins to CertificatePinning Module
    ↓
HTTPS Request Made
    ↓
Electron Certificate Verify Proc Triggered
    ↓
Extract Server Certificate Public Key
    ↓
Calculate SHA-256 Hash
    ↓
Compare Against Configured Pins
    ↓
Accept (Match) or Reject (No Match)
```

## Configuration

### Environment Variables

Certificate pinning is controlled by three environment variables in `.env`:

```bash
# Enable/disable certificate pinning
CERT_PINNING_ENABLED=true

# Primary pin (your specific leaf certificate)
CERT_PIN_PRIMARY=sha256/YOUR_CERTIFICATE_PIN_HERE

# Backup pin (intermediate CA or backup certificate)
CERT_PIN_BACKUP=sha256/YOUR_BACKUP_PIN_HERE
```

### Configuration Modes

#### 1. Development Mode (Local Testing)

```bash
# .env for development
API_BASE_URL=http://localhost:8080
CERT_PINNING_ENABLED=false
```

- Certificate pinning is **disabled** for HTTP connections
- Localhost/127.0.0.1 connections bypass pinning
- No pins required

#### 2. Production Mode (Recommended)

```bash
# .env for production
API_BASE_URL=https://api.example.com
CERT_PINNING_ENABLED=true
CERT_PIN_PRIMARY=sha256/ABC123... (your leaf certificate)
CERT_PIN_BACKUP=sha256/jQJTbIh0grw0/1TkHSumWb+Fs0Ggogr621gT3PvPKG0= (Let's Encrypt R3)
```

- Certificate pinning is **enabled**
- Requires at least 2 pins (primary + backup)
- Maximum security

#### 3. Production Mode (Fallback CA Pins)

```bash
# .env for production with fallback
API_BASE_URL=https://api.example.com
CERT_PINNING_ENABLED=true
CERT_PIN_PRIMARY=
CERT_PIN_BACKUP=
```

- Certificate pinning is **enabled** with fallback pins
- Uses well-known CA pins (Let's Encrypt, DigiCert)
- Provides protection against unauthorized CAs
- **Warning**: Less secure than specific certificate pins

## Extracting Certificate Pins

### Method 1: Using the Extraction Script (Recommended)

We provide a comprehensive script to extract certificate pins:

```bash
# Interactive mode (guided)
./scripts/extract-cert-pins.sh

# Extract from your API server
./scripts/extract-cert-pins.sh --server api.example.com

# Extract from a certificate file
./scripts/extract-cert-pins.sh --file /path/to/certificate.pem

# Show Let's Encrypt backup pins
./scripts/extract-cert-pins.sh --letsencrypt

# Show DigiCert backup pins
./scripts/extract-cert-pins.sh --digicert
```

### Method 2: Manual Extraction

Extract pin from a live server:

```bash
openssl s_client -connect api.example.com:443 -servername api.example.com < /dev/null 2>/dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  base64
```

Extract pin from a certificate file:

```bash
openssl x509 -in certificate.pem -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  base64
```

The output will be a base64-encoded string. Prefix it with `sha256/` for use in the `.env` file:

```
sha256/ABC123XYZ789==
```

## Well-Known Certificate Pins

### Let's Encrypt (Most Common for Production)

Let's Encrypt provides free SSL/TLS certificates and is widely used for production APIs.

```bash
# Let's Encrypt R3 (Primary RSA Intermediate)
sha256/jQJTbIh0grw0/1TkHSumWb+Fs0Ggogr621gT3PvPKG0=

# Let's Encrypt E1 (ECDSA Intermediate)
sha256/VQYeFC8zhEDLrcyYYWBvPTfM5VWhTzfhEHQ9L5wBaB0=

# ISRG Root X1 (Let's Encrypt Root CA)
sha256/C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=
```

**Usage**: If your API uses Let's Encrypt certificates, use these as backup pins along with your specific leaf certificate pin.

### DigiCert (Enterprise Alternative)

DigiCert is commonly used for enterprise and paid certificates.

```bash
# DigiCert Global Root G2
sha256/i7WTqTvh0OioIruIfFR4kMPnBqrS2rdiVPl/s2uC/CY=

# DigiCert TLS RSA SHA256 2020 CA1
sha256/RQeZkB42znUfsDIIFWWHm0nizHcVpsJNL8Qgg6iEvto=
```

**Usage**: If your API uses DigiCert certificates, use these as backup pins.

## Certificate Rotation Strategy

Certificate rotation is critical for maintaining security and uptime. Follow this zero-downtime rotation procedure:

### Pre-Rotation (30+ Days Before Expiration)

1. **Extract New Certificate Pin**
   ```bash
   # Get pin from your new certificate (before installing on server)
   ./scripts/extract-cert-pins.sh --file new-certificate.pem
   ```

2. **Update Backup Pin**
   ```bash
   # .env
   CERT_PIN_PRIMARY=sha256/OLD_CERT_PIN (current certificate)
   CERT_PIN_BACKUP=sha256/NEW_CERT_PIN (new certificate)
   ```

3. **Deploy Updated Application**
   - Build and release new version with updated pins
   - Users download and install update
   - Application now accepts both old and new certificates

### Rotation (On Certificate Expiration Date)

4. **Install New Certificate on Server**
   - Replace old certificate with new certificate
   - Restart server/update load balancer

5. **Verify Connection**
   ```bash
   # Test that connections work with new certificate
   ./scripts/extract-cert-pins.sh --server api.example.com
   ```

### Post-Rotation (After Verification)

6. **Update Primary Pin**
   ```bash
   # .env (for next release)
   CERT_PIN_PRIMARY=sha256/NEW_CERT_PIN (current certificate)
   CERT_PIN_BACKUP=sha256/NEXT_BACKUP_PIN (intermediate CA or future cert)
   ```

7. **Deploy Next Update**
   - This can be included in your next regular release
   - No urgency since backup pin is already valid

### Rotation Timeline

```
Day 0:   Certificate valid (365 days remaining)
Day 335: Begin rotation planning (30 days before expiration)
Day 340: Extract new certificate pin
Day 345: Update CERT_PIN_BACKUP and deploy app update
Day 355: Wait for user adoption (10 days for users to update)
Day 365: Rotate certificate on server
Day 366: Verify all connections work
Day 370: Update CERT_PIN_PRIMARY for next release (optional)
```

## Testing Certificate Pinning

### Test 1: Verify Pinning is Enabled

Run the application and check console output:

```
[CERT-PIN] Configuring certificate pinning for api.example.com
[CERT-PIN] Number of pins configured: 2
[CERT-PIN] ✓ Certificate pinning initialized successfully
[AUTH] ✓ Certificate pinning enabled for api.example.com
[AUTH]   - Configured 2 certificate pin(s)
```

### Test 2: Test Valid Pin (Should Succeed)

1. Configure valid pins in `.env`
2. Start application
3. Make API request
4. Should see: `[CERT-PIN] ✓ Certificate validated for api.example.com`

### Test 3: Test Invalid Pin (Should Fail)

1. Configure incorrect pin in `.env`:
   ```bash
   CERT_PIN_PRIMARY=sha256/INVALID_PIN_HERE
   ```
2. Start application
3. Make API request
4. Should see: `[CERT-PIN] ✗ CERTIFICATE PINNING FAILED`
5. Request should be rejected

### Test 4: Automated Test Script

Run the provided test script:

```bash
./test-certificate-pinning.sh
```

Expected output:
```
✓ Build successful
✓ Certificate pinning file compiled
✓ Certificate pinning integrated in main process
✓ CERT_PIN_PRIMARY documented in .env.example
✓ CERT_PIN_BACKUP documented in .env.example
All Tests Passed! ✓
```

## Security Considerations

### Pin Selection Strategy

**Best Practice**: Pin at Multiple Levels

1. **Leaf Certificate Pin (Most Specific)**
   - Your actual API server certificate
   - Highest security, requires update on rotation
   - Use as `CERT_PIN_PRIMARY`

2. **Intermediate CA Pin (Flexible)**
   - Let's Encrypt R3, DigiCert CA, etc.
   - Allows certificate rotation without app update (if using same CA)
   - Use as `CERT_PIN_BACKUP`

3. **Root CA Pin (Least Specific)**
   - ISRG Root X1, DigiCert Global Root, etc.
   - Maximum flexibility, least security
   - Use as additional backup only

**Recommended Configuration**:
```bash
CERT_PIN_PRIMARY=sha256/YOUR_LEAF_CERT (most secure)
CERT_PIN_BACKUP=sha256/INTERMEDIATE_CA (rotation flexibility)
```

### Fallback Behavior

The implementation includes smart fallback behavior:

1. **Production with Specific Pins**: Maximum security, uses your configured pins
2. **Production without Pins**: Uses well-known CA pins (Let's Encrypt, DigiCert)
3. **Development Mode**: Pinning disabled for localhost
4. **HTTP Connections**: Pinning disabled (HTTP is not secure anyway)

### Disabling Certificate Pinning

**Warning**: Only disable for local development testing!

```bash
# .env
CERT_PINNING_ENABLED=false
```

**Never deploy to production with pinning disabled!**

## Troubleshooting

### Issue: Certificate Pinning Failed

**Symptoms**:
```
[CERT-PIN] ✗ CERTIFICATE PINNING FAILED for api.example.com
[AUTH] Security error: Server certificate verification failed
```

**Solutions**:

1. **Verify Pins are Correct**
   ```bash
   # Extract current server pin
   ./scripts/extract-cert-pins.sh --server api.example.com

   # Compare with your .env configuration
   ```

2. **Check Certificate Has Not Been Rotated**
   - Server admin may have updated certificate
   - Extract new pin and update configuration

3. **Verify Format**
   - Pins must start with `sha256/`
   - Example: `sha256/ABC123...==`

### Issue: No Certificate Pins Configured

**Symptoms**:
```
[AUTH] WARNING: No certificate pins configured!
[AUTH] Using fallback pins for common CAs
```

**Solution**:
```bash
# Extract pins for your API
./scripts/extract-cert-pins.sh --server api.example.com

# Update .env
CERT_PIN_PRIMARY=sha256/YOUR_PIN_HERE
CERT_PIN_BACKUP=sha256/YOUR_BACKUP_PIN_HERE
```

### Issue: Localhost Development Blocked

**Symptoms**:
- Cannot connect to localhost API during development

**Solution**:
```bash
# .env
API_BASE_URL=http://localhost:8080  # Use HTTP, not HTTPS
CERT_PINNING_ENABLED=false          # Disable for local dev
```

### Issue: Certificate Expired

**Symptoms**:
- All API requests fail
- Certificate validation errors

**Solution**:
1. Check certificate expiration:
   ```bash
   echo | openssl s_client -connect api.example.com:443 2>/dev/null | \
     openssl x509 -noout -enddate
   ```

2. If expired, coordinate with server admin to rotate certificate
3. Follow certificate rotation procedure above

## Production Checklist

Before deploying to production:

- [ ] `CERT_PINNING_ENABLED=true` in production `.env`
- [ ] `API_BASE_URL` uses HTTPS (not HTTP)
- [ ] `CERT_PIN_PRIMARY` configured with leaf certificate pin
- [ ] `CERT_PIN_BACKUP` configured with intermediate CA pin
- [ ] Tested with valid pins (connections succeed)
- [ ] Tested with invalid pins (connections rejected)
- [ ] Certificate rotation procedure documented for operations team
- [ ] Monitoring/alerting configured for certificate expiration
- [ ] Calendar reminders set for certificate rotation (30 days before expiration)

## API Reference

### Environment Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `CERT_PINNING_ENABLED` | boolean | `true` | Enable/disable certificate pinning |
| `CERT_PIN_PRIMARY` | string | `""` | Primary certificate pin (leaf cert) |
| `CERT_PIN_BACKUP` | string | `""` | Backup certificate pin (intermediate CA) |

### Console Output

| Message | Meaning |
|---------|---------|
| `[CERT-PIN] ✓ Certificate pinning initialized successfully` | Pinning enabled and configured |
| `[CERT-PIN] ✓ Certificate validated` | Pin matched, connection allowed |
| `[CERT-PIN] ✗ CERTIFICATE PINNING FAILED` | No pin matched, connection rejected |
| `[AUTH] Certificate pinning DISABLED` | Pinning not active (development mode) |
| `[AUTH] Using fallback pins for common CAs` | No specific pins, using CA defaults |

## Additional Resources

- [OWASP Certificate Pinning](https://owasp.org/www-community/controls/Certificate_and_Public_Key_Pinning)
- [Let's Encrypt Certificate Compatibility](https://letsencrypt.org/docs/certificate-compatibility/)
- [OpenSSL Documentation](https://www.openssl.org/docs/)

## Support

For issues or questions about certificate pinning:

1. Check this guide for troubleshooting steps
2. Run `./scripts/extract-cert-pins.sh --help` for script usage
3. Review console logs for detailed error messages
4. Verify certificate with `openssl s_client -connect api.example.com:443`

## Changelog

### 2024-11-06 - Certificate Pinning Enabled

- ✅ Certificate pinning fully implemented and enabled
- ✅ Real CA pins included (Let's Encrypt, DigiCert)
- ✅ Pin extraction script created
- ✅ Comprehensive documentation written
- ✅ Production-ready with zero-downtime rotation strategy
- ✅ Smart fallback for development and production modes

**Status**: PRODUCTION BLOCKER RESOLVED ✅
