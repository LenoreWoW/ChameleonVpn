package shared

import (
	"testing"
	"time"
)

// TestNewLocalOTPService verifies service initialization
func TestNewLocalOTPService(t *testing.T) {
	service := NewLocalOTPService()

	if service == nil {
		t.Fatal("NewLocalOTPService returned nil")
	}

	if service.OTPExpiry != 10*time.Minute {
		t.Errorf("Expected OTPExpiry to be 10 minutes, got %v", service.OTPExpiry)
	}

	if service.RateLimitMax != 5 {
		t.Errorf("Expected RateLimitMax to be 5, got %d", service.RateLimitMax)
	}

	if service.MaxVerifyAttempts != 3 {
		t.Errorf("Expected MaxVerifyAttempts to be 3, got %d", service.MaxVerifyAttempts)
	}

	if service.otpStore == nil {
		t.Error("otpStore not initialized")
	}

	if service.rateLimitStore == nil {
		t.Error("rateLimitStore not initialized")
	}
}

// TestGenerateOTP verifies OTP generation
func TestGenerateOTP(t *testing.T) {
	service := NewLocalOTPService()

	// Test multiple generations
	codes := make(map[string]bool)
	for i := 0; i < 100; i++ {
		code := service.GenerateOTP()

		// Verify length
		if len(code) != 6 {
			t.Errorf("Expected OTP length 6, got %d for code %s", len(code), code)
		}

		// Verify it's numeric
		for _, char := range code {
			if char < '0' || char > '9' {
				t.Errorf("OTP contains non-numeric character: %s", code)
			}
		}

		codes[code] = true
	}

	// Verify some randomness (should have multiple unique codes)
	if len(codes) < 50 {
		t.Errorf("Expected at least 50 unique codes from 100 generations, got %d", len(codes))
	}
}

// TestSendOTP verifies OTP sending
func TestSendOTP(t *testing.T) {
	service := NewLocalOTPService()
	phoneNumber := "+1234567890"

	err := service.Send(phoneNumber)
	if err != nil {
		t.Fatalf("Failed to send OTP: %v", err)
	}

	// Verify OTP was stored
	service.mu.RLock()
	entry, exists := service.otpStore[phoneNumber]
	service.mu.RUnlock()

	if !exists {
		t.Fatal("OTP not stored after Send")
	}

	if entry.Code == "" {
		t.Error("OTP code is empty")
	}

	if len(entry.Code) != 6 {
		t.Errorf("Expected OTP length 6, got %d", len(entry.Code))
	}

	if time.Since(entry.CreatedAt) > time.Second {
		t.Error("OTP timestamp not recent")
	}

	if entry.Attempts != 0 {
		t.Errorf("Expected 0 attempts, got %d", entry.Attempts)
	}
}

// TestVerifyOTP verifies OTP verification logic
func TestVerifyOTP(t *testing.T) {
	service := NewLocalOTPService()
	phoneNumber := "+1234567890"

	// Send OTP
	err := service.Send(phoneNumber)
	if err != nil {
		t.Fatalf("Failed to send OTP: %v", err)
	}

	// Get the generated code
	service.mu.RLock()
	code := service.otpStore[phoneNumber].Code
	service.mu.RUnlock()

	// Test valid verification
	if !service.Verify(phoneNumber, code) {
		t.Error("Failed to verify correct OTP")
	}

	// Verify OTP was removed after successful verification
	service.mu.RLock()
	_, exists := service.otpStore[phoneNumber]
	service.mu.RUnlock()

	if exists {
		t.Error("OTP still exists after successful verification")
	}
}

// TestVerifyInvalidOTP verifies rejection of invalid codes
func TestVerifyInvalidOTP(t *testing.T) {
	service := NewLocalOTPService()
	phoneNumber := "+1234567890"

	// Send OTP
	err := service.Send(phoneNumber)
	if err != nil {
		t.Fatalf("Failed to send OTP: %v", err)
	}

	// Test invalid code
	if service.Verify(phoneNumber, "000000") {
		t.Error("Verification succeeded with invalid code")
	}

	// Verify OTP still exists (not removed on failed attempt)
	service.mu.RLock()
	_, exists := service.otpStore[phoneNumber]
	service.mu.RUnlock()

	if !exists {
		t.Error("OTP was removed after failed verification")
	}
}

