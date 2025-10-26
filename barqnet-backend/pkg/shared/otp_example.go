package shared

// This file contains example usage patterns for the OTP service.
// These are documentation examples and not meant to be executed directly.

import (
	"fmt"
	"log"
	"time"
)

// ExampleBasicUsage demonstrates basic OTP service usage
func ExampleBasicUsage() {
	// Initialize the service
	otpService := NewLocalOTPService()

	phoneNumber := "+1234567890"

	// Send OTP to user
	err := otpService.Send(phoneNumber)
	if err != nil {
		log.Printf("Error sending OTP: %v", err)
		return
	}

	// In development, the OTP is logged to console
	// In production, it would be sent via SMS

	// User receives OTP and enters it
	userEnteredCode := "123456"

	// Verify the code
	if otpService.Verify(phoneNumber, userEnteredCode) {
		fmt.Println("Authentication successful!")
	} else {
		fmt.Println("Invalid or expired OTP")
	}
}

// ExampleCustomConfiguration shows how to customize service settings
func ExampleCustomConfiguration() {
	otpService := NewLocalOTPService()

	// Shorter expiry for high-security scenarios
	otpService.OTPExpiry = 5 * time.Minute

	// Higher rate limit for trusted environments
	otpService.RateLimitMax = 10

	// More verification attempts for better UX
	otpService.MaxVerifyAttempts = 5

	// Use the configured service
	otpService.Send("+1234567890")
}

// ExampleRateLimitHandling demonstrates rate limit error handling
func ExampleRateLimitHandling() {
	otpService := NewLocalOTPService()
	phoneNumber := "+1234567890"

	err := otpService.Send(phoneNumber)
	if err != nil {
		// Check if it's a rate limit error
		if err.Error() == fmt.Sprintf("rate limit exceeded: maximum %d OTP requests per hour", otpService.RateLimitMax) {
			log.Println("Please wait before requesting another OTP")
			// Show user a cooldown message
		} else {
			log.Printf("Failed to send OTP: %v", err)
		}
		return
	}

	log.Println("OTP sent successfully")
}

// ExampleMonitoring shows how to monitor OTP service health
func ExampleMonitoring() {
	otpService := NewLocalOTPService()

	// Send some OTPs
	otpService.Send("+1111111111")
	otpService.Send("+2222222222")

	// Get statistics
	stats := otpService.GetStats()

	log.Printf("Service Statistics:")
	log.Printf("  Active OTPs: %v", stats["active_otps"])
	log.Printf("  Rate Limited Numbers: %v", stats["rate_limited"])
	log.Printf("  OTP Expiry (minutes): %v", stats["expiry_minutes"])
	log.Printf("  Rate Limit Max: %v", stats["rate_limit_max"])
	log.Printf("  Max Verification Attempts: %v", stats["max_attempts"])
}

// ExampleProductionSetup demonstrates environment-based service selection
func ExampleProductionSetup() {
	var otpService OTPService

	// In a real application, check environment variable
	environment := "development" // Could be from os.Getenv("ENVIRONMENT")

	if environment == "production" {
		// TODO: Replace with your production OTP service
		// otpService = NewProductionOTPService(apiKey)
		log.Println("Would initialize production OTP service")
		otpService = NewLocalOTPService() // Fallback for this example
	} else {
		otpService = NewLocalOTPService()
		log.Println("Using local OTP service for development")
	}

	// Use the service (same interface regardless of implementation)
	otpService.Send("+1234567890")
}

// ExampleManualCleanup shows how to manually trigger cleanup
func ExampleManualCleanup() {
	otpService := NewLocalOTPService()

	// Send some OTPs
	otpService.Send("+1234567890")

	// Manually trigger cleanup (usually done automatically)
	otpService.Cleanup()

	// Check stats after cleanup
	stats := otpService.GetStats()
	log.Printf("Active OTPs after cleanup: %v", stats["active_otps"])
}

// ExampleHTTPHandler demonstrates integration with HTTP handlers
// This is a conceptual example - actual implementation would need proper imports
func ExampleHTTPHandler() {
	// In your HTTP handler setup:
	otpService := NewLocalOTPService()

	// Example handler logic (pseudo-code)
	handleSendOTP := func(phoneNumber string) error {
		if err := otpService.Send(phoneNumber); err != nil {
			return fmt.Errorf("failed to send OTP: %w", err)
		}
		return nil
	}

	handleVerifyOTP := func(phoneNumber, code string) bool {
		return otpService.Verify(phoneNumber, code)
	}

	// Use these handlers in your HTTP routes
	_ = handleSendOTP
	_ = handleVerifyOTP
}

// ExampleSecurityBestPractices shows security best practices
func ExampleSecurityBestPractices() {
	otpService := NewLocalOTPService()

	// 1. Use HTTPS for OTP transmission
	// 2. Validate phone number format before sending
	phoneNumber := "+1234567890"
	if !isValidPhoneNumber(phoneNumber) {
		log.Println("Invalid phone number format")
		return
	}

	// 3. Log OTP requests for audit trail
	log.Printf("OTP requested for: %s", maskPhoneNumber(phoneNumber))

	// 4. Send OTP
	err := otpService.Send(phoneNumber)
	if err != nil {
		// 5. Don't expose internal errors to users
		log.Printf("Internal error: %v", err)
		fmt.Println("Unable to send OTP. Please try again.")
		return
	}

	// 6. Rate limiting is handled automatically by the service

	// 7. Set appropriate OTP expiry based on security requirements
	// Already configured in the service

	// 8. Limit verification attempts (handled by service)

	// 9. Use OTP only once (handled by service)
}

// Helper functions for examples
func isValidPhoneNumber(phone string) bool {
	// Simplified validation - use a proper library in production
	return len(phone) > 10 && phone[0] == '+'
}

func maskPhoneNumber(phone string) string {
	// Show only last 4 digits for privacy
	if len(phone) <= 4 {
		return "****"
	}
	return "****" + phone[len(phone)-4:]
}

// ExampleComparison shows different implementation strategies
func ExampleComparison() {
	// Strategy 1: Local development with console logging (current)
	localService := NewLocalOTPService()
	localService.Send("+1234567890")
	// OTP printed to console

	// Strategy 2: Production with SMS gateway (to be implemented)
	// productionService := NewProductionOTPService("your-api-key")
	// productionService.Send("+1234567890")
	// OTP sent via SMS

	// Both implement the same interface, so business logic doesn't change
	var service OTPService = localService
	service.Verify("+1234567890", "123456")
}

// ExampleErrorHandling demonstrates comprehensive error handling
func ExampleErrorHandling() {
	otpService := NewLocalOTPService()
	phoneNumber := "+1234567890"

	// Send OTP with error handling
	if err := otpService.Send(phoneNumber); err != nil {
		switch {
		case err.Error() == fmt.Sprintf("rate limit exceeded: maximum %d OTP requests per hour", otpService.RateLimitMax):
			// User hit rate limit
			log.Println("Too many requests. Please wait before trying again.")
			// Could calculate and show remaining time

		default:
			// Other errors
			log.Printf("Failed to send OTP: %v", err)
			// Show generic error to user
		}
		return
	}

	// Verify OTP with proper feedback
	userCode := "123456"
	if otpService.Verify(phoneNumber, userCode) {
		// Success
		log.Println("OTP verified successfully")
		// Proceed with authentication
	} else {
		// Failed verification - could be:
		// - Wrong code
		// - Expired OTP
		// - No OTP sent
		// - Max attempts exceeded
		log.Println("Verification failed")
		// Show user-friendly message
	}
}
