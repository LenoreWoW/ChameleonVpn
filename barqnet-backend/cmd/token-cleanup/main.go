package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	"barqnet-backend/pkg/shared"

	_ "github.com/lib/pq"
)

// TokenCleanupJob performs periodic cleanup of expired blacklist entries
// This should be run as a cron job (e.g., hourly or daily)
//
// Usage:
//   go run cmd/token-cleanup/main.go
//   Or compile and run: ./token-cleanup
//
// Environment variables required:
//   DB_HOST     - PostgreSQL host (default: localhost)
//   DB_PORT     - PostgreSQL port (default: 5432)
//   DB_USER     - Database user
//   DB_PASSWORD - Database password
//   DB_NAME     - Database name
//   DB_SSLMODE  - SSL mode (default: disable)

func main() {
	// Command line flags
	dryRun := flag.Bool("dry-run", false, "Simulate cleanup without deleting entries")
	verbose := flag.Bool("verbose", false, "Enable verbose output")
	flag.Parse()

	log.SetPrefix("[TOKEN_CLEANUP] ")
	log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)

	if *verbose {
		log.Println("Starting token blacklist cleanup job...")
	}

	// Get database configuration from environment
	dbConfig := &shared.DatabaseConfig{
		Host:     getEnv("DB_HOST", "localhost"),
		Port:     getEnvInt("DB_PORT", 5432),
		User:     getEnv("DB_USER", "postgres"),
		Password: os.Getenv("DB_PASSWORD"),
		DBName:   getEnv("DB_NAME", "barqnet"),
		SSLMode:  getEnv("DB_SSLMODE", "disable"),
	}

	if dbConfig.Password == "" {
		log.Fatal("DB_PASSWORD environment variable is required")
	}

	// Connect to database
	dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		dbConfig.Host, dbConfig.Port, dbConfig.User, dbConfig.Password, dbConfig.DBName, dbConfig.SSLMode)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Test connection
	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}

	if *verbose {
		log.Printf("Connected to database: %s@%s:%d/%s", dbConfig.User, dbConfig.Host, dbConfig.Port, dbConfig.DBName)
	}

	// Create blacklist handler
	blacklist := shared.NewTokenBlacklist(db)

	// Get statistics before cleanup
	if *verbose {
		stats, err := blacklist.GetBlacklistStats()
		if err != nil {
			log.Printf("Failed to get stats before cleanup: %v", err)
		} else {
			log.Printf("Before cleanup: %d total entries, %d active, %d expired",
				stats["total_entries"], stats["active_entries"], stats["expired_entries"])
		}
	}

	// Perform cleanup
	startTime := time.Now()

	if *dryRun {
		// Dry run: Just count entries that would be deleted
		var expiredCount int
		err := db.QueryRow("SELECT COUNT(*) FROM token_blacklist WHERE expires_at < $1", time.Now()).Scan(&expiredCount)
		if err != nil {
			log.Fatalf("Failed to count expired entries: %v", err)
		}
		log.Printf("DRY RUN: Would delete %d expired entries", expiredCount)
		return
	}

	deletedCount, err := blacklist.CleanupExpiredEntries()
	if err != nil {
		log.Fatalf("Cleanup failed: %v", err)
	}

	duration := time.Since(startTime)

	// Log results
	if deletedCount > 0 {
		log.Printf("Cleanup completed: deleted %d expired entries in %v", deletedCount, duration)
	} else {
		if *verbose {
			log.Printf("Cleanup completed: no expired entries found (took %v)", duration)
		}
	}

	// Get statistics after cleanup
	if *verbose && deletedCount > 0 {
		stats, err := blacklist.GetBlacklistStats()
		if err != nil {
			log.Printf("Failed to get stats after cleanup: %v", err)
		} else {
			log.Printf("After cleanup: %d total entries, %d active, %d expired",
				stats["total_entries"], stats["active_entries"], stats["expired_entries"])
		}
	}

	// Exit with success
	os.Exit(0)
}

// getEnv gets an environment variable with a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEnvInt gets an integer environment variable with a default value
func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		var intValue int
		if _, err := fmt.Sscanf(value, "%d", &intValue); err == nil {
			return intValue
		}
	}
	return defaultValue
}
