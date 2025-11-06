# Rate Limiting Code Examples

This document provides code examples for using the rate limiting system in ChameleonVPN backend.

## Table of Contents

1. [Basic Usage](#basic-usage)
2. [Endpoint-Specific Rate Limiting](#endpoint-specific-rate-limiting)
3. [Custom Rate Limits](#custom-rate-limits)
4. [Error Handling](#error-handling)
5. [Testing Examples](#testing-examples)
6. [Admin Operations](#admin-operations)

## Basic Usage

### Initialize Rate Limiter

```go
package main

import (
    "log"
    "barqnet-backend/pkg/shared"
)

func main() {
    // Create rate limiter (reads from environment variables)
    rateLimiter, err := shared.NewRateLimiter()
    if err != nil {
        log.Printf("Warning: Rate limiter initialization issue: %v", err)
        // System continues with degraded rate limiting
    }
    defer rateLimiter.Close()

    // Check if rate limiting is enabled
    if rateLimiter.IsEnabled() {
        log.Println("Rate limiting is ENABLED")
    } else {
        log.Println("Rate limiting is DISABLED")
    }
}
```

### Check Rate Limit

```go
// Check if a request is allowed
allowed, remaining, resetTime, err := rateLimiter.Allow(
    shared.RateLimitOTP,  // Rate limit type
    "+1234567890",         // Key (phone number)
)

if err != nil {
    log.Printf("Rate limit check error: %v", err)
    // Handle error - typically allow request in production
}

if !allowed {
    // Rate limit exceeded
    log.Printf("Rate limit exceeded. Reset at: %s", resetTime.Format(time.RFC3339))
    return
}

// Request allowed - proceed
log.Printf("Request allowed. Remaining: %d, Reset: %s", remaining, resetTime.Format(time.RFC3339))
```

## Endpoint-Specific Rate Limiting

### OTP Endpoint Example

```go
func HandleSendOTP(w http.ResponseWriter, r *http.Request, rateLimiter *shared.RateLimiter) {
    var req struct {
        PhoneNumber string `json:"phone_number"`
    }

    json.NewDecoder(r.Body).Decode(&req)

    // Apply rate limit
    if rateLimiter != nil && rateLimiter.IsEnabled() {
        allowed, remaining, resetTime, err := rateLimiter.Allow(
            shared.RateLimitOTP,
            req.PhoneNumber,
        )

        if err != nil {
            log.Printf("Rate limit error: %v", err)
            // Continue processing (graceful degradation)
        } else if !allowed {
            // Set rate limit headers
            w.Header().Set("X-RateLimit-Limit", "5")
            w.Header().Set("X-RateLimit-Remaining", "0")
            w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))
            w.Header().Set("Retry-After", fmt.Sprintf("%d", int(time.Until(resetTime).Seconds())))

            // Return 429 error
            w.WriteHeader(http.StatusTooManyRequests)
            json.NewEncoder(w).Encode(map[string]interface{}{
                "success": false,
                "message": fmt.Sprintf("Too many OTP requests. Try again in %d seconds.",
                    int(time.Until(resetTime).Seconds())),
            })
            return
        }

        // Set success headers
        w.Header().Set("X-RateLimit-Limit", "5")
        w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
        w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))
    }

    // Process OTP request
    // ... your OTP logic here ...
}
```

### Login Endpoint Example

```go
func HandleLogin(w http.ResponseWriter, r *http.Request, rateLimiter *shared.RateLimiter) {
    var req struct {
        PhoneNumber string `json:"phone_number"`
        Password    string `json:"password"`
    }

    json.NewDecoder(r.Body).Decode(&req)

    // Apply rate limit per phone number
    if rateLimiter != nil && rateLimiter.IsEnabled() {
        allowed, remaining, resetTime, err := rateLimiter.Allow(
            shared.RateLimitLogin,
            req.PhoneNumber,
        )

        if !allowed {
            w.Header().Set("X-RateLimit-Limit", "10")
            w.Header().Set("X-RateLimit-Remaining", "0")
            w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))
            w.Header().Set("Retry-After", fmt.Sprintf("%d", int(time.Until(resetTime).Seconds())))

            w.WriteHeader(http.StatusTooManyRequests)
            json.NewEncoder(w).Encode(map[string]interface{}{
                "success": false,
                "message": "Too many login attempts. Please try again later.",
            })
            return
        }

        w.Header().Set("X-RateLimit-Limit", "10")
        w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
        w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))
    }

    // Process login
    // ... your login logic here ...
}
```

### Registration Endpoint Example

```go
func HandleRegister(w http.ResponseWriter, r *http.Request, rateLimiter *shared.RateLimiter) {
    // Extract IP address
    ip := r.RemoteAddr
    if idx := strings.LastIndex(ip, ":"); idx != -1 {
        ip = ip[:idx]
    }

    var req struct {
        PhoneNumber string `json:"phone_number"`
        Password    string `json:"password"`
        OTP         string `json:"otp"`
    }

    json.NewDecoder(r.Body).Decode(&req)

    // Apply rate limit per IP address
    if rateLimiter != nil && rateLimiter.IsEnabled() {
        allowed, remaining, resetTime, err := rateLimiter.Allow(
            shared.RateLimitRegister,
            ip,  // Use IP as key
        )

        if !allowed {
            w.Header().Set("X-RateLimit-Limit", "3")
            w.Header().Set("X-RateLimit-Remaining", "0")
            w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))

            w.WriteHeader(http.StatusTooManyRequests)
            json.NewEncoder(w).Encode(map[string]interface{}{
                "success": false,
                "message": "Too many registration attempts from this IP.",
            })
            return
        }

        w.Header().Set("X-RateLimit-Limit", "3")
        w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
    }

    // Process registration
    // ... your registration logic here ...
}
```

## Middleware Example

### Global API Rate Limiting Middleware

```go
func RateLimitMiddleware(rateLimiter *shared.RateLimiter) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // Skip rate limiting for health checks
            if r.URL.Path == "/health" {
                next.ServeHTTP(w, r)
                return
            }

            // Extract IP address
            ip := extractIP(r)

            // Check rate limit
            if rateLimiter != nil && rateLimiter.IsEnabled() {
                allowed, remaining, resetTime, err := rateLimiter.Allow(
                    shared.RateLimitAPI,
                    ip,
                )

                if err != nil {
                    log.Printf("Rate limit error: %v", err)
                    // Continue with request (graceful degradation)
                } else {
                    // Set rate limit headers
                    w.Header().Set("X-RateLimit-Limit", "100")
                    w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
                    w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))

                    if !allowed {
                        w.Header().Set("Retry-After", fmt.Sprintf("%d", int(time.Until(resetTime).Seconds())))
                        w.WriteHeader(http.StatusTooManyRequests)
                        json.NewEncoder(w).Encode(map[string]interface{}{
                            "success": false,
                            "message": "Rate limit exceeded. Please try again later.",
                        })
                        return
                    }
                }
            }

            // Continue to next handler
            next.ServeHTTP(w, r)
        })
    }
}

// Helper function to extract IP
func extractIP(r *http.Request) string {
    // Check X-Forwarded-For (proxy/load balancer)
    if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
        ips := strings.Split(xff, ",")
        if len(ips) > 0 {
            return strings.TrimSpace(ips[0])
        }
    }

    // Check X-Real-IP (nginx)
    if xri := r.Header.Get("X-Real-IP"); xri != "" {
        return xri
    }

    // Fall back to RemoteAddr
    ip := r.RemoteAddr
    if idx := strings.LastIndex(ip, ":"); idx != -1 {
        ip = ip[:idx]
    }
    return strings.Trim(ip, "[]")
}

// Usage
func main() {
    rateLimiter, _ := shared.NewRateLimiter()
    defer rateLimiter.Close()

    mux := http.NewServeMux()
    mux.HandleFunc("/api/users", handleUsers)

    // Apply middleware
    handler := RateLimitMiddleware(rateLimiter)(mux)

    http.ListenAndServe(":8080", handler)
}
```

## Custom Rate Limits

### Override Default Limits via Environment

```bash
# In .env file or environment
export RATE_LIMIT_OTP_MAX=10           # Increase OTP limit
export RATE_LIMIT_OTP_WINDOW_MINUTES=30 # Decrease window to 30 min
export RATE_LIMIT_LOGIN_MAX=20          # Increase login limit
export RATE_LIMIT_API_MAX=200           # Increase API limit
```

### Check Current Configuration

```go
// Get current status without incrementing counter
count, remaining, resetTime, err := rateLimiter.GetStatus(
    shared.RateLimitOTP,
    "+1234567890",
)

if err != nil {
    log.Printf("Error: %v", err)
} else {
    log.Printf("Current: %d/%d, Reset: %s", count, count+remaining, resetTime)
}
```

## Error Handling

### Graceful Degradation Example

```go
func checkRateLimitWithFallback(rateLimiter *shared.RateLimiter, limitType shared.RateLimitType, key string) bool {
    // If rate limiter is nil or disabled, allow request
    if rateLimiter == nil || !rateLimiter.IsEnabled() {
        return true
    }

    // Check rate limit
    allowed, _, _, err := rateLimiter.Allow(limitType, key)

    if err != nil {
        // Log error but allow request (graceful degradation)
        log.Printf("Rate limit check error for %s: %v (allowing request)", key, err)
        return true
    }

    return allowed
}

// Usage
if !checkRateLimitWithFallback(rateLimiter, shared.RateLimitOTP, phoneNumber) {
    // Rate limit exceeded
    return http.StatusTooManyRequests
}
```

### Retry Logic Example

```go
func sendOTPWithRetry(rateLimiter *shared.RateLimiter, phoneNumber string) error {
    allowed, _, resetTime, err := rateLimiter.Allow(shared.RateLimitOTP, phoneNumber)

    if err != nil {
        return fmt.Errorf("rate limit check failed: %w", err)
    }

    if !allowed {
        waitDuration := time.Until(resetTime)
        return fmt.Errorf("rate limit exceeded, please wait %v", waitDuration)
    }

    // Send OTP
    return sendOTP(phoneNumber)
}
```

## Testing Examples

### Unit Test Example

```go
func TestRateLimiting(t *testing.T) {
    // Set up test environment
    os.Setenv("REDIS_HOST", "localhost")
    os.Setenv("REDIS_PORT", "6379")
    os.Setenv("RATE_LIMIT_ENABLED", "true")

    rateLimiter, err := shared.NewRateLimiter()
    if err != nil {
        t.Skip("Redis not available, skipping test")
    }
    defer rateLimiter.Close()

    testPhone := "+1234567890"

    // Reset before test
    rateLimiter.Reset(shared.RateLimitOTP, testPhone)

    // Test: First 5 requests should succeed
    for i := 0; i < 5; i++ {
        allowed, remaining, _, err := rateLimiter.Allow(shared.RateLimitOTP, testPhone)
        assert.NoError(t, err)
        assert.True(t, allowed, "Request %d should be allowed", i+1)
        assert.Equal(t, 4-i, remaining, "Remaining count mismatch")
    }

    // Test: 6th request should fail
    allowed, remaining, _, err := rateLimiter.Allow(shared.RateLimitOTP, testPhone)
    assert.NoError(t, err)
    assert.False(t, allowed, "6th request should be blocked")
    assert.Equal(t, 0, remaining)

    // Cleanup
    rateLimiter.Reset(shared.RateLimitOTP, testPhone)
}
```

### Integration Test Example

```go
func TestAPIRateLimiting(t *testing.T) {
    // Start test server
    server := httptest.NewServer(handler)
    defer server.Close()

    // Make requests up to limit
    for i := 0; i < 100; i++ {
        resp, err := http.Get(server.URL + "/api/test")
        assert.NoError(t, err)
        assert.Equal(t, http.StatusOK, resp.StatusCode)
        resp.Body.Close()
    }

    // 101st request should be rate limited
    resp, err := http.Get(server.URL + "/api/test")
    assert.NoError(t, err)
    assert.Equal(t, http.StatusTooManyRequests, resp.StatusCode)

    // Check headers
    assert.Equal(t, "0", resp.Header.Get("X-RateLimit-Remaining"))
    assert.NotEmpty(t, resp.Header.Get("Retry-After"))
    resp.Body.Close()
}
```

## Admin Operations

### Reset Rate Limit (Admin Function)

```go
func handleResetRateLimit(w http.ResponseWriter, r *http.Request) {
    // Verify admin authentication first
    if !isAdmin(r) {
        http.Error(w, "Unauthorized", http.StatusUnauthorized)
        return
    }

    var req struct {
        LimitType string `json:"limit_type"`
        Key       string `json:"key"`
    }

    json.NewDecoder(r.Body).Decode(&req)

    // Map string to rate limit type
    var limitType shared.RateLimitType
    switch req.LimitType {
    case "otp":
        limitType = shared.RateLimitOTP
    case "login":
        limitType = shared.RateLimitLogin
    case "register":
        limitType = shared.RateLimitRegister
    case "api":
        limitType = shared.RateLimitAPI
    default:
        http.Error(w, "Invalid limit type", http.StatusBadRequest)
        return
    }

    // Reset the limit
    err := rateLimiter.Reset(limitType, req.Key)
    if err != nil {
        http.Error(w, "Failed to reset limit", http.StatusInternalServerError)
        return
    }

    log.Printf("[ADMIN] Rate limit reset: %s for %s", req.LimitType, req.Key)

    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": true,
        "message": "Rate limit reset successfully",
    })
}
```

### Get Rate Limit Status (Admin Function)

```go
func handleGetRateLimitStatus(w http.ResponseWriter, r *http.Request) {
    if !isAdmin(r) {
        http.Error(w, "Unauthorized", http.StatusUnauthorized)
        return
    }

    limitType := shared.RateLimitOTP
    key := r.URL.Query().Get("key")

    count, remaining, resetTime, err := rateLimiter.GetStatus(limitType, key)
    if err != nil {
        http.Error(w, "Failed to get status", http.StatusInternalServerError)
        return
    }

    json.NewEncoder(w).Encode(map[string]interface{}{
        "key":       key,
        "count":     count,
        "remaining": remaining,
        "reset_at":  resetTime.Unix(),
        "reset_in":  int(time.Until(resetTime).Seconds()),
    })
}
```

## Complete Handler Example

### Full Handler with All Best Practices

```go
func HandleSendOTP(
    w http.ResponseWriter,
    r *http.Request,
    rateLimiter *shared.RateLimiter,
    auditLogger AuditLogger,
) {
    // 1. Parse request
    var req struct {
        PhoneNumber string `json:"phone_number"`
    }

    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        sendErrorResponse(w, "Invalid request", http.StatusBadRequest)
        return
    }

    // 2. Validate input
    if err := validatePhoneNumber(req.PhoneNumber); err != nil {
        sendErrorResponse(w, "Invalid phone number", http.StatusBadRequest)
        return
    }

    // 3. Apply rate limiting
    if rateLimiter != nil && rateLimiter.IsEnabled() {
        allowed, remaining, resetTime, err := rateLimiter.Allow(
            shared.RateLimitOTP,
            req.PhoneNumber,
        )

        // Set rate limit headers
        w.Header().Set("X-RateLimit-Limit", "5")
        w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
        w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))

        if err != nil {
            log.Printf("[RATE-LIMIT] Error checking limit: %v", err)
            // Continue processing (graceful degradation)
        } else if !allowed {
            // Rate limit exceeded
            w.Header().Set("Retry-After", fmt.Sprintf("%d", int(time.Until(resetTime).Seconds())))

            // Log to audit
            auditLogger.Log("OTP_RATE_LIMIT_EXCEEDED", req.PhoneNumber,
                fmt.Sprintf("Rate limit exceeded, reset at %s", resetTime))

            sendErrorResponse(w,
                fmt.Sprintf("Too many OTP requests. Please try again in %d seconds.",
                    int(time.Until(resetTime).Seconds())),
                http.StatusTooManyRequests)
            return
        }
    }

    // 4. Process OTP request
    otp, err := sendOTP(req.PhoneNumber)
    if err != nil {
        log.Printf("[OTP] Failed to send OTP: %v", err)
        sendErrorResponse(w, "Failed to send OTP", http.StatusInternalServerError)
        return
    }

    // 5. Log success
    auditLogger.Log("OTP_SENT", req.PhoneNumber, "OTP sent successfully")

    // 6. Send response
    sendJSONResponse(w, map[string]interface{}{
        "success": true,
        "message": "OTP sent successfully",
        "data": map[string]interface{}{
            "phone_number": req.PhoneNumber,
            "expires_in":   300, // 5 minutes
        },
    }, http.StatusOK)
}

// Helper functions
func sendErrorResponse(w http.ResponseWriter, message string, status int) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(map[string]interface{}{
        "success": false,
        "message": message,
    })
}

func sendJSONResponse(w http.ResponseWriter, data interface{}, status int) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(data)
}
```

## Summary

These examples demonstrate:

1. **Basic Usage**: Initialize and use the rate limiter
2. **Endpoint-Specific**: Apply different limits to different endpoints
3. **Middleware**: Global rate limiting for all APIs
4. **Error Handling**: Graceful degradation and error recovery
5. **Testing**: Unit and integration test examples
6. **Admin Operations**: Reset and monitor rate limits
7. **Best Practices**: Complete handler with all features

For more details, see:
- `RATE_LIMITING.md` - Full documentation
- `RATE_LIMITING_QUICKSTART.md` - Quick start guide
- `pkg/shared/rate_limit.go` - Implementation
- `pkg/shared/rate_limit_test.go` - Test examples
