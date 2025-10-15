package com.workvpn.android.util

import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Unit tests for ConnectionRetryManager
 * Tests exponential backoff and retry logic
 */
class ConnectionRetryManagerTest {

    private lateinit var retryManager: ConnectionRetryManager

    @Before
    fun setup() {
        retryManager = ConnectionRetryManager()
    }

    @Test
    fun `initial state should allow retries`() {
        assertTrue(retryManager.shouldRetry(), "Should allow retries initially")
        assertEquals(0, retryManager.getRetryCount(), "Retry count should be 0 initially")
    }

    @Test
    fun `getRetryDelay should use exponential backoff`() {
        val delays = mutableListOf<Long>()

        for (i in 0..5) {
            delays.add(retryManager.getRetryDelay())
            retryManager.incrementRetry()
        }

        // Verify exponential growth: 1s, 2s, 4s, 8s, 16s, 32s
        assertEquals(1000L, delays[0], "First delay should be 1 second")
        assertEquals(2000L, delays[1], "Second delay should be 2 seconds")
        assertEquals(4000L, delays[2], "Third delay should be 4 seconds")
        assertEquals(8000L, delays[3], "Fourth delay should be 8 seconds")
        assertEquals(16000L, delays[4], "Fifth delay should be 16 seconds")
        assertEquals(32000L, delays[5], "Sixth delay should be 32 seconds (max)")
    }

    @Test
    fun `should stop retrying after max retries`() {
        // Max retries is 5
        repeat(5) {
            assertTrue(retryManager.shouldRetry(), "Should retry attempt ${it + 1}")
            retryManager.incrementRetry()
        }

        assertFalse(retryManager.shouldRetry(), "Should not retry after max attempts")
    }

    @Test
    fun `reset should clear retry count`() {
        // Do some retries
        repeat(3) {
            retryManager.incrementRetry()
        }

        assertEquals(3, retryManager.getRetryCount(), "Should have 3 retries")

        // Reset
        retryManager.reset()

        assertEquals(0, retryManager.getRetryCount(), "Retry count should be 0 after reset")
        assertTrue(retryManager.shouldRetry(), "Should allow retries after reset")
    }

    @Test
    fun `executeWithRetry should succeed on first try`() = runTest {
        var attempts = 0

        val result = retryManager.executeWithRetry {
            attempts++
            Result.success("Success")
        }

        assertTrue(result.isSuccess, "Should succeed")
        assertEquals("Success", result.getOrNull(), "Should return success value")
        assertEquals(1, attempts, "Should only attempt once")
    }

    @Test
    fun `executeWithRetry should retry on failure`() = runTest {
        var attempts = 0

        val result = retryManager.executeWithRetry {
            attempts++
            if (attempts < 3) {
                Result.failure(Exception("Temporary failure"))
            } else {
                Result.success("Success after retries")
            }
        }

        assertTrue(result.isSuccess, "Should eventually succeed")
        assertEquals("Success after retries", result.getOrNull())
        assertEquals(3, attempts, "Should have attempted 3 times")
    }

    @Test
    fun `executeWithRetry should give up after max retries`() = runTest {
        var attempts = 0

        val result = retryManager.executeWithRetry {
            attempts++
            Result.failure(Exception("Always fails"))
        }

        assertTrue(result.isFailure, "Should fail after max retries")
        assertEquals(5, attempts, "Should have attempted 5 times (max retries)")
    }

    @Test
    fun `getMaxRetries should return 5`() {
        assertEquals(5, retryManager.getMaxRetries(), "Max retries should be 5")
    }

    @Test
    fun `delay should cap at 32 seconds`() {
        // Increment way beyond max retries
        repeat(10) {
            retryManager.incrementRetry()
        }

        val delay = retryManager.getRetryDelay()
        assertEquals(32000L, delay, "Delay should cap at 32 seconds")
    }
}
