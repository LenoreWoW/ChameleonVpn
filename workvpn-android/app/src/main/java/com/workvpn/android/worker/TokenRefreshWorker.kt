package com.barqnet.android.worker

import android.content.Context
import android.util.Log
import androidx.work.*
import com.barqnet.android.auth.AuthManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

/**
 * Background Worker for Automatic Token Refresh
 *
 * This worker runs periodically to refresh authentication tokens
 * before they expire. It ensures the user stays authenticated
 * even when the app is in the background.
 *
 * Features:
 * - Runs every 15 minutes (configurable)
 * - Only refreshes if token is expiring soon
 * - Handles network failures gracefully
 * - Respects battery optimization
 * - Supports API 23+
 *
 * Usage:
 * TokenRefreshWorker.schedule(context)  // Start periodic refresh
 * TokenRefreshWorker.cancel(context)    // Stop periodic refresh
 *
 * @author BarqNet Team
 */
class TokenRefreshWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    private val authManager = AuthManager(context)

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "TokenRefreshWorker started")

            // Check if user is authenticated
            if (!authManager.isAuthenticated()) {
                Log.d(TAG, "User not authenticated, skipping token refresh")
                return@withContext Result.success()
            }

            // Refresh token
            val result = authManager.refreshToken()

            if (result.isSuccess) {
                Log.d(TAG, "Token refreshed successfully")
                Result.success()
            } else {
                Log.e(TAG, "Token refresh failed: ${result.exceptionOrNull()?.message}")
                // Retry on failure
                Result.retry()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception in TokenRefreshWorker", e)
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "TokenRefreshWorker"
        private const val WORK_NAME = "token_refresh_work"
        private const val REFRESH_INTERVAL_MINUTES = 15L

        /**
         * Schedule periodic token refresh
         */
        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val refreshRequest = PeriodicWorkRequestBuilder<TokenRefreshWorker>(
                REFRESH_INTERVAL_MINUTES,
                TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    15,
                    TimeUnit.MINUTES
                )
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                refreshRequest
            )

            Log.d(TAG, "Token refresh worker scheduled")
        }

        /**
         * Cancel periodic token refresh
         */
        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            Log.d(TAG, "Token refresh worker cancelled")
        }

        /**
         * Run token refresh immediately (one-time)
         */
        fun runNow(context: Context) {
            val refreshRequest = OneTimeWorkRequestBuilder<TokenRefreshWorker>()
                .build()

            WorkManager.getInstance(context).enqueue(refreshRequest)
            Log.d(TAG, "One-time token refresh enqueued")
        }
    }
}
