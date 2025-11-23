package shared

import (
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
)

// RequiredEnvVar represents a required environment variable with validation
type RequiredEnvVar struct {
	Name         string
	Description  string
	DefaultValue string // Empty string means no default (required)
	MinLength    int    // Minimum length for security-sensitive values
}

// EnvValidationResult contains the result of environment variable validation
type EnvValidationResult struct {
	Valid   bool
	Missing []string
	Warnings []string
}

// Required environment variables for BarqNet backend
var requiredEnvVars = []RequiredEnvVar{
	// Database Configuration (CRITICAL - No defaults)
	{Name: "DB_HOST", Description: "Database host address", DefaultValue: "", MinLength: 0},
	{Name: "DB_PORT", Description: "Database port number", DefaultValue: "", MinLength: 0},
	{Name: "DB_USER", Description: "Database username", DefaultValue: "", MinLength: 0},
	{Name: "DB_PASSWORD", Description: "Database password", DefaultValue: "", MinLength: 8},
	{Name: "DB_NAME", Description: "Database name", DefaultValue: "", MinLength: 0},
	{Name: "DB_SSLMODE", Description: "Database SSL mode", DefaultValue: "disable", MinLength: 0},

	// Security Configuration (CRITICAL - No defaults)
	{Name: "JWT_SECRET", Description: "JWT signing secret", DefaultValue: "", MinLength: 32},
	{Name: "API_KEY", Description: "API authentication key", DefaultValue: "", MinLength: 16},

	// Redis Configuration (OPTIONAL - Has fallbacks)
	{Name: "REDIS_HOST", Description: "Redis host", DefaultValue: "localhost", MinLength: 0},
	{Name: "REDIS_PORT", Description: "Redis port", DefaultValue: "6379", MinLength: 0},
	{Name: "REDIS_DB", Description: "Redis database number", DefaultValue: "0", MinLength: 0},
}

// ValidateEnvironment validates all required environment variables
// Returns an error if critical variables are missing or invalid
func ValidateEnvironment() (*EnvValidationResult, error) {
	result := &EnvValidationResult{
		Valid:    true,
		Missing:  []string{},
		Warnings: []string{},
	}

	log.Println("[ENV] Validating environment variables...")

	for _, envVar := range requiredEnvVars {
		value := os.Getenv(envVar.Name)

		// Check if variable is set
		if value == "" {
			if envVar.DefaultValue == "" {
				// No default - this is REQUIRED
				result.Valid = false
				result.Missing = append(result.Missing, envVar.Name)
				log.Printf("[ENV] ❌ MISSING: %s (%s)", envVar.Name, envVar.Description)
			} else {
				// Has default - use it
				os.Setenv(envVar.Name, envVar.DefaultValue)
				log.Printf("[ENV] ⚠️  USING DEFAULT: %s = %s", envVar.Name, envVar.DefaultValue)
				result.Warnings = append(result.Warnings,
					fmt.Sprintf("%s not set, using default: %s", envVar.Name, envVar.DefaultValue))
			}
			continue
		}

		// Validate minimum length for security-sensitive variables
		if envVar.MinLength > 0 && len(value) < envVar.MinLength {
			result.Valid = false
			result.Missing = append(result.Missing,
				fmt.Sprintf("%s (too short: %d chars, minimum: %d chars)",
					envVar.Name, len(value), envVar.MinLength))
			log.Printf("[ENV] ❌ INVALID: %s is too short (%d chars, minimum %d required)",
				envVar.Name, len(value), envVar.MinLength)
			continue
		}

		// Security warnings for weak values
		if envVar.Name == "JWT_SECRET" && isWeakSecret(value) {
			result.Warnings = append(result.Warnings,
				"JWT_SECRET appears weak - use a strong random value in production")
			log.Printf("[ENV] ⚠️  WARNING: JWT_SECRET may be weak - ensure it's random and secure")
		}

		if envVar.Name == "DB_PASSWORD" && isWeakPassword(value) {
			result.Warnings = append(result.Warnings,
				"DB_PASSWORD appears weak - use a strong password in production")
			log.Printf("[ENV] ⚠️  WARNING: DB_PASSWORD may be weak - use a strong password")
		}

		// Mask sensitive values in logs
		maskedValue := value
		if isSensitiveVar(envVar.Name) {
			maskedValue = maskSensitiveValue(value)
		}

		log.Printf("[ENV] ✅ VALID: %s = %s", envVar.Name, maskedValue)
	}

	// Validate numeric environment variables
	if err := validateNumericEnvVars(); err != nil {
		result.Valid = false
		result.Missing = append(result.Missing, err.Error())
	}

	// Print summary
	log.Println("[ENV] " + strings.Repeat("=", 60))
	if result.Valid {
		log.Println("[ENV] ✅ Environment validation PASSED")
		if len(result.Warnings) > 0 {
			log.Printf("[ENV] ⚠️  %d warnings (see above)", len(result.Warnings))
		}
	} else {
		log.Println("[ENV] ❌ Environment validation FAILED")
		log.Printf("[ENV] Missing/invalid variables: %d", len(result.Missing))
		return result, fmt.Errorf("missing required environment variables: %s",
			strings.Join(result.Missing, ", "))
	}
	log.Println("[ENV] " + strings.Repeat("=", 60))

	return result, nil
}

