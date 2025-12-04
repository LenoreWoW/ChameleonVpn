#!/bin/bash
# Quick script to run management server locally for iOS development

echo "🚀 Starting local management server for iOS development..."

cd barqnet-backend/apps/management

# Set environment variables
export DB_HOST="192.168.10.217"  # PostgreSQL on remote server
export DB_PORT="5432"
export DB_USER="barqnet"
export DB_PASSWORD="your_db_password_here"  # ⚠️ UPDATE THIS
export DB_NAME="barqnet"
export DB_SSLMODE="disable"
export MANAGEMENT_URL="http://127.0.0.1:8080"
export JWT_SECRET="your-super-secret-jwt-key-change-in-production"
export API_KEY="test-api-key-12345"
export EMAIL_SERVICE_MODE="local"  # Use local email service for dev
export AUDIT_FILE_ENABLED="true"
export AUDIT_DB_ENABLED="true"
export RATE_LIMIT_ENABLED="false"  # Disable for dev

# Build and run
echo "📦 Building management server..."
go build -o management

echo "▶️  Starting server on http://127.0.0.1:8080"
./management

