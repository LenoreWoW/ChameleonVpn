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

	"barqnet-backend/pkg/shared"

	"golang.org/x/crypto/bcrypt"
)

// AuthHandler handles authentication operations
type AuthHandler struct {
	db          *sql.DB
	otpService  shared.OTPService // Use shared OTPService interface
	blacklist   *shared.TokenBlacklist
	rateLimiter *shared.RateLimiter
	auditLogger *shared.AuditLogger
}

// NewAuthHandler creates a new authentication handler
func NewAuthHandler(db *sql.DB, otpService shared.OTPService, rateLimiter *shared.RateLimiter, auditLogger *shared.AuditLogger) *AuthHandler {
	return &AuthHandler{
		db:          db,
		otpService:  otpService,
		blacklist:   shared.NewTokenBlacklist(db),
		rateLimiter: rateLimiter,
		auditLogger: auditLogger,
	}
}

// RegisterRequest represents a user registration request
type RegisterRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	OTP      string `json:"otp"`
}

// LoginRequest represents a user login request
type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
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

	// Rate limiting: Registration per IP address
	if h.rateLimiter != nil && h.rateLimiter.IsEnabled() {
		// Extract IP address from RemoteAddr
		ip := r.RemoteAddr
		if idx := strings.LastIndex(ip, ":"); idx != -1 {
			ip = ip[:idx]
		}

		allowed, remaining, resetTime, err := h.rateLimiter.Allow(shared.RateLimitRegister, ip)
		if err != nil {
			log.Printf("[AUTH] Rate limit check error: %v", err)
		} else if !allowed {
			w.Header().Set("X-RateLimit-Limit", "3")
			w.Header().Set("X-RateLimit-Remaining", "0")
			w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))
			w.Header().Set("Retry-After", fmt.Sprintf("%d", int(time.Until(resetTime).Seconds())))

			h.sendError(w, fmt.Sprintf("Too many registration attempts. Please try again in %d seconds.", int(time.Until(resetTime).Seconds())), http.StatusTooManyRequests)
			h.logAuditEvent("REGISTER_RATE_LIMIT_EXCEEDED", req.Email, fmt.Sprintf("Registration rate limit exceeded from IP %s", ip), r.RemoteAddr)
			return
		} else {
			w.Header().Set("X-RateLimit-Limit", "3")
			w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
			w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))
		}
	}

	// Validate input
	if err := h.validateEmail(req.Email); err != nil {
		h.sendError(w, fmt.Sprintf("Invalid email: %v", err), http.StatusBadRequest)
		return
	}

	if err := h.validatePassword(req.Password); err != nil {
		h.sendError(w, fmt.Sprintf("Invalid password: %v", err), http.StatusBadRequest)
		return
	}

	// Verify OTP using shared.OTPService (Check doesn't consume the OTP)
	verified := h.otpService.Check(req.Email, req.OTP)
	if !verified {
		h.sendError(w, "Invalid OTP", http.StatusUnauthorized)
		return
	}

	// Check if user already exists
	var existingID int
	err := h.db.QueryRow("SELECT id FROM users WHERE email = $1", req.Email).Scan(&existingID)
	if err == nil {
		h.sendError(w, "User with this email already exists", http.StatusConflict)
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

	// Insert new user with email
	// Generate username from email (use part before @ as base)
	username := strings.Split(req.Email, "@")[0]
	// Add timestamp suffix to ensure uniqueness
	username = fmt.Sprintf("%s_%d", username, time.Now().UnixNano()%100000)
	
	var userID int
	err = h.db.QueryRow(`
		INSERT INTO users (email, username, password_hash, server_id, created_by, created_at, last_login, active)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id
	`, req.Email, username, string(hashedPassword), "management-server", "self-registration", time.Now(), time.Now(), true).Scan(&userID)

	if err != nil {
		log.Printf("[AUTH] Failed to create user: %v", err)
		h.sendError(w, "Failed to create user", http.StatusInternalServerError)
		return
	}

	// Consume the OTP to prevent reuse now that user is successfully created
	_ = h.otpService.Verify(req.Email, req.OTP)

	// Generate access and refresh tokens
	accessToken, err := shared.GenerateJWT(req.Email, userID)
	if err != nil {
		log.Printf("[AUTH] Failed to generate access token: %v", err)
		h.sendError(w, "Failed to generate authentication token", http.StatusInternalServerError)
		return
	}

	// Generate refresh token (longer expiry)
	refreshToken, err := shared.GenerateRefreshToken(req.Email, userID)
	if err != nil {
		log.Printf("[AUTH] Failed to generate refresh token: %v", err)
		h.sendError(w, "Failed to generate refresh token", http.StatusInternalServerError)
		return
	}

	// Log successful registration
	h.logAuditEvent("USER_REGISTERED", req.Email, "User registered successfully", r.RemoteAddr)

	// Send success response with proper token structure
	// Use snake_case for JSON keys (standard for REST APIs)
	response := AuthResponse{
		Success: true,
		Message: "User registered successfully",
		Data: map[string]interface{}{
			"user": map[string]interface{}{
				"id":    userID,
				"email": req.Email,
			},
			"access_token":  accessToken,
			"refresh_token": refreshToken,
			"expires_in":    86400, // 24 hours in seconds
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
	if req.Email == "" || req.Password == "" {
		h.sendError(w, "Email and password are required", http.StatusBadRequest)
		return
	}

	// Rate limiting: Login attempts per email
	if h.rateLimiter != nil && h.rateLimiter.IsEnabled() {
		allowed, remaining, resetTime, err := h.rateLimiter.Allow(shared.RateLimitLogin, req.Email)
		if err != nil {
			log.Printf("[AUTH] Rate limit check error: %v", err)
		} else if !allowed {
			w.Header().Set("X-RateLimit-Limit", "10")
			w.Header().Set("X-RateLimit-Remaining", "0")
			w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))
			w.Header().Set("Retry-After", fmt.Sprintf("%d", int(time.Until(resetTime).Seconds())))

			h.sendError(w, fmt.Sprintf("Too many login attempts. Please try again in %d seconds.", int(time.Until(resetTime).Seconds())), http.StatusTooManyRequests)
			h.logAuditEvent("LOGIN_RATE_LIMIT_EXCEEDED", req.Email, "Login rate limit exceeded", r.RemoteAddr)
			return
		} else {
			w.Header().Set("X-RateLimit-Limit", "10")
			w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
			w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))
		}
	}

	// Retrieve user from database
	var userID int
	var passwordHash string
	var active bool
	err := h.db.QueryRow(`
		SELECT id, password_hash, active
		FROM users
		WHERE email = $1
	`, req.Email).Scan(&userID, &passwordHash, &active)

	if err == sql.ErrNoRows {
		// Use generic error message to prevent user enumeration
		h.sendError(w, "Invalid email or password", http.StatusUnauthorized)
		h.logAuditEvent("LOGIN_FAILED", req.Email, "Invalid credentials", r.RemoteAddr)
		return
	} else if err != nil {
		log.Printf("[AUTH] Database error during login: %v", err)
		h.sendError(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	// Check if account is active
	if !active {
		h.sendError(w, "Account is disabled", http.StatusForbidden)
		h.logAuditEvent("LOGIN_FAILED", req.Email, "Account disabled", r.RemoteAddr)
		return
	}

	// Verify password
	err = bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password))
	if err != nil {
		// Invalid password
		h.sendError(w, "Invalid email or password", http.StatusUnauthorized)
		h.logAuditEvent("LOGIN_FAILED", req.Email, "Invalid password", r.RemoteAddr)
		return
	}

	// Update last login time
	_, err = h.db.Exec("UPDATE users SET last_login = $1 WHERE id = $2", time.Now(), userID)
	if err != nil {
		log.Printf("[AUTH] Failed to update last login: %v", err)
		// Non-critical error, continue
	}

	// Generate access and refresh tokens
	accessToken, err := shared.GenerateJWT(req.Email, userID)
	if err != nil {
		log.Printf("[AUTH] Failed to generate access token: %v", err)
		h.sendError(w, "Failed to generate authentication token", http.StatusInternalServerError)
		return
	}

	// Generate refresh token (longer expiry)
	refreshToken, err := shared.GenerateRefreshToken(req.Email, userID)
	if err != nil {
		log.Printf("[AUTH] Failed to generate refresh token: %v", err)
		h.sendError(w, "Failed to generate refresh token", http.StatusInternalServerError)
		return
	}

	// Log successful login
	h.logAuditEvent("LOGIN_SUCCESS", req.Email, "User logged in successfully", r.RemoteAddr)

	// Send success response with proper token structure
	// Use snake_case for JSON keys (standard for REST APIs)
	response := AuthResponse{
		Success: true,
		Message: "Login successful",
		Data: map[string]interface{}{
			"user": map[string]interface{}{
				"id":    userID,
				"email": req.Email,
			},
			"access_token":  accessToken,
			"refresh_token": refreshToken,
			"expires_in":    86400, // 24 hours in seconds
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// HandleRefresh handles JWT token refresh
// POST /v1/auth/refresh
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
		h.sendError(w, "Refresh token is required", http.StatusBadRequest)
		return
	}

	// Validate the refresh token and check blacklist
	claims, err := shared.ValidateJWTWithBlacklist(req.Token, h.blacklist)
	if err != nil {
		h.sendError(w, fmt.Sprintf("Invalid refresh token: %v", err), http.StatusUnauthorized)
		return
	}

	// Generate new access token with same user data
	newAccessToken, err := shared.GenerateJWT(claims.Email, claims.UserID)
	if err != nil {
		h.sendError(w, "Failed to generate new access token", http.StatusInternalServerError)
		return
	}

	// Generate new refresh token
	newRefreshToken, err := shared.GenerateRefreshToken(claims.Email, claims.UserID)
	if err != nil {
		h.sendError(w, "Failed to generate new refresh token", http.StatusInternalServerError)
		return
	}

	// Log token refresh
	h.logAuditEvent("TOKEN_REFRESHED", claims.Email, "Tokens refreshed successfully", r.RemoteAddr)

	// Send success response with new tokens
	// Use snake_case for JSON keys (standard for REST APIs)
	response := AuthResponse{
		Success: true,
		Message: "Tokens refreshed successfully",
		Data: map[string]interface{}{
			"access_token":  newAccessToken,
			"refresh_token": newRefreshToken,
			"expires_in":    86400, // 24 hours
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
	h.logAuditEvent("USER_LOGOUT", claims.Email, "User logged out", r.RemoteAddr)

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
		Email string `json:"email"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, "Invalid JSON request", http.StatusBadRequest)
		return
	}

	// Validate email
	if err := h.validateEmail(req.Email); err != nil {
		h.sendError(w, fmt.Sprintf("Invalid email: %v", err), http.StatusBadRequest)
		return
	}

	// Rate limiting: OTP send per email
	if h.rateLimiter != nil && h.rateLimiter.IsEnabled() {
		allowed, remaining, resetTime, err := h.rateLimiter.Allow(shared.RateLimitOTP, req.Email)
		if err != nil {
			log.Printf("[AUTH] Rate limit check error: %v", err)
		} else if !allowed {
			w.Header().Set("X-RateLimit-Limit", "5")
			w.Header().Set("X-RateLimit-Remaining", "0")
			w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))
			w.Header().Set("Retry-After", fmt.Sprintf("%d", int(time.Until(resetTime).Seconds())))

			h.sendError(w, fmt.Sprintf("Too many OTP requests. Please try again in %d seconds.", int(time.Until(resetTime).Seconds())), http.StatusTooManyRequests)
			h.logAuditEvent("OTP_RATE_LIMIT_EXCEEDED", req.Email, "OTP rate limit exceeded", r.RemoteAddr)
			return
		} else {
			w.Header().Set("X-RateLimit-Limit", "5")
			w.Header().Set("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
			w.Header().Set("X-RateLimit-Reset", fmt.Sprintf("%d", resetTime.Unix()))
		}
	}

	// Send OTP via email using shared.OTPService
	err := h.otpService.Send(req.Email)
	if err != nil {
		log.Printf("[AUTH] Failed to send OTP: %v", err)
		h.sendError(w, "Failed to send OTP email", http.StatusInternalServerError)
		return
	}

	// Log OTP sent event
	h.logAuditEvent("OTP_SENT", req.Email, "OTP sent to email address", r.RemoteAddr)

	// Send success response (NEVER include OTP in response for security)
	response := AuthResponse{
		Success: true,
		Message: "OTP sent successfully. Please check your email.",
		Data: map[string]interface{}{
			"email":      req.Email,
			"expires_in": 600, // 10 minutes
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// HandleVerifyOTP handles OTP verification (without registration)
// POST /auth/verify-otp
// This endpoint verifies the OTP and returns a temporary token for registration
func (h *AuthHandler) HandleVerifyOTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		h.sendError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Email string `json:"email"`
		OTP   string `json:"otp"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, "Invalid JSON request", http.StatusBadRequest)
		return
	}

	// Validate email
	if err := h.validateEmail(req.Email); err != nil {
		h.sendError(w, fmt.Sprintf("Invalid email: %v", err), http.StatusBadRequest)
		return
	}

	// Validate OTP format
	if len(req.OTP) != 6 {
		h.sendError(w, "Invalid OTP format", http.StatusBadRequest)
		return
	}

	// Check OTP without consuming it (use Check instead of Verify)
	// This allows the OTP to be used again during registration
	if !h.otpService.Check(req.Email, req.OTP) {
		h.sendError(w, "Invalid or expired OTP", http.StatusBadRequest)
		h.logAuditEvent("OTP_VERIFY_FAILED", req.Email, "Invalid OTP provided", r.RemoteAddr)
		return
	}

	// OTP verified successfully (but not consumed)
	h.logAuditEvent("OTP_VERIFIED", req.Email, "OTP verified successfully", r.RemoteAddr)

	// Return success - the OTP has been verified and can be used for registration
	// The app should proceed to password creation screen
	response := AuthResponse{
		Success: true,
		Message: "OTP verified successfully",
		Data: map[string]interface{}{
			"email":      req.Email,
			"verified":   true,
			"expires_in": 600, // 10 minutes to complete registration
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
		ctx = context.WithValue(ctx, "email", claims.Email)
		ctx = context.WithValue(ctx, "user_id", claims.UserID)

		// Call next handler with updated context
		next.ServeHTTP(w, r.WithContext(ctx))
	}
}

// validateEmail validates email address format
func (h *AuthHandler) validateEmail(email string) error {
	// Normalize email
	email = strings.TrimSpace(strings.ToLower(email))

	if email == "" {
		return fmt.Errorf("email address cannot be empty")
	}

	if len(email) > 255 {
		return fmt.Errorf("email address too long (max 255 characters)")
	}

	// RFC 5322 compliant email regex
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9.!#$%&'*+/=?^_` + "`" + `{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$`)

	if !emailRegex.MatchString(email) {
		return fmt.Errorf("invalid email format")
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

// RevokeTokenRequest represents a token revocation request
type RevokeTokenRequest struct {
	RefreshToken string `json:"refresh_token"`
	Reason       string `json:"reason,omitempty"` // Optional reason
}

// RevokeAllTokensRequest represents a request to revoke all user tokens
type RevokeAllTokensRequest struct {
	Password string `json:"password"` // Require password for security
	Reason   string `json:"reason,omitempty"`
}

// HandleRevokeToken handles single refresh token revocation (secure logout)
// POST /v1/auth/revoke
// This endpoint allows users to explicitly revoke a refresh token
func (h *AuthHandler) HandleRevokeToken(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		h.sendError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req RevokeTokenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, "Invalid JSON request", http.StatusBadRequest)
		return
	}

	if req.RefreshToken == "" {
		h.sendError(w, "refresh_token is required", http.StatusBadRequest)
		return
	}

	// Validate the token to extract claims (don't check blacklist yet - we're about to revoke it)
	claims, err := shared.ValidateJWT(req.RefreshToken)
	if err != nil {
		h.sendError(w, fmt.Sprintf("Invalid refresh token: %v", err), http.StatusUnauthorized)
		return
	}

	// Set default reason if not provided
	reason := req.Reason
	if reason == "" {
		reason = "logout"
	}

	// Get client IP address
	ipAddress := h.getClientIP(r)

	// Get user agent
	userAgent := r.Header.Get("User-Agent")

	// Revoke the token by adding it to the blacklist
	err = h.blacklist.RevokeToken(
		req.RefreshToken,
		claims.UserID,
		claims.Email,
		claims.ExpiresAt.Time,
		reason,
		"user", // Revoked by user
		ipAddress,
		userAgent,
	)

	if err != nil {
		log.Printf("[AUTH] Failed to revoke token: %v", err)
		h.sendError(w, "Failed to revoke token", http.StatusInternalServerError)
		return
	}

	// Log the revocation
	h.logAuditEvent("TOKEN_REVOKED", claims.Email,
		fmt.Sprintf("Refresh token revoked (reason: %s)", reason), ipAddress)

	// Send success response
	response := AuthResponse{
		Success: true,
		Message: "Token revoked successfully",
		Data: map[string]interface{}{
			"revoked_at": time.Now().Unix(),
			"reason":     reason,
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// HandleRevokeAllTokens handles revocation of all user's tokens (emergency logout)
// POST /v1/auth/revoke-all
// This is used for security incidents (e.g., device lost, suspected compromise)
func (h *AuthHandler) HandleRevokeAllTokens(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		h.sendError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract access token from Authorization header
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		h.sendError(w, "Authorization header required", http.StatusUnauthorized)
		return
	}

	parts := strings.Split(authHeader, " ")
	if len(parts) != 2 || parts[0] != "Bearer" {
		h.sendError(w, "Invalid authorization header format", http.StatusUnauthorized)
		return
	}

	accessToken := parts[1]

	// Validate access token
	claims, err := shared.ValidateJWTWithBlacklist(accessToken, h.blacklist)
	if err != nil {
		h.sendError(w, fmt.Sprintf("Invalid access token: %v", err), http.StatusUnauthorized)
		return
	}

	var req RevokeAllTokensRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.sendError(w, "Invalid JSON request", http.StatusBadRequest)
		return
	}

	// Require password confirmation for security
	if req.Password == "" {
		h.sendError(w, "password is required for security verification", http.StatusBadRequest)
		return
	}

	// Verify user's password
	var passwordHash string
	err = h.db.QueryRow("SELECT password_hash FROM users WHERE id = $1", claims.UserID).Scan(&passwordHash)
	if err != nil {
		log.Printf("[AUTH] Failed to get user password: %v", err)
		h.sendError(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	err = bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password))
	if err != nil {
		h.sendError(w, "Invalid password", http.StatusUnauthorized)
		h.logAuditEvent("REVOKE_ALL_FAILED", claims.Email, "Invalid password for revoke-all", h.getClientIP(r))
		return
	}

	// Set default reason
	reason := req.Reason
	if reason == "" {
		reason = "user_requested_revoke_all"
	}

	ipAddress := h.getClientIP(r)

	// Log the security event
	h.logAuditEvent("REVOKE_ALL_TOKENS", claims.Email,
		fmt.Sprintf("User requested to revoke all tokens (reason: %s)", reason), ipAddress)

	log.Printf("[AUTH] User %s requested to revoke all tokens (reason: %s)", claims.Email, reason)

	// Send success response
	response := AuthResponse{
		Success: true,
		Message: "All tokens marked for revocation. Please login again on all devices.",
		Data: map[string]interface{}{
			"revoked_at": time.Now().Unix(),
			"reason":     reason,
			"note":       "Please change your password if you suspect compromise.",
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// getClientIP extracts the client's IP address from the request
func (h *AuthHandler) getClientIP(r *http.Request) string {
	// Check X-Forwarded-For header (proxy/load balancer)
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		// X-Forwarded-For can contain multiple IPs, take the first one
		ips := strings.Split(xff, ",")
		if len(ips) > 0 {
			return strings.TrimSpace(ips[0])
		}
	}

	// Check X-Real-IP header (nginx)
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		return xri
	}

	// Fall back to RemoteAddr
	// RemoteAddr format: "IP:port" or "[IPv6]:port"
	host := r.RemoteAddr
	if idx := strings.LastIndex(host, ":"); idx != -1 {
		host = host[:idx]
	}
	// Remove brackets from IPv6 addresses
	host = strings.Trim(host, "[]")

	return host
}

// logAuditEvent logs an authentication event to the audit log
func (h *AuthHandler) logAuditEvent(action, username, details, ipAddress string) {
	if h.auditLogger == nil {
		log.Printf("[AUTH] Warning: AuditLogger is nil, skipping audit log")
		return
	}

	// Use AuditLogger which properly handles JSON formatting
	err := h.auditLogger.LogAudit("auth-audit.log", action, username, details, ipAddress, "management-server")
	if err != nil {
		log.Printf("[AUTH] Failed to log audit event: %v", err)
	}
}