// validateNumericEnvVars validates that numeric environment variables are valid integers
func validateNumericEnvVars() error {
	numericVars := map[string]string{
		"DB_PORT":    os.Getenv("DB_PORT"),
		"REDIS_PORT": os.Getenv("REDIS_PORT"),
		"REDIS_DB":   os.Getenv("REDIS_DB"),
	}

	for name, value := range numericVars {
		if value == "" {
			continue // Already handled by main validation
		}
		if _, err := strconv.Atoi(value); err != nil {
			return fmt.Errorf("%s must be a valid integer (got: %s)", name, value)
		}
	}

	return nil
}

// isSensitiveVar checks if an environment variable contains sensitive data
func isSensitiveVar(name string) bool {
	sensitiveVars := []string{
		"PASSWORD", "SECRET", "KEY", "TOKEN", "PRIVATE",
	}
	nameUpper := strings.ToUpper(name)
	for _, sensitive := range sensitiveVars {
		if strings.Contains(nameUpper, sensitive) {
			return true
		}
	}
	return false
}

// maskSensitiveValue masks sensitive values for logging
func maskSensitiveValue(value string) string {
	if len(value) <= 4 {
		return "****"
	}
	return value[:2] + strings.Repeat("*", len(value)-4) + value[len(value)-2:]
}

// isWeakSecret checks if a JWT secret is weak (common test values)
func isWeakSecret(secret string) bool {
	weakSecrets := []string{
		"your_jwt_secret",
		"test_secret",
		"secret",
		"password",
		"123456",
		"change_me",
		"your_jwt_secret_key_here",
	}
	lowerSecret := strings.ToLower(secret)
	for _, weak := range weakSecrets {
		if strings.Contains(lowerSecret, weak) {
			return true
		}
	}
	return len(secret) < 32 // JWT secrets should be at least 32 characters
}

// isWeakPassword checks if a database password is weak
func isWeakPassword(password string) bool {
	weakPasswords := []string{
		"password",
		"123456",
		"admin",
		"root",
		"postgres",
		"barqnet123", // Example password from .env.example
	}
	lowerPassword := strings.ToLower(password)
	for _, weak := range weakPasswords {
		if lowerPassword == weak {
			return true
		}
	}
	return len(password) < 8 // Passwords should be at least 8 characters
}

// GetEnvWithDefault gets an environment variable with a default value
func GetEnvWithDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// GetEnvAsInt gets an environment variable as an integer with a default value
func GetEnvAsInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
		log.Printf("[ENV] Warning: %s is not a valid integer, using default: %d", key, defaultValue)
	}
	return defaultValue
}

// GetEnvAsBool gets an environment variable as a boolean with a default value
func GetEnvAsBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		lowerValue := strings.ToLower(value)
		if lowerValue == "true" || lowerValue == "1" || lowerValue == "yes" {
			return true
		}
		if lowerValue == "false" || lowerValue == "0" || lowerValue == "no" {
			return false
		}
		log.Printf("[ENV] Warning: %s is not a valid boolean, using default: %v", key, defaultValue)
	}
	return defaultValue
}

// MustGetEnv gets an environment variable or panics if not set
func MustGetEnv(key string) string {
	value := os.Getenv(key)
	if value == "" {
		log.Fatalf("[ENV] FATAL: Required environment variable %s is not set", key)
	}
	return value
}

