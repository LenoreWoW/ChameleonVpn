-- =====================================================
-- Migration: 002_add_phone_auth
-- Description: Add phone-based authentication support
-- Created: 2025-10-26
-- =====================================================

-- ============== MIGRATION UP ==============

-- Add phone authentication columns to users table
DO $$
BEGIN
    -- Add phone_number column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'phone_number'
    ) THEN
        ALTER TABLE users ADD COLUMN phone_number VARCHAR(20) UNIQUE;
    END IF;

    -- Add password_hash column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'password_hash'
    ) THEN
        ALTER TABLE users ADD COLUMN password_hash VARCHAR(255);
    END IF;

    -- Add created_via column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'created_via'
    ) THEN
        ALTER TABLE users ADD COLUMN created_via VARCHAR(20) DEFAULT 'api';
    END IF;

    -- Add last_login column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'last_login'
    ) THEN
        ALTER TABLE users ADD COLUMN last_login TIMESTAMP;
    END IF;
END $$;

-- Create unique index on phone_number (idempotent)
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone_number ON users(phone_number) WHERE phone_number IS NOT NULL;

-- Create index on created_via for analytics
CREATE INDEX IF NOT EXISTS idx_users_created_via ON users(created_via);

-- Create index on last_login for session management
CREATE INDEX IF NOT EXISTS idx_users_last_login ON users(last_login);

-- Create user_sessions table for JWT token tracking
CREATE TABLE IF NOT EXISTS user_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    device_info TEXT,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    revoked BOOLEAN DEFAULT false,
    revoked_at TIMESTAMP,
    revoked_reason VARCHAR(255)
);

-- Create indexes for user_sessions
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON user_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON user_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_sessions_revoked ON user_sessions(revoked) WHERE revoked = false;
CREATE INDEX IF NOT EXISTS idx_sessions_last_activity ON user_sessions(last_activity);

-- Create otp_attempts table for rate limiting
CREATE TABLE IF NOT EXISTS otp_attempts (
    id SERIAL PRIMARY KEY,
    phone_number VARCHAR(20) NOT NULL,
    otp_code VARCHAR(6) NOT NULL,
    attempt_type VARCHAR(20) NOT NULL, -- 'send' or 'verify'
    ip_address INET,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    verified BOOLEAN DEFAULT false,
    verified_at TIMESTAMP,
    attempt_count INTEGER DEFAULT 0,
    last_attempt_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for otp_attempts
CREATE INDEX IF NOT EXISTS idx_otp_phone_number ON otp_attempts(phone_number);
CREATE INDEX IF NOT EXISTS idx_otp_created_at ON otp_attempts(created_at);
CREATE INDEX IF NOT EXISTS idx_otp_expires_at ON otp_attempts(expires_at);
CREATE INDEX IF NOT EXISTS idx_otp_verified ON otp_attempts(verified);
CREATE INDEX IF NOT EXISTS idx_otp_attempt_type ON otp_attempts(attempt_type);
CREATE INDEX IF NOT EXISTS idx_otp_ip_address ON otp_attempts(ip_address);

-- Create composite index for active OTP lookup
CREATE INDEX IF NOT EXISTS idx_otp_phone_active ON otp_attempts(phone_number, expires_at, verified)
WHERE verified = false AND expires_at > CURRENT_TIMESTAMP;

-- Add comment to document the migration
COMMENT ON TABLE user_sessions IS 'Tracks active user sessions with JWT tokens for authentication';
COMMENT ON TABLE otp_attempts IS 'Tracks OTP send and verification attempts for rate limiting and security';
COMMENT ON COLUMN users.phone_number IS 'User phone number for authentication (E.164 format recommended)';
COMMENT ON COLUMN users.password_hash IS 'Bcrypt hashed password for phone-based authentication';
COMMENT ON COLUMN users.created_via IS 'Tracks how the user was created: api, phone, admin, etc.';
COMMENT ON COLUMN users.last_login IS 'Timestamp of last successful login';

-- ============== ROLLBACK DOWN ==============

/*
-- To rollback this migration, run the following SQL:

-- Drop OTP attempts table
DROP TABLE IF EXISTS otp_attempts CASCADE;

-- Drop user sessions table
DROP TABLE IF EXISTS user_sessions CASCADE;

-- Remove indexes
DROP INDEX IF EXISTS idx_users_last_login;
DROP INDEX IF EXISTS idx_users_created_via;
DROP INDEX IF EXISTS idx_users_phone_number;

-- Remove columns from users table
ALTER TABLE users DROP COLUMN IF EXISTS last_login;
ALTER TABLE users DROP COLUMN IF EXISTS created_via;
ALTER TABLE users DROP COLUMN IF EXISTS password_hash;
ALTER TABLE users DROP COLUMN IF EXISTS phone_number;

*/
