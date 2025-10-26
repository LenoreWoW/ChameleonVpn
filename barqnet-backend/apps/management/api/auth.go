package api

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"regexp"
	"strings"
	"time"

	"vpnmanager/pkg/shared"

	"golang.org/x/crypto/bcrypt"
)

// OTPService interface for OTP verification
// This will be implemented later with actual OTP service
type OTPService interface {
	// SendOTP sends an OTP to the given phone number
	SendOTP(phoneNumber string) (string, error)

	// VerifyOTP verifies the OTP for the given phone number
	VerifyOTP(phoneNumber, otp string) (bool, error)

	// GenerateOTP generates a new OTP for testing purposes
	GenerateOTP() string
}

// MockOTPService is a mock implementation for development
type MockOTPService struct {
	otpStore map[string]string
}

// NewMockOTPService creates a new mock OTP service
func NewMockOTPService() *MockOTPService {
	return &MockOTPService{
		otpStore: make(map[string]string),
	}
}

// SendOTP sends a mock OTP (in production, this would send SMS)
func (m *MockOTPService) SendOTP(phoneNumber string) (string, error) {
	otp := m.GenerateOTP()
	m.otpStore[phoneNumber] = otp
	log.Printf("[OTP] Sent OTP to %s: %s (this is a mock - in production, send via SMS)", phoneNumber, otp)
	return otp, nil
}

// VerifyOTP verifies the OTP
func (m *MockOTPService) VerifyOTP(phoneNumber, otp string) (bool, error) {
	storedOTP, exists := m.otpStore[phoneNumber]
	if !exists {
		return false, fmt.Errorf("no OTP found for this phone number")
	}

	if storedOTP != otp {
		return false, nil
	}

	// Delete OTP after successful verification
	delete(m.otpStore, phoneNumber)
	return true, nil
}

// GenerateOTP generates a 6-digit OTP
func (m *MockOTPService) GenerateOTP() string {
	// In production, use crypto/rand for secure random generation
	return fmt.Sprintf("%06d", time.Now().Unix()%1000000)
}

// AuthHandler handles authentication operations
type AuthHandler struct {
	db         *sql.DB
	otpService OTPService
}

// NewAuthHandler creates a new authentication handler
func NewAuthHandler(db *sql.DB, otpService OTPService) *AuthHandler {
	return &AuthHandler{
		db:         db,
		otpService: otpService,
	}
}

// RegisterRequest represents a user registration request
type RegisterRequest struct {
	PhoneNumber string `json:"phone_number"`
	Password    string `json:"password"`
	OTP         string `json:"otp"`
}

// LoginRequest represents a user login request
type LoginRequest struct {
	PhoneNumber string `json:"phone_number"`
	Password    string `json:"password"`
}

// RefreshRequest represents a token refresh request
type RefreshRequest struct {
	Token string `json:"token"`
}

// AuthResponse represents an authentication response
type AuthResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
	Token   string      `json:"token,omitempty"`
}

