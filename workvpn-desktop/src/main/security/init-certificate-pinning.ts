import { session } from 'electron';
import { CertificatePinning } from '../vpn/certificate-pinning';

/**
 * Initialize Certificate Pinning for Desktop App
 *
 * This function sets up certificate pinning for all HTTPS requests
 * to protect against MITM attacks. It uses Electron's session API
 * to intercept and validate certificates.
 *
 * IMPORTANT: This must be called BEFORE any network requests are made,
 * ideally in app.whenReady() before initializing other services.
 */
export function initializeCertificatePinning(): void {
  console.log('[CERT-PIN] Initializing certificate pinning...');

  // Parse API hostname from environment variable
  const apiBaseUrl = process.env.API_BASE_URL || 'http://localhost:8080';
  let apiHostname: string;

  try {
    const url = new URL(apiBaseUrl);
    apiHostname = url.hostname;
  } catch (error) {
    console.error('[CERT-PIN] Invalid API_BASE_URL:', apiBaseUrl);
    apiHostname = 'localhost';
  }

  // Get certificate pins from environment variables
  // In production, these should be set in .env file or environment
  const primaryPin = process.env.CERT_PIN_PRIMARY;
  const backupPin = process.env.CERT_PIN_BACKUP;

  // Configure certificate pins for API server
  const pins: string[] = [];

  if (primaryPin) {
    pins.push(primaryPin);
  }

  if (backupPin) {
    pins.push(backupPin);
  }

  // Only configure pinning if pins are provided
  let pinning: CertificatePinning | null = null;

  if (pins.length > 0) {
    console.log(`[CERT-PIN] Configuring certificate pinning for ${apiHostname}`);
    console.log(`[CERT-PIN] Number of pins configured: ${pins.length}`);

    pinning = new CertificatePinning([
      {
        hostname: apiHostname,
        pins: pins
      }
    ]);
  } else {
    console.warn('[CERT-PIN] WARNING: No certificate pins configured!');
    console.warn('[CERT-PIN] Set CERT_PIN_PRIMARY and CERT_PIN_BACKUP environment variables');
    console.warn('[CERT-PIN] Certificate pinning will be DISABLED - vulnerable to MITM attacks');
  }

  // Set certificate verification handler
  session.defaultSession.setCertificateVerifyProc((request, callback) => {
    const { hostname, certificate, verificationResult, errorCode } = request;

    // Development mode: Allow localhost without pinning
    if (process.env.NODE_ENV !== 'production' && hostname === 'localhost') {
      console.log(`[CERT-PIN] Allowing localhost connection (development mode)`);
      callback(0);
      return;
    }

    // Development mode: Allow 127.0.0.1 without pinning
    if (process.env.NODE_ENV !== 'production' && hostname === '127.0.0.1') {
      console.log(`[CERT-PIN] Allowing 127.0.0.1 connection (development mode)`);
      callback(0);
      return;
    }

    // If no pinning configured, use default verification
    if (!pinning) {
      console.log(`[CERT-PIN] No pinning configured, using default verification for ${hostname}`);
      callback(verificationResult === 'net::OK' ? 0 : errorCode);
      return;
    }

    // Check if this hostname requires pinning
    const pinsForHost = pinning.getPins(hostname);
    const needsPinning = pinsForHost.length > 0;

    if (needsPinning) {
      console.log(`[CERT-PIN] Verifying certificate for ${hostname}...`);

      // Verify certificate pinning
      const isValid = pinning.verifyCertificate(hostname, certificate);

      if (isValid) {
        console.log(`[CERT-PIN] ✓ Certificate validated for ${hostname}`);
        callback(0); // Accept certificate
      } else {
        console.error(`[CERT-PIN] ✗ CERTIFICATE PINNING FAILED for ${hostname}`);
        console.error(`[CERT-PIN] This could indicate a MITM attack!`);
        console.error(`[CERT-PIN] Expected one of: ${pinsForHost.join(', ')}`);
        callback(-2); // Reject certificate (CERT_INVALID)
      }
    } else {
      // No pinning configured for this hostname, use default verification
      console.log(`[CERT-PIN] No pins configured for ${hostname}, using default verification`);
      callback(verificationResult === 'net::OK' ? 0 : errorCode);
    }
  });

  if (pins.length > 0) {
    console.log('[CERT-PIN] ✓ Certificate pinning initialized successfully');
    console.log(`[CERT-PIN] Protected hostname: ${apiHostname}`);
  } else {
    console.warn('[CERT-PIN] ⚠ Certificate pinning NOT active (no pins configured)');
  }
}

/**
 * Get certificate pin from a server
 *
 * This is a helper function to get the certificate pin from a server.
 * Use this during development/setup to get the pin for your API server.
 *
 * Usage (from terminal):
 *
 * # Get certificate pin from server
 * openssl s_client -connect api.chameleonvpn.com:443 < /dev/null 2>/dev/null | \
 *   openssl x509 -pubkey -noout | \
 *   openssl pkey -pubin -outform der | \
 *   openssl dgst -sha256 -binary | \
 *   base64
 *
 * # Output: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
 * # This is your pin - use it as: sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
 *
 * Then set in .env:
 * CERT_PIN_PRIMARY=sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
 */
export function getCertificatePinningInstructions(): string {
  return `
To get certificate pins for your API server:

1. Get primary certificate pin:
   openssl s_client -connect your-api.com:443 < /dev/null 2>/dev/null | \\
     openssl x509 -pubkey -noout | \\
     openssl pkey -pubin -outform der | \\
     openssl dgst -sha256 -binary | \\
     base64

2. Get backup certificate pin (from intermediate CA or backup cert):
   # Same command with backup server or CA certificate

3. Add to .env file:
   CERT_PIN_PRIMARY=sha256/YOUR_PRIMARY_PIN_HERE
   CERT_PIN_BACKUP=sha256/YOUR_BACKUP_PIN_HERE

4. Restart the application

IMPORTANT:
- Always have at least 2 pins (primary + backup)
- Backup pin allows smooth certificate rotation
- Update pins before certificates expire
- Test with wrong pins to verify rejection works
  `;
}
