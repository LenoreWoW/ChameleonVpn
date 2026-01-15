//
//  APIClient.swift
//  BarqNet
//
//  Professional API client for backend integration with certificate pinning and JWT token management
//

import Foundation
import Security

// MARK: - API Models

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
}

struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

struct User: Codable {
    let id: Int
    let email: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
    }
}

struct AuthData: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: User?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

struct OTPSessionData: Codable {
    let sessionId: String?
    let expiresAt: String?
    let email: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case expiresAt = "expires_at"
        case email = "email"
        case expiresIn = "expires_in"
    }
}

struct OTPVerificationData: Codable {
    let verificationToken: String?
    let email: String?
    let verified: Bool?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case verificationToken = "verification_token"
        case email = "email"
        case verified = "verified"
        case expiresIn = "expires_in"
    }
}

struct APIVPNConfigResponse: Codable {
    let username: String
    let serverID: String
    let serverHost: String
    let serverPort: Int
    let `protocol`: String
    let ovpnContent: String
    let recommendedServers: [String]

    enum CodingKeys: String, CodingKey {
        case username
        case serverID = "server_id"
        case serverHost = "server_host"
        case serverPort = "server_port"
        case `protocol`
        case ovpnContent = "ovpn_content"
        case recommendedServers = "recommended_servers"
    }
}

// MARK: - API Errors

enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(Int, String)
    case decodingError(Error)
    case unauthorized
    case certificatePinningFailed
    case invalidRequest(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized - please login again"
        case .certificatePinningFailed:
            return "Certificate validation failed"
        case .invalidRequest(let message):
            return message
        }
    }
}

// MARK: - API Client

class APIClient: NSObject, URLSessionDelegate {

    // MARK: - Properties

    static let shared = APIClient()

    private var baseURL: String
    private var session: URLSession!
    private let certificatePinning: CertificatePinning
    private let keychainService = "com.barqnet.ios"

    // Token storage keys
    private let tokenStorageKey = "auth_tokens"
    private let tokenIssuedAtKey = "token_issued_at"

    // Token refresh timer
    private var tokenRefreshTimer: Timer?

    // MARK: - Initialization

    private override init() {
        // Read API base URL from Info.plist (configured via xcconfig files)
        // This allows environment-specific configuration without code changes
        if let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
            self.baseURL = baseURL
        } else {
            // Fallback for safety (if Info.plist not configured)
            #if DEBUG
            self.baseURL = "http://127.0.0.1:8080"
            #else
            self.baseURL = "https://api.barqnet.com"
            #endif
            NSLog("[APIClient] ⚠️ WARNING: API_BASE_URL not found in Info.plist, using fallback")
        }

        // Read other configuration values from Info.plist
        let envName = Bundle.main.object(forInfoDictionaryKey: "ENVIRONMENT_NAME") as? String ?? "Unknown"
        let debugLoggingEnabled = Bundle.main.object(forInfoDictionaryKey: "ENABLE_DEBUG_LOGGING") as? String == "YES"
        let certPinningEnabled = Bundle.main.object(forInfoDictionaryKey: "ENABLE_CERTIFICATE_PINNING") as? String == "YES"

        // Log configuration (helpful for debugging)
        NSLog("[APIClient] ═══════════════════════════════════════")
        NSLog("[APIClient] Environment: \(envName)")
        NSLog("[APIClient] Base URL: \(baseURL)")
        NSLog("[APIClient] Debug Logging: \(debugLoggingEnabled ? "Enabled" : "Disabled")")
        NSLog("[APIClient] Certificate Pinning: \(certPinningEnabled ? "Enabled" : "Disabled")")
        NSLog("[APIClient] ═══════════════════════════════════════")

        // Initialize certificate pinning
        self.certificatePinning = CertificatePinning()

        super.init()

        // Configure URLSession with environment-specific settings
        let configuration = URLSessionConfiguration.default

        // Read timeout from Info.plist or use default
        if let timeoutString = Bundle.main.object(forInfoDictionaryKey: "API_TIMEOUT_INTERVAL") as? String,
           let timeout = TimeInterval(timeoutString) {
            configuration.timeoutIntervalForRequest = timeout
            NSLog("[APIClient] Request timeout: \(timeout)s")
        } else {
            configuration.timeoutIntervalForRequest = 30
        }
        configuration.timeoutIntervalForResource = 60

        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

        // Initialize certificate pins only if enabled (typically only in production)
        if certPinningEnabled {
            initializeCertificatePins()
            NSLog("[APIClient] Certificate pinning initialized")
        } else {
            NSLog("[APIClient] Certificate pinning disabled for this environment")
        }

        // Start token refresh timer if authenticated
        scheduleTokenRefresh()

