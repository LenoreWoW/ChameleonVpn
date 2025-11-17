package com.barqnet.android.auth

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

/**
 * Rate Limiter for OTP requests
 *
 * Implements client-side rate limiting to prevent OTP spam:
 * - Maximum 3 OTP requests per 5 minutes per email address
 * - Tracks request count and cooldown period
 * - Provides countdown timer for UI feedback
 *
 * Security Benefits:
 * - Prevents brute-force OTP attacks
 * - Reduces load on email gateway
 * - Protects against accidental button spam
 * - Improves user experience with clear cooldown messages
 *
 * @author BarqNet Team
 */
class RateLimiter(private val context: Context) {

    companion object {
        private val Context.rateLimiterDataStore by preferencesDataStore(name = "rate_limiter")

        private const val MAX_REQUESTS = 3
        private const val COOLDOWN_PERIOD_MS = 5 * 60 * 1000L // 5 minutes in milliseconds

        private fun requestCountKey(email: String) = intPreferencesKey("otp_count_$email")
        private fun cooldownStartKey(email: String) = longPreferencesKey("cooldown_start_$email")
    }

    /**
     * Check if OTP request is allowed for given email address
     *
     * @param email Email address to check
     * @return Pair<Boolean, Long> - (isAllowed, remainingCooldownMs)
     */
    suspend fun canSendOTP(email: String): Pair<Boolean, Long> {
        val preferences = context.rateLimiterDataStore.data.first()

        val requestCount = preferences[requestCountKey(email)] ?: 0
        val cooldownStart = preferences[cooldownStartKey(email)] ?: 0L

        val currentTime = System.currentTimeMillis()
        val cooldownElapsed = currentTime - cooldownStart

        // If cooldown period has passed, reset counter
        if (cooldownElapsed >= COOLDOWN_PERIOD_MS) {
            resetRateLimit(email)
            return Pair(true, 0L)
        }

        // Check if under request limit
        if (requestCount < MAX_REQUESTS) {
            return Pair(true, 0L)
        }

        // Calculate remaining cooldown time
        val remainingCooldown = COOLDOWN_PERIOD_MS - cooldownElapsed
        return Pair(false, remainingCooldown)
    }

    /**
     * Record an OTP request for given email address
     *
     * @param email Email address to track
     */
    suspend fun recordOTPRequest(email: String) {
        context.rateLimiterDataStore.edit { preferences ->
            val currentCount = preferences[requestCountKey(email)] ?: 0
            val cooldownStart = preferences[cooldownStartKey(email)] ?: 0L

            val currentTime = System.currentTimeMillis()
            val cooldownElapsed = currentTime - cooldownStart

            if (cooldownElapsed >= COOLDOWN_PERIOD_MS) {
                // Reset counter and start new cooldown period
                preferences[requestCountKey(email)] = 1
                preferences[cooldownStartKey(email)] = currentTime
            } else {
                // Increment counter within existing cooldown period
                preferences[requestCountKey(email)] = currentCount + 1

                // If first request, set cooldown start time
                if (currentCount == 0) {
                    preferences[cooldownStartKey(email)] = currentTime
                }
            }
        }
    }

    /**
     * Get remaining requests before rate limit
     *
     * @param email Email address to check
     * @return Number of remaining requests (0-3)
     */
    suspend fun getRemainingRequests(email: String): Int {
        val preferences = context.rateLimiterDataStore.data.first()
        val requestCount = preferences[requestCountKey(email)] ?: 0
        val cooldownStart = preferences[cooldownStartKey(email)] ?: 0L

        val currentTime = System.currentTimeMillis()
        val cooldownElapsed = currentTime - cooldownStart

        // If cooldown has passed, full requests available
        if (cooldownElapsed >= COOLDOWN_PERIOD_MS) {
            return MAX_REQUESTS
        }

        return MAX_REQUESTS - requestCount
    }

    /**
     * Format remaining cooldown time for display
     *
     * @param remainingMs Remaining cooldown in milliseconds
     * @return Formatted string (e.g., "4m 32s")
     */
    fun formatCooldown(remainingMs: Long): String {
        val totalSeconds = remainingMs / 1000
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60

        return if (minutes > 0) {
            "${minutes}m ${seconds}s"
        } else {
            "${seconds}s"
        }
    }

    /**
     * Reset rate limit for given email address
     *
     * @param email Email address to reset
     */
    suspend fun resetRateLimit(email: String) {
        context.rateLimiterDataStore.edit { preferences ->
            preferences.remove(requestCountKey(email))
            preferences.remove(cooldownStartKey(email))
        }
    }

    /**
     * Clear all rate limit data (for testing or admin purposes)
     */
    suspend fun clearAll() {
        context.rateLimiterDataStore.edit { preferences ->
            preferences.clear()
        }
    }
}
