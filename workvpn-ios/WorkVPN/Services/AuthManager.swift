//
//  AuthManager.swift
//  BarqNet
//
//  Authentication manager with backend API integration
//

import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: String?

    private let apiClient = APIClient.shared
    private let keychainService = "com.barqnet.ios"
    private let currentUserKey = "current_user"

    // OTP session storage (temporary, in-memory only)
    private var otpSessions: [String: OTPSession] = [:]

    struct OTPSession {
        let phoneNumber: String
        let sessionId: String?
        let verificationToken: String?
        let timestamp: Date
    }

    private init() {
        loadAuthState()
    }

    private func loadAuthState() {
        // Check if we have valid tokens in keychain
        if apiClient.hasValidToken() {
            // Load current user from keychain
            if let userData = KeychainHelper.load(service: keychainService, account: currentUserKey),
               let phoneNumber = String(data: userData, encoding: .utf8) {
                self.currentUser = phoneNumber
                self.isAuthenticated = true
                NSLog("[AuthManager] Restored authentication state for user: ***\(phoneNumber.suffix(4))")
            }
        }
    }

    func sendOTP(phoneNumber: String, completion: @escaping (Result<Void, Error>) -> Void) {
        NSLog("[AuthManager] Sending OTP to phone: ***\(phoneNumber.suffix(4))")

        apiClient.sendOTP(phoneNumber: phoneNumber) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let sessionId):
                    // Store session information
                    self.otpSessions[phoneNumber] = OTPSession(
                        phoneNumber: phoneNumber,
                        sessionId: sessionId,
                        verificationToken: nil,
                        timestamp: Date()
                    )
                    NSLog("[AuthManager] OTP sent successfully")
                    completion(.success(()))

                case .failure(let error):
                    NSLog("[AuthManager] Failed to send OTP: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }

    func verifyOTP(phoneNumber: String, code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        NSLog("[AuthManager] Verifying OTP for phone: ***\(phoneNumber.suffix(4))")

        guard code.count == 6, code.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil else {
            let error = NSError(domain: "AuthManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid OTP format. Must be 6 digits."])
            completion(.failure(error))
            return
        }

        let session = otpSessions[phoneNumber]

        apiClient.verifyOTP(phoneNumber: phoneNumber, code: code, sessionId: session?.sessionId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let verificationToken):
                    // Update session with verification token
                    self.otpSessions[phoneNumber] = OTPSession(
                        phoneNumber: phoneNumber,
                        sessionId: session?.sessionId,
                        verificationToken: verificationToken ?? code,
                        timestamp: Date()
                    )
                    NSLog("[AuthManager] OTP verified successfully")
                    completion(.success(()))

                case .failure(let error):
                    NSLog("[AuthManager] OTP verification failed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }

    func createAccount(phoneNumber: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        NSLog("[AuthManager] Creating account for phone: ***\(phoneNumber.suffix(4))")

        // Validate password
        guard password.count >= 8 else {
            let error = NSError(domain: "AuthManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Password must be at least 8 characters"])
            completion(.failure(error))
            return
        }

        // Get OTP code from session
        guard let session = otpSessions[phoneNumber],
              let otpCode = session.verificationToken else {
            let error = NSError(domain: "AuthManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "OTP verification required before registration"])
            completion(.failure(error))
            return
        }

        apiClient.register(phoneNumber: phoneNumber, password: password, otpCode: otpCode) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let (tokens, user)):
                    // Save current user to keychain
                    let phoneToStore = user?.phoneNumber ?? phoneNumber
                    if let userData = phoneToStore.data(using: .utf8) {
                        _ = KeychainHelper.save(userData, service: self.keychainService, account: self.currentUserKey)
                    }

                    // Update auth state
                    self.currentUser = phoneToStore
                    self.isAuthenticated = true

                    // Clean up OTP session
                    self.otpSessions.removeValue(forKey: phoneNumber)

                    NSLog("[AuthManager] Account created successfully")
                    completion(.success(()))

                case .failure(let error):
                    NSLog("[AuthManager] Account creation failed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }

    func login(phoneNumber: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        NSLog("[AuthManager] Logging in user: ***\(phoneNumber.suffix(4))")

        apiClient.login(phoneNumber: phoneNumber, password: password) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let (tokens, user)):
                    // Save current user to keychain
                    let phoneToStore = user?.phoneNumber ?? phoneNumber
                    if let userData = phoneToStore.data(using: .utf8) {
                        _ = KeychainHelper.save(userData, service: self.keychainService, account: self.currentUserKey)
                    }

                    // Update auth state
                    self.currentUser = phoneToStore
                    self.isAuthenticated = true

                    NSLog("[AuthManager] Login successful")
                    completion(.success(()))

                case .failure(let error):
                    NSLog("[AuthManager] Login failed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }

    func logout() {
        NSLog("[AuthManager] Logging out user")

        // Clear current user from keychain
        _ = KeychainHelper.delete(service: keychainService, account: currentUserKey)

        // Call API to logout and clear tokens
        apiClient.logout { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                self.currentUser = nil
                self.isAuthenticated = false

                // Clear OTP sessions
                self.otpSessions.removeAll()

                switch result {
                case .success:
                    NSLog("[AuthManager] Logout successful")
                case .failure(let error):
                    NSLog("[AuthManager] Logout completed (API call failed: \(error.localizedDescription))")
                }
            }
        }
    }
}
