package main

import (
	"flag"
	"log"
	"os"

	"barqnet-backend/pkg/shared"
	"github.com/joho/godotenv"
	"golang.org/x/crypto/bcrypt"
)

// This script creates a test user for iOS development and testing
// Usage: go run scripts/create_test_user.go

func main() {
	// Parse flags
	email := flag.String("email", "test@barqnet.local", "Test user email")
	username := flag.String("username", "testuser", "Test user username")
	password := flag.String("password", "Test1234", "Test user password")
	serverID := flag.String("server", "test-server", "Server ID for test user")
	force := flag.Bool("force", false, "Force recreate user if exists")

	flag.Parse()

	// Load .env file
	if err := godotenv.Load(); err != nil {
		log.Printf("Warning: No .env file found, using environment variables only")
	}

	// Create database configuration from environment
	cfg := &shared.DatabaseConfig{
		Host:     getEnv("DB_HOST", "localhost"),
		Port:     5432,
		User:     getEnv("DB_USER", "vpnmanager"),
		Password: getEnv("DB_PASSWORD", ""),
		DBName:   getEnv("DB_NAME", "vpnmanager"),
		SSLMode:  getEnv("DB_SSLMODE", "disable"),
	}

	if cfg.Password == "" {
		log.Fatal("DB_PASSWORD not set in environment")
	}

	// Connect to database
	log.Printf("Connecting to database %s@%s:%d/%s...", cfg.User, cfg.Host, cfg.Port, cfg.DBName)
	db, err := shared.NewDatabase(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()
	log.Println("Database connection established")

	// Get the underlying connection
	conn := db.GetConnection()

	// Check if user already exists
	var existingUserID int
	err = conn.QueryRow(
		"SELECT id FROM users WHERE email = $1 OR username = $2",
		*email, *username,
	).Scan(&existingUserID)

	if err == nil {
		// User exists
		if *force {
			log.Printf("Test user exists (ID: %d), deleting...", existingUserID)
			_, err = conn.Exec("DELETE FROM users WHERE id = $1", existingUserID)
			if err != nil {
				log.Fatalf("Failed to delete existing user: %v", err)
			}
			log.Println("Existing user deleted")
		} else {
			log.Printf("Test user already exists (ID: %d)", existingUserID)
			log.Println("Use -force flag to recreate")
			return
		}
	}

	// Hash the password using bcrypt
	log.Println("Hashing password...")
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(*password), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("Failed to hash password: %v", err)
	}

	// Create the test user
	log.Println("Creating test user...")
	query := `
		INSERT INTO users (
			username,
			email,
			password_hash,
			server_id,
			status,
			active,
			created_via,
			created_by
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id
	`

	var userID int
	err = conn.QueryRow(
		query,
		*username,              // username
		*email,                 // email
		string(hashedPassword), // password_hash
		*serverID,              // server_id
		"active",               // status
		true,                   // active
		"testing",              // created_via
		"test-script",          // created_by
	).Scan(&userID)

	if err != nil {
		log.Fatalf("Failed to create test user: %v", err)
	}

	log.Println("")
	log.Println("========================================")
	log.Println("Test User Created Successfully!")
	log.Println("========================================")
	log.Printf("User ID:  %d", userID)
	log.Printf("Username: %s", *username)
	log.Printf("Email:    %s", *email)
	log.Printf("Password: %s", *password)
	log.Printf("Server:   %s", *serverID)
	log.Println("========================================")
	log.Println("")
	log.Println("You can now use these credentials to test the iOS app!")
	log.Println("Quick Login button in DEBUG mode will auto-fill these credentials.")
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
