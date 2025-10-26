# Desktop Certificate Pinning Integration - TODO

**Status:** Code exists but not integrated
**Priority:** HIGH (Required for production)
**Estimated Effort:** 2-3 hours
**Blocker:** No - app functional without it, but vulnerable to MITM

---

## Current Situation

**Certificate pinning code exists:** `src/main/vpn/certificate-pinning.ts` (188 lines)
- ✅ Full implementation with SHA256 hash verification
- ✅ TLS options generation
- ✅ Multiple pin support (primary + backup)
- ✅ Helper functions for pin calculation
- ❌ **NOT INTEGRATED** - Code is unused

**Authentication service:** `src/main/auth/service.ts`
- Uses `fetch()` API for HTTP requests
- No certificate validation customization
- **Vulnerable to MITM attacks** without pinning

---

## Why Not Integrated Yet

The existing `CertificatePinning` class is designed for Node.js TLS connections but:

1. **Auth service uses `fetch()`** - Not compatible with custom TLS options
2. **Fetch in Electron** doesn't support custom certificate validation callbacks
3. **Requires Electron session API** - Different integration approach needed

---

## Integration Approaches

### Option 1: Use Electron Session API (RECOMMENDED)

**File:** `src/main/auth/service.ts`

Electron's session API allows certificate validation:

```typescript
import { session } from 'electron';
import { CertificatePinning } from '../vpn/certificate-pinning';

// In AuthService constructor or init method:
const pinning = new CertificatePinning([
  {
    hostname: 'api.chameleonvpn.com',
    pins: [
      'sha256/PRIMARY_CERT_HASH_HERE', // Replace with actual hash
      'sha256/BACKUP_CERT_HASH_HERE'   // Backup certificate
    ]
  }
]);

// Add certificate verification handler
session.defaultSession.setCertificateVerifyProc((request, callback) => {
  const { hostname, certificate } = request;

  // Verify certificate pinning
  const isValid = pinning.verifyCertificate(hostname, certificate);

  if (isValid) {
    callback(0); // Accept
  } else {
    callback(-2); // Reject
  }
});
```

**Pros:**
- Works with fetch()
- Global for all requests
- Proper Electron integration

**Cons:**
- Affects all network requests (need hostname filtering)
- Requires session setup before any requests

---

### Option 2: Switch to HTTPS Module

Replace `fetch()` with Node.js `https` module:

```typescript
import https from 'https';
import { CertificatePinning } from '../vpn/certificate-pinning';

class AuthService {
  private pinning: CertificatePinning;

  constructor() {
    this.pinning = new CertificatePinning([...]);
  }

  private async apiCall(endpoint: string, options: any) {
    const url = new URL(`${this.apiBaseUrl}${endpoint}`);
    const tlsOptions = this.pinning.getTLSOptions(url.hostname);

    return new Promise((resolve, reject) => {
      const req = https.request({
        hostname: url.hostname,
        port: 443,
        path: url.pathname + url.search,
        method: options.method || 'GET',
        headers: options.headers,
        ...tlsOptions
      }, (res) => {
        // Handle response
      });

      req.write(options.body);
      req.end();
    });
  }
}
```

**Pros:**
- Uses existing CertificatePinning code directly
- More granular control

**Cons:**
- More code changes required
- Need to rewrite all fetch() calls
- More complex response handling

---

### Option 3: Use node-fetch with Custom Agent

Use `node-fetch` with custom https agent:

```typescript
import fetch from 'node-fetch';
import https from 'https';
import { CertificatePinning } from '../vpn/certificate-pinning';

const pinning = new CertificatePinning([...]);

const agent = new https.Agent({
  checkServerIdentity: (host, cert) => {
    if (!pinning.verifyCertificate(host, cert)) {
      throw new Error('Certificate pinning validation failed');
    }
  }
});

// In apiCall:
const response = await fetch(url, {
  agent,
  ...options
});
```

**Pros:**
- Minimal code changes
- Works with existing fetch() pattern

**Cons:**
- Requires `node-fetch` dependency
- Agent needs to be passed to every request

---

## Recommended Implementation: Option 1 (Electron Session)

### Step-by-Step Implementation

#### 1. Get Actual Certificate Pins

First, get the SHA256 pins from your backend server:

```bash
# Get certificate pin from production server
openssl s_client -connect api.chameleonvpn.com:443 < /dev/null 2>/dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  base64

# Output: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
# This is your primary pin
```

**Get backup pin too** (from backup certificate or CA certificate)

#### 2. Create Certificate Pinning Initialization

**New File:** `src/main/security/init-certificate-pinning.ts`

