package com.barqnet.android.auth

import android.content.Context
import android.util.Log
import com.barqnet.android.api.ApiService
import com.barqnet.android.api.models.UserData
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Authentication Manager - PRODUCTION VERSION with Real Backend Integration
 *
 * This class handles all authentication operations with the BarqNet backend:
 * - OTP sending and verification
 * - User registration
 * - User login
 * - Token refresh (automatic and manual)
 * - Secure token storage
 *
 * Features:
 * - Real backend API integration via Retrofit
 * - Encrypted token storage via EncryptedSharedPreferences
 * - Automatic token refresh (5 min before expiry)
 * - Coroutine-based async operations
 * - Proper error handling
 *
 * Security:
 * - All tokens stored encrypted
 * - Automatic token rotation
 * - No plaintext credentials stored
 * - Certificate pinning via ApiService
 *
 * @author BarqNet Team
 * @version 2.0 - Production Ready
 */
class AuthManager(private val context: Context) {

    private val tokenStorage = TokenStorage(context)
    private val rateLimiter = RateLimiter(context)
    private val authScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val _authState = MutableStateFlow<AuthState>(AuthState.Unauthenticated)
    val authState: StateFlow<AuthState> = _authState

    private var currentOtpSessionId: String? = null

    init {
        // Start automatic token refresh monitoring
        startTokenRefreshMonitoring()

        // Check if user is already authenticated
        authScope.launch {
            if (tokenStorage.isAuthenticated()) {
                val userData = tokenStorage.getUserData()
                if (userData != null) {
                    _authState.value = AuthState.Authenticated(userData)
                }
            }
        }
    }

    // ==================== OTP Flow ====================

