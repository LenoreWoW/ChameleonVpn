# VPN Manager Distributed Architecture Makefile

.PHONY: all build-endnode build-management build-shared clean test deps

# Default target
all: deps build-shared build-endnode build-management

# Build shared components
build-shared:
	@echo "Building shared components..."
	@go build -o bin/shared ./pkg/shared/...

# Build end-node application
build-endnode:
	@echo "Building end-node application..."
	@go build -o bin/vpnmanager-endnode ./apps/endnode/

# Build management application
build-management:
	@echo "Building management application..."
	@go build -o bin/vpnmanager-management ./apps/management/

# Build both applications
build: build-endnode build-management

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf bin/
	@go clean

# Install dependencies
deps:
	@echo "Installing dependencies..."
	@go mod download
	@go mod tidy

# Run tests
test:
	@echo "Running tests..."
	@go test ./...

# Run end-node with default config
run-endnode:
	@echo "Running end-node application..."
	@./bin/vpnmanager-endnode -server-id $(SERVER_ID) -config endnode-config.json

# Run management server
run-management:
	@echo "Running management server..."
	@./bin/vpnmanager-management -server-id management-server -config management-config.json

# Create sample configuration files
config:
	@echo "Creating sample configuration files..."
	@echo '{"server_id": "endnode-1", "management_url": "http://localhost:8080", "api_key": "your-api-key", "database": {"host": "localhost", "port": 5432, "user": "vpnmanager", "password": "password", "dbname": "vpnmanager", "sslmode": "disable"}}' > endnode-config.json
	@echo '{"server_id": "management-server", "api_key": "your-api-key", "database": {"host": "localhost", "port": 5432, "user": "vpnmanager", "password": "password", "dbname": "vpnmanager", "sslmode": "disable"}}' > management-config.json

# Setup database
setup-db:
	@echo "Setting up PostgreSQL database..."
	@echo "Please ensure PostgreSQL is running and create the database:"
	@echo "CREATE DATABASE vpnmanager;"
	@echo "CREATE USER vpnmanager WITH PASSWORD 'password';"
	@echo "GRANT ALL PRIVILEGES ON DATABASE vpnmanager TO vpnmanager;"

# Help
help:
	@echo "VPN Manager Distributed Architecture"
	@echo "===================================="
	@echo ""
	@echo "Available targets:"
	@echo "  all              - Build all components"
	@echo "  build-endnode    - Build end-node application"
	@echo "  build-management - Build management application"
	@echo "  build            - Build both applications"
	@echo "  clean            - Clean build artifacts"
	@echo "  deps             - Install dependencies"
	@echo "  test             - Run tests"
	@echo "  config           - Create sample configuration files"
	@echo "  setup-db         - Show database setup instructions"
	@echo "  run-endnode      - Run end-node (set SERVER_ID=your-server-id)"
	@echo "  run-management   - Run management server"
	@echo "  help             - Show this help"
	@echo ""
	@echo "Environment variables:"
	@echo "  SERVER_ID        - Server ID for end-node"
	@echo "  DB_HOST          - Database host (default: localhost)"
	@echo "  DB_USER          - Database user (default: vpnmanager)"
	@echo "  DB_PASSWORD      - Database password"
	@echo "  DB_NAME          - Database name (default: vpnmanager)"
	@echo "  MANAGEMENT_URL   - Management server URL"
	@echo "  API_KEY          - API key for authentication"
