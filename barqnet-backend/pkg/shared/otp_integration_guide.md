# OTP Service Integration Guide

## Overview

The OTP service provides a clean, interface-based design for One-Time Password functionality in BarqNet. The current implementation is a local/mock version for development and testing.

## Files Created

- **`pkg/shared/otp.go`**: Core OTP service interface and LocalOTPService implementation
- **`pkg/shared/otp_test.go`**: Comprehensive unit tests with 17 test cases
- **`pkg/shared/otp_integration_guide.md`**: This integration guide

## Quick Start

### Basic Usage

```go
package main

import (
    "log"
    "barqnet-backend/pkg/shared"
)

func main() {
    // Initialize the OTP service
    otpService := shared.NewLocalOTPService()

    phoneNumber := "+1234567890"

    // Send OTP
    err := otpService.Send(phoneNumber)
    if err != nil {
        log.Printf("Failed to send OTP: %v", err)
        return
    }

    // In development mode, check console for the OTP code
    // User receives code via SMS in production

    // Verify OTP
    userCode := "123456" // User input
    if otpService.Verify(phoneNumber, userCode) {
        log.Println("OTP verified successfully!")
    } else {
        log.Println("Invalid or expired OTP")
    }
}
```

### Custom Configuration

```go
// Create service with custom settings
otpService := shared.NewLocalOTPService()

// Customize expiry time (default: 10 minutes)
otpService.OTPExpiry = 5 * time.Minute

// Customize rate limit (default: 5 per hour)
otpService.RateLimitMax = 10
otpService.RateLimitWindow = 1 * time.Hour

// Customize max verification attempts (default: 3)
otpService.MaxVerifyAttempts = 5
```

### Monitoring

```go
// Get service statistics
stats := otpService.GetStats()
log.Printf("Active OTPs: %v", stats["active_otps"])
log.Printf("Rate Limited Numbers: %v", stats["rate_limited"])
log.Printf("Expiry (minutes): %v", stats["expiry_minutes"])
```

## Integration with Real SMS Service

When you're ready to integrate your local OTP solution or SMS gateway, follow these steps:

### Step 1: Create Your Custom Implementation

```go
package shared

import "your-sms-provider/sdk"

type ProductionOTPService struct {
    smsClient *sdk.Client
    apiKey    string
    // ... other fields from LocalOTPService for rate limiting, etc.
}

func NewProductionOTPService(apiKey string) *ProductionOTPService {
    return &ProductionOTPService{
        smsClient: sdk.NewClient(apiKey),
        apiKey:    apiKey,
        // Initialize rate limiting maps, etc.
    }
}

// Implement the OTPService interface
func (s *ProductionOTPService) Send(phoneNumber string) error {
    // Check rate limiting (reuse logic from LocalOTPService)

    // Generate OTP
    code := s.GenerateOTP()

    // Send via your SMS provider
    err := s.smsClient.SendSMS(phoneNumber,
        fmt.Sprintf("Your BarqNet code is: %s", code))
    if err != nil {
        return fmt.Errorf("failed to send SMS: %w", err)
    }

    // Store OTP for verification
    // ... storage logic

    return nil
}

func (s *ProductionOTPService) Verify(phoneNumber, code string) bool {
    // Reuse verification logic from LocalOTPService
}

func (s *ProductionOTPService) GenerateOTP() string {
    // Reuse generation logic from LocalOTPService
}

func (s *ProductionOTPService) Cleanup() {
    // Reuse cleanup logic from LocalOTPService
}
```

### Step 2: Update Initialization

Replace the service initialization in your application:

```go
// Development
var otpService shared.OTPService = shared.NewLocalOTPService()

// Production
var otpService shared.OTPService = shared.NewProductionOTPService(apiKey)
```

### Step 3: Environment-Based Selection

```go
func initOTPService() shared.OTPService {
    if os.Getenv("ENVIRONMENT") == "production" {
        apiKey := os.Getenv("SMS_API_KEY")
        return shared.NewProductionOTPService(apiKey)
    }
    return shared.NewLocalOTPService()
}
```

## Common SMS Provider Examples

### Twilio

```go
import "github.com/twilio/twilio-go"

func (s *ProductionOTPService) Send(phoneNumber string) error {
    code := s.GenerateOTP()

    params := &api.CreateMessageParams{}
    params.SetTo(phoneNumber)
    params.SetFrom(s.twilioNumber)
    params.SetBody(fmt.Sprintf("Your BarqNet code: %s", code))

    _, err := s.twilioClient.Api.CreateMessage(params)
    return err
}
```

### AWS SNS

```go
import "github.com/aws/aws-sdk-go/service/sns"

func (s *ProductionOTPService) Send(phoneNumber string) error {
    code := s.GenerateOTP()

    message := fmt.Sprintf("Your BarqNet code: %s", code)
    _, err := s.snsClient.Publish(&sns.PublishInput{
        Message:     &message,
        PhoneNumber: &phoneNumber,
    })
    return err
}
```

