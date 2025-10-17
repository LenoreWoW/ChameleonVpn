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

            // In production, send SMS via Twilio/similar
            print("[AUTH] OTP for \(phoneNumber): \(otp)")

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

    func createAccount(phoneNumber: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.async {
            var users = self.getUsersMap()

            if users[phoneNumber] != nil {
                completion(.failure(NSError(domain: "AuthManager", code: 409, userInfo: [NSLocalizedDescriptionKey: "Account already exists"])))
                return
            }

            // In production, hash password with bcrypt
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
