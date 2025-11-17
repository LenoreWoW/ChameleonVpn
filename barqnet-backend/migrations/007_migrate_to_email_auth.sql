-- Migration: 007 - Migrate from Phone to Email Authentication
-- Date: November 16, 2025
-- Description: Add email support, migrate OTP system to use email instead of phone numbers

-- =======================
-- UP MIGRATION
-- =======================

-- Add email column to users table
ALTER TABLE users ADD COLUMN email VARCHAR(255);

-- Create unique index on email (will enforce uniqueness once populated)
CREATE UNIQUE INDEX idx_users_email ON users(email) WHERE email IS NOT NULL;

-- Make email NOT NULL after migration (done separately in production)
-- ALTER TABLE users ALTER COLUMN email SET NOT NULL;

-- Update otp_attempts table to support both phone and email
-- Rename phone_number column to identifier for flexibility
ALTER TABLE otp_attempts RENAME COLUMN phone_number TO identifier;

-- Add identifier_type column to distinguish between phone and email
ALTER TABLE otp_attempts ADD COLUMN identifier_type VARCHAR(20) DEFAULT 'email';

-- Update existing records to mark as phone type (if any exist)
UPDATE otp_attempts SET identifier_type = 'phone' WHERE identifier_type IS NULL OR identifier_type = 'email';

-- For future: users can migrate their phone numbers to emails
-- This allows gradual migration without breaking existing users
ALTER TABLE users ADD COLUMN migrated_from_phone BOOLEAN DEFAULT false;

-- =======================
-- DOWN MIGRATION
-- =======================
-- Rollback instructions (run these in reverse order if needed)

-- Remove migrated_from_phone column
-- ALTER TABLE users DROP COLUMN migrated_from_phone;

-- Remove identifier_type column
-- ALTER TABLE otp_attempts DROP COLUMN identifier_type;

-- Rename identifier back to phone_number
-- ALTER TABLE otp_attempts RENAME COLUMN identifier TO phone_number;

-- Remove email index
-- DROP INDEX idx_users_email;

-- Remove email column
-- ALTER TABLE users DROP COLUMN email;

-- =======================
-- MIGRATION NOTES
-- =======================
-- 1. Email column is initially nullable to allow gradual migration
-- 2. Once all users migrated, run: ALTER TABLE users ALTER COLUMN email SET NOT NULL
-- 3. phone_number column kept for backward compatibility during transition
-- 4. After full migration, optionally drop phone_number column
-- 5. identifier_type allows future support for other auth methods (OAuth, etc.)

-- =======================
-- VERIFICATION QUERIES
-- =======================
-- Check migration applied successfully:
-- SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = 'users' AND column_name IN ('email', 'phone_number');
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'otp_attempts' AND column_name IN ('identifier', 'identifier_type');
