package shared

import (
	"context"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/go-redis/redis/v8"
)

// RateLimitType defines different types of rate limits
type RateLimitType string

const (
	// RateLimitOTP limits OTP send requests per phone number
	RateLimitOTP RateLimitType = "otp"
	// RateLimitLogin limits login attempts per phone number
	RateLimitLogin RateLimitType = "login"
	// RateLimitRegister limits registration attempts per IP
	RateLimitRegister RateLimitType = "register"
	// RateLimitAPI limits general API requests per IP
	RateLimitAPI RateLimitType = "api"
)

// RateLimitConfig holds configuration for a specific rate limit type
type RateLimitConfig struct {
	MaxRequests int           // Maximum number of requests allowed
	Window      time.Duration // Time window for rate limiting
}

// RateLimiter provides Redis-based rate limiting functionality
type RateLimiter struct {
	client  *redis.Client
	enabled bool
	configs map[RateLimitType]RateLimitConfig
}

// NewRateLimiter creates a new rate limiter with Redis backend
func NewRateLimiter() (*RateLimiter, error) {
	// Check if rate limiting is enabled
	enabled := getEnvBool("RATE_LIMIT_ENABLED", true)

	if !enabled {
		log.Println("[RATE-LIMIT] Rate limiting is DISABLED via configuration")
		return &RateLimiter{
			enabled: false,
			configs: getDefaultRateLimitConfigs(),
		}, nil
	}

	// Get Redis configuration from environment
	redisHost := getEnvString("REDIS_HOST", "localhost")
	redisPort := getEnvString("REDIS_PORT", "6379")
	redisPassword := getEnvString("REDIS_PASSWORD", "")
	redisDB := getEnvInt("REDIS_DB", 0)

	// Create Redis client
	client := redis.NewClient(&redis.Options{
		Addr:         fmt.Sprintf("%s:%s", redisHost, redisPort),
		Password:     redisPassword,
		DB:           redisDB,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
		PoolSize:     10,
		MinIdleConns: 2,
	})

	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		log.Printf("[RATE-LIMIT] WARNING: Failed to connect to Redis: %v", err)
		log.Println("[RATE-LIMIT] Rate limiting will operate in DEGRADED mode (allow all requests)")

		// Return limiter with client but note connection failure
		return &RateLimiter{
			client:  client,
			enabled: true,
			configs: getDefaultRateLimitConfigs(),
		}, nil
	}

	log.Printf("[RATE-LIMIT] Successfully connected to Redis at %s:%s", redisHost, redisPort)
	log.Println("[RATE-LIMIT] Rate limiting is ENABLED")

	return &RateLimiter{
		client:  client,
		enabled: true,
		configs: getDefaultRateLimitConfigs(),
	}, nil
}

// getDefaultRateLimitConfigs returns default rate limit configurations
func getDefaultRateLimitConfigs() map[RateLimitType]RateLimitConfig {
	return map[RateLimitType]RateLimitConfig{
		RateLimitOTP: {
			MaxRequests: getEnvInt("RATE_LIMIT_OTP_MAX", 5),
			Window:      time.Duration(getEnvInt("RATE_LIMIT_OTP_WINDOW_MINUTES", 60)) * time.Minute,
		},
		RateLimitLogin: {
			MaxRequests: getEnvInt("RATE_LIMIT_LOGIN_MAX", 10),
			Window:      time.Duration(getEnvInt("RATE_LIMIT_LOGIN_WINDOW_MINUTES", 60)) * time.Minute,
		},
		RateLimitRegister: {
			MaxRequests: getEnvInt("RATE_LIMIT_REGISTER_MAX", 3),
			Window:      time.Duration(getEnvInt("RATE_LIMIT_REGISTER_WINDOW_MINUTES", 60)) * time.Minute,
		},
		RateLimitAPI: {
			MaxRequests: getEnvInt("RATE_LIMIT_API_MAX", 100),
			Window:      time.Duration(getEnvInt("RATE_LIMIT_API_WINDOW_SECONDS", 60)) * time.Second,
		},
	}
}

