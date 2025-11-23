package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/joho/godotenv"

	"barqnet-backend/pkg/shared"
	"barqnet-backend/apps/management/api"
	"barqnet-backend/apps/management/manager"
)

func main() {
	var (
		configFile = flag.String("config", "management-config.json", "Configuration file path")
		serverID = flag.String("server-id", "management-server", "Server ID for management server")
		help     = flag.Bool("help", false, "Show help")
	)
	flag.Parse()

	if *help {
		showHelp()
		return
	}

	// Load .env file if it exists
	log.Println("========================================")
	log.Println("BarqNet Management Server - Starting...")
	log.Println("========================================")

	if err := godotenv.Load(); err != nil {
		log.Printf("[ENV] ⚠️  No .env file found, using environment variables only")
	} else {
		log.Printf("[ENV] ✅ Loaded configuration from .env file")
	}

	// Validate environment variables before proceeding
	if _, err := shared.ValidateEnvironment(); err != nil {
		log.Fatalf("❌ Environment validation failed: %v", err)
	}

	// Load configuration
	config, err := loadConfig(*configFile)
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Connect to database
	db, err := shared.NewDatabase(&config.Database)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Run database migrations
	log.Println("[DB] Running database migrations...")
	migrationsPath := "../../migrations"
	if err := db.RunMigrations(migrationsPath); err != nil {
		log.Fatalf("Failed to run database migrations: %v", err)
	}
	log.Println("[DB] ✅ Database migrations completed successfully")

	// Initialize rate limiter
	rateLimiter, err := shared.NewRateLimiter()
	if err != nil {
		log.Printf("Warning: Rate limiter initialization had issues: %v", err)
		log.Println("Continuing with degraded rate limiting...")
	}
	defer func() {
		if rateLimiter != nil {
			rateLimiter.Close()
		}
	}()

	// Create managers
	userManager := shared.NewUserManager(db)
	serverManager := shared.NewServerManager(db)
	auditManager := shared.NewAuditManager(db)

	// Create management server manager
	managementManager := manager.NewManagementManager(
		*serverID,
		config,
		userManager,
		serverManager,
		auditManager,
	)

	// Start API server with rate limiter
	apiServer := api.NewManagementAPI(managementManager, rateLimiter)
	
	// Start the API server in a goroutine
	go func() {
		if err := apiServer.Start(8080); err != nil {
			log.Fatalf("Failed to start API server: %v", err)
		}
	}()

	// Start end-node monitoring
	go managementManager.StartEndNodeMonitoring()

	// Start user sync coordination
	go managementManager.StartUserSyncCoordination()

	log.Printf("Management server started with ID: %s", *serverID)
	log.Printf("API server running on port 8080")
	log.Printf("Database: %s:%d/%s", config.Database.Host, config.Database.Port, config.Database.DBName)

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	log.Println("Shutting down management server...")
}

func loadConfig(configFile string) (*shared.ManagementConfig, error) {
	// For now, return a default config
	// In production, this would load from JSON file
	return &shared.ManagementConfig{
		ServerID: "management-server",
		APIKey:   os.Getenv("API_KEY"),
		Database: shared.DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     5432,
			User:     getEnv("DB_USER", "barqnet"),
			Password: getEnv("DB_PASSWORD", ""),
			DBName:   getEnv("DB_NAME", "barqnet"),
			SSLMode:  getEnv("DB_SSLMODE", "disable"),
		},
	}, nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func showHelp() {
	fmt.Println("VPN Manager Management Server")
	fmt.Println("============================")
	fmt.Println("")
	fmt.Println("Usage:")
	fmt.Println("  vpnmanager-management [options]")
	fmt.Println("")
	fmt.Println("Options:")
	fmt.Println("  -config string")
	fmt.Println("        Configuration file path (default: management-config.json)")
	fmt.Println("  -server-id string")
	fmt.Println("        Server ID for management server (default: management-server)")
	fmt.Println("  -help")
	fmt.Println("        Show this help message")
	fmt.Println("")
	fmt.Println("Environment Variables:")
	fmt.Println("  API_KEY              API key for authentication")
	fmt.Println("  DB_HOST              Database host (default: localhost)")
	fmt.Println("  DB_USER              Database user (default: barqnet)")
	fmt.Println("  DB_PASSWORD          Database password")
	fmt.Println("  DB_NAME              Database name (default: barqnet)")
	fmt.Println("  DB_SSLMODE           Database SSL mode (default: disable)")
	fmt.Println("")
	fmt.Println("Rate Limiting:")
	fmt.Println("  RATE_LIMIT_ENABLED   Enable rate limiting (default: true)")
	fmt.Println("  REDIS_HOST           Redis host (default: localhost)")
	fmt.Println("  REDIS_PORT           Redis port (default: 6379)")
	fmt.Println("  REDIS_PASSWORD       Redis password (optional)")
	fmt.Println("  REDIS_DB             Redis database number (default: 0)")
	fmt.Println("")
	fmt.Println("Examples:")
	fmt.Println("  vpnmanager-management")
	fmt.Println("  vpnmanager-management -server-id main-management")
}
