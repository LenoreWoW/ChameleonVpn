import * as tls from 'tls';
import * as crypto from 'crypto';

/**
 * Certificate Pinning for Desktop VPN Client
 *
 * Validates server certificates against known public keys
 * to prevent MITM attacks
 */

export interface CertificatePin {
  hostname: string;
  pins: string[]; // Array of SHA256 hashes in format: sha256/<base64>
}

export class CertificatePinning {
  private pinnedCertificates: Map<string, Set<string>>;

  constructor(pins: CertificatePin[] = []) {
    this.pinnedCertificates = new Map();

    pins.forEach(pin => {
      this.addPin(pin.hostname, pin.pins);
    });
  }

  /**
   * Add certificate pins for a hostname
   */
  addPin(hostname: string, pins: string[]): void {
    if (!this.pinnedCertificates.has(hostname)) {
      this.pinnedCertificates.set(hostname, new Set());
    }

    const hostPins = this.pinnedCertificates.get(hostname)!;
    pins.forEach(pin => hostPins.add(pin));
  }

  /**
   * Verify certificate matches pinned public keys
   */
  verifyCertificate(hostname: string, certificate: any): boolean {
    const pins = this.pinnedCertificates.get(hostname);

    if (!pins || pins.size === 0) {
      // No pins configured for this hostname, allow connection
      // In production, you might want to reject unpinned connections
      console.warn(`[CERT-PIN] No pins configured for ${hostname}`);
      return true;
    }

    // Extract public key from certificate
    const publicKeyHash = this.getPublicKeyHash(certificate);
    const pinString = `sha256/${publicKeyHash}`;

    const isValid = pins.has(pinString);

    if (!isValid) {
      console.error(`[CERT-PIN] Certificate validation failed for ${hostname}`);
      console.error(`[CERT-PIN] Expected one of:`, Array.from(pins));
      console.error(`[CERT-PIN] Got: ${pinString}`);
    } else {
      console.log(`[CERT-PIN] Certificate validated for ${hostname}`);
    }

    return isValid;
  }

  /**
   * Get SHA256 hash of certificate's public key
   */
  private getPublicKeyHash(certificate: any): string {
    // Get DER-encoded public key
    const publicKeyDer = certificate.pubkey;

    // Calculate SHA256 hash
    const hash = crypto.createHash('sha256');
    hash.update(publicKeyDer);

    // Return base64-encoded hash
    return hash.digest('base64');
  }

  /**
   * Create TLS options with certificate pinning
   */
  getTLSOptions(hostname: string): tls.ConnectionOptions {
    return {
      checkServerIdentity: (host, cert) => {
        // First, do standard hostname verification
        const err = tls.checkServerIdentity(host, cert);
        if (err) {
          return err;
        }

        // Then, verify certificate pinning
        if (!this.verifyCertificate(hostname, cert)) {
          return new Error('Certificate pinning validation failed');
        }

        return undefined;
      }
    };
  }

  /**
   * Get pinned certificates for a hostname
   */
  getPins(hostname: string): string[] {
    const pins = this.pinnedCertificates.get(hostname);
    return pins ? Array.from(pins) : [];
  }

  /**
   * Remove all pins for a hostname
   */
  clearPins(hostname: string): void {
    this.pinnedCertificates.delete(hostname);
  }

  /**
   * Clear all pinned certificates
   */
  clearAll(): void {
    this.pinnedCertificates.clear();
  }
}

/**
 * Helper: Calculate certificate pin from .pem file
 *
 * Usage:
 * const pin = await calculatePinFromPEM(pemString);
 * console.log(`Pin: sha256/${pin}`);
 */
export async function calculatePinFromPEM(pemString: string): Promise<string> {
  // Remove PEM header/footer and decode base64
  const certData = pemString
    .replace(/-----BEGIN CERTIFICATE-----/, '')
    .replace(/-----END CERTIFICATE-----/, '')
    .replace(/\s/g, '');

  const certBuffer = Buffer.from(certData, 'base64');

  // Parse certificate (simplified - in production use a proper library)
  // This is a basic implementation
  const hash = crypto.createHash('sha256');
  hash.update(certBuffer);

  return hash.digest('base64');
}

/**
 * Usage Example:
 *
 * ```typescript
 * // Define certificate pins
 * const pinning = new CertificatePinning([
 *   {
 *     hostname: 'vpn.server.com',
 *     pins: [
 *       'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // Primary
 *       'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB='  // Backup
 *     ]
 *   }
 * ]);
 *
 * // In VPN manager, when connecting:
 * const tlsOptions = pinning.getTLSOptions('vpn.server.com');
 *
 * // Apply to OpenVPN connection
 * const connection = tls.connect({
 *   host: 'vpn.server.com',
 *   port: 1194,
 *   ...tlsOptions
 * });
 * ```
 *
 * To get SHA256 hash of a server's certificate:
 * ```bash
 * openssl s_client -connect vpn.server.com:443 < /dev/null | \
 *   openssl x509 -pubkey -noout | \
 *   openssl pkey -pubin -outform der | \
 *   openssl dgst -sha256 -binary | \
 *   base64
 * ```
 */