// Allow checks if a request should be allowed based on rate limits
// Uses sliding window algorithm with Redis
// Returns: (allowed bool, remaining int, resetTime time.Time, error)
func (rl *RateLimiter) Allow(limitType RateLimitType, key string) (bool, int, time.Time, error) {
	// If rate limiting is disabled, allow all requests
	if !rl.enabled {
		return true, 999, time.Now().Add(time.Hour), nil
	}

	// Get configuration for this limit type
	config, exists := rl.configs[limitType]
	if !exists {
		return false, 0, time.Now(), fmt.Errorf("unknown rate limit type: %s", limitType)
	}

	// Check Redis connection health
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	// If Redis is unavailable, gracefully degrade (allow request but log warning)
	if err := rl.client.Ping(ctx).Err(); err != nil {
		log.Printf("[RATE-LIMIT] WARNING: Redis unavailable, allowing request (degraded mode): %v", err)
		return true, config.MaxRequests, time.Now().Add(config.Window), nil
	}

	// Create Redis key
	redisKey := fmt.Sprintf("ratelimit:%s:%s", limitType, key)

	// Get current count
	count, err := rl.client.Get(ctx, redisKey).Int()
	if err != nil && err != redis.Nil {
		log.Printf("[RATE-LIMIT] WARNING: Redis error, allowing request (degraded mode): %v", err)
		return true, config.MaxRequests, time.Now().Add(config.Window), nil
	}

	// Calculate reset time
	ttl, err := rl.client.TTL(ctx, redisKey).Result()
	if err != nil {
		ttl = config.Window
	}
	resetTime := time.Now().Add(ttl)

	// Check if limit exceeded
	if count >= config.MaxRequests {
		remaining := 0
		log.Printf("[RATE-LIMIT] BLOCKED: %s - key=%s count=%d/%d reset=%s",
			limitType, key, count, config.MaxRequests, resetTime.Format(time.RFC3339))
		return false, remaining, resetTime, nil
	}

	// Increment counter using pipeline for atomicity
	pipe := rl.client.Pipeline()
	incr := pipe.Incr(ctx, redisKey)

	// Set expiration only if this is the first request
	if count == 0 {
		pipe.Expire(ctx, redisKey, config.Window)
	}

	_, err = pipe.Exec(ctx)
	if err != nil {
		log.Printf("[RATE-LIMIT] WARNING: Failed to increment counter, allowing request: %v", err)
		return true, config.MaxRequests - count, resetTime, nil
	}

	newCount := int(incr.Val())
	remaining := config.MaxRequests - newCount

	log.Printf("[RATE-LIMIT] ALLOWED: %s - key=%s count=%d/%d remaining=%d reset=%s",
		limitType, key, newCount, config.MaxRequests, remaining, resetTime.Format(time.RFC3339))

	return true, remaining, resetTime, nil
}

// Reset resets the rate limit for a specific key (useful for testing or admin override)
func (rl *RateLimiter) Reset(limitType RateLimitType, key string) error {
	if !rl.enabled || rl.client == nil {
		return nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	redisKey := fmt.Sprintf("ratelimit:%s:%s", limitType, key)
	err := rl.client.Del(ctx, redisKey).Err()
	if err != nil {
		return fmt.Errorf("failed to reset rate limit: %w", err)
	}

	log.Printf("[RATE-LIMIT] RESET: %s - key=%s", limitType, key)
	return nil
}

// GetStatus returns the current status for a specific key
func (rl *RateLimiter) GetStatus(limitType RateLimitType, key string) (int, int, time.Time, error) {
	if !rl.enabled || rl.client == nil {
		config := rl.configs[limitType]
		return 0, config.MaxRequests, time.Now().Add(config.Window), nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	redisKey := fmt.Sprintf("ratelimit:%s:%s", limitType, key)

	count, err := rl.client.Get(ctx, redisKey).Int()
	if err != nil && err != redis.Nil {
		return 0, 0, time.Now(), err
	}

	config := rl.configs[limitType]
	remaining := config.MaxRequests - count
	if remaining < 0 {
		remaining = 0
	}

	ttl, err := rl.client.TTL(ctx, redisKey).Result()
	if err != nil {
		ttl = config.Window
	}
	resetTime := time.Now().Add(ttl)

	return count, remaining, resetTime, nil
}

// Close closes the Redis connection
func (rl *RateLimiter) Close() error {
	if rl.client != nil {
		return rl.client.Close()
	}
	return nil
}

// IsEnabled returns whether rate limiting is enabled
func (rl *RateLimiter) IsEnabled() bool {
	return rl.enabled
}

// Helper functions for environment variables

func getEnvString(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intVal, err := strconv.Atoi(value); err == nil {
			return intVal
		}
	}
	return defaultValue
}

func getEnvBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if boolVal, err := strconv.ParseBool(value); err == nil {
			return boolVal
		}
	}
	return defaultValue
}

// RateLimitInfo contains information about rate limit status
type RateLimitInfo struct {
	Allowed   bool      `json:"allowed"`
	Limit     int       `json:"limit"`
	Remaining int       `json:"remaining"`
	ResetAt   time.Time `json:"reset_at"`
}

// CheckRateLimit is a convenience function that checks rate limit and returns structured info
func (rl *RateLimiter) CheckRateLimit(limitType RateLimitType, key string) (*RateLimitInfo, error) {
	allowed, remaining, resetTime, err := rl.Allow(limitType, key)
	if err != nil {
		return nil, err
	}

	config := rl.configs[limitType]

	return &RateLimitInfo{
		Allowed:   allowed,
		Limit:     config.MaxRequests,
		Remaining: remaining,
		ResetAt:   resetTime,
	}, nil
}
