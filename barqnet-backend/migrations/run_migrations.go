package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"barqnet-backend/pkg/shared"
)

// This is a standalone utility to run database migrations
// Usage: go run migrations/run_migrations.go -host localhost -port 5432 -user postgres -password yourpass -dbname barqnet

func main() {
	// Parse command-line flags
	host := flag.String("host", "localhost", "Database host")
	port := flag.Int("port", 5432, "Database port")
	user := flag.String("user", "postgres", "Database user")
	password := flag.String("password", "", "Database password")
	dbname := flag.String("dbname", "barqnet", "Database name")
	sslmode := flag.String("sslmode", "disable", "SSL mode (disable, require, verify-ca, verify-full)")
	migrationsDir := flag.String("migrations", "./migrations", "Path to migrations directory")
	status := flag.Bool("status", false, "Show migration status only (don't run migrations)")

	flag.Parse()

	// Validate required flags
	if *password == "" {
		fmt.Println("Error: -password flag is required")
		flag.Usage()
		os.Exit(1)
	}

	// Create database configuration
	cfg := &shared.DatabaseConfig{
		Host:     *host,
		Port:     *port,
		User:     *user,
		Password: *password,
		DBName:   *dbname,
		SSLMode:  *sslmode,
	}

	// Connect to database
	log.Printf("Connecting to database %s@%s:%d/%s...", *user, *host, *port, *dbname)
	db, err := shared.NewDatabase(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()
	log.Println("Database connection established")

	// If status flag is set, just show migration status
	if *status {
		showMigrationStatus(db)
		return
	}

	// Get absolute path to migrations directory
	absPath, err := filepath.Abs(*migrationsDir)
	if err != nil {
		log.Fatalf("Failed to get absolute path: %v", err)
	}

	// Check if migrations directory exists
	if _, err := os.Stat(absPath); os.IsNotExist(err) {
		log.Fatalf("Migrations directory does not exist: %s", absPath)
	}

	// Run migrations
	log.Printf("Running migrations from: %s", absPath)
	if err := db.RunMigrations(absPath); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	log.Println("")
	log.Println("========================================")
	log.Println("All migrations completed successfully!")
	log.Println("========================================")

	// Show final status
	showMigrationStatus(db)
}

func showMigrationStatus(db *shared.DB) {
	log.Println("")
	log.Println("========================================")
	log.Println("Migration Status:")
	log.Println("========================================")

	status, err := db.GetMigrationStatus()
	if err != nil {
		log.Printf("Failed to get migration status: %v", err)
		return
	}

	if len(status) == 0 {
		log.Println("No migrations have been applied yet")
		return
	}

	fmt.Println("")
	fmt.Printf("%-8s %-30s %-25s\n", "Version", "Name", "Applied At")
	fmt.Println("------------------------------------------------------------------------")

	for _, migration := range status {
		fmt.Printf("%-8d %-30s %-25s\n",
			migration["version"],
			migration["name"],
			migration["applied_at"])
	}

	fmt.Println("")
	log.Printf("Total migrations applied: %d", len(status))
}