```typescript
import { session } from 'electron';
import { CertificatePinning } from '../vpn/certificate-pinning';

export function initializeCertificatePinning(): void {
  // Configure certificate pins for API server
  const pinning = new CertificatePinning([
    {
      hostname: process.env.API_HOSTNAME || 'api.chameleonvpn.com',
      pins: [
        'sha256/PRIMARY_PIN_HERE',  // TODO: Replace with actual pin
        'sha256/BACKUP_PIN_HERE'    // TODO: Replace with backup pin
      ]
    }
  ]);

  // Set certificate verification handler
  session.defaultSession.setCertificateVerifyProc((request, callback) => {
    const { hostname, certificate, verificationResult, errorCode } = request;

    // Allow localhost in development
    if (process.env.NODE_ENV !== 'production' && hostname === 'localhost') {
      callback(0);
      return;
    }

    // Check if hostname needs pinning
    const needsPinning = pinning.getPins(hostname).length > 0;

    if (needsPinning) {
      // Verify certificate pinning
      const isValid = pinning.verifyCertificate(hostname, certificate);

      if (isValid) {
        console.log(`[CERT-PIN] Certificate validated for ${hostname}`);
        callback(0); // Accept
      } else {
        console.error(`[CERT-PIN] Certificate pinning FAILED for ${hostname}`);
        callback(-2); // Reject - CERT_INVALID
      }
    } else {
      // No pinning configured, use default verification
      callback(verificationResult === 'net::OK' ? 0 : errorCode);
    }
  });

  console.log('[CERT-PIN] Certificate pinning initialized');
}
```

#### 3. Initialize in Main Process

**File:** `src/main/index.ts`

```typescript
import { initializeCertificatePinning } from './security/init-certificate-pinning';

app.whenReady().then(() => {
  // Initialize certificate pinning BEFORE any network requests
  initializeCertificatePinning();

  // Then initialize everything else
  init();
});
```

#### 4. Add Environment Variables

**File:** `.env.example`

```bash
# Certificate Pinning Configuration
API_HOSTNAME=api.chameleonvpn.com
CERT_PIN_PRIMARY=sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
CERT_PIN_BACKUP=sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=
```

#### 5. Testing

```typescript
// Test certificate pinning in development
// Temporarily use wrong pin to verify rejection works

// Should see in console:
// [CERT-PIN] Certificate pinning FAILED for api.chameleonvpn.com
// [AUTH] API call failed: net::ERR_CERT_INVALID
```

---

## Pin Rotation Strategy

Certificate pins should be rotated when:
1. Certificate expires (plan 30 days before)
2. Security incident (immediate)
3. Regular rotation (every 90 days recommended)

**Always include backup pin** to allow smooth rotation:
- Primary pin: Current certificate
- Backup pin: Next certificate (staged before rotation)

---

## Additional Security Considerations

### 1. Pin Multiple Certificates

Always pin at least 2 certificates:
- Current server certificate
- Intermediate CA certificate (as backup)

### 2. Handle Pin Mismatch Gracefully

```typescript
// Don't just fail silently
if (!isValid) {
  // Log to error reporting service (Sentry, etc.)
  logSecurityEvent('certificate_pin_mismatch', { hostname });

  // Alert user
  dialog.showErrorBox(
    'Security Error',
    'Could not verify server identity. Please check your connection.'
  );

  callback(-2);
}
```

### 3. Update Mechanism

Pins need to be updatable without app update:
- Fetch pin list from trusted source on startup
- Store in encrypted config
- Fallback to built-in pins if fetch fails

---

## Production Checklist

Before enabling in production:

- [ ] Get actual certificate pins from production API server
- [ ] Get backup certificate pin (intermediate CA or future cert)
- [ ] Configure pins in environment variables or config
- [ ] Test with correct pins (should connect)
- [ ] Test with wrong pins (should reject)
- [ ] Test certificate rotation procedure
- [ ] Add error reporting for pin mismatch
- [ ] Document pin rotation process
- [ ] Set up alerts for pin expiration (30 days before)
- [ ] Test across all platforms (Windows, macOS, Linux)

---

## Estimated Timeline

- **Setup & Testing:** 1-2 hours
- **Integration:** 30 minutes
- **Testing:** 30 minutes
- **Documentation:** 30 minutes
- **Total:** 2-3 hours

---

## References

- Electron Certificate Verification: https://www.electronjs.org/docs/latest/api/session#sessetcertificateverifyproccallback
- OWASP Certificate Pinning: https://owasp.org/www-community/controls/Certificate_and_Public_Key_Pinning
- Existing Code: `src/main/vpn/certificate-pinning.ts`

---

## Current Status

**Code Ready:** ✅ CertificatePinning class fully implemented
**Integration:** ❌ Not yet integrated (use Option 1 above)
**Testing:** ❌ Not tested
**Production Ready:** ❌ Blocked on integration

**Next Action:** Implement Option 1 (Electron Session API) following steps above
