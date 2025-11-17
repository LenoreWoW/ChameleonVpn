package shared

import (
	"crypto/rand"
	"fmt"
	"log"
	"math/big"
	"sync"
	"time"
)

// OTPService defines the interface for OTP operations.
// This interface allows for easy swapping between different OTP implementations
// (email, SMS gateway, third-party services, etc.)
//
// MIGRATION NOTE: Changed from phone numbers to email addresses
// This maintains the same interface contract for seamless integration
type OTPService interface {
	// Send generates and sends an OTP to the specified email address
	// Returns error if rate limit exceeded or sending fails
	Send(email string) error

	// Verify checks if the provided code matches the stored OTP for the email address
	// Returns true if valid and not expired, false otherwise
	Verify(email, code string) bool

	// GenerateOTP creates a new 6-digit OTP code
	// This is exposed for testing purposes and custom implementations
	GenerateOTP() string

	// Cleanup removes expired OTP entries from storage
	// Should be called periodically to prevent memory leaks
	Cleanup()
}

// OTPEntry stores OTP data with timestamp and attempt tracking
type OTPEntry struct {
	Code      string
	CreatedAt time.Time
	Attempts  int // Track verification attempts to prevent brute force
}

// RateLimitEntry tracks send attempts for rate limiting
type RateLimitEntry struct {
	Count     int
	ResetTime time.Time
}

// LocalOTPService is a production-ready implementation of OTPService
// that stores OTP codes in memory and uses EmailService for delivery.
//
// Configuration Options:
// - OTPExpiry: How long OTP codes remain valid (default: 10 minutes)
// - RateLimit: Maximum OTP sends per email per hour (default: 5)
// - MaxVerifyAttempts: Maximum verification attempts per OTP (default: 3)
type LocalOTPService struct {
	mu sync.RWMutex

	// otpStore maps email address to OTP entry
	otpStore map[string]*OTPEntry

	// rateLimitStore maps email address to rate limit tracking
	rateLimitStore map[string]*RateLimitEntry

	// stopCh is used to signal the cleanup goroutine to stop
	stopCh chan struct{}

	// emailService handles actual email delivery (Resend, local, etc.)
	emailService EmailService

	// Configuration
	OTPExpiry          time.Duration // Default: 10 minutes
	RateLimitWindow    time.Duration // Default: 1 hour
	RateLimitMax       int           // Default: 5 attempts
	MaxVerifyAttempts  int           // Default: 3 attempts
}

// NewLocalOTPService creates a new LocalOTPService with default settings
// emailService: Can be ResendEmailService for production or LocalEmailService for development
func NewLocalOTPService(emailService EmailService) *LocalOTPService {
	service := &LocalOTPService{
		otpStore:           make(map[string]*OTPEntry),
		rateLimitStore:     make(map[string]*RateLimitEntry),
		stopCh:             make(chan struct{}),
		emailService:       emailService,
		OTPExpiry:          10 * time.Minute,
		RateLimitWindow:    1 * time.Hour,
		RateLimitMax:       5,
		MaxVerifyAttempts:  3,
	}

	// Start background cleanup goroutine (can be stopped with Stop())
	go service.cleanupRoutine()

	return service
}

// Send generates an OTP and sends it via email
// Uses the configured EmailService (Resend for production, Local for development)
func (s *LocalOTPService) Send(email string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Check rate limiting
	if !s.checkRateLimit(email) {
		return fmt.Errorf("rate limit exceeded: maximum %d OTP requests per hour", s.RateLimitMax)
	}

	// Generate new OTP
	code := s.GenerateOTP()

	// Store OTP with timestamp
	s.otpStore[email] = &OTPEntry{
		Code:      code,
		CreatedAt: time.Now(),
		Attempts:  0,
	}

	// Update rate limit counter
	s.updateRateLimit(email)

	// Send OTP via email service (Resend or Local)
	// This is called AFTER storing to ensure OTP exists for verification
	// even if email delivery is slow
	err := s.emailService.SendOTP(email, code)
	if err != nil {
		// Log error but don't fail - OTP is still valid for manual entry
		log.Printf("[OTP] Failed to send email to %s: %v", email, err)
		// Optionally, you could delete the OTP here if email send fails
		// delete(s.otpStore, email)
		return fmt.Errorf("failed to send OTP email: %w", err)
	}

	log.Printf("[OTP] Successfully sent OTP to %s (expires: %v)",
		email, time.Now().Add(s.OTPExpiry).Format("15:04:05"))

	return nil
}