// HandleRegister handles user registration
// POST /auth/register
func (h *AuthHandler) HandleRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		h.sendError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, "Invalid JSON request", http.StatusBadRequest)
		return
	}

	// Validate input
	if err := h.validatePhoneNumber(req.PhoneNumber); err != nil {
		h.sendError(w, fmt.Sprintf("Invalid phone number: %v", err), http.StatusBadRequest)
		return
	}

	if err := h.validatePassword(req.Password); err != nil {
		h.sendError(w, fmt.Sprintf("Invalid password: %v", err), http.StatusBadRequest)
		return
	}

	// Verify OTP
	verified, err := h.otpService.VerifyOTP(req.PhoneNumber, req.OTP)
	if err != nil {
		h.sendError(w, fmt.Sprintf("OTP verification failed: %v", err), http.StatusBadRequest)
		return
	}
	if !verified {
		h.sendError(w, "Invalid OTP", http.StatusUnauthorized)
		return
	}

	// Check if user already exists
	var existingID int
	err = h.db.QueryRow("SELECT id FROM auth_users WHERE phone_number = $1", req.PhoneNumber).Scan(&existingID)
	if err == nil {
		h.sendError(w, "User with this phone number already exists", http.StatusConflict)
		return
	} else if err != sql.ErrNoRows {
		log.Printf("[AUTH] Database error checking existing user: %v", err)
		h.sendError(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	// Hash password using bcrypt with 12 rounds
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		log.Printf("[AUTH] Failed to hash password: %v", err)
		h.sendError(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	// Insert new user
	var userID int
	err = h.db.QueryRow(`
		INSERT INTO auth_users (phone_number, password_hash, created_at, last_login, active)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id
	`, req.PhoneNumber, string(hashedPassword), time.Now(), time.Now(), true).Scan(&userID)

	if err != nil {
		log.Printf("[AUTH] Failed to create user: %v", err)
		h.sendError(w, "Failed to create user", http.StatusInternalServerError)
		return
	}

	// Generate JWT token
	token, err := shared.GenerateJWT(req.PhoneNumber, userID)
	if err != nil {
		log.Printf("[AUTH] Failed to generate JWT: %v", err)
		h.sendError(w, "Failed to generate authentication token", http.StatusInternalServerError)
		return
	}

	// Log successful registration
	h.logAuditEvent("USER_REGISTERED", req.PhoneNumber, "User registered successfully", r.RemoteAddr)

	// Send success response
	response := AuthResponse{
		Success: true,
		Message: "User registered successfully",
		Token:   token,
		Data: map[string]interface{}{
			"user_id":      userID,
			"phone_number": req.PhoneNumber,
			"created_at":   time.Now().Unix(),
		},
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(response)
}

// HandleLogin handles user login
// POST /auth/login
func (h *AuthHandler) HandleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		h.sendError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, "Invalid JSON request", http.StatusBadRequest)
		return
	}

	// Validate input
	if req.PhoneNumber == "" || req.Password == "" {
		h.sendError(w, "Phone number and password are required", http.StatusBadRequest)
		return
	}

	// Retrieve user from database
	var userID int
	var passwordHash string
	var active bool
	err := h.db.QueryRow(`
		SELECT id, password_hash, active
		FROM auth_users
		WHERE phone_number = $1
	`, req.PhoneNumber).Scan(&userID, &passwordHash, &active)

	if err == sql.ErrNoRows {
		// Use generic error message to prevent user enumeration
		h.sendError(w, "Invalid phone number or password", http.StatusUnauthorized)
		h.logAuditEvent("LOGIN_FAILED", req.PhoneNumber, "Invalid credentials", r.RemoteAddr)
		return
	} else if err != nil {
		log.Printf("[AUTH] Database error during login: %v", err)
		h.sendError(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	// Check if account is active
	if !active {
		h.sendError(w, "Account is disabled", http.StatusForbidden)
		h.logAuditEvent("LOGIN_FAILED", req.PhoneNumber, "Account disabled", r.RemoteAddr)
		return
	}

	// Verify password
	err = bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password))
	if err != nil {
		// Invalid password
		h.sendError(w, "Invalid phone number or password", http.StatusUnauthorized)
		h.logAuditEvent("LOGIN_FAILED", req.PhoneNumber, "Invalid password", r.RemoteAddr)
		return
	}

	// Update last login time
	_, err = h.db.Exec("UPDATE auth_users SET last_login = $1 WHERE id = $2", time.Now(), userID)
	if err != nil {
		log.Printf("[AUTH] Failed to update last login: %v", err)
		// Non-critical error, continue
	}

	// Generate JWT token
	token, err := shared.GenerateJWT(req.PhoneNumber, userID)
	if err != nil {
		log.Printf("[AUTH] Failed to generate JWT: %v", err)
		h.sendError(w, "Failed to generate authentication token", http.StatusInternalServerError)
		return
	}

	// Log successful login
	h.logAuditEvent("LOGIN_SUCCESS", req.PhoneNumber, "User logged in successfully", r.RemoteAddr)

	// Send success response
	response := AuthResponse{
		Success: true,
		Message: "Login successful",
		Token:   token,
		Data: map[string]interface{}{
			"user_id":      userID,
			"phone_number": req.PhoneNumber,
			"login_time":   time.Now().Unix(),
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// HandleRefresh handles JWT token refresh
// POST /auth/refresh
func (h *AuthHandler) HandleRefresh(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		h.sendError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req RefreshRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, "Invalid JSON request", http.StatusBadRequest)
		return
	}

	if req.Token == "" {
		h.sendError(w, "Token is required", http.StatusBadRequest)
		return
	}

	// Refresh the token
	newToken, err := shared.RefreshJWT(req.Token)
	if err != nil {
		h.sendError(w, fmt.Sprintf("Failed to refresh token: %v", err), http.StatusUnauthorized)
		return
	}

	// Extract phone number for logging (optional)
	phoneNumber, _ := shared.ExtractPhoneNumber(newToken)
	h.logAuditEvent("TOKEN_REFRESHED", phoneNumber, "JWT token refreshed", r.RemoteAddr)

	// Send success response
	response := AuthResponse{
		Success: true,
		Message: "Token refreshed successfully",
		Token:   newToken,
		Data: map[string]interface{}{
			"refreshed_at": time.Now().Unix(),
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// HandleLogout handles user logout
// POST /auth/logout
// Note: JWT is stateless, so logout is primarily client-side (delete token)
// This endpoint is for audit logging purposes
func (h *AuthHandler) HandleLogout(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		h.sendError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract token from Authorization header
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		h.sendError(w, "Authorization header required", http.StatusUnauthorized)
		return
	}

	// Extract token (format: "Bearer <token>")
	parts := strings.Split(authHeader, " ")
	if len(parts) != 2 || parts[0] != "Bearer" {
		h.sendError(w, "Invalid authorization header format", http.StatusUnauthorized)
		return
	}

	token := parts[1]

	// Validate token
	claims, err := shared.ValidateJWT(token)
	if err != nil {
		h.sendError(w, "Invalid token", http.StatusUnauthorized)
		return
	}

	// Log logout event
	h.logAuditEvent("USER_LOGOUT", claims.PhoneNumber, "User logged out", r.RemoteAddr)

	// Send success response
	response := AuthResponse{
		Success: true,
		Message: "Logout successful. Please delete the token on client side.",
		Data: map[string]interface{}{
			"logout_time": time.Now().Unix(),
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// HandleSendOTP handles OTP generation and sending
// POST /auth/send-otp
func (h *AuthHandler) HandleSendOTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		h.sendError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		PhoneNumber string `json:"phone_number"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, "Invalid JSON request", http.StatusBadRequest)
		return
	}

	// Validate phone number
	if err := h.validatePhoneNumber(req.PhoneNumber); err != nil {
		h.sendError(w, fmt.Sprintf("Invalid phone number: %v", err), http.StatusBadRequest)
		return
	}

	// Send OTP
	otp, err := h.otpService.SendOTP(req.PhoneNumber)
	if err != nil {
		log.Printf("[AUTH] Failed to send OTP: %v", err)
		h.sendError(w, "Failed to send OTP", http.StatusInternalServerError)
		return
	}

	// Log OTP sent event
	h.logAuditEvent("OTP_SENT", req.PhoneNumber, "OTP sent to phone number", r.RemoteAddr)

	// Send success response
	response := AuthResponse{
		Success: true,
		Message: "OTP sent successfully",
		Data: map[string]interface{}{
			"phone_number": req.PhoneNumber,
			"otp":          otp, // In production, NEVER send OTP in response!
			"expires_in":   300, // 5 minutes
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// JWTAuthMiddleware validates JWT token for protected routes
func (h *AuthHandler) JWTAuthMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Extract token from Authorization header
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			h.sendError(w, "Authorization header required", http.StatusUnauthorized)
			return
		}

		// Extract token (format: "Bearer <token>")
		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			h.sendError(w, "Invalid authorization header format", http.StatusUnauthorized)
			return
		}

		token := parts[1]

		// Validate token
		claims, err := shared.ValidateJWT(token)
		if err != nil {
			h.sendError(w, fmt.Sprintf("Invalid token: %v", err), http.StatusUnauthorized)
			return
		}

		// Add claims to request context
		ctx := context.WithValue(r.Context(), "claims", claims)
		ctx = context.WithValue(ctx, "phone_number", claims.PhoneNumber)
		ctx = context.WithValue(ctx, "user_id", claims.UserID)

		// Call next handler with updated context
		next.ServeHTTP(w, r.WithContext(ctx))
	}
}

// validatePhoneNumber validates phone number format
func (h *AuthHandler) validatePhoneNumber(phoneNumber string) error {
	// Remove spaces and dashes
	phoneNumber = strings.ReplaceAll(phoneNumber, " ", "")
	phoneNumber = strings.ReplaceAll(phoneNumber, "-", "")

	// Length check (minimum 10 digits, maximum 15 digits)
	if len(phoneNumber) < 10 || len(phoneNumber) > 15 {
		return fmt.Errorf("phone number must be 10-15 digits")
	}

	// Check if it contains only digits and optional + prefix
	matched, _ := regexp.MatchString(`^\+?[0-9]+$`, phoneNumber)
	if !matched {
		return fmt.Errorf("phone number must contain only digits and optional + prefix")
	}

	return nil
}

// validatePassword validates password strength
func (h *AuthHandler) validatePassword(password string) error {
	// Minimum length
	if len(password) < 8 {
		return fmt.Errorf("password must be at least 8 characters long")
	}

	// Maximum length (prevent DoS)
	if len(password) > 128 {
		return fmt.Errorf("password must be at most 128 characters long")
	}

	// Check for at least one uppercase letter
	hasUpper := regexp.MustCompile(`[A-Z]`).MatchString(password)
	if !hasUpper {
		return fmt.Errorf("password must contain at least one uppercase letter")
	}

	// Check for at least one lowercase letter
	hasLower := regexp.MustCompile(`[a-z]`).MatchString(password)
	if !hasLower {
		return fmt.Errorf("password must contain at least one lowercase letter")
	}

	// Check for at least one digit
	hasDigit := regexp.MustCompile(`[0-9]`).MatchString(password)
	if !hasDigit {
		return fmt.Errorf("password must contain at least one digit")
	}

	return nil
}

// sendError sends an error response
func (h *AuthHandler) sendError(w http.ResponseWriter, message string, statusCode int) {
	response := AuthResponse{
		Success: false,
		Message: message,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(response)
}

// logAuditEvent logs an authentication event to the audit log
func (h *AuthHandler) logAuditEvent(action, username, details, ipAddress string) {
	_, err := h.db.Exec(`
		INSERT INTO audit_log (timestamp, action, username, details, ip_address, server_id)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, time.Now(), action, username, details, ipAddress, "management-server")

	if err != nil {
		log.Printf("[AUTH] Failed to log audit event: %v", err)
	}
}
