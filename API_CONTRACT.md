# API Contract: VPN Client ↔ Backend

**Version**: 1.0.0
**Last Updated**: 2025-10-14
**Status**: Draft - For Review

---

## Overview

This document defines the API contract between the VPN clients (Desktop, Android, iOS) and the backend server. Your colleague developing the backend should implement these endpoints.

---

## Base URL

```
Production: https://api.workvpn.com/v1
Staging: https://staging-api.workvpn.com/v1
Development: http://localhost:3000/v1
```

---

## Authentication Flow

### 1. Send OTP
**POST** `/auth/otp/send`

**Request Body**:
```json
{
  "phoneNumber": "+1234567890",
  "countryCode": "US"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "message": "OTP sent successfully",
  "expiresIn": 600,
  "sessionId": "sess_abc123xyz"
}
```

**Response** (429 Too Many Requests):
```json
{
  "success": false,
  "error": "RATE_LIMIT_EXCEEDED",
  "message": "Too many OTP requests. Please wait 60 seconds.",
  "retryAfter": 60
}
```

---

### 2. Verify OTP
**POST** `/auth/otp/verify`

**Request Body**:
```json
{
  "phoneNumber": "+1234567890",
  "otp": "123456",
  "sessionId": "sess_abc123xyz"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "verified": true,
  "verificationToken": "vtoken_xyz789abc"
}
```

**Response** (400 Bad Request):
```json
{
  "success": false,
  "error": "INVALID_OTP",
  "message": "Invalid or expired OTP",
  "attemptsRemaining": 2
}
```

---

### 3. Create Account
**POST** `/auth/register`

**Request Body**:
```json
{
  "phoneNumber": "+1234567890",
  "password": "securePassword123!",
  "verificationToken": "vtoken_xyz789abc"
}
```

**Response** (201 Created):
```json
{
  "success": true,
  "user": {
    "id": "user_123",
    "phoneNumber": "+1234567890",
    "createdAt": "2025-10-14T10:30:00Z"
  },
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "refresh_token_here",
  "expiresIn": 3600
}
```

---

### 4. Login
**POST** `/auth/login`

**Request Body**:
```json
{
  "phoneNumber": "+1234567890",
  "password": "securePassword123!"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "user": {
    "id": "user_123",
    "phoneNumber": "+1234567890"
  },
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "refresh_token_here",
  "expiresIn": 3600
}
```

**Response** (401 Unauthorized):
```json
{
  "success": false,
  "error": "INVALID_CREDENTIALS",
  "message": "Invalid phone number or password"
}
```

---

### 5. Refresh Token
**POST** `/auth/refresh`

**Request Body**:
```json
{
  "refreshToken": "refresh_token_here"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "accessToken": "new_access_token",
  "expiresIn": 3600
}
```

---

### 6. Logout
**POST** `/auth/logout`

**Headers**: `Authorization: Bearer {accessToken}`

**Response** (200 OK):
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

## VPN Configuration

### 7. Get VPN Config
**GET** `/vpn/config`

**Headers**: `Authorization: Bearer {accessToken}`

**Response** (200 OK):
```json
{
  "success": true,
  "config": {
    "ovpnContent": "client\ndev tun\nproto udp\nremote vpn.server.com 1194\n...",
    "serverAddress": "vpn.server.com",
    "port": 1194,
    "protocol": "udp",
    "certificatePinning": [
      "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    ],
    "expiresAt": "2025-10-21T10:30:00Z"
  }
}
```

---

### 8. Upload Custom Config (Optional)
**POST** `/vpn/config/custom`

**Headers**: `Authorization: Bearer {accessToken}`

**Request Body**:
```json
{
  "ovpnContent": "client\ndev tun\n...",
  "name": "My Custom Server"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "message": "Custom config saved",
  "configId": "config_123"
}
```

---

## VPN Connection

### 9. Report Connection Status
**POST** `/vpn/status`

**Headers**: `Authorization: Bearer {accessToken}`

**Request Body**:
```json
{
  "status": "CONNECTED",
  "connectedAt": "2025-10-14T10:35:00Z",
  "localIp": "10.8.0.2",
  "serverIp": "vpn.server.com",
  "platform": "android",
  "appVersion": "1.0.0"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "sessionId": "vpn_session_123"
}
```

---

### 10. Report Traffic Stats (Periodic)
**POST** `/vpn/stats`

**Headers**: `Authorization: Bearer {accessToken}`

