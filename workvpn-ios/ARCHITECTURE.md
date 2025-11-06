# iOS Backend Integration Architecture

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS Application                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                      SwiftUI Views                         │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │  │
│  │  │ PhoneNumber  │  │     OTP      │  │   Password   │   │  │
│  │  │     View     │  │ Verification │  │   Creation   │   │  │
│  │  │              │  │     View     │  │     View     │   │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │  │
│  │         │                  │                  │            │  │
│  └─────────┼──────────────────┼──────────────────┼───────────┘  │
│            │                  │                  │               │
│            │                  │                  │               │
│  ┌─────────▼──────────────────▼──────────────────▼───────────┐  │
│  │                     AuthManager                           │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  • sendOTP(phoneNumber)                           │  │  │
│  │  │  • verifyOTP(phoneNumber, code)                   │  │  │
│  │  │  • createAccount(phoneNumber, password)           │  │  │
│  │  │  • login(phoneNumber, password)                   │  │  │
│  │  │  • logout()                                        │  │  │
│  │  │  • OTP Session Management                         │  │  │
│  │  └────────────────────┬───────────────────────────────┘  │  │
│  └───────────────────────┼──────────────────────────────────┘  │
│                          │                                      │
│                          │                                      │
│  ┌───────────────────────▼──────────────────────────────────┐  │
│  │                      APIClient                           │  │
│  │  ┌────────────────────────────────────────────────────┐ │  │
│  │  │  HTTP Methods:                                     │ │  │
│  │  │  • POST /v1/auth/send-otp                         │ │  │
│  │  │  • POST /v1/auth/verify-otp                       │ │  │
│  │  │  • POST /v1/auth/register                         │ │  │
│  │  │  • POST /v1/auth/login                            │ │  │
│  │  │  • POST /v1/auth/refresh                          │ │  │
│  │  │  • POST /v1/auth/logout                           │ │  │
│  │  └────────────────────────────────────────────────────┘ │  │
│  │  ┌────────────────────────────────────────────────────┐ │  │
│  │  │  Security Features:                                │ │  │
│  │  │  • Certificate Pinning (URLSession Delegate)      │ │  │
│  │  │  • JWT Token Management                            │ │  │
│  │  │  • Automatic Token Refresh (Timer)                │ │  │
│  │  │  • HTTPS Enforcement                               │ │  │
│  │  └────────────────────────────────────────────────────┘ │  │
│  └──────────────┬─────────────────────┬────────────────────┘  │
│                 │                     │                        │
│  ┌──────────────▼─────────┐  ┌────────▼───────────────────┐  │
│  │   KeychainHelper       │  │  CertificatePinning        │  │
│  │  • save()              │  │  • validateCertificate()   │  │
│  │  • load()              │  │  • getPublicKeyHash()      │  │
│  │  • delete()            │  │  • SHA-256 validation      │  │
│  │  • update()            │  │                            │  │
│  └────────────────────────┘  └────────────────────────────┘  │
│                                                                │
└─────────────────────────────┬──────────────────────────────────┘
                              │
                              │ HTTPS / Certificate Pinning
                              │
┌─────────────────────────────▼──────────────────────────────────┐
│                      Backend API Server                        │
│                     (Go + PostgreSQL)                          │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                  Authentication Endpoints                │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  POST /v1/auth/send-otp                         │  │  │
│  │  │  POST /v1/auth/verify-otp                       │  │  │
│  │  │  POST /v1/auth/register                         │  │  │
│  │  │  POST /v1/auth/login                            │  │  │
│  │  │  POST /v1/auth/refresh                          │  │  │
│  │  │  POST /v1/auth/logout                           │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                  Security Features                      │  │
│  │  • JWT Token Generation & Validation                   │  │
│  │  • Password Hashing (bcrypt/PBKDF2)                    │  │
│  │  • OTP Generation & Validation                         │  │
│  │  • Rate Limiting                                        │  │
│  │  • SQL Injection Prevention                            │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Registration Flow