// ValidateEndnodeEnvironment validates environment variables for endnode servers
// Endnodes do NOT need database access - they communicate with Management API only
func ValidateEndnodeEnvironment() (*EnvValidationResult, error) {
	result := &EnvValidationResult{
		Valid:    true,
		Missing:  []string{},
		Warnings: []string{},
	}

	log.Println("[ENV] Validating endnode environment variables...")
	log.Println("[ENV] Note: Endnodes use Management API, no direct database access needed")

	// Endnode-specific required variables (NO database credentials)
	endnodeRequiredVars := []RequiredEnvVar{
		// Security Configuration (CRITICAL)
		{Name: "JWT_SECRET", Description: "JWT signing secret (must match management server)", DefaultValue: "", MinLength: 32},
		{Name: "API_KEY", Description: "API key for management server authentication", DefaultValue: "", MinLength: 16},

		// Management Server Connection (CRITICAL)
		{Name: "MANAGEMENT_URL", Description: "Management server API URL", DefaultValue: "", MinLength: 0},

		// Redis Configuration (OPTIONAL - for caching)
		{Name: "REDIS_HOST", Description: "Redis host", DefaultValue: "localhost", MinLength: 0},
		{Name: "REDIS_PORT", Description: "Redis port", DefaultValue: "6379", MinLength: 0},
		{Name: "REDIS_DB", Description: "Redis database number", DefaultValue: "0", MinLength: 0},
	}

	for _, envVar := range endnodeRequiredVars {
		value := os.Getenv(envVar.Name)

		// Check if variable is set
		if value == "" {
			if envVar.DefaultValue == "" {
				// No default - this is REQUIRED
				result.Valid = false
				result.Missing = append(result.Missing, envVar.Name)
				log.Printf("[ENV] ❌ MISSING: %s (%s)", envVar.Name, envVar.Description)
			} else {
				// Has default - use it
				os.Setenv(envVar.Name, envVar.DefaultValue)
				log.Printf("[ENV] ⚠️  USING DEFAULT: %s = %s", envVar.Name, envVar.DefaultValue)
				result.Warnings = append(result.Warnings,
					fmt.Sprintf("%s not set, using default: %s", envVar.Name, envVar.DefaultValue))
			}
			continue
		}

		// Validate minimum length for security-sensitive variables
		if envVar.MinLength > 0 && len(value) < envVar.MinLength {
			result.Valid = false
			result.Missing = append(result.Missing,
				fmt.Sprintf("%s (too short: %d chars, minimum: %d chars)",
					envVar.Name, len(value), envVar.MinLength))
			log.Printf("[ENV] ❌ INVALID: %s is too short (%d chars, minimum %d required)",
				envVar.Name, len(value), envVar.MinLength)
			continue
		}

		// Security warnings
		if envVar.Name == "JWT_SECRET" && isWeakSecret(value) {
			result.Warnings = append(result.Warnings,
				"JWT_SECRET appears weak - use a strong random value")
			log.Printf("[ENV] ⚠️  WARNING: JWT_SECRET may be weak")
		}

		// Mask sensitive values in logs
		maskedValue := value
		if isSensitiveVar(envVar.Name) {
			maskedValue = maskSensitiveValue(value)
		}

		log.Printf("[ENV] ✅ VALID: %s = %s", envVar.Name, maskedValue)
	}

	// Validate Redis port is numeric
	if redisPort := os.Getenv("REDIS_PORT"); redisPort != "" {
		if _, err := strconv.Atoi(redisPort); err != nil {
			result.Valid = false
			result.Missing = append(result.Missing, fmt.Sprintf("REDIS_PORT must be a valid integer (got: %s)", redisPort))
		}
	}

	// Print summary
	log.Println("[ENV] " + strings.Repeat("=", 60))
	if result.Valid {
		log.Println("[ENV] ✅ Endnode environment validation PASSED")
		if len(result.Warnings) > 0 {
			log.Printf("[ENV] ⚠️  %d warnings (see above)", len(result.Warnings))
		}
	} else {
		log.Println("[ENV] ❌ Endnode environment validation FAILED")
		log.Printf("[ENV] Missing/invalid variables: %d", len(result.Missing))
		return result, fmt.Errorf("missing required endnode environment variables: %s",
			strings.Join(result.Missing, ", "))
	}
	log.Println("[ENV] " + strings.Repeat("=", 60))

	return result, nil
}
