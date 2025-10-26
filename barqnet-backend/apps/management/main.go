package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"vpnmanager/pkg/shared"
	"vpnmanager/apps/management/api"
	"vpnmanager/apps/management/manager"
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

	// Start API server
	apiServer := api.NewManagementAPI(managementManager)
	
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
			User:     getEnv("DB_USER", "vpnmanager"),
			Password: getEnv("DB_PASSWORD", ""),
			DBName:   getEnv("DB_NAME", "vpnmanager"),
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
	fmt.Println("  DB_USER              Database user (default: vpnmanager)")
	fmt.Println("  DB_PASSWORD          Database password")
	fmt.Println("  DB_NAME              Database name (default: vpnmanager)")
	fmt.Println("  DB_SSLMODE           Database SSL mode (default: disable)")
	fmt.Println("")
	fmt.Println("Examples:")
	fmt.Println("  vpnmanager-management")
	fmt.Println("  vpnmanager-management -server-id main-management")
}