**Request Body**:
```json
{
  "sessionId": "vpn_session_123",
  "bytesIn": 1048576,
  "bytesOut": 524288,
  "duration": 120,
  "timestamp": "2025-10-14T10:37:00Z"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "usage": {
    "totalBytesIn": 5242880,
    "totalBytesOut": 2621440,
    "remainingQuota": 10737418240
  }
}
```

---

## User Management

### 11. Get User Profile
**GET** `/user/profile`

**Headers**: `Authorization: Bearer {accessToken}`

**Response** (200 OK):
```json
{
  "success": true,
  "user": {
    "id": "user_123",
    "phoneNumber": "+1234567890",
    "subscription": {
      "plan": "premium",
      "expiresAt": "2026-01-01T00:00:00Z",
      "dataQuota": 10737418240,
      "usedData": 1048576
    },
    "devices": [
      {
        "id": "device_1",
        "name": "iPhone 13",
        "platform": "ios",
        "lastConnected": "2025-10-14T10:35:00Z"
      }
    ],
    "createdAt": "2025-10-01T00:00:00Z"
  }
}
```

---

### 12. Update Profile
**PATCH** `/user/profile`

**Headers**: `Authorization: Bearer {accessToken}`

**Request Body**:
```json
{
  "email": "user@example.com",
  "preferences": {
    "autoConnect": true,
    "killSwitch": true
  }
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "user": {
    // Updated user object
  }
}
```

---

## Error Codes

| Code | Description |
|------|-------------|
| `INVALID_CREDENTIALS` | Wrong username/password |
| `INVALID_OTP` | OTP is wrong or expired |
| `RATE_LIMIT_EXCEEDED` | Too many requests |
| `TOKEN_EXPIRED` | Access token expired |
| `ACCOUNT_EXISTS` | Phone number already registered |
| `INVALID_CONFIG` | VPN config is malformed |
| `SERVER_ERROR` | Internal server error |
| `MAINTENANCE` | Service under maintenance |

---

## Security Requirements

### 1. Transport Security
- All API requests **MUST** use HTTPS (TLS 1.2+)
- Implement certificate pinning on clients
- No sensitive data in URL parameters

### 2. Authentication
- Use JWT for access tokens (short-lived: 1 hour)
- Use secure refresh tokens (long-lived: 30 days)
- Store refresh tokens in secure storage only
- Implement token rotation on refresh

### 3. Rate Limiting
- OTP send: 3 requests per phone number per hour
- Login attempts: 5 failures per phone number per 15 minutes
- API calls: 100 requests per user per minute

### 4. Password Requirements
- Minimum 8 characters
- Must contain: uppercase, lowercase, number
- Hashed with BCrypt (strength 12)
- Never log passwords

### 5. OTP Requirements
- 6-digit numeric code
- Valid for 10 minutes
- Single-use only
- Maximum 3 verification attempts
- Delivered via SMS (Twilio/AWS SNS recommended)

---

## Client Implementation Notes

### Desktop (Electron)
- Store tokens in electron-store (encrypted)
- Location: `workvpn-desktop/src/main/auth/service.ts`

### Android (Kotlin)
- Store tokens in DataStore Preferences (encrypted)
- Location: `workvpn-android/app/src/main/java/com/workvpn/android/auth/AuthManager.kt`

### iOS (Swift)
- Store tokens in Keychain
- Location: `workvpn-ios/WorkVPN/Services/AuthManager.swift`

---

## Testing Endpoints

For development/testing, provide mock endpoints that return success responses without actual OTP delivery:

**POST** `/test/auth/bypass`
```json
{
  "phoneNumber": "+1234567890",
  "testMode": true
}
```

**Response**:
```json
{
  "success": true,
  "testOtp": "123456",
  "accessToken": "test_token"
}
```

---

## Changelog

### Version 1.0.0 (2025-10-14)
- Initial API contract definition
- Authentication flow
- VPN configuration endpoints
- Stats reporting

---

## Questions for Backend Developer

1. **OTP Delivery**: Which SMS provider will you use? (Twilio, AWS SNS, other?)
2. **Token Storage**: Will you use Redis for token blacklisting?
3. **Database**: PostgreSQL, MongoDB, other?
4. **Rate Limiting**: Redis-based or in-memory?
5. **Analytics**: Should clients report analytics events?
6. **Push Notifications**: For disconnection alerts?
7. **Multi-device**: How many devices per account?
8. **Data Quota**: Soft or hard limits?

---

**Status**: Ready for backend implementation

Please review and provide feedback before implementation begins.
