# Authentication API Documentation

## Overview

This document describes the authentication API endpoints for the BarqNet backend. The authentication system uses JWT (JSON Web Tokens) for secure, stateless authentication with phone numbers as the primary user identifier.

## Architecture

### Components

1. **JWT Utilities** (`pkg/shared/jwt.go`)
   - Token generation
   - Token validation
   - Token refresh
   - Claims management

2. **Authentication Handler** (`apps/management/api/auth.go`)
   - User registration
   - User login
   - Token refresh
   - User logout
   - OTP verification (with mock service)

3. **Database Schema** (`pkg/shared/database.go`)
   - `auth_users` table for user credentials
   - Indexed for optimal query performance

## Security Features

- **Password Hashing**: bcrypt with 12 rounds
- **JWT Tokens**: 24-hour expiration
- **Phone Validation**: International format support
- **Password Requirements**:
  - Minimum 8 characters
  - At least one uppercase letter
  - At least one lowercase letter
  - At least one digit
- **Audit Logging**: All authentication events logged
- **Account Locking**: Support for failed login attempts tracking

## API Endpoints

### 1. Send OTP

**Endpoint:** `POST /auth/send-otp`

**Description:** Sends an OTP to the specified phone number for registration verification.

**Request Body:**
```json
{
  "phone_number": "+1234567890"
}
```

**Response:**
```json
{
  "success": true,
  "message": "OTP sent successfully",
  "data": {
    "phone_number": "+1234567890",
    "otp": "123456",
    "expires_in": 300
  }
}
```

**Note:** In production, the OTP should NOT be returned in the response. It's included here for development/testing purposes only.

---

### 2. Register User

**Endpoint:** `POST /auth/register`

**Description:** Registers a new user with phone number, password, and OTP verification.

**Request Body:**
```json
{
  "phone_number": "+1234567890",
  "password": "SecurePass123",
  "otp": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "message": "User registered successfully",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "data": {
    "user_id": 1,
    "phone_number": "+1234567890",
    "created_at": 1698765432
  }
}
```

**Status Codes:**
- `201 Created`: User registered successfully
- `400 Bad Request`: Invalid input or OTP
- `401 Unauthorized`: Invalid OTP
- `409 Conflict`: User already exists
- `500 Internal Server Error`: Server error

---

### 3. Login

**Endpoint:** `POST /auth/login`

**Description:** Authenticates a user and returns a JWT token.

**Request Body:**
```json
{
  "phone_number": "+1234567890",
  "password": "SecurePass123"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "data": {
    "user_id": 1,
    "phone_number": "+1234567890",
    "login_time": 1698765432
  }
}
```

**Status Codes:**
- `200 OK`: Login successful
- `400 Bad Request`: Missing credentials
- `401 Unauthorized`: Invalid credentials
- `403 Forbidden`: Account disabled
- `500 Internal Server Error`: Server error

---

### 4. Refresh Token

**Endpoint:** `POST /auth/refresh`

**Description:** Refreshes an existing JWT token. Only works for tokens close to expiration (within 1 hour).

**Request Body:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:**
```json
{
  "success": true,
  "message": "Token refreshed successfully",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "data": {
    "refreshed_at": 1698765432
  }
}
```

**Status Codes:**
- `200 OK`: Token refreshed
- `400 Bad Request`: Missing token
- `401 Unauthorized`: Invalid or not eligible for refresh
- `500 Internal Server Error`: Server error

---

### 5. Logout

**Endpoint:** `POST /auth/logout`

**Description:** Logs out a user. Since JWT is stateless, this primarily serves as an audit log entry. Clients should delete the token.

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response:**
```json
{
  "success": true,
  "message": "Logout successful. Please delete the token on client side.",
  "data": {
    "logout_time": 1698765432
  }
}
```

**Status Codes:**
- `200 OK`: Logout successful
- `401 Unauthorized`: Missing or invalid token
- `500 Internal Server Error`: Server error

---

## Protected Endpoints

To protect any endpoint with JWT authentication, use the `JWTAuthMiddleware`:

```go
// Example usage
authHandler := NewAuthHandler(db, otpService)

// Protect a route
http.HandleFunc("/protected", authHandler.JWTAuthMiddleware(protectedHandler))

// Access user data in protected handler
func protectedHandler(w http.ResponseWriter, r *http.Request) {
    phoneNumber := r.Context().Value("phone_number").(string)
    userID := r.Context().Value("user_id").(int)
    // ... handler logic
}
```

