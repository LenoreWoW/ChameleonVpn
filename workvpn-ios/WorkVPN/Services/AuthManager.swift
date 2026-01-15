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
        let email: String
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
               let email = String(data: userData, encoding: .utf8) {
                self.currentUser = email
                self.isAuthenticated = true
                NSLog("[AuthManager] Restored authentication state for user: \(email)")
            }
        }
    }

    func sendOTP(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        NSLog("[AuthManager] Sending OTP to email: \(email)")

        apiClient.sendOTP(email: email) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let sessionId):
                    // Store session information
                    self.otpSessions[email] = OTPSession(
                        email: email,
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

    func verifyOTP(email: String, code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        NSLog("[AuthManager] Verifying OTP for email: \(email)")

        guard code.count == 6, code.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil else {
            let error = NSError(domain: "AuthManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid OTP format. Must be 6 digits."])
            completion(.failure(error))
            return
        }

        let session = otpSessions[email]

        apiClient.verifyOTP(email: email, code: code, sessionId: session?.sessionId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let verificationToken):
                    // Update session with verification token
                    self.otpSessions[email] = OTPSession(
                        email: email,
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

    func createAccount(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        NSLog("[AuthManager] Creating account for email: \(email)")

        // Validate password
        guard password.count >= 8 else {
            let error = NSError(domain: "AuthManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Password must be at least 8 characters"])
            completion(.failure(error))
            return
        }

        // Get OTP code from session
        guard let session = otpSessions[email],
              let otpCode = session.verificationToken else {
            let error = NSError(domain: "AuthManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "OTP verification required before registration"])
            completion(.failure(error))
            return
        }

        apiClient.register(email: email, password: password, otpCode: otpCode) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let (_, user)):
                    // Save current user to keychain
                    let emailToStore = user?.email ?? email
                    if let userData = emailToStore.data(using: .utf8) {
                        _ = KeychainHelper.save(userData, service: self.keychainService, account: self.currentUserKey)
                    }

                    // Update auth state
                    self.currentUser = emailToStore
                    self.isAuthenticated = true

                    // Clean up OTP session
                    self.otpSessions.removeValue(forKey: email)

                    NSLog("[AuthManager] Account created successfully")
                    completion(.success(()))

                case .failure(let error):
                    NSLog("[AuthManager] Account creation failed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }

    func login(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        NSLog("[AuthManager] Logging in user: \(email)")

        apiClient.login(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let (_, user)):
                    // Save current user to keychain
                    let emailToStore = user?.email ?? email
                    if let userData = emailToStore.data(using: .utf8) {
                        _ = KeychainHelper.save(userData, service: self.keychainService, account: self.currentUserKey)
                    }

                    // Update auth state
                    self.currentUser = emailToStore
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

    /// Download VPN configuration and import it
    func downloadAndConfigureVPN(completion: @escaping (Result<Void, Error>) -> Void) {
        NSLog("[AuthManager] Downloading VPN configuration")

        apiClient.fetchVPNConfig { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let config):
                    NSLog("[AuthManager] VPN config received - Server: \(config.serverID)")

                    // Import the OVPN configuration into VPN manager
                    let vpnManager = VPNManager.shared
                    do {
                        try vpnManager.importConfig(content: config.ovpnContent, name: "\(config.username).ovpn")
                        NSLog("[AuthManager] VPN configuration imported successfully")
                        completion(.success(()))
                    } catch {
                        NSLog("[AuthManager] Failed to import VPN config: \(error.localizedDescription)")
                        completion(.failure(error))
                    }

                case .failure(let error):
                    NSLog("[AuthManager] Failed to download VPN config: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
}
