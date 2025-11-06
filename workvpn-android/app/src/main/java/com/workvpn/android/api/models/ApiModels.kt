package com.barqnet.android.api.models

import com.google.gson.annotations.SerializedName

/**
 * API Data Models for BarqNet Backend
 *
 * These models match the backend API contract:
 * - POST /v1/auth/send-otp
 * - POST /v1/auth/verify-otp
 * - POST /v1/auth/register
 * - POST /v1/auth/login
 * - POST /v1/auth/refresh
 */

// ==================== Request Models ====================

data class SendOtpRequest(
    @SerializedName("phone_number")
    val phoneNumber: String
)

data class VerifyOtpRequest(
    @SerializedName("phone_number")
    val phoneNumber: String,
    @SerializedName("otp")
    val otp: String
)

data class RegisterRequest(
    @SerializedName("phone_number")
    val phoneNumber: String,
    @SerializedName("password")
    val password: String,
    @SerializedName("otp_session_id")
    val otpSessionId: String
)

data class LoginRequest(
    @SerializedName("phone_number")
    val phoneNumber: String,
    @SerializedName("password")
    val password: String
)

data class RefreshTokenRequest(
    @SerializedName("refresh_token")
    val refreshToken: String
)

// ==================== Response Models ====================

data class SendOtpResponse(
    @SerializedName("session_id")
    val sessionId: String,
    @SerializedName("expires_at")
    val expiresAt: Long,
    @SerializedName("message")
    val message: String
)

data class VerifyOtpResponse(
    @SerializedName("verified")
    val verified: Boolean,
    @SerializedName("session_id")
    val sessionId: String,
    @SerializedName("message")
    val message: String
)

data class RegisterResponse(
    @SerializedName("user_id")
    val userId: String,
    @SerializedName("phone_number")
    val phoneNumber: String,
    @SerializedName("access_token")
    val accessToken: String,
    @SerializedName("refresh_token")
    val refreshToken: String,
    @SerializedName("expires_at")
    val expiresAt: Long,
    @SerializedName("message")
    val message: String
)

data class LoginResponse(
    @SerializedName("user_id")
    val userId: String,
    @SerializedName("phone_number")
    val phoneNumber: String,
    @SerializedName("access_token")
    val accessToken: String,
    @SerializedName("refresh_token")
    val refreshToken: String,
    @SerializedName("expires_at")
    val expiresAt: Long,
    @SerializedName("message")
    val message: String
)

data class RefreshTokenResponse(
    @SerializedName("access_token")
    val accessToken: String,
    @SerializedName("expires_at")
    val expiresAt: Long,
    @SerializedName("message")
    val message: String
)

data class ErrorResponse(
    @SerializedName("error")
    val error: String,
    @SerializedName("message")
    val message: String,
    @SerializedName("code")
    val code: Int? = null
)

// ==================== User Data Model ====================

data class UserData(
    val userId: String,
    val phoneNumber: String,
    val accessToken: String,
    val refreshToken: String,
    val expiresAt: Long
) {
    fun isTokenExpired(): Boolean {
        return System.currentTimeMillis() > expiresAt
    }

    fun shouldRefreshToken(): Boolean {
        // Refresh 5 minutes before expiry
        val fiveMinutesInMs = 5 * 60 * 1000
        return System.currentTimeMillis() > (expiresAt - fiveMinutesInMs)
    }
}
