//
//  CertificatePinning.swift
//  BarqNet
//
//  Certificate pinning implementation for iOS
//

import Foundation
import Security

/**
 * Certificate Pinning Manager
 *
 * Validates server certificates against known public keys
 * to prevent MITM attacks
 */
class CertificatePinning {

    /// Certificate pins in format: "sha256/BASE64HASH"
    private var pinnedCertificates: [String: Set<String>] = [:]

    init(pins: [String: [String]] = [:]) {
        pins.forEach { hostname, pinList in
            pinnedCertificates[hostname] = Set(pinList)
        }
    }

    /**
     * Add certificate pins for a hostname
     */
    func addPins(hostname: String, pins: [String]) {
        if pinnedCertificates[hostname] == nil {
            pinnedCertificates[hostname] = Set()
        }
        pins.forEach { pinnedCertificates[hostname]?.insert($0) }
    }

    /**
     * Verify server certificate matches pinned public keys
     *
     * Call this from URLSession delegate:
     * urlSession(_ session:, didReceive challenge:, completionHandler:)
     */
    func validateCertificate(
        challenge: URLAuthenticationChallenge,
        hostname: String
    ) -> (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?) {

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            print("[CERT-PIN] No server trust found")
            return (.cancelAuthenticationChallenge, nil)
        }

        guard let pins = pinnedCertificates[hostname], !pins.isEmpty else {
            print("[CERT-PIN] WARNING: No pins configured for \(hostname)")
            // In production, you might want to reject unpinned connections
            return (.performDefaultHandling, nil)
        }

        // Get certificate chain (iOS 15+ compatible)
        guard let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let certificate = certificates.first else {
            print("[CERT-PIN] Failed to get certificate")
            return (.cancelAuthenticationChallenge, nil)
        }

        // Get public key hash
        guard let publicKeyHash = getPublicKeyHash(certificate: certificate) else {
            print("[CERT-PIN] Failed to get public key hash")
            return (.cancelAuthenticationChallenge, nil)
        }

        let pinString = "sha256/\(publicKeyHash)"

        if pins.contains(pinString) {
            print("[CERT-PIN] ✓ Certificate validated for \(hostname)")
            return (.useCredential, URLCredential(trust: serverTrust))
        } else {
            print("[CERT-PIN] ✗ Certificate validation failed for \(hostname)")
            print("[CERT-PIN] Expected one of: \(pins)")
            print("[CERT-PIN] Got: \(pinString)")
            return (.cancelAuthenticationChallenge, nil)
        }
    }

    /**
     * Get SHA256 hash of certificate's public key
     */
    private func getPublicKeyHash(certificate: SecCertificate) -> String? {
        // Get public key from certificate
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            return nil
        }

        // Export public key data
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        // Calculate SHA256 hash
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        publicKeyData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(publicKeyData.count), &hash)
        }

        // Convert to base64
        let hashData = Data(hash)
        return hashData.base64EncodedString()
    }

    /**
     * Get pinned certificates for a hostname
     */
    func getPins(hostname: String) -> [String] {
        return Array(pinnedCertificates[hostname] ?? [])
    }

    /**
     * Remove all pins for a hostname
     */
    func clearPins(hostname: String) {
        pinnedCertificates.removeValue(forKey: hostname)
    }

    /**
     * Clear all pinned certificates
     */
    func clearAll() {
        pinnedCertificates.removeAll()
    }
}

// Import CommonCrypto for SHA256
import CommonCrypto

/**
 * Usage Example:
 *
 * ```swift
 * // Initialize with pins
 * let pinning = CertificatePinning(pins: [
 *     "vpn.server.com": [
 *         "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", // Primary
 *         "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="  // Backup
 *     ]
 * ])
 *
 * // In URLSessionDelegate:
 * func urlSession(
 *     _ session: URLSession,
 *     didReceive challenge: URLAuthenticationChallenge,
 *     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
 * ) {
 *     let (disposition, credential) = pinning.validateCertificate(
 *         challenge: challenge,
 *         hostname: "vpn.server.com"
 *     )
 *     completionHandler(disposition, credential)
 * }
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

/**
 * Extension for VPNManager to use certificate pinning
 */
extension VPNManager {

    func setupCertificatePinning(hostname: String, pins: [String]) {
        // Store certificate pinning configuration
        // Apply to NetworkExtension tunnel configuration

        // This would be integrated into the VPN configuration
        // when setting up the tunnel provider
    }
}