// Verify checks if the provided OTP code is valid for the email address
// Returns true if code matches and hasn't expired
func (s *LocalOTPService) Verify(email, code string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	entry, exists := s.otpStore[email]
	if !exists {
		return false
	}

	// Check if OTP has expired
	if time.Since(entry.CreatedAt) > s.OTPExpiry {
		delete(s.otpStore, email)
		return false
	}

	// Check if max attempts already exceeded
	if entry.Attempts >= s.MaxVerifyAttempts {
		delete(s.otpStore, email)
		return false
	}

	// Verify code BEFORE incrementing attempts
	// This prevents counting successful attempts and fixes race condition
	if entry.Code == code {
		// Success - remove OTP to prevent reuse
		delete(s.otpStore, email)
		return true
	}

	// ONLY increment on FAILURE (atomic operation under mutex)
	entry.Attempts++
	s.otpStore[email] = entry

	return false
}

// GenerateOTP creates a cryptographically secure 6-digit OTP code
// CRITICAL: Panics if crypto random fails (never degrade security)
func (s *LocalOTPService) GenerateOTP() string {
	// Generate a random number between 0 and 999999
	max := big.NewInt(1000000)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		// SECURITY: Never fall back to insecure generation
		// If crypto random fails, system is fundamentally broken
		log.Printf("[OTP-FATAL] Failed to generate secure random OTP: %v", err)
		panic(fmt.Sprintf("FATAL: Cryptographic random number generation failed: %v. System cannot operate securely.", err))
	}

	// Format as 6-digit string with leading zeros
	return fmt.Sprintf("%06d", n.Int64())
}

// Cleanup removes expired OTP entries and old rate limit data
func (s *LocalOTPService) Cleanup() {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now()

	// Clean expired OTPs
	for email, entry := range s.otpStore {
		if now.Sub(entry.CreatedAt) > s.OTPExpiry {
			delete(s.otpStore, email)
		}
	}

	// Clean expired rate limits
	for email, limit := range s.rateLimitStore {
		if now.After(limit.ResetTime) {
			delete(s.rateLimitStore, email)
		}
	}
}

// cleanupRoutine runs periodic cleanup in the background
// Stops when Stop() is called or service is garbage collected
func (s *LocalOTPService) cleanupRoutine() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			s.Cleanup()
		case <-s.stopCh:
			log.Println("[OTP] Cleanup goroutine stopped")
			return
		}
	}
}

// Stop gracefully stops the OTP service cleanup goroutine
// Should be called when shutting down the application
func (s *LocalOTPService) Stop() {
	close(s.stopCh)
}

// checkRateLimit verifies if the email address has exceeded rate limits
// Must be called with lock held
func (s *LocalOTPService) checkRateLimit(email string) bool {
	limit, exists := s.rateLimitStore[email]
	if !exists {
		return true
	}

	// Check if rate limit window has expired
	if time.Now().After(limit.ResetTime) {
		delete(s.rateLimitStore, email)
		return true
	}

	// Check if limit exceeded
	return limit.Count < s.RateLimitMax
}

// updateRateLimit increments the rate limit counter for an email address
// Must be called with lock held
func (s *LocalOTPService) updateRateLimit(email string) {
	limit, exists := s.rateLimitStore[email]
	if !exists {
		s.rateLimitStore[email] = &RateLimitEntry{
			Count:     1,
			ResetTime: time.Now().Add(s.RateLimitWindow),
		}
		return
	}

	limit.Count++
	s.rateLimitStore[email] = limit
}

// GetStats returns statistics about current OTP service state (for monitoring/debugging)
func (s *LocalOTPService) GetStats() map[string]interface{} {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return map[string]interface{}{
		"active_otps":      len(s.otpStore),
		"rate_limited":     len(s.rateLimitStore),
		"expiry_minutes":   s.OTPExpiry.Minutes(),
		"rate_limit_max":   s.RateLimitMax,
		"max_attempts":     s.MaxVerifyAttempts,
	}
}