        NSLog("[APIClient] Initialization complete")
    }

    // MARK: - Configuration

    func configure(baseURL: String) {
        self.baseURL = baseURL
        NSLog("[APIClient] Base URL updated to: \(baseURL)")
    }

    private func initializeCertificatePins() {
        guard let url = URL(string: baseURL),
              let hostname = url.host,
              url.scheme == "https" else {
            NSLog("[APIClient] Certificate pinning skipped (not using HTTPS)")
            return
        }

        // ═══════════════════════════════════════════════════════════════════
        // CERTIFICATE PINNING CONFIGURATION
        // ═══════════════════════════════════════════════════════════════════
        //
        // IMPORTANT: Before going to production, you MUST configure certificate pins.
        //
        // To generate pins for your server, run this command:
        //   openssl s_client -connect api.barqnet.com:443 < /dev/null 2>/dev/null | \
        //     openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | \
        //     openssl dgst -sha256 -binary | base64
        //
        // Always include:
        //   1. Primary certificate pin (your current server certificate)
        //   2. Backup certificate pin (for certificate rotation)
        //
        // ═══════════════════════════════════════════════════════════════════

        var pins: [String] = []

        // Production pins for api.barqnet.com
        // ⚠️ REPLACE THESE WITH YOUR ACTUAL CERTIFICATE PINS BEFORE PRODUCTION
        #if !DEBUG
        pins = [
            // Primary certificate - Replace with your server's actual pin
            // "sha256/your-primary-certificate-pin-here=",
            // Backup certificate - For rotation (e.g., Let's Encrypt intermediate)
            // "sha256/your-backup-certificate-pin-here="
        ]

        // PRODUCTION SECURITY CHECK: Fail if no pins configured
        if pins.isEmpty {
            NSLog("[APIClient] ⚠️ CRITICAL: No certificate pins configured for production!")
            NSLog("[APIClient] ⚠️ This app is vulnerable to MITM attacks!")
            NSLog("[APIClient] ⚠️ Generate pins using the openssl command above")
            // In production, you MUST crash to prevent insecure deployment:
            fatalError("Certificate pins must be configured for production")
        }
        #else
        // Development: Skip pinning for localhost
        NSLog("[APIClient] Certificate pinning disabled in DEBUG mode")
        #endif

        if !pins.isEmpty {
            certificatePinning.addPins(hostname: hostname, pins: pins)
            NSLog("[APIClient] Certificate pinning enabled for \(hostname) with \(pins.count) pins")
        }
    }

    // MARK: - URLSessionDelegate (Certificate Pinning)

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let hostname = URL(string: baseURL)?.host else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let (disposition, credential) = certificatePinning.validateCertificate(
            challenge: challenge,
            hostname: hostname
        )

        completionHandler(disposition, credential)
    }

    // MARK: - Token Management

    private func getStoredTokens() -> (tokens: AuthTokens, issuedAt: Date)? {
        guard let tokensData = KeychainHelper.load(service: keychainService, account: tokenStorageKey),
              let tokens = try? JSONDecoder().decode(AuthTokens.self, from: tokensData),
              let issuedAtData = KeychainHelper.load(service: keychainService, account: tokenIssuedAtKey),
              let issuedAtString = String(data: issuedAtData, encoding: .utf8),
              let issuedAtTimestamp = Double(issuedAtString) else {
            return nil
        }

        let issuedAt = Date(timeIntervalSince1970: issuedAtTimestamp)
        return (tokens, issuedAt)
    }

    private func saveTokens(_ tokens: AuthTokens, issuedAt: Date = Date()) {
        if let tokensData = try? JSONEncoder().encode(tokens) {
            _ = KeychainHelper.save(tokensData, service: keychainService, account: tokenStorageKey)
        }

        let issuedAtTimestamp = String(issuedAt.timeIntervalSince1970)
        if let issuedAtData = issuedAtTimestamp.data(using: .utf8) {
            _ = KeychainHelper.save(issuedAtData, service: keychainService, account: tokenIssuedAtKey)
        }

        // Schedule token refresh
        scheduleTokenRefresh()
    }

    private func clearTokens() {
        _ = KeychainHelper.delete(service: keychainService, account: tokenStorageKey)
        _ = KeychainHelper.delete(service: keychainService, account: tokenIssuedAtKey)
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
    }

    private func getAccessToken() -> String? {
        return getStoredTokens()?.tokens.accessToken
    }

    // MARK: - Token Refresh

    private func scheduleTokenRefresh() {
        tokenRefreshTimer?.invalidate()

        guard let (tokens, issuedAt) = getStoredTokens() else {
            return
        }

        // Calculate when to refresh (5 minutes before expiry)
        let expiryDate = issuedAt.addingTimeInterval(TimeInterval(tokens.expiresIn))
        let refreshDate = expiryDate.addingTimeInterval(-5 * 60) // 5 minutes before

        let timeUntilRefresh = refreshDate.timeIntervalSinceNow

        if timeUntilRefresh > 0 {
            NSLog("[APIClient] Token refresh scheduled in \(Int(timeUntilRefresh / 60)) minutes")
            tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: timeUntilRefresh, repeats: false) { [weak self] _ in
                self?.refreshAccessToken { _ in }
            }
        } else {
            // Token expired or about to expire, refresh immediately
            NSLog("[APIClient] Token expired, refreshing immediately")
            refreshAccessToken { _ in }
        }
    }

    private func refreshAccessToken(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let (tokens, _) = getStoredTokens() else {
            completion(.failure(APIError.unauthorized))
            return
        }

        NSLog("[APIClient] Refreshing access token...")

        let request = ["token": tokens.refreshToken]

        post("/v1/auth/refresh", body: request) { [weak self] (result: Result<APIResponse<AuthData>, Error>) in
            guard let self = self else { return }

            switch result {
            case .success(let response):
                if response.success, let authData = response.data {
                    let newTokens = AuthTokens(
                        accessToken: authData.accessToken,
                        refreshToken: authData.refreshToken,
                        expiresIn: authData.expiresIn
                    )
                    self.saveTokens(newTokens)
                    NSLog("[APIClient] Token refreshed successfully")
                    completion(.success(()))
                } else {
                    NSLog("[APIClient] Token refresh failed: \(response.error ?? "Unknown error")")
                    self.clearTokens()
                    completion(.failure(APIError.unauthorized))
                }
            case .failure(let error):
                NSLog("[APIClient] Token refresh error: \(error.localizedDescription)")
                self.clearTokens()
                completion(.failure(error))
            }
        }
    }

    // MARK: - HTTP Request Methods

    private func request<T: Codable>(
        _ endpoint: String,
        method: String,
        body: Encodable? = nil,
        requiresAuth: Bool = false,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let url = URL(string: baseURL + endpoint) else {
            completion(.failure(APIError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authorization header if required
        if requiresAuth {
            if let accessToken = getAccessToken() {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            } else {
                completion(.failure(APIError.unauthorized))
                return
            }
        }

        // Encode request body
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                completion(.failure(APIError.decodingError(error)))
                return
            }
        }

        // Make request
        let task = session.dataTask(with: request) { data, response, error in
            // Handle network errors
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(APIError.networkError(error)))
                }
                return
            }

            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(APIError.invalidResponse))
                }
                return
            }

            // Handle HTTP errors
            if httpResponse.statusCode == 401 {
                DispatchQueue.main.async {
                    completion(.failure(APIError.unauthorized))
                }
                return
            }

            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                DispatchQueue.main.async {
                    completion(.failure(APIError.httpError(httpResponse.statusCode, errorMessage)))
                }
                return
            }

            // Decode response
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(APIError.invalidResponse))
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(decoded))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(APIError.decodingError(error)))
                }
            }
        }

        task.resume()
    }

    private func get<T: Codable>(
        _ endpoint: String,
        requiresAuth: Bool = false,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        request(endpoint, method: "GET", requiresAuth: requiresAuth, completion: completion)
    }

    private func post<T: Codable>(
        _ endpoint: String,
        body: Encodable,
        requiresAuth: Bool = false,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        request(endpoint, method: "POST", body: body, requiresAuth: requiresAuth, completion: completion)
    }

    // MARK: - Authentication API Methods

    /// Send OTP to email
    func sendOTP(email: String, completion: @escaping (Result<String?, Error>) -> Void) {
        struct SendOTPRequest: Encodable {
            let email: String
        }

        let request = SendOTPRequest(email: email)

        post("/v1/auth/send-otp", body: request) { (result: Result<APIResponse<OTPSessionData>, Error>) in
            switch result {
            case .success(let response):
                if response.success {
                    NSLog("[APIClient] OTP sent successfully")
                    completion(.success(response.data?.sessionId))
                } else {
                    let error = NSError(
                        domain: "APIClient",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: response.error ?? response.message ?? "Failed to send OTP"]
                    )
                    completion(.failure(error))
                }
            case .failure(let error):
                NSLog("[APIClient] Send OTP failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    /// Verify OTP code
    func verifyOTP(email: String, code: String, sessionId: String?, completion: @escaping (Result<String?, Error>) -> Void) {
        // Use proper struct for encoding to ensure session_id is correctly sent
        struct VerifyOTPRequest: Encodable {
            let email: String
            let otp: String
            let session_id: String?

            enum CodingKeys: String, CodingKey {
                case email
                case otp
                case session_id = "session_id"
            }
        }

        let request = VerifyOTPRequest(
            email: email,
            otp: code,
            session_id: sessionId
        )

        post("/v1/auth/verify-otp", body: request) { (result: Result<APIResponse<OTPVerificationData>, Error>) in
            switch result {
            case .success(let response):
                if response.success {
                    NSLog("[APIClient] OTP verified successfully")
                    completion(.success(response.data?.verificationToken))
                } else {
                    let error = NSError(
                        domain: "APIClient",
                        code: 401,
                        userInfo: [NSLocalizedDescriptionKey: response.error ?? response.message ?? "Invalid OTP code"]
                    )
                    completion(.failure(error))
                }
            case .failure(let error):
                NSLog("[APIClient] Verify OTP failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    /// Register new account
    func register(email: String, password: String, otpCode: String, completion: @escaping (Result<(tokens: AuthTokens, user: User?), Error>) -> Void) {
        struct RegisterRequest: Encodable {
            let email: String
            let password: String
            let otp: String
        }

        let request = RegisterRequest(
            email: email,
            password: password,
            otp: otpCode
        )

        post("/v1/auth/register", body: request) { [weak self] (result: Result<APIResponse<AuthData>, Error>) in
            guard let self = self else { return }

            switch result {
            case .success(let response):
                if response.success, let authData = response.data {
                    let tokens = AuthTokens(
                        accessToken: authData.accessToken,
                        refreshToken: authData.refreshToken,
                        expiresIn: authData.expiresIn
                    )

                    // Save tokens to keychain
                    self.saveTokens(tokens)

                    NSLog("[APIClient] Registration successful")
                    completion(.success((tokens: tokens, user: authData.user)))
                } else {
                    let error = NSError(
                        domain: "APIClient",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: response.error ?? response.message ?? "Registration failed"]
                    )
                    completion(.failure(error))
                }
            case .failure(let error):
                NSLog("[APIClient] Registration failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    /// Login with email and password
    func login(email: String, password: String, completion: @escaping (Result<(tokens: AuthTokens, user: User?), Error>) -> Void) {
        struct LoginRequest: Encodable {
            let email: String
            let password: String
        }

        let request = LoginRequest(
            email: email,
            password: password
        )

        post("/v1/auth/login", body: request) { [weak self] (result: Result<APIResponse<AuthData>, Error>) in
            guard let self = self else { return }

            switch result {
            case .success(let response):
                if response.success, let authData = response.data {
                    let tokens = AuthTokens(
                        accessToken: authData.accessToken,
                        refreshToken: authData.refreshToken,
                        expiresIn: authData.expiresIn
                    )

                    // Save tokens to keychain
                    self.saveTokens(tokens)

                    NSLog("[APIClient] Login successful")
                    completion(.success((tokens: tokens, user: authData.user)))
                } else {
                    let error = NSError(
                        domain: "APIClient",
                        code: 401,
                        userInfo: [NSLocalizedDescriptionKey: response.error ?? response.message ?? "Login failed"]
                    )
                    completion(.failure(error))
                }
            case .failure(let error):
                NSLog("[APIClient] Login failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    /// Logout and clear tokens
    func logout(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let accessToken = getAccessToken() else {
            clearTokens()
            completion(.success(()))
            return
        }

        // Call logout endpoint
        let request = ["token": accessToken]

        post("/v1/auth/logout", body: request, requiresAuth: true) { [weak self] (result: Result<APIResponse<[String: String]>, Error>) in
            guard let self = self else { return }

            // Always clear local tokens regardless of API response
            self.clearTokens()

            switch result {
            case .success:
                NSLog("[APIClient] Logout successful")
                completion(.success(()))
            case .failure(let error):
                NSLog("[APIClient] Logout API call failed (tokens cleared anyway): \(error.localizedDescription)")
                completion(.success(())) // Still succeed since tokens are cleared
            }
        }
    }

    /// Fetch VPN configuration for the authenticated user
    func fetchVPNConfig(completion: @escaping (Result<APIVPNConfigResponse, Error>) -> Void) {
        NSLog("[APIClient] Fetching VPN configuration")

        get("/v1/vpn/config", requiresAuth: true) { (result: Result<APIResponse<APIVPNConfigResponse>, Error>) in
            switch result {
            case .success(let response):
                if response.success, let config = response.data {
                    NSLog("[APIClient] VPN config fetched successfully for server: \(config.serverID)")
                    completion(.success(config))
                } else {
                    let error = NSError(
                        domain: "APIClient",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: response.error ?? response.message ?? "Failed to fetch VPN config"]
                    )
                    completion(.failure(error))
                }
            case .failure(let error):
                NSLog("[APIClient] Failed to fetch VPN config: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Token Access

    func hasValidToken() -> Bool {
        guard let (tokens, issuedAt) = getStoredTokens() else {
            return false
        }

        let expiryDate = issuedAt.addingTimeInterval(TimeInterval(tokens.expiresIn))
        return Date() < expiryDate
    }
}
