package shared

import (
	"testing"
	"time"
)

// TestNewLocalOTPService verifies service initialization
func TestNewLocalOTPService(t *testing.T) {
	// Use local email service for testing (logs to console)
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)

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
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)

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
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)
	email := "test@example.com"

	err := service.Send(email)
	if err != nil {
		t.Fatalf("Failed to send OTP: %v", err)
	}

	// Verify OTP was stored
	service.mu.RLock()
	entry, exists := service.otpStore[email]
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
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)
	email := "test@example.com"

	// Send OTP
	err := service.Send(email)
	if err != nil {
		t.Fatalf("Failed to send OTP: %v", err)
	}

	// Get the generated code
	service.mu.RLock()
	code := service.otpStore[email].Code
	service.mu.RUnlock()

	// Test valid verification
	if !service.Verify(email, code) {
		t.Error("Failed to verify correct OTP")
	}

	// Verify OTP was removed after successful verification
	service.mu.RLock()
	_, exists := service.otpStore[email]
	service.mu.RUnlock()

	if exists {
		t.Error("OTP still exists after successful verification")
	}
}

// TestVerifyInvalidOTP verifies rejection of invalid codes
func TestVerifyInvalidOTP(t *testing.T) {
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)
	email := "test@example.com"

	// Send OTP
	err := service.Send(email)
	if err != nil {
		t.Fatalf("Failed to send OTP: %v", err)
	}

	// Test invalid code
	if service.Verify(email, "000000") {
		t.Error("Verification succeeded with invalid code")
	}

	// Verify OTP still exists (not removed on failed attempt)
	service.mu.RLock()
	_, exists := service.otpStore[email]
	service.mu.RUnlock()

	if !exists {
		t.Error("OTP was removed after failed verification")
	}
}

// TestVerifyNonExistentOTP verifies behavior with non-existent email
func TestVerifyNonExistentOTP(t *testing.T) {
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)

	if service.Verify("nonexistent@example.com", "123456") {
		t.Error("Verification succeeded for non-existent email")
	}
}

// TestOTPExpiry verifies OTP expiration logic
func TestOTPExpiry(t *testing.T) {
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)
	service.OTPExpiry = 100 * time.Millisecond // Short expiry for testing
	email := "test@example.com"

	// Send OTP
	err := service.Send(email)
	if err != nil {
		t.Fatalf("Failed to send OTP: %v", err)
	}

	// Get the code before it expires
	service.mu.RLock()
	code := service.otpStore[email].Code
	service.mu.RUnlock()

	// Wait for expiry
	time.Sleep(150 * time.Millisecond)

	// Try to verify expired OTP
	if service.Verify(email, code) {
		t.Error("Verification succeeded with expired OTP")
	}

	// Verify expired OTP was removed
	service.mu.RLock()
	_, exists := service.otpStore[email]
	service.mu.RUnlock()

	if exists {
		t.Error("Expired OTP was not removed")
	}
}

// TestRateLimiting verifies rate limiting functionality
func TestRateLimiting(t *testing.T) {
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)
	service.RateLimitMax = 3 // Set low limit for testing
	email := "test@example.com"

	// Send OTPs up to the limit
	for i := 0; i < 3; i++ {
		err := service.Send(email)
		if err != nil {
			t.Fatalf("Send %d failed: %v", i+1, err)
		}
	}

	// Next send should fail due to rate limit
	err := service.Send(email)
	if err == nil {
		t.Error("Expected rate limit error, got nil")
	}

	if err.Error() != "rate limit exceeded: maximum 3 OTP requests per hour" {
		t.Errorf("Unexpected error message: %v", err)
	}
}

// TestRateLimitReset verifies rate limit window reset
func TestRateLimitReset(t *testing.T) {
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)
	service.RateLimitMax = 2
	service.RateLimitWindow = 200 * time.Millisecond // Short window for testing
	email := "test@example.com"

	// Exhaust rate limit
	for i := 0; i < 2; i++ {
		err := service.Send(email)
		if err != nil {
			t.Fatalf("Send %d failed: %v", i+1, err)
		}
	}

	// Verify rate limit is hit
	err := service.Send(email)
	if err == nil {
		t.Error("Expected rate limit error")
	}

	// Wait for rate limit window to expire
	time.Sleep(250 * time.Millisecond)

	// Should succeed after window reset
	err = service.Send(email)
	if err != nil {
		t.Errorf("Send failed after rate limit reset: %v", err)
	}
}

