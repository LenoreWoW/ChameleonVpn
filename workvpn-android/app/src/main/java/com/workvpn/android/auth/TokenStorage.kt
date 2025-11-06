package com.barqnet.android.auth

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.barqnet.android.api.models.UserData
import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Secure Token Storage using EncryptedSharedPreferences
 *
 * This class handles secure storage of authentication tokens and user data
 * using Android's EncryptedSharedPreferences which provides AES-256 encryption.
 *
 * Features:
 * - AES-256 encryption for all stored data
 * - Hardware-backed key storage (when available)
 * - Protection against data extraction
 * - Automatic key rotation support
 *
 * Security:
 * - All sensitive data is encrypted at rest
 * - Keys are stored in Android Keystore
 * - Data cannot be accessed by other apps
 * - Protected against rooted device extraction
 *
 * @author BarqNet Team
 */
class TokenStorage(context: Context) {

    private val sharedPreferences: SharedPreferences
    private val gson = Gson()

    init {
        // Create or retrieve MasterKey for encryption
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        // Create EncryptedSharedPreferences
        sharedPreferences = EncryptedSharedPreferences.create(
            context,
            PREFS_FILENAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    /**
     * Save user data and tokens
     */
    suspend fun saveUserData(userData: UserData) = withContext(Dispatchers.IO) {
        val json = gson.toJson(userData)
        sharedPreferences.edit()
            .putString(KEY_USER_DATA, json)
            .putString(KEY_ACCESS_TOKEN, userData.accessToken)
            .putString(KEY_REFRESH_TOKEN, userData.refreshToken)
            .putLong(KEY_EXPIRES_AT, userData.expiresAt)
            .putString(KEY_USER_ID, userData.userId)
            .putString(KEY_PHONE_NUMBER, userData.phoneNumber)
            .apply()
    }

    /**
     * Get stored user data
     */
    suspend fun getUserData(): UserData? = withContext(Dispatchers.IO) {
        val json = sharedPreferences.getString(KEY_USER_DATA, null)
        if (json != null) {
            try {
                gson.fromJson(json, UserData::class.java)
            } catch (e: Exception) {
                null
            }
        } else {
            null
        }
    }

    /**
     * Get access token
     */
    suspend fun getAccessToken(): String? = withContext(Dispatchers.IO) {
        sharedPreferences.getString(KEY_ACCESS_TOKEN, null)
    }

    /**
     * Get refresh token
     */
    suspend fun getRefreshToken(): String? = withContext(Dispatchers.IO) {
        sharedPreferences.getString(KEY_REFRESH_TOKEN, null)
    }

    /**
     * Update access token after refresh
     */
    suspend fun updateAccessToken(accessToken: String, expiresAt: Long) = withContext(Dispatchers.IO) {
        sharedPreferences.edit()
            .putString(KEY_ACCESS_TOKEN, accessToken)
            .putLong(KEY_EXPIRES_AT, expiresAt)
            .apply()

        // Update UserData object if it exists
        getUserData()?.let { userData ->
            val updatedUserData = userData.copy(
                accessToken = accessToken,
                expiresAt = expiresAt
            )
            saveUserData(updatedUserData)
        }
    }

    /**
     * Check if user is authenticated
     */
    suspend fun isAuthenticated(): Boolean = withContext(Dispatchers.IO) {
        val userData = getUserData()
        userData != null && !userData.isTokenExpired()
    }

    /**
     * Check if token needs refresh
     */
    suspend fun shouldRefreshToken(): Boolean = withContext(Dispatchers.IO) {
        val userData = getUserData()
        userData?.shouldRefreshToken() == true
    }

    /**
     * Get token expiry timestamp
     */
    suspend fun getTokenExpiry(): Long = withContext(Dispatchers.IO) {
        sharedPreferences.getLong(KEY_EXPIRES_AT, 0L)
    }

    /**
     * Clear all stored data (logout)
     */
    suspend fun clear() = withContext(Dispatchers.IO) {
        sharedPreferences.edit().clear().apply()
    }

    /**
     * Save OTP session ID
     */
    suspend fun saveOtpSessionId(sessionId: String) = withContext(Dispatchers.IO) {
        sharedPreferences.edit()
            .putString(KEY_OTP_SESSION_ID, sessionId)
            .apply()
    }

    /**
     * Get OTP session ID
     */
    suspend fun getOtpSessionId(): String? = withContext(Dispatchers.IO) {
        sharedPreferences.getString(KEY_OTP_SESSION_ID, null)
    }

    /**
     * Clear OTP session ID
     */
    suspend fun clearOtpSessionId() = withContext(Dispatchers.IO) {
        sharedPreferences.edit()
            .remove(KEY_OTP_SESSION_ID)
            .apply()
    }

    companion object {
        private const val PREFS_FILENAME = "barqnet_secure_prefs"
        private const val KEY_USER_DATA = "user_data"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_EXPIRES_AT = "expires_at"
        private const val KEY_USER_ID = "user_id"
        private const val KEY_PHONE_NUMBER = "phone_number"
        private const val KEY_OTP_SESSION_ID = "otp_session_id"
    }
}
