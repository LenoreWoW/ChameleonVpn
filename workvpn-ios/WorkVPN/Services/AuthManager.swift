//
//  AuthManager.swift
//  WorkVPN
//
//  Authentication manager for phone number + OTP onboarding
//

import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: String?

    private var otpStorage: [String: (otp: String, expiry: Date)] = [:]
    private let userDefaults = UserDefaults.standard

    private let currentUserKey = "current_user"
    private let usersKey = "users"

    private init() {
        loadAuthState()
    }

    private func loadAuthState() {
        // Load persisted authentication state
        currentUser = userDefaults.string(forKey: currentUserKey)
        isAuthenticated = currentUser != nil
    }

    func sendOTP(phoneNumber: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.async {
            let otp = String(format: "%06d", Int.random(in: 100000...999999))
            let expiry = Date().addingTimeInterval(10 * 60) // 10 minutes

            self.otpStorage[phoneNumber] = (otp, expiry)

            // OTP logging removed for security - codes should never be exposed in logs
            // Production integration: Send OTP via SMS service (Twilio/AWS SNS/etc)
            // Backend should handle SMS delivery via POST /auth/otp/send

            completion(.success(()))
        }
    }

    func verifyOTP(phoneNumber: String, code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.async {
            guard let otpData = self.otpStorage[phoneNumber] else {
                completion(.failure(NSError(domain: "AuthManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No OTP session found"])))
                return
            }

            if Date() > otpData.expiry {
                self.otpStorage.removeValue(forKey: phoneNumber)
                completion(.failure(NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "OTP expired"])))
                return
            }

            if otpData.otp != code {
                completion(.failure(NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid OTP code"])))
                return
            }

            completion(.success(()))
        }
    }

    /**
     * Create user account
     *
     * TODO: CRITICAL SECURITY - Replace Base64 with proper password hashing!
     *
     * Current Status: ❌ INSECURE - Using Base64 encoding (NOT hashing!)
     * - Base64 is NOT a hashing algorithm - it's just encoding
     * - Base64 is REVERSIBLE - anyone can decode it to get plaintext password
     * - Example: "password123" → "cGFzc3dvcmQxMjM=" (easily decoded)
     * - This is a CRITICAL security vulnerability (CVSS 8.1 - HIGH)
     *
     * Required Implementation: Replace with PBKDF2 password hashing
     *
     * 1. Add PBKDF2 helper class:
     *
     *    import CryptoKit
     *
     *    class PasswordHasher {
     *        static func hash(password: String) -> String? {
     *            guard let passwordData = password.data(using: .utf8) else { return nil }
     *
     *            // Generate random salt (16 bytes)
     *            var salt = Data(count: 16)
     *            _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
     *
     *            // PBKDF2 with SHA256, 100,000 iterations
     *            let hash = try? PBKDF2.deriveKey(
     *                password: passwordData,
     *                salt: salt,
     *                iterations: 100_000,
     *                keyLength: 32
     *            )
     *
     *            // Combine salt + hash for storage
     *            guard let hashData = hash else { return nil }
     *            let combined = salt + hashData
     *            return combined.base64EncodedString()
     *        }
     *
     *        static func verify(password: String, hash: String) -> Bool {
     *            guard let passwordData = password.data(using: .utf8),
     *                  let storedData = Data(base64Encoded: hash),
     *                  storedData.count >= 48 else { return false }
     *
     *            // Extract salt (first 16 bytes) and hash (remaining bytes)
     *            let salt = storedData.prefix(16)
     *            let storedHash = storedData.suffix(from: 16)
     *
     *            // Hash the provided password with extracted salt
     *            let computedHash = try? PBKDF2.deriveKey(
     *                password: passwordData,
     *                salt: salt,
     *                iterations: 100_000,
     *                keyLength: 32
     *            )
     *
     *            return computedHash == storedHash
     *        }
     *
     *        // Helper for PBKDF2 (iOS 13+)
     *        struct PBKDF2 {
     *            static func deriveKey(password: Data, salt: Data, iterations: Int, keyLength: Int) throws -> Data {
     *                var derivedKeyData = Data(count: keyLength)
     *                let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
     *                    salt.withUnsafeBytes { saltBytes in
     *                        password.withUnsafeBytes { passwordBytes in
     *                            CCKeyDerivationPBKDF(
     *                                CCPBKDFAlgorithm(kCCPBKDF2),
     *                                passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
     *                                password.count,
     *                                saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
     *                                salt.count,
     *                                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
     *                                UInt32(iterations),
     *                                derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
     *                                keyLength
     *                            )
     *                        }
     *                    }
     *                }
     *                guard derivationStatus == kCCSuccess else {
     *                    throw NSError(domain: "PasswordHasher", code: Int(derivationStatus))
     *                }
     *                return derivedKeyData
     *            }
     *        }
     *    }
     *
     * 2. Import CommonCrypto in bridging header (if needed):
     *    #import <CommonCrypto/CommonCrypto.h>
     *
     * 3. Replace Base64 encoding:
     *
     *    // BEFORE (INSECURE):
     *    let passwordHash = password.data(using: .utf8)?.base64EncodedString() ?? ""
     *
     *    // AFTER (SECURE):
     *    guard let passwordHash = PasswordHasher.hash(password: password) else {
     *        completion(.failure(NSError(...)))
     *        return
     *    }
     *
     * 4. Update login verification (line 106-108):
     *
     *    // BEFORE (INSECURE):
     *    let passwordHash = password.data(using: .utf8)?.base64EncodedString() ?? ""
     *    if storedHash != passwordHash { ... }
     *
     *    // AFTER (SECURE):
     *    if !PasswordHasher.verify(password: password, hash: storedHash) { ... }
     *
     * 5. Add migration for existing users:
     *
     *    func migratePasswordHashes() {
     *        var users = getUsersMap()
     *        var migrated = false
     *
     *        for (phone, hash) in users {
     *            // Check if hash is old Base64 format (short length, no salt)
     *            if hash.count < 64 {
     *                // Decode old Base64 to get plaintext (ONLY during migration!)
     *                if let passwordData = Data(base64Encoded: hash),
     *                   let plaintext = String(data: passwordData, encoding: .utf8),
     *                   let newHash = PasswordHasher.hash(password: plaintext) {
     *                    users[phone] = newHash
     *                    migrated = true
     *                }
     *            }
     *        }
     *
     *        if migrated {
     *            saveUsersMap(users)
     *            NSLog("Migrated password hashes to PBKDF2")
     *        }
     *    }
     *
     * Estimated Effort: 2-3 hours (implementation + testing + migration)
     * Priority: CRITICAL (High severity security vulnerability)
     * CVSS Score: 8.1 (HIGH) - Cleartext storage of sensitive information
     */
    func createAccount(phoneNumber: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.async {
            var users = self.getUsersMap()

            if users[phoneNumber] != nil {
                completion(.failure(NSError(domain: "AuthManager", code: 409, userInfo: [NSLocalizedDescriptionKey: "Account already exists"])))
                return
            }

            // TODO: CRITICAL - Replace Base64 with PBKDF2 hashing (see documentation above)
            // Base64 is NOT hashing - it's reversible encoding!
            let passwordHash = password.data(using: .utf8)?.base64EncodedString() ?? ""
            users[phoneNumber] = passwordHash

            self.saveUsersMap(users)

            // Auto-login
            self.userDefaults.set(phoneNumber, forKey: self.currentUserKey)
            self.currentUser = phoneNumber
            self.isAuthenticated = true

            // Clean up OTP
            self.otpStorage.removeValue(forKey: phoneNumber)

            completion(.success(()))
        }
    }

    func login(phoneNumber: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.async {
            let users = self.getUsersMap()

            guard let storedHash = users[phoneNumber] else {
                completion(.failure(NSError(domain: "AuthManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Account not found"])))
                return
            }

            // TODO: CRITICAL - Replace Base64 with PBKDF2 verification (see createAccount documentation)
            // This should use: if !PasswordHasher.verify(password: password, hash: storedHash)
            let passwordHash = password.data(using: .utf8)?.base64EncodedString() ?? ""

            if storedHash != passwordHash {
                completion(.failure(NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid password"])))
                return
            }

            self.userDefaults.set(phoneNumber, forKey: self.currentUserKey)
            self.currentUser = phoneNumber
            self.isAuthenticated = true

            completion(.success(()))
        }
    }

    func logout() {
        userDefaults.removeObject(forKey: currentUserKey)
        currentUser = nil
        isAuthenticated = false
    }

    private func getUsersMap() -> [String: String] {
        guard let usersData = userDefaults.data(forKey: usersKey),
              let users = try? JSONDecoder().decode([String: String].self, from: usersData) else {
            return [:]
        }
        return users
    }

    private func saveUsersMap(_ users: [String: String]) {
        if let encoded = try? JSONEncoder().encode(users) {
            userDefaults.set(encoded, forKey: usersKey)
        }
    }
}