## Database Schema

### auth_users Table

```sql
CREATE TABLE auth_users (
    id SERIAL PRIMARY KEY,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    active BOOLEAN DEFAULT true,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP,
    email VARCHAR(255),
    full_name VARCHAR(255)
);

-- Indexes
CREATE INDEX idx_auth_users_phone_number ON auth_users(phone_number);
CREATE INDEX idx_auth_users_active ON auth_users(active);
CREATE INDEX idx_auth_users_created_at ON auth_users(created_at);
```

## Environment Variables

### Required

- `JWT_SECRET`: Secret key for JWT signing (MUST be set in production)
  - Example: `export JWT_SECRET="your-super-secret-key-minimum-32-chars"`

### Optional

- Database configuration (via DatabaseConfig struct)

## OTP Service

The current implementation includes a `MockOTPService` for development. In production, replace this with a real SMS gateway integration:

```go
type ProductionOTPService struct {
    smsClient *SMSClient
}

func (p *ProductionOTPService) SendOTP(phoneNumber string) (string, error) {
    otp := generateSecureOTP()
    err := p.smsClient.SendSMS(phoneNumber, "Your OTP: " + otp)
    // Store OTP in Redis with TTL
    return "", err // Don't return OTP in production
}
```

## Integration Example

```go
package main

import (
    "database/sql"
    "log"
    "net/http"

    "barqnet-backend/apps/management/api"
    "barqnet-backend/pkg/shared"
)

func main() {
    // Initialize database
    dbConfig := &shared.DatabaseConfig{
        Host:     "localhost",
        Port:     5432,
        User:     "barqnet",
        Password: "password",
        DBName:   "barqnet",
        SSLMode:  "disable",
    }

    db, err := shared.NewDatabase(dbConfig)
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()

    // Initialize OTP service (use mock for development)
    otpService := api.NewMockOTPService()

    // Initialize auth handler
    authHandler := api.NewAuthHandler(db.GetConnection(), otpService)

    // Register routes
    http.HandleFunc("/auth/send-otp", authHandler.HandleSendOTP)
    http.HandleFunc("/auth/register", authHandler.HandleRegister)
    http.HandleFunc("/auth/login", authHandler.HandleLogin)
    http.HandleFunc("/auth/refresh", authHandler.HandleRefresh)
    http.HandleFunc("/auth/logout", authHandler.HandleLogout)

    // Start server
    log.Println("Authentication API running on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

## Testing

### Test User Registration

```bash
# Send OTP
curl -X POST http://localhost:8080/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+1234567890"}'

# Register user (use OTP from previous response)
curl -X POST http://localhost:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+1234567890",
    "password": "SecurePass123",
    "otp": "123456"
  }'
```

### Test Login

```bash
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+1234567890",
    "password": "SecurePass123"
  }'
```

### Test Protected Endpoint

```bash
curl -X GET http://localhost:8080/protected \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE"
```

## Security Best Practices

1. **Always use HTTPS in production**
2. **Set strong JWT_SECRET** (minimum 32 characters, random)
3. **Implement rate limiting** on auth endpoints
4. **Use Redis** for OTP storage with TTL
5. **Implement account locking** after failed login attempts
6. **Monitor audit logs** for suspicious activity
7. **Rotate JWT secrets** periodically
8. **Use secure cookie** storage on client side
9. **Implement CSRF protection** for web clients
10. **Add 2FA** for sensitive operations

## Error Handling

All endpoints return consistent error responses:

```json
{
  "success": false,
  "message": "Error description here"
}
```

## Audit Logging

All authentication events are logged to the `audit_log` table:

- `USER_REGISTERED`: New user registration
- `LOGIN_SUCCESS`: Successful login
- `LOGIN_FAILED`: Failed login attempt
- `TOKEN_REFRESHED`: Token refresh
- `USER_LOGOUT`: User logout
- `OTP_SENT`: OTP sent to phone number

## Future Enhancements

1. Implement real SMS gateway for OTP
2. Add email verification
3. Implement social login (OAuth)
4. Add biometric authentication support
5. Implement device fingerprinting
6. Add IP-based rate limiting
7. Implement refresh token rotation
8. Add support for multiple sessions
9. Implement password reset flow
10. Add account recovery mechanisms

## Support

For issues or questions, contact the development team.

---

**Last Updated:** October 26, 2025
**Version:** 1.0.0
