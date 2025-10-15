package com.workvpn.android.util

import kotlinx.coroutines.delay
import kotlin.math.min
import kotlin.math.pow

/**
 * Manages VPN connection retry with exponential backoff
 */
class ConnectionRetryManager {

    private var retryCount = 0
    private val maxRetries = 5
    private val baseDelayMs = 1000L // 1 second
    private val maxDelayMs = 32000L // 32 seconds

    /**
     * Get the delay before next retry
     * Uses exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s
     */
    fun getRetryDelay(): Long {
        val exponentialDelay = baseDelayMs * (2.0.pow(retryCount.toDouble())).toLong()
        return min(exponentialDelay, maxDelayMs)
    }

    /**
     * Check if should retry connection
     */
    fun shouldRetry(): Boolean {
        return retryCount < maxRetries
    }

    /**
     * Increment retry count
     */
    fun incrementRetry() {
        retryCount++
        android.util.Log.d(TAG, "Retry attempt: $retryCount/$maxRetries, delay: ${getRetryDelay()}ms")
    }

    /**
     * Reset retry counter on successful connection
     */
    fun reset() {
        retryCount = 0
        android.util.Log.d(TAG, "Retry counter reset")
    }

    /**
     * Get current retry count
     */
    fun getRetryCount(): Int = retryCount

    /**
     * Get max retries
     */
    fun getMaxRetries(): Int = maxRetries

    /**
     * Execute retry with exponential backoff
     */
    suspend fun <T> executeWithRetry(
        operation: suspend () -> Result<T>
    ): Result<T> {
        while (shouldRetry()) {
            val result = operation()

            if (result.isSuccess) {
                reset()
                return result
            }

            incrementRetry()

            if (shouldRetry()) {
                val delayMs = getRetryDelay()
                android.util.Log.d(TAG, "Retrying in ${delayMs}ms...")
                delay(delayMs)
            } else {
                android.util.Log.e(TAG, "Max retries reached, giving up")
                return result
            }
        }

        return Result.failure(Exception("Max retries exceeded"))
    }

    companion object {
        private const val TAG = "ConnectionRetryManager"
    }
}
