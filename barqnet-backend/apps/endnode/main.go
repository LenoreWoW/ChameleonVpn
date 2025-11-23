package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/joho/godotenv"

	"barqnet-backend/pkg/shared"
	"barqnet-backend/apps/endnode/api"
	"barqnet-backend/apps/endnode/manager"
)

func main() {
	var (
		configFile = flag.String("config", "endnode-config.json", "Configuration file path")
		serverID   = flag.String("server-id", "", "Server ID for this end-node")
		help       = flag.Bool("help", false, "Show help")
	)
	flag.Parse()

	if *help {
		showHelp()
		return
	}

	// Load .env file if it exists
	log.Println("========================================")
	log.Println("BarqNet Endnode Server - Starting...")
	log.Println("========================================")

	if err := godotenv.Load(); err != nil {
		log.Printf("[ENV] ⚠️  No .env file found, using environment variables only")
	} else {
		log.Printf("[ENV] ✅ Loaded configuration from .env file")
	}

	// Validate environment variables before proceeding
	// Note: Endnodes use ValidateEndnodeEnvironment() which doesn't require database credentials
	// Endnodes communicate with Management API only, no direct database access needed
	if _, err := shared.ValidateEndnodeEnvironment(); err != nil {
		log.Fatalf("❌ Environment validation failed: %v", err)
	}

	if *serverID == "" {
		log.Fatal("Server ID is required. Use -server-id flag or set ENDNODE_SERVER_ID environment variable")
	}

	// Load configuration
	config, err := loadConfig(*configFile)
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// End-nodes don't need direct database access
	// They communicate with the management server via API
	log.Println("End-node mode: No direct database connection needed")
	log.Println("Communication with management server via API only")

	// Create end-node manager (no database managers needed)
	endNodeManager := manager.NewEndNodeManager(
		*serverID,
		config,
	)

	// Start API server
	apiServer := api.NewEndNodeAPI(endNodeManager)
	
	// Start the API server in a goroutine
	go func() {
		if err := apiServer.Start(8080); err != nil {
			log.Fatalf("Failed to start API server: %v", err)
		}
	}()

	// Wait for the API server to fully start and be ready
	log.Printf("Waiting for API server to fully initialize...")
	if err := waitForAPIServer("http://localhost:8080/health", 10*time.Second); err != nil {
		log.Printf("Warning: API server health check failed: %v", err)
		log.Printf("Proceeding with registration anyway...")
	} else {
		log.Printf("✅ API server is ready")
	}

	// Register with management server
	log.Printf("Attempting to register with management server...")
	if err := endNodeManager.RegisterWithManagement(); err != nil {
		log.Printf("❌ Failed to register with management server: %v", err)
		log.Printf("Please check:")
		log.Printf("  - Management server is running and accessible")
		log.Printf("  - Management URL is correct: %s", config.ManagementURL)
		log.Printf("  - API key is valid (if required)")
		log.Printf("  - Network connectivity to management server")
		log.Printf("End-node will continue running but may not be visible to management server")
	} else {
		log.Printf("✅ Successfully registered with management server")
	}

	// Start health check routine
	go endNodeManager.StartHealthCheck()

	// Start sync routine
	go endNodeManager.StartSyncRoutine()

	log.Printf("End-node server started with ID: %s", *serverID)
	log.Printf("API server running on port 8080")
	log.Printf("Management URL: %s", config.ManagementURL)

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	log.Println("Shutting down end-node server...")
	
	// Deregister from management server
	if err := endNodeManager.DeregisterFromManagement(); err != nil {
		log.Printf("Warning: Failed to deregister from management server: %v", err)
	}
}

func loadConfig(configFile string) (*shared.EndNodeConfig, error) {
	// For now, return a default config
	// In production, this would load from JSON file
	return &shared.EndNodeConfig{
		ServerID:      os.Getenv("ENDNODE_SERVER_ID"),
		ManagementURL: os.Getenv("MANAGEMENT_URL"),
		APIKey:        os.Getenv("API_KEY"),
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

// waitForAPIServer waits for the API server to be ready
func waitForAPIServer(url string, timeout time.Duration) error {
	client := &http.Client{Timeout: 2 * time.Second}
	deadline := time.Now().Add(timeout)
	
	for time.Now().Before(deadline) {
		resp, err := client.Get(url)
		if err == nil && resp.StatusCode == 200 {
			resp.Body.Close()
			return nil
		}
		if resp != nil {
			resp.Body.Close()
		}
		time.Sleep(500 * time.Millisecond)
	}
	
	return fmt.Errorf("API server not ready after %v", timeout)
}

func showHelp() {
	fmt.Println("VPN Manager End-Node Server")
	fmt.Println("==========================")
	fmt.Println("")
	fmt.Println("Usage:")
	fmt.Println("  vpnmanager-endnode -server-id <server-id> [options]")
	fmt.Println("")
	fmt.Println("Options:")
	fmt.Println("  -config string")
	fmt.Println("        Configuration file path (default: endnode-config.json)")
	fmt.Println("  -server-id string")
	fmt.Println("        Server ID for this end-node (required)")
	fmt.Println("  -help")
	fmt.Println("        Show this help message")
	fmt.Println("")
	fmt.Println("Environment Variables:")
	fmt.Println("  ENDNODE_SERVER_ID    Server ID for this end-node")
	fmt.Println("  MANAGEMENT_URL       Management server URL")
	fmt.Println("  API_KEY              API key for authentication")
	fmt.Println("  DB_HOST              Database host (default: localhost)")
	fmt.Println("  DB_USER              Database user (default: vpnmanager)")
	fmt.Println("  DB_PASSWORD          Database password")
	fmt.Println("  DB_NAME              Database name (default: vpnmanager)")
	fmt.Println("  DB_SSLMODE           Database SSL mode (default: disable)")
	fmt.Println("")
	fmt.Println("Examples:")
	fmt.Println("  vpnmanager-endnode -server-id server-1")
	fmt.Println("  ENDNODE_SERVER_ID=server-1 vpnmanager-endnode")
}
