package api

import (
	"database/sql"
	"log"
	"net/http"

	"barqnet-backend/pkg/shared"
)

// Example: How to integrate the authentication API with your existing ManagementAPI

// IntegrateAuthEndpoints adds authentication endpoints to the existing API
// This is an example of how to integrate the auth handler with your server
func (api *ManagementAPI) IntegrateAuthEndpoints(mux *http.ServeMux, db *sql.DB) {
	// Initialize OTP service (use MockOTPService for development)
	otpService := NewMockOTPService()

	// Initialize rate limiter (required for production)
	// For development, you can pass nil, but production requires rate limiting
	rateLimiter, err := shared.NewRateLimiter()
	if err != nil {
		log.Printf("[WARNING] Failed to initialize rate limiter: %v", err)
		log.Printf("[WARNING] Continuing without rate limiting - NOT RECOMMENDED FOR PRODUCTION")
		rateLimiter = nil // Will disable rate limiting
	}

	// Initialize auth handler
	authHandler := NewAuthHandler(db, otpService, rateLimiter)

	// Register public authentication endpoints
	mux.HandleFunc("/auth/send-otp", authHandler.HandleSendOTP)
	mux.HandleFunc("/auth/register", authHandler.HandleRegister)
	mux.HandleFunc("/auth/login", authHandler.HandleLogin)
	mux.HandleFunc("/auth/refresh", authHandler.HandleRefresh)
	mux.HandleFunc("/auth/logout", authHandler.HandleLogout)

	// Example: Protect existing endpoints with JWT authentication
	// Replace the existing handlers with protected versions

	// Original: mux.HandleFunc("/api/users", api.handleUsers)
	// Protected version:
	mux.HandleFunc("/api/users", authHandler.JWTAuthMiddleware(api.handleUsers))

	// Original: mux.HandleFunc("/api/endnodes", api.handleEndNodes)
	// Protected version:
	mux.HandleFunc("/api/endnodes", authHandler.JWTAuthMiddleware(api.handleEndNodes))

	// You can also create a mixed approach where some endpoints are public
	// and others are protected:

	// Public endpoint (no auth required)
	mux.HandleFunc("/health", api.handleHealth)

	// Protected endpoint (JWT required)
	mux.HandleFunc("/api/profile", authHandler.JWTAuthMiddleware(api.handleUserProfile))
}

// Example protected handler that uses JWT claims
func (api *ManagementAPI) handleUserProfile(w http.ResponseWriter, r *http.Request) {
	// Extract user information from context (set by JWTAuthMiddleware)
	phoneNumber, ok := r.Context().Value("phone_number").(string)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	userID, ok := r.Context().Value("user_id").(int)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Use the authenticated user's information
	// ... your handler logic here ...

	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"phone_number": "` + phoneNumber + `", "user_id": ` + string(rune(userID)) + `}`))
}

// Example: Modified Start method with authentication
func ExampleStartWithAuth() {
	// This is an example - do not use directly
	// Modify your existing Start method in api.go to include auth endpoints

	/*
	func (api *ManagementAPI) Start(port int) error {
		mux := http.NewServeMux()

		// Integrate authentication endpoints
		api.IntegrateAuthEndpoints(mux, api.manager.GetDB())

		// ... rest of your existing code ...

		server := &http.Server{
			Addr:         fmt.Sprintf(":%d", port),
			Handler:      api.middleware(mux),
			ReadTimeout:  15 * time.Second,
			WriteTimeout: 15 * time.Second,
		}

		return server.ListenAndServe()
	}
	*/
}

// Example: How to use in main.go
func ExampleMainIntegration() {
	// This is an example - do not use directly

	/*
	package main

	import (
		"log"
		"os"

		"barqnet-backend/apps/management/api"
		"barqnet-backend/apps/management/manager"
		"barqnet-backend/pkg/shared"
	)

	func main() {
		// Set JWT secret (REQUIRED!)
		os.Setenv("JWT_SECRET", "your-super-secret-key-minimum-32-characters-long")

		// Initialize database
		dbConfig := &shared.DatabaseConfig{
			Host:     os.Getenv("DB_HOST"),
			Port:     5432,
			User:     os.Getenv("DB_USER"),
			Password: os.Getenv("DB_PASSWORD"),
			DBName:   os.Getenv("DB_NAME"),
			SSLMode:  "disable",
		}

		db, err := shared.NewDatabase(dbConfig)
		if err != nil {
			log.Fatalf("Failed to connect to database: %v", err)
		}
		defer db.Close()

		// Initialize manager
		mgr := manager.NewManagementManager(db)

		// Initialize API with authentication support
		managementAPI := api.NewManagementAPI(mgr)

		// Start server (will include auth endpoints if IntegrateAuthEndpoints is called)
		log.Println("Starting Management API server on :8080")
		log.Println("Auth endpoints available at:")
		log.Println("  POST /auth/send-otp")
		log.Println("  POST /auth/register")
		log.Println("  POST /auth/login")
		log.Println("  POST /auth/refresh")
		log.Println("  POST /auth/logout")

		if err := managementAPI.Start(8080); err != nil {
			log.Fatalf("Server failed: %v", err)
		}
	}
	*/
}

// Production Notes:
//
// 1. Replace MockOTPService with a real SMS gateway integration
// 2. Set JWT_SECRET environment variable to a strong random value
// 3. Enable HTTPS/TLS in production
// 4. Implement rate limiting on auth endpoints
// 5. Configure CORS properly for your frontend domain
// 6. Set up monitoring and alerting for failed login attempts
// 7. Implement account lockout after N failed attempts
// 8. Use Redis or similar for OTP storage with TTL
// 9. Add refresh token rotation for enhanced security
// 10. Implement proper logging and monitoring
