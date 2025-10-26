# Testing Backend Integration - ChameleonVPN Desktop

## Overview

This guide provides instructions for testing the newly integrated backend API with the ChameleonVPN Desktop client.

## Prerequisites

1. **Backend Server Running**
   - Ensure the backend server (go-hello) is running on `http://localhost:8080`
   - Or set `API_BASE_URL` environment variable to your backend URL

2. **Dependencies Installed**
   ```bash
   cd /Users/hassanalsahli/Desktop/ChameleonVpn/workvpn-desktop
   npm install
   ```

## Configuration

### 1. Set API Base URL

**Option A: Environment Variable (Recommended)**
```bash
export API_BASE_URL=http://localhost:8080
npm start
```

**Option B: .env File**
```bash
# Copy example file
cp .env.example .env

# Edit .env and set:
API_BASE_URL=http://localhost:8080
```

**Option C: Default (No Configuration)**
- If not set, defaults to `http://localhost:8080`

## Running the Application

### Development Mode
```bash
npm run build
npm start
```

### Watch Mode (Auto-rebuild)
```bash
# Terminal 1: Watch TypeScript
npm run watch

# Terminal 2: Start Electron
npm start
```

## Testing Scenarios

### Scenario 1: New User Registration Flow

**Steps:**
1. Launch the application
2. Click "Create Account" or similar
3. Enter phone number (e.g., `+1234567890`)
4. Click "Send OTP"
5. **Expected:** Backend sends OTP via SMS (or logs it in dev mode)
6. Enter the 6-digit OTP code
7. Click "Verify"
8. **Expected:** OTP verification succeeds
9. Enter a password (minimum 8 characters)
10. Click "Create Account"
11. **Expected:** Account created, JWT tokens stored, user logged in

**API Calls Made:**
- `POST /v1/auth/otp/send`
- `POST /v1/auth/otp/verify`
- `POST /v1/auth/register`

### Scenario 2: Existing User Login

**Steps:**
1. Launch the application
2. Click "Login" or "Sign In"
3. Enter phone number
4. Enter password
5. Click "Login"
6. **Expected:** User logged in, JWT tokens stored

**API Calls Made:**
- `POST /v1/auth/login`

### Scenario 3: Token Refresh (Automatic)

**Background Process:**
- Tokens are automatically refreshed 5 minutes before expiry
- No user action required

**Manual Testing:**
1. Login to the application
2. Wait for token to approach expiry (or manually trigger)
3. **Expected:** Token refreshes automatically in background

**API Calls Made:**
- `POST /v1/auth/refresh` (automatic)

### Scenario 4: Logout

**Steps:**
1. While logged in, click "Logout"
2. **Expected:** Tokens cleared, user logged out

**API Calls Made:**
- `POST /v1/auth/logout`

### Scenario 5: Backend Unavailable (Graceful Degradation)

**Steps:**
1. Stop the backend server
2. Try to login or register
3. **Expected:** Error message: "Backend server is not available. Please check your connection or try again later."
4. Application should not crash

## Debugging

### Check API Configuration
Open Developer Tools (in app) and run:
```javascript
window.vpn.getApiConfig().then(config => console.log(config));
```

**Expected Output:**
```json
{
  "apiBaseUrl": "http://localhost:8080",
  "isProduction": false
}
```

### View Stored Tokens
Tokens are stored in electron-store:
```bash
# macOS
cat ~/Library/Application\ Support/workvpn-desktop/auth.json

# Windows
type %APPDATA%\workvpn-desktop\auth.json

# Linux
cat ~/.config/workvpn-desktop/auth.json
```

### Enable Verbose Logging
Check the Electron console for logs:
- `[AUTH]` prefix: Authentication-related logs
- `[Main]` prefix: Main process logs
- `[IPC]` prefix: IPC communication logs

### Common Issues

**Issue 1: "Backend server is not available"**
- **Cause:** Backend not running or wrong URL
- **Fix:** 
  - Verify backend is running: `curl http://localhost:8080`
  - Check `API_BASE_URL` environment variable
  - Check `.env` file

**Issue 2: "Invalid OTP code"**
- **Cause:** OTP expired or incorrect
- **Fix:** Request new OTP

**Issue 3: "Phone number not verified"**
- **Cause:** Trying to create account without OTP verification
- **Fix:** Complete OTP verification first

**Issue 4: Build fails with TypeScript errors**
- **Cause:** TypeScript compilation error
- **Fix:** `npm run build` and check errors

## API Endpoints Reference

All endpoints are prefixed with `API_BASE_URL/v1`

### Authentication
- `POST /auth/otp/send` - Send OTP to phone number
- `POST /auth/otp/verify` - Verify OTP code
- `POST /auth/register` - Create new account
- `POST /auth/login` - Login existing user
- `POST /auth/refresh` - Refresh access token
- `POST /auth/logout` - Logout user

### Headers
All authenticated requests include:
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

## Production Deployment

### Environment Variables
```bash
# Production API URL
export API_BASE_URL=https://api.chameleonvpn.com

# Production mode
export NODE_ENV=production

# Build and package
npm run build
npm run make
```

### Security Notes
1. Always use HTTPS in production
2. JWT tokens are stored securely in electron-store
3. Refresh tokens are used to renew access tokens
4. Tokens are cleared on logout
5. Network errors are handled gracefully

## Testing Checklist

- [ ] Registration with phone + OTP works
- [ ] OTP verification works
- [ ] Account creation works
- [ ] Login with phone + password works
- [ ] Tokens are stored correctly
- [ ] Auto token refresh works
- [ ] Logout works and clears tokens
- [ ] Backend unavailable shows proper error
- [ ] Network errors don't crash the app
- [ ] API configuration is correct
- [ ] TypeScript builds without errors
- [ ] Electron app launches successfully

## Support

For issues or questions:
1. Check console logs for errors
2. Verify backend is running and accessible
3. Check API contract matches backend implementation
4. Review BACKEND_INTEGRATION_ANALYSIS.md for known issues