```
User → PhoneNumberView → AuthManager.sendOTP()
                              ↓
                         APIClient.sendOTP()
                              ↓
                         POST /v1/auth/send-otp
                              ↓
                         Backend generates OTP
                              ↓
                         Response: { session_id }
                              ↓
                         Store session in memory
                              ↓
User receives OTP via SMS ← Backend sends SMS

User enters OTP → OTPVerificationView → AuthManager.verifyOTP()
                                              ↓
                                         APIClient.verifyOTP()
                                              ↓
                                         POST /v1/auth/verify-otp
                                              ↓
                                         Backend validates OTP
                                              ↓
                                         Response: { verification_token }
                                              ↓
                                         Store verification token
                                              ↓
User creates password → PasswordCreationView → AuthManager.createAccount()
                                                    ↓
                                               APIClient.register()
                                                    ↓
                                               POST /v1/auth/register
                                                    ↓
                                               Backend creates account
                                                    ↓
                                               Response: { access_token, refresh_token, user }
                                                    ↓
                                               Store tokens in Keychain
                                                    ↓
                                               Schedule token refresh
                                                    ↓
                                               Update UI: isAuthenticated = true
```

### 2. Login Flow

```
User → LoginView → AuthManager.login()
                        ↓
                   APIClient.login()
                        ↓
                   POST /v1/auth/login
                        ↓
                   Backend validates credentials
                        ↓
                   Response: { access_token, refresh_token, user }
                        ↓
                   Store tokens in Keychain
                        ↓
                   Schedule token refresh
                        ↓
                   Update UI: isAuthenticated = true
```

### 3. Token Refresh Flow

```
Timer fires (5 min before expiry) → APIClient.refreshAccessToken()
                                           ↓
                                      Load refresh_token from Keychain
                                           ↓
                                      POST /v1/auth/refresh
                                           ↓
                                      Backend validates refresh token
                                           ↓
                                      Response: { access_token, refresh_token }
                                           ↓
                                      Update tokens in Keychain
                                           ↓
                                      Schedule next refresh
```

### 4. Logout Flow

```
User → Settings → AuthManager.logout()
                       ↓
                  APIClient.logout()
                       ↓
                  POST /v1/auth/logout
                       ↓
                  Backend invalidates tokens
                       ↓
                  Clear tokens from Keychain
                       ↓
                  Cancel refresh timer
                       ↓
                  Update UI: isAuthenticated = false
```

## Security Layers

### Layer 1: Transport Security
```
┌─────────────────────────────────────────┐
│         HTTPS with TLS 1.2+             │
│   ┌─────────────────────────────────┐   │
│   │   Certificate Pinning (SHA-256)  │   │
│   │   • Primary Pin: Leaf Cert      │   │
│   │   • Backup Pin: Intermediate CA │   │
│   │   • Challenge Validation        │   │
│   └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Layer 2: Authentication Security
```
┌─────────────────────────────────────────┐
│         JWT Token Authentication        │
│   ┌─────────────────────────────────┐   │
│   │   Bearer Token in Headers       │   │
│   │   • Access Token (short-lived)  │   │
│   │   • Refresh Token (long-lived)  │   │
│   │   • Automatic Refresh           │   │
│   └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Layer 3: Data Security
```
┌─────────────────────────────────────────┐
│          Keychain Encryption            │
│   ┌─────────────────────────────────┐   │
│   │   iOS Secure Enclave            │   │
│   │   • Hardware-backed encryption  │   │
│   │   • When unlocked only          │   │
│   │   • Biometric protection        │   │
│   └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

## Component Responsibilities

### APIClient (603 lines)
**Responsibilities**:
- HTTP request/response handling
- Certificate pinning validation
- JWT token storage and management
- Automatic token refresh scheduling
- Error handling and logging

**Key Methods**:
- `sendOTP()` - Send OTP to phone
- `verifyOTP()` - Verify OTP code
- `register()` - Create new account
- `login()` - Authenticate user
- `refreshAccessToken()` - Refresh tokens
- `logout()` - Clear tokens

### AuthManager (214 lines)
**Responsibilities**:
- Authentication flow orchestration
- OTP session management
- User state management
- UI state updates (isAuthenticated, currentUser)

**Key Methods**:
- `sendOTP()` - Wrapper for APIClient
- `verifyOTP()` - Wrapper with validation
- `createAccount()` - Registration wrapper
- `login()` - Login wrapper
- `logout()` - Cleanup and API call

### KeychainHelper (164 lines)
**Responsibilities**:
- Secure data storage
- Keychain CRUD operations
- Access control management

**Key Methods**:
- `save()` - Store data
- `load()` - Retrieve data
- `delete()` - Remove data
- `update()` - Modify data
- `exists()` - Check existence

### CertificatePinning (185 lines)
**Responsibilities**:
- Certificate validation
- Public key extraction
- SHA-256 hashing
- Pin comparison

**Key Methods**:
- `validateCertificate()` - URLSession challenge
- `getPublicKeyHash()` - Extract and hash key
- `addPins()` - Configure pins
- `clearPins()` - Remove pins

## Storage Strategy

### Keychain Storage
```
Service: com.barqnet.ios

