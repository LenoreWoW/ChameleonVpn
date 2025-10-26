# Desktop Backend Integration - Quick Start

## What Changed?

The Desktop client now connects to your backend API for authentication instead of using local storage.

## Quick Setup (3 steps)

### 1. Start Your Backend
```bash
# Make sure your backend is running on port 8080
curl http://localhost:8080
```

### 2. Configure Desktop Client
```bash
cd /Users/hassanalsahli/Desktop/ChameleonVpn/workvpn-desktop

# Set API URL (optional - defaults to localhost:8080)
export API_BASE_URL=http://localhost:8080
```

### 3. Build & Run
```bash
npm run build
npm start
```

## API Endpoints Used

- `POST /v1/auth/otp/send` - Send OTP
- `POST /v1/auth/otp/verify` - Verify OTP  
- `POST /v1/auth/register` - Create account
- `POST /v1/auth/login` - Login
- `POST /v1/auth/refresh` - Refresh token (automatic)
- `POST /v1/auth/logout` - Logout

## Files Modified

1. `src/main/auth/service.ts` - API integration
2. `src/main/index.ts` - API config & error handling
3. `src/preload/index.ts` - API config exposure
4. `.env.example` - Updated documentation

## Testing

```bash
# 1. Registration Flow
Phone → Send OTP → Verify → Create Password → Account Created

# 2. Login Flow  
Phone → Password → Login Success

# 3. Token Refresh
Auto-refreshes 5 minutes before expiry

# 4. Error Handling
If backend is down, shows friendly error message
```

## Environment Variables

```bash
# Development (default)
API_BASE_URL=http://localhost:8080

# Production
API_BASE_URL=https://api.chameleonvpn.com
NODE_ENV=production
```

## Troubleshooting

**"Backend server is not available"**
→ Check if backend is running on port 8080

**"Invalid OTP code"**  
→ Request new OTP (expires in 10 minutes)

**Build fails**
→ Run `npm run build` and check errors

## Documentation

- `DESKTOP_BACKEND_INTEGRATION_SUMMARY.md` - Complete details
- `TESTING_BACKEND_INTEGRATION.md` - Testing guide
- `API_CONTRACT.md` - API specification

## Status

✅ Build: PASSING  
✅ TypeScript: COMPILED  
✅ Ready: YES

**Next:** Test with running backend server!