// TestVerifyNonExistentOTP verifies behavior with non-existent phone number
func TestVerifyNonExistentOTP(t *testing.T) {
	service := NewLocalOTPService()

	if service.Verify("+9999999999", "123456") {
		t.Error("Verification succeeded for non-existent phone number")
	}
}

// TestOTPExpiry verifies OTP expiration logic
func TestOTPExpiry(t *testing.T) {
	service := NewLocalOTPService()
	service.OTPExpiry = 100 * time.Millisecond // Short expiry for testing
	phoneNumber := "+1234567890"

	// Send OTP
	err := service.Send(phoneNumber)
	if err != nil {
		t.Fatalf("Failed to send OTP: %v", err)
	}

	// Get the code before it expires
	service.mu.RLock()
	code := service.otpStore[phoneNumber].Code
	service.mu.RUnlock()

	// Wait for expiry
	time.Sleep(150 * time.Millisecond)

	// Try to verify expired OTP
	if service.Verify(phoneNumber, code) {
		t.Error("Verification succeeded with expired OTP")
	}

	// Verify expired OTP was removed
	service.mu.RLock()
	_, exists := service.otpStore[phoneNumber]
	service.mu.RUnlock()

	if exists {
		t.Error("Expired OTP was not removed")
	}
}

// TestRateLimiting verifies rate limiting functionality
func TestRateLimiting(t *testing.T) {
	service := NewLocalOTPService()
	service.RateLimitMax = 3 // Set low limit for testing
	phoneNumber := "+1234567890"

	// Send OTPs up to the limit
	for i := 0; i < 3; i++ {
		err := service.Send(phoneNumber)
		if err != nil {
			t.Fatalf("Send %d failed: %v", i+1, err)
		}
	}

	// Next send should fail due to rate limit
	err := service.Send(phoneNumber)
	if err == nil {
		t.Error("Expected rate limit error, got nil")
	}

	if err.Error() != "rate limit exceeded: maximum 3 OTP requests per hour" {
		t.Errorf("Unexpected error message: %v", err)
	}
}

// TestRateLimitReset verifies rate limit window reset
func TestRateLimitReset(t *testing.T) {
	service := NewLocalOTPService()
	service.RateLimitMax = 2
	service.RateLimitWindow = 200 * time.Millisecond // Short window for testing
	phoneNumber := "+1234567890"

	// Exhaust rate limit
	for i := 0; i < 2; i++ {
		err := service.Send(phoneNumber)
		if err != nil {
			t.Fatalf("Send %d failed: %v", i+1, err)
		}
	}

	// Verify rate limit is hit
	err := service.Send(phoneNumber)
	if err == nil {
		t.Error("Expected rate limit error")
	}

	// Wait for rate limit window to expire
	time.Sleep(250 * time.Millisecond)

	// Should succeed after window reset
	err = service.Send(phoneNumber)
	if err != nil {
		t.Errorf("Send failed after rate limit reset: %v", err)
	}
}

// TestMaxVerifyAttempts verifies brute force protection
func TestMaxVerifyAttempts(t *testing.T) {
	service := NewLocalOTPService()
	service.MaxVerifyAttempts = 3
	phoneNumber := "+1234567890"

	// Send OTP
	err := service.Send(phoneNumber)
	if err != nil {
		t.Fatalf("Failed to send OTP: %v", err)
	}

	// Make 3 failed attempts
	for i := 0; i < 3; i++ {
		if service.Verify(phoneNumber, "000000") {
			t.Error("Verification should have failed")
		}
	}

	// Get the actual code
	service.mu.RLock()
	entry, exists := service.otpStore[phoneNumber]
	service.mu.RUnlock()

	// Fourth attempt should fail even with correct code
	var code string
	if exists {
		code = entry.Code
	} else {
		// OTP was already removed after 3 attempts
		code = "999999" // Use dummy code
	}

	if service.Verify(phoneNumber, code) {
		t.Error("Verification succeeded after max attempts exceeded")
	}

	// Verify OTP was removed
	service.mu.RLock()
	_, exists = service.otpStore[phoneNumber]
	service.mu.RUnlock()

	if exists {
		t.Error("OTP not removed after max attempts")
	}
}