### MessageBird

```go
import "github.com/messagebird/go-rest-api"

func (s *ProductionOTPService) Send(phoneNumber string) error {
    code := s.GenerateOTP()

    msg, err := s.mbClient.NewMessage(
        s.originator,
        []string{phoneNumber},
        fmt.Sprintf("Your BarqNet code: %s", code),
        nil,
    )
    return err
}
```

## Testing

### Run All Tests

```bash
cd /Users/hassanalsahli/Desktop/ChameleonVpn/barqnet-backend
go test -v ./pkg/shared -run TestOTP
```

### Run Specific Tests

```bash
# Test OTP generation
go test -v ./pkg/shared -run TestGenerateOTP

# Test rate limiting
go test -v ./pkg/shared -run TestRateLimiting

# Test expiry logic
go test -v ./pkg/shared -run TestOTPExpiry
```

### Test Coverage

```bash
go test -cover ./pkg/shared
```

## Features

### Security Features

1. **Rate Limiting**: Prevents spam by limiting OTP requests (default: 5 per hour)
2. **Expiry**: OTPs automatically expire (default: 10 minutes)
3. **Attempt Limiting**: Max verification attempts to prevent brute force (default: 3)
4. **One-Time Use**: OTPs are deleted after successful verification
5. **Cryptographic Random**: Uses `crypto/rand` for secure OTP generation

### Development Features

1. **Console Logging**: OTPs logged to console in development mode
2. **Statistics**: Monitor service health with `GetStats()`
3. **Automatic Cleanup**: Background goroutine removes expired entries
4. **Thread Safe**: Mutex-protected for concurrent access

### Production Ready

1. **Interface-Based**: Easy to swap implementations
2. **Configurable**: All timeouts and limits are adjustable
3. **Memory Efficient**: Automatic cleanup prevents memory leaks
4. **Testable**: Comprehensive test suite with 17 test cases

## API Reference

### OTPService Interface

```go
type OTPService interface {
    Send(phoneNumber string) error
    Verify(phoneNumber, code string) bool
    GenerateOTP() string
    Cleanup()
}
```

### LocalOTPService Methods

- **`NewLocalOTPService() *LocalOTPService`**: Create new service instance
- **`Send(phoneNumber string) error`**: Generate and send OTP
- **`Verify(phoneNumber, code string) bool`**: Verify OTP code
- **`GenerateOTP() string`**: Generate 6-digit OTP
- **`Cleanup()`**: Remove expired entries
- **`GetStats() map[string]interface{}`**: Get service statistics

## Configuration Options

| Field | Default | Description |
|-------|---------|-------------|
| `OTPExpiry` | 10 minutes | How long OTP remains valid |
| `RateLimitWindow` | 1 hour | Rate limit reset window |
| `RateLimitMax` | 5 | Max OTP requests per window |
| `MaxVerifyAttempts` | 3 | Max verification attempts per OTP |

## Migration Path

### Phase 1: Development (Current)
- Use `LocalOTPService`
- OTPs logged to console
- Test all authentication flows

### Phase 2: Integration
- Obtain SMS provider credentials
- Implement `ProductionOTPService`
- Test with real phone numbers
- Keep `LocalOTPService` for testing

### Phase 3: Production
- Environment-based service selection
- Monitor rate limits and delivery
- Set up alerting for failures

## Example: HTTP Handler Integration

```go
func (h *Handler) SendOTPHandler(w http.ResponseWriter, r *http.Request) {
    var req struct {
        PhoneNumber string `json:"phone_number"`
    }

    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "Invalid request", http.StatusBadRequest)
        return
    }

    // Send OTP
    if err := h.otpService.Send(req.PhoneNumber); err != nil {
        if strings.Contains(err.Error(), "rate limit") {
            http.Error(w, err.Error(), http.StatusTooManyRequests)
            return
        }
        http.Error(w, "Failed to send OTP", http.StatusInternalServerError)
        return
    }

    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "message": "OTP sent successfully",
    })
}

func (h *Handler) VerifyOTPHandler(w http.ResponseWriter, r *http.Request) {
    var req struct {
        PhoneNumber string `json:"phone_number"`
        Code        string `json:"code"`
    }

    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "Invalid request", http.StatusBadRequest)
        return
    }

    // Verify OTP
    if !h.otpService.Verify(req.PhoneNumber, req.Code) {
        http.Error(w, "Invalid or expired OTP", http.StatusUnauthorized)
        return
    }

    // OTP verified - proceed with authentication
    // Create session, generate token, etc.

    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "message": "OTP verified successfully",
    })
}
```

## Support

For questions or issues:
1. Check test cases in `otp_test.go` for usage examples
2. Review inline documentation in `otp.go`
3. Consult your SMS provider's documentation
4. Test with `LocalOTPService` first before production deployment