    /**
     * Send OTP to email address
     *
     * Backend: POST /v1/auth/send-otp
     *
     * Includes client-side rate limiting:
     * - Max 3 requests per 5 minutes per email
     * - Returns error with cooldown time if limit exceeded
     */
    suspend fun sendOTP(email: String): Result<Unit> {
        return try {
            // Check rate limit before sending
            val (canSend, remainingCooldown) = rateLimiter.canSendOTP(email)

            if (!canSend) {
                val cooldownFormatted = rateLimiter.formatCooldown(remainingCooldown)
                val errorMsg = "Too many OTP requests. Please wait $cooldownFormatted before trying again."
                Log.w(TAG, errorMsg)
                return Result.failure(Exception(errorMsg))
            }

            Log.d(TAG, "Sending OTP to: $email")

            val result = ApiService.sendOtp(email)

            if (result.isSuccess) {
                val response = result.getOrNull()!!
                currentOtpSessionId = response.sessionId
                tokenStorage.saveOtpSessionId(response.sessionId)

                // Record OTP request for rate limiting
                rateLimiter.recordOTPRequest(email)

                val remainingRequests = rateLimiter.getRemainingRequests(email)
                Log.d(TAG, "OTP sent successfully. Remaining requests: $remainingRequests")

                Result.success(Unit)
            } else {
                val error = result.exceptionOrNull()
                Log.e(TAG, "Failed to send OTP", error)
                Result.failure(error ?: Exception("Failed to send OTP"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception sending OTP", e)
            Result.failure(e)
        }
    }

    /**
     * Verify OTP code
     *
     * Backend: POST /v1/auth/verify-otp
     */
    suspend fun verifyOTP(email: String, code: String): Result<Unit> {
        return try {
            Log.d(TAG, "Verifying OTP for: $email")

            // Get current session ID to send with verification
            val sessionId = currentOtpSessionId ?: tokenStorage.getOtpSessionId()
            val result = ApiService.verifyOtp(email, code, sessionId)

            if (result.isSuccess) {
                val response = result.getOrNull()!!
                if (response.verified) {
                    currentOtpSessionId = response.sessionId
                    tokenStorage.saveOtpSessionId(response.sessionId)

                    Log.d(TAG, "OTP verified successfully")
                    Result.success(Unit)
                } else {
                    Log.w(TAG, "OTP verification failed")
                    Result.failure(Exception("Invalid OTP code"))
                }
            } else {
                val error = result.exceptionOrNull()
                Log.e(TAG, "Failed to verify OTP", error)
                Result.failure(error ?: Exception("Failed to verify OTP"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception verifying OTP", e)
            Result.failure(e)
        }
    }

    // ==================== Registration ====================

    /**
     * Create new account
     *
     * Backend: POST /v1/auth/register
     */
    suspend fun createAccount(email: String, password: String): Result<Unit> {
        return try {
            // Validate password strength
            if (password.length < 8) {
                return Result.failure(Exception("Password must be at least 8 characters"))
            }

            val sessionId = currentOtpSessionId ?: tokenStorage.getOtpSessionId()
                ?: return Result.failure(Exception("No OTP session found. Please verify OTP first."))

            Log.d(TAG, "Creating account for: $email")

            val result = ApiService.register(email, password, sessionId)

            if (result.isSuccess) {
                val response = result.getOrNull()!!

                // Create UserData from response
                val userData = UserData(
                    userId = response.userId,
                    email = response.email,
                    accessToken = response.accessToken,
                    refreshToken = response.refreshToken,
                    expiresAt = response.expiresAt
                )

                // Save to encrypted storage
                tokenStorage.saveUserData(userData)
                tokenStorage.clearOtpSessionId()
                currentOtpSessionId = null

                // Update auth state
                _authState.value = AuthState.Authenticated(userData)

                Log.d(TAG, "Account created successfully for user: ${response.userId}")
                Result.success(Unit)
            } else {
                val error = result.exceptionOrNull()
                Log.e(TAG, "Failed to create account", error)
                Result.failure(error ?: Exception("Failed to create account"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception creating account", e)
            Result.failure(e)
        }
    }

    // ==================== Login ====================

    /**
     * Login existing user
     *
     * Backend: POST /v1/auth/login
     */
    suspend fun login(email: String, password: String): Result<Unit> {
        return try {
            Log.d(TAG, "Logging in user: $email")

            val result = ApiService.login(email, password)

            if (result.isSuccess) {
                val response = result.getOrNull()!!

                // Create UserData from response
                val userData = UserData(
                    userId = response.userId,
                    email = response.email,
                    accessToken = response.accessToken,
                    refreshToken = response.refreshToken,
                    expiresAt = response.expiresAt
                )

                // Save to encrypted storage
                tokenStorage.saveUserData(userData)

                // Update auth state
                _authState.value = AuthState.Authenticated(userData)

                Log.d(TAG, "Login successful for user: ${response.userId}")
                Result.success(Unit)
            } else {
                val error = result.exceptionOrNull()
                Log.e(TAG, "Login failed", error)
                Result.failure(error ?: Exception("Invalid email or password"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception during login", e)
            Result.failure(e)
        }
    }

    // ==================== Logout ====================

    /**
     * Logout current user
     */
    suspend fun logout() {
        try {
            Log.d(TAG, "Logging out user")

            // Clear all stored tokens and data
            tokenStorage.clear()

            // Update auth state
            _authState.value = AuthState.Unauthenticated

            Log.d(TAG, "Logout successful")
        } catch (e: Exception) {
            Log.e(TAG, "Error during logout", e)
        }
    }

    // ==================== Token Refresh ====================

    /**
     * Refresh access token
     *
     * Backend: POST /v1/auth/refresh
     */
    suspend fun refreshToken(): Result<Unit> {
        return try {
            val refreshToken = tokenStorage.getRefreshToken()
                ?: return Result.failure(Exception("No refresh token available"))

            Log.d(TAG, "Refreshing access token")

            val result = ApiService.refreshToken(refreshToken)

            if (result.isSuccess) {
                val response = result.getOrNull()!!

                // Update access token in storage
                tokenStorage.updateAccessToken(response.accessToken, response.expiresAt)

                Log.d(TAG, "Token refreshed successfully. Expires at: ${response.expiresAt}")
                Result.success(Unit)
            } else {
                val error = result.exceptionOrNull()
                Log.e(TAG, "Failed to refresh token", error)

                // If refresh fails, logout user
                logout()
                Result.failure(error ?: Exception("Failed to refresh token"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception refreshing token", e)
            logout()
            Result.failure(e)
        }
    }

    /**
     * Start automatic token refresh monitoring
     *
     * This coroutine runs in the background and automatically refreshes
     * the access token 5 minutes before it expires.
     */
    private fun startTokenRefreshMonitoring() {
        authScope.launch {
            while (isActive) {
                try {
                    if (tokenStorage.shouldRefreshToken()) {
                        Log.d(TAG, "Token needs refresh, refreshing automatically...")
                        refreshToken()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in token refresh monitoring", e)
                }

                // Check every minute
                delay(60_000)
            }
        }
    }

    // ==================== User Info ====================

    /**
     * Check if user is authenticated
     */
    suspend fun isAuthenticated(): Boolean {
        return tokenStorage.isAuthenticated()
    }

    /**
     * Get current user data
     */
    suspend fun getCurrentUser(): UserData? {
        return tokenStorage.getUserData()
    }

    /**
     * Get access token for API calls
     */
    suspend fun getAccessToken(): String? {
        // Refresh if needed
        if (tokenStorage.shouldRefreshToken()) {
            refreshToken()
        }
        return tokenStorage.getAccessToken()
    }

    companion object {
        private const val TAG = "AuthManager"
    }
}

/**
 * Authentication state sealed class
 */
sealed class AuthState {
    object Unauthenticated : AuthState()
    data class Authenticated(val userData: UserData) : AuthState()
}