// TestCleanup verifies cleanup functionality
func TestCleanup(t *testing.T) {
	service := NewLocalOTPService()
	service.OTPExpiry = 100 * time.Millisecond
	service.RateLimitWindow = 100 * time.Millisecond

	// Create some OTPs
	service.Send("+1111111111")
	service.Send("+2222222222")
	service.Send("+3333333333")

	// Verify they exist
	if len(service.otpStore) != 3 {
		t.Errorf("Expected 3 OTPs, got %d", len(service.otpStore))
	}

	// Wait for expiry
	time.Sleep(150 * time.Millisecond)

	// Run cleanup
	service.Cleanup()

	// Verify cleanup removed expired entries
	service.mu.RLock()
	otpCount := len(service.otpStore)
	rateLimitCount := len(service.rateLimitStore)
	service.mu.RUnlock()

	if otpCount != 0 {
		t.Errorf("Expected 0 OTPs after cleanup, got %d", otpCount)
	}

	if rateLimitCount != 0 {
		t.Errorf("Expected 0 rate limits after cleanup, got %d", rateLimitCount)
	}
}

// TestGetStats verifies statistics retrieval
func TestGetStats(t *testing.T) {
	service := NewLocalOTPService()

	// Send a few OTPs
	service.Send("+1111111111")
	service.Send("+2222222222")

	stats := service.GetStats()

	if stats["active_otps"] != 2 {
		t.Errorf("Expected 2 active OTPs, got %v", stats["active_otps"])
	}

	if stats["rate_limited"] != 2 {
		t.Errorf("Expected 2 rate limited entries, got %v", stats["rate_limited"])
	}

	if stats["expiry_minutes"] != 10.0 {
		t.Errorf("Expected 10 minute expiry, got %v", stats["expiry_minutes"])
	}

	if stats["rate_limit_max"] != 5 {
		t.Errorf("Expected rate limit max of 5, got %v", stats["rate_limit_max"])
	}

	if stats["max_attempts"] != 3 {
		t.Errorf("Expected max attempts of 3, got %v", stats["max_attempts"])
	}
}

// TestConcurrentAccess verifies thread safety
func TestConcurrentAccess(t *testing.T) {
	service := NewLocalOTPService()
	phoneNumbers := []string{"+1111111111", "+2222222222", "+3333333333"}

	// Concurrent sends
	done := make(chan bool)
	for _, phone := range phoneNumbers {
		go func(p string) {
			for i := 0; i < 10; i++ {
				service.Send(p)
			}
			done <- true
		}(phone)
	}

	// Wait for all goroutines
	for i := 0; i < len(phoneNumbers); i++ {
		<-done
	}

	// Service should still be functional
	stats := service.GetStats()
	if stats == nil {
		t.Error("GetStats returned nil after concurrent access")
	}
}

// TestMultiplePhoneNumbers verifies isolation between different phone numbers
func TestMultiplePhoneNumbers(t *testing.T) {
	service := NewLocalOTPService()

	phone1 := "+1111111111"
	phone2 := "+2222222222"

	// Send OTPs to both numbers
	service.Send(phone1)
	service.Send(phone2)

	// Get codes
	service.mu.RLock()
	code1 := service.otpStore[phone1].Code
	code2 := service.otpStore[phone2].Code
	service.mu.RUnlock()

	// Verify isolation - wrong code for wrong number
	if service.Verify(phone1, code2) {
		t.Error("Verified phone1 with phone2's code")
	}

	if service.Verify(phone2, code1) {
		t.Error("Verified phone2 with phone1's code")
	}

	// Verify correct codes work
	if !service.Verify(phone1, code1) {
		t.Error("Failed to verify phone1 with correct code")
	}

	if !service.Verify(phone2, code2) {
		t.Error("Failed to verify phone2 with correct code")
	}
}

// TestOTPReuse verifies OTP cannot be reused
func TestOTPReuse(t *testing.T) {
	service := NewLocalOTPService()
	phoneNumber := "+1234567890"

	// Send OTP
	service.Send(phoneNumber)

	// Get code
	service.mu.RLock()
	code := service.otpStore[phoneNumber].Code
	service.mu.RUnlock()

	// First verification should succeed
	if !service.Verify(phoneNumber, code) {
		t.Error("First verification failed")
	}

	// Second verification with same code should fail
	if service.Verify(phoneNumber, code) {
		t.Error("OTP was reused successfully")
	}
}