// TestMaxVerifyAttempts verifies brute force protection
func TestMaxVerifyAttempts(t *testing.T) {
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)
	service.MaxVerifyAttempts = 3
	email := "test@example.com"

	// Send OTP
	err := service.Send(email)
	if err != nil {
		t.Fatalf("Failed to send OTP: %v", err)
	}

	// Make 3 failed attempts
	for i := 0; i < 3; i++ {
		if service.Verify(email, "000000") {
			t.Error("Verification should have failed")
		}
	}

	// Get the actual code
	service.mu.RLock()
	entry, exists := service.otpStore[email]
	service.mu.RUnlock()

	// Fourth attempt should fail even with correct code
	var code string
	if exists {
		code = entry.Code
	} else {
		// OTP was already removed after 3 attempts
		code = "999999" // Use dummy code
	}

	if service.Verify(email, code) {
		t.Error("Verification succeeded after max attempts exceeded")
	}

	// Verify OTP was removed
	service.mu.RLock()
	_, exists = service.otpStore[email]
	service.mu.RUnlock()

	if exists {
		t.Error("OTP not removed after max attempts")
	}
}

// TestCleanup verifies cleanup functionality
func TestCleanup(t *testing.T) {
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)
	service.OTPExpiry = 100 * time.Millisecond
	service.RateLimitWindow = 100 * time.Millisecond

	// Create some OTPs
	service.Send("test1@example.com")
	service.Send("test2@example.com")
	service.Send("test3@example.com")

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
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)

	// Send a few OTPs
	service.Send("test1@example.com")
	service.Send("test2@example.com")

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
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)
	emails := []string{"test1@example.com", "test2@example.com", "test3@example.com"}

	// Concurrent sends
	done := make(chan bool)
	for _, email := range emails {
		go func(e string) {
			for i := 0; i < 10; i++ {
				service.Send(e)
			}
			done <- true
		}(email)
	}

	// Wait for all goroutines
	for i := 0; i < len(emails); i++ {
		<-done
	}

	// Service should still be functional
	stats := service.GetStats()
	if stats == nil {
		t.Error("GetStats returned nil after concurrent access")
	}
}

// TestMultipleEmails verifies isolation between different email addresses
func TestMultipleEmails(t *testing.T) {
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)

	email1 := "test1@example.com"
	email2 := "test2@example.com"

	// Send OTPs to both emails
	service.Send(email1)
	service.Send(email2)

	// Get codes
	service.mu.RLock()
	code1 := service.otpStore[email1].Code
	code2 := service.otpStore[email2].Code
	service.mu.RUnlock()

	// Verify isolation - wrong code for wrong email
	if service.Verify(email1, code2) {
		t.Error("Verified email1 with email2's code")
	}

	if service.Verify(email2, code1) {
		t.Error("Verified email2 with email1's code")
	}

	// Verify correct codes work
	if !service.Verify(email1, code1) {
		t.Error("Failed to verify email1 with correct code")
	}

	if !service.Verify(email2, code2) {
		t.Error("Failed to verify email2 with correct code")
	}
}

// TestOTPReuse verifies OTP cannot be reused
func TestOTPReuse(t *testing.T) {
	emailService := NewLocalEmailService()
	service := NewLocalOTPService(emailService)
	email := "test@example.com"

	// Send OTP
	service.Send(email)

	// Get code
	service.mu.RLock()
	code := service.otpStore[email].Code
	service.mu.RUnlock()

	// First verification should succeed
	if !service.Verify(email, code) {
		t.Error("First verification failed")
	}

	// Second verification with same code should fail
	if service.Verify(email, code) {
		t.Error("OTP was reused successfully")
	}
}
