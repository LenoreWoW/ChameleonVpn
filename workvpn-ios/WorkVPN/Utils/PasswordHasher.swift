//
//  PasswordHasher.swift
//  WorkVPN
//
//  Secure password hashing using PBKDF2-HMAC-SHA256
//

import Foundation
import CommonCrypto

class PasswordHasher {

    // Security Parameters
    private static let saltSize = 16           // 16 bytes = 128 bits
    private static let keyLength = 32          // 32 bytes = 256 bits
    private static let iterations = 100_000    // OWASP recommendation for PBKDF2-SHA256

    /**
     * Hash a password using PBKDF2-HMAC-SHA256
     *
     * - Parameter password: The plaintext password to hash
     * - Returns: Base64-encoded string containing salt + hash, or nil on error
     *
     * Format: [16-byte salt][32-byte hash] = 48 bytes total
     * Base64 encoded: ~64 characters
     */
    static func hash(password: String) -> String? {
        guard let passwordData = password.data(using: .utf8) else {
            NSLog("[PasswordHasher] ERROR: Failed to convert password to UTF-8")
            return nil
        }

        // Generate cryptographically secure random salt
        var salt = Data(count: saltSize)
        let saltResult = salt.withUnsafeMutableBytes { saltBytes in
            SecRandomCopyBytes(kSecRandomDefault, saltSize, saltBytes.baseAddress!)
        }

        guard saltResult == errSecSuccess else {
            NSLog("[PasswordHasher] ERROR: Failed to generate random salt")
            return nil
        }

        // Derive key using PBKDF2
        guard let hashData = deriveKey(password: passwordData, salt: salt) else {
            NSLog("[PasswordHasher] ERROR: Failed to derive key")
            return nil
        }

        // Combine salt + hash for storage
        let combined = salt + hashData
        return combined.base64EncodedString()
    }

    /**
     * Verify a password against a stored hash
     *
     * - Parameters:
     *   - password: The plaintext password to verify
     *   - hash: The stored hash (Base64-encoded salt + hash)
     * - Returns: true if password matches, false otherwise
     */
    static func verify(password: String, hash: String) -> Bool {
        guard let passwordData = password.data(using: .utf8),
              let storedData = Data(base64Encoded: hash),
              storedData.count >= (saltSize + keyLength) else {
            return false
        }

        // Extract salt (first 16 bytes) and hash (remaining bytes)
        let salt = storedData.prefix(saltSize)
        let storedHash = storedData.suffix(from: saltSize)

        // Derive key with the same salt
        guard let computedHash = deriveKey(password: passwordData, salt: salt) else {
            return false
        }

        // Constant-time comparison to prevent timing attacks
        return constantTimeCompare(computedHash, storedHash)
    }

    /**
     * Check if a hash is using the old insecure Base64 encoding
     *
     * - Parameter hash: The hash to check
     * - Returns: true if hash is old Base64 format (short, no salt)
     */
    static func isLegacyBase64Hash(hash: String) -> Bool {
        // Legacy Base64 hashes are much shorter (no salt + hash, just encoded password)
        // PBKDF2 hashes are ~64 characters (48 bytes Base64 encoded)
        // Legacy hashes are typically < 50 characters
        if hash.count < 50 {
            return true
        }

        // Additional check: try to decode and see if it's a valid PBKDF2 hash
        guard let data = Data(base64Encoded: hash) else {
            return true  // If it's not valid Base64, it's definitely legacy
        }

        // Valid PBKDF2 hash should be at least 48 bytes (16 salt + 32 hash)
        return data.count < (saltSize + keyLength)
    }

    // MARK: - Private Helpers

    /**
     * Derive a key using PBKDF2-HMAC-SHA256
     *
     * - Parameters:
     *   - password: Password data
     *   - salt: Salt data
     * - Returns: Derived key data, or nil on error
     */
    private static func deriveKey(password: Data, salt: Data) -> Data? {
        var derivedKeyData = Data(count: keyLength)

        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard derivationStatus == kCCSuccess else {
            NSLog("[PasswordHasher] ERROR: PBKDF2 derivation failed with status: \(derivationStatus)")
            return nil
        }

        return derivedKeyData
    }

    /**
     * Constant-time comparison to prevent timing attacks
     *
     * - Parameters:
     *   - lhs: First data to compare
     *   - rhs: Second data to compare
     * - Returns: true if data is equal
     */
    private static func constantTimeCompare(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }

        var result: UInt8 = 0
        for i in 0..<lhs.count {
            result |= lhs[i] ^ rhs[i]
        }

        return result == 0
    }
}
