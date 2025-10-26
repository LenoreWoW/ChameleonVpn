package shared

import (
	"fmt"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Claims represents the JWT claims structure
type Claims struct {
	PhoneNumber string `json:"phone_number"`
	UserID      int    `json:"user_id"`
	jwt.RegisteredClaims
}

// JWTConfig holds JWT configuration
type JWTConfig struct {
	Secret     string
	Expiration time.Duration
}

// GetJWTSecret returns the JWT secret from environment variable
// or returns a default value for development (should never be used in production)
func GetJWTSecret() string {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		// SECURITY WARNING: This is only for development
		// In production, JWT_SECRET must be set as an environment variable
		fmt.Println("WARNING: JWT_SECRET not set, using insecure default. Set JWT_SECRET environment variable in production!")
		return "insecure-default-secret-change-in-production"
	}
	return secret
}

// GenerateJWT generates a new JWT token for a user
// Parameters:
//   - phoneNumber: The user's phone number (used as primary identifier)
//   - userID: The user's database ID
//
// Returns: JWT token string and error
func GenerateJWT(phoneNumber string, userID int) (string, error) {
	if phoneNumber == "" {
		return "", fmt.Errorf("phone number cannot be empty")
	}

	secret := GetJWTSecret()
	expirationTime := time.Now().Add(24 * time.Hour)

	// Create the claims
	claims := &Claims{
		PhoneNumber: phoneNumber,
		UserID:      userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
			Issuer:    "barqnet-auth",
			Subject:   phoneNumber,
		},
	}

	// Create token with claims
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	// Sign the token with the secret
	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		return "", fmt.Errorf("failed to sign token: %v", err)
	}

	return tokenString, nil
}

// ValidateJWT validates a JWT token and returns the claims
// Parameters:
//   - tokenString: The JWT token to validate
//
// Returns: Claims object and error
func ValidateJWT(tokenString string) (*Claims, error) {
	if tokenString == "" {
		return nil, fmt.Errorf("token cannot be empty")
	}

	secret := GetJWTSecret()

	// Parse the token
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		// Verify the signing method
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(secret), nil
	})

	if err != nil {
		return nil, fmt.Errorf("failed to parse token: %v", err)
	}

	// Extract and validate claims
	claims, ok := token.Claims.(*Claims)
	if !ok {
		return nil, fmt.Errorf("invalid token claims")
	}

	if !token.Valid {
		return nil, fmt.Errorf("token is invalid")
	}

	// Check if token is expired
	if claims.ExpiresAt.Before(time.Now()) {
		return nil, fmt.Errorf("token has expired")
	}

	return claims, nil
}

// RefreshJWT refreshes an existing JWT token
// This creates a new token with updated expiration time while keeping the same user data
// Parameters:
//   - tokenString: The existing JWT token to refresh
//
// Returns: New JWT token string and error
func RefreshJWT(tokenString string) (string, error) {
	// First, validate the existing token
	claims, err := ValidateJWT(tokenString)
	if err != nil {
		return "", fmt.Errorf("cannot refresh invalid token: %v", err)
	}

	// Check if the token is close to expiration (within 1 hour)
	// This prevents refreshing tokens that were just created
	timeUntilExpiry := time.Until(claims.ExpiresAt.Time)
	if timeUntilExpiry > 1*time.Hour {
		return "", fmt.Errorf("token is not close to expiration yet (expires in %v)", timeUntilExpiry)
	}

	// Generate a new token with the same user data
	newToken, err := GenerateJWT(claims.PhoneNumber, claims.UserID)
	if err != nil {
		return "", fmt.Errorf("failed to generate new token: %v", err)
	}

	return newToken, nil
}

// ExtractPhoneNumber extracts the phone number from a JWT token without full validation
// This is useful for logging and debugging purposes
// For actual authentication, always use ValidateJWT
func ExtractPhoneNumber(tokenString string) (string, error) {
	token, _, err := new(jwt.Parser).ParseUnverified(tokenString, &Claims{})
	if err != nil {
		return "", fmt.Errorf("failed to parse token: %v", err)
	}

	claims, ok := token.Claims.(*Claims)
	if !ok {
		return "", fmt.Errorf("invalid token claims")
	}

	return claims.PhoneNumber, nil
}

// IsTokenExpired checks if a token is expired without validating the signature
// Useful for determining if a refresh is needed
func IsTokenExpired(tokenString string) bool {
	token, _, err := new(jwt.Parser).ParseUnverified(tokenString, &Claims{})
	if err != nil {
		return true
	}

	claims, ok := token.Claims.(*Claims)
	if !ok {
		return true
	}

	return claims.ExpiresAt.Before(time.Now())
}
