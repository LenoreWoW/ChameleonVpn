package com.workvpn.android.auth

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlin.random.Random

private val Context.authDataStore by preferencesDataStore(name = "auth_prefs")

class AuthManager(private val context: Context) {

    private val CURRENT_USER_KEY = stringPreferencesKey("current_user")
    private val USERS_KEY = stringPreferencesKey("users")

    private var otpStorage = mutableMapOf<String, Pair<String, Long>>() // phoneNumber -> (OTP, expiry)

    suspend fun sendOTP(phoneNumber: String): Result<Unit> {
        return try {
            val otp = Random.nextInt(100000, 999999).toString()
            val expiry = System.currentTimeMillis() + 10 * 60 * 1000 // 10 minutes

            otpStorage[phoneNumber] = Pair(otp, expiry)

            // In production, send SMS via Twilio/similar
            android.util.Log.d("AuthManager", "OTP for $phoneNumber: $otp")

            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun verifyOTP(phoneNumber: String, code: String): Result<Unit> {
        return try {
            val otpData = otpStorage[phoneNumber]
                ?: return Result.failure(Exception("No OTP session found"))

            val (storedOtp, expiry) = otpData

            if (System.currentTimeMillis() > expiry) {
                otpStorage.remove(phoneNumber)
                return Result.failure(Exception("OTP expired"))
            }

            if (storedOtp != code) {
                return Result.failure(Exception("Invalid OTP code"))
            }

            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun createAccount(phoneNumber: String, password: String): Result<Unit> {
        return try {
            val users = getUsersMap()

            if (users.containsKey(phoneNumber)) {
                return Result.failure(Exception("Account already exists"))
            }

            // In production, hash password with BCrypt
            val passwordHash = android.util.Base64.encodeToString(
                password.toByteArray(),
                android.util.Base64.DEFAULT
            )

            users[phoneNumber] = passwordHash

            saveUsersMap(users)

            // Auto-login
            context.authDataStore.edit { prefs ->
                prefs[CURRENT_USER_KEY] = phoneNumber
            }

            // Clean up OTP
            otpStorage.remove(phoneNumber)

            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun login(phoneNumber: String, password: String): Result<Unit> {
        return try {
            val users = getUsersMap()
            val storedHash = users[phoneNumber]
                ?: return Result.failure(Exception("Account not found"))

            val passwordHash = android.util.Base64.encodeToString(
                password.toByteArray(),
                android.util.Base64.DEFAULT
            )

            if (storedHash != passwordHash) {
                return Result.failure(Exception("Invalid password"))
            }

            context.authDataStore.edit { prefs ->
                prefs[CURRENT_USER_KEY] = phoneNumber
            }

            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun logout() {
        context.authDataStore.edit { prefs ->
            prefs.remove(CURRENT_USER_KEY)
        }
    }

    suspend fun isAuthenticated(): Boolean {
        val currentUser = context.authDataStore.data
            .map { prefs -> prefs[CURRENT_USER_KEY] }
            .first()
        return currentUser != null
    }

    suspend fun getCurrentUser(): String? {
        return context.authDataStore.data
            .map { prefs -> prefs[CURRENT_USER_KEY] }
            .first()
    }

    private suspend fun getUsersMap(): MutableMap<String, String> {
        val usersJson = context.authDataStore.data
            .map { prefs -> prefs[USERS_KEY] ?: "{}" }
            .first()

        return try {
            val map = mutableMapOf<String, String>()
            usersJson.removeSurrounding("{", "}").split(",").forEach { entry ->
                if (entry.isNotBlank()) {
                    val (key, value) = entry.split(":")
                    map[key.trim()] = value.trim()
                }
            }
            map
        } catch (e: Exception) {
            mutableMapOf()
        }
    }

    private suspend fun saveUsersMap(users: Map<String, String>) {
        val usersJson = users.entries.joinToString(",") { "${it.key}:${it.value}" }
        context.authDataStore.edit { prefs ->
            prefs[USERS_KEY] = "{$usersJson}"
        }
    }
}