Accounts:
├── auth_tokens          (AuthTokens struct as JSON)
│   ├── access_token
│   ├── refresh_token
│   └── expires_in
├── token_issued_at      (Timestamp string)
└── current_user         (Phone number string)
```

### In-Memory Storage
```
AuthManager.otpSessions: [String: OTPSession]
├── phoneNumber
├── sessionId
├── verificationToken
└── timestamp
```

## Error Handling Strategy

### API Errors
```
APIError enum:
├── invalidURL           → "Invalid API URL"
├── networkError(Error)  → "Network error: [details]"
├── invalidResponse      → "Invalid server response"
├── httpError(Int, Msg)  → "HTTP [code]: [message]"
├── decodingError(Error) → "Failed to decode: [details]"
├── unauthorized         → "Unauthorized - please login again"
├── certificatePinningFailed → "Certificate validation failed"
└── invalidRequest(Msg)  → Custom message
```

### Error Propagation
```
APIClient → Result<T, Error> → AuthManager → Result<Void, Error> → View
```

## Threading Model

### Main Thread
- UI updates (SwiftUI @Published properties)
- AuthManager completion handlers
- State changes

### Background Threads
- URLSession network requests
- Certificate validation
- JSON encoding/decoding
- Token refresh timer

### Thread Safety
```swift
DispatchQueue.main.async {
    // Update UI state
    self.isAuthenticated = true
    self.currentUser = phoneNumber
}
```

## Configuration Management

### Build Configurations

**Debug**:
```swift
#if DEBUG
baseURL = "http://localhost:8080"
certificatePinning = disabled
logging = verbose
#endif
```

**Release**:
```swift
#if RELEASE
baseURL = "https://api.barqnet.com"
certificatePinning = enabled
logging = minimal
#endif
```

### Environment Variables
```swift
// Future enhancement
if let apiURL = ProcessInfo.processInfo.environment["API_BASE_URL"] {
    APIClient.shared.configure(baseURL: apiURL)
}
```

## Performance Considerations

### Token Caching
- Tokens cached in Keychain (no repeated API calls)
- Token validity checked before each request
- Automatic refresh prevents expiry

### Request Optimization
- Single URLSession instance (connection pooling)
- Request timeout: 30 seconds
- Resource timeout: 60 seconds

### Memory Management
- Weak self in closures prevents retain cycles
- Sensitive data cleared after use
- OTP sessions cleaned up after registration

## Testing Strategy

### Unit Tests
- AuthManager methods
- APIClient request building
- Token refresh logic
- Error handling

### Integration Tests
- Complete auth flows
- Token management
- Certificate pinning
- Keychain operations

### Security Tests
- Certificate validation
- Token encryption
- Data clearing
- HTTPS enforcement

## Future Enhancements

### Phase 2
1. Biometric authentication (Face ID/Touch ID)
2. Token caching optimization
3. Offline operation queue
4. Request retry logic

### Phase 3
1. Request signing (HMAC)
2. Analytics integration
3. Deep linking support
4. Multi-account management

### Phase 4
1. Advanced security (hardware security module)
2. Zero-knowledge proofs
3. End-to-end encryption
4. Advanced fraud detection

## Maintenance

### Regular Tasks
- Update certificate pins on certificate rotation
- Review security logs
- Update dependencies
- Performance monitoring

### Monitoring
- Token refresh success rate
- API error rates
- Certificate pinning failures
- Authentication success rate

---

**Architecture Status: Production Ready**

All components implemented with security best practices and production-grade error handling.
