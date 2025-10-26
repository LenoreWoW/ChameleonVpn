package com.barqnet.android.util

import android.content.Context
import android.widget.Toast
import com.barqnet.android.BuildConfig

/**
 * Centralized error handling for the VPN app
 * Provides user-friendly error messages and logging
 */
object ErrorHandler {

    /**
     * VPN-specific errors with user-friendly messages
     */
    sealed class VPNError(val message: String, val userMessage: String) {
        object NetworkUnavailable : VPNError(
            "Network unavailable",
            "No internet connection. Please check your network settings."
        )

        object InvalidConfig : VPNError(
            "Invalid VPN configuration",
            "The VPN configuration file is invalid or corrupted."
        )

        object ServerUnreachable : VPNError(
            "VPN server unreachable",
            "Cannot connect to VPN server. Please check your internet connection."
        )

        object AuthenticationFailed : VPNError(
            "Authentication failed",
            "Invalid credentials. Please check your username and password."
        )

        object ConnectionTimeout : VPNError(
            "Connection timeout",
            "Connection timed out. Please try again."
        )

        object CertificateInvalid : VPNError(
            "Certificate validation failed",
            "Server certificate is not trusted. Connection aborted for security."
        )

        object PermissionDenied : VPNError(
            "VPN permission denied",
            "VPN permission is required to establish a secure connection."
        )

        object ConfigNotFound : VPNError(
            "Configuration not found",
            "No VPN configuration found. Please import a .ovpn file first."
        )

        object AlreadyConnected : VPNError(
            "Already connected",
            "VPN is already connected."
        )

        object DisconnectFailed : VPNError(
            "Disconnect failed",
            "Failed to disconnect VPN. Please try again."
        )

        data class Unknown(val error: String) : VPNError(
            "Unknown error: $error",
            "An unexpected error occurred. Please try again."
        )
    }

    /**
     * Authentication errors
     */
    sealed class AuthError(val message: String, val userMessage: String) {
        object InvalidPhoneNumber : AuthError(
            "Invalid phone number",
            "Please enter a valid phone number."
        )

        object InvalidOTP : AuthError(
            "Invalid OTP",
            "The verification code is incorrect. Please try again."
        )

        object OTPExpired : AuthError(
            "OTP expired",
            "The verification code has expired. Please request a new one."
        )

        object WeakPassword : AuthError(
            "Weak password",
            "Password must be at least 8 characters long."
        )

        object AccountExists : AuthError(
            "Account exists",
            "An account with this phone number already exists."
        )

        object AccountNotFound : AuthError(
            "Account not found",
            "No account found with this phone number."
        )

        object RateLimitExceeded : AuthError(
            "Rate limit exceeded",
            "Too many attempts. Please try again later."
        )

        data class Unknown(val error: String) : AuthError(
            "Unknown error: $error",
            "An unexpected error occurred during authentication."
        )
    }

    /**
     * Handle VPN errors
     */
    fun handleVPNError(context: Context, error: VPNError, showToast: Boolean = true) {
        // Log error
        logError("VPN", error.message)

        // Show user-friendly message
        if (showToast) {
            showError(context, error.userMessage)
        }

        // ENHANCEMENT: Add analytics (Firebase, Sentry, etc.)
        // Analytics.trackError("vpn_error", error.message)
    }

    /**
     * Handle authentication errors
     */
    fun handleAuthError(context: Context, error: AuthError, showToast: Boolean = true) {
        // Log error
        logError("Auth", error.message)

        // Show user-friendly message
        if (showToast) {
            showError(context, error.userMessage)
        }

        // ENHANCEMENT: Add analytics tracking
        // Analytics.trackError("auth_error", error.message)
    }

    /**
     * Handle generic exceptions
     */
    fun handleException(
        context: Context,
        exception: Exception,
        category: String = "General",
        showToast: Boolean = true
    ) {
        // Log exception
        logException(category, exception)

        // Show generic error message
        if (showToast) {
            val message = if (BuildConfig.DEBUG) {
                "Error: ${exception.message}"
            } else {
                "An unexpected error occurred. Please try again."
            }
            showError(context, message)
        }

        // ENHANCEMENT: Add crash reporting (Firebase Crashlytics, Sentry)
        // Crashlytics.recordException(exception)
    }

    /**
     * Convert exceptions to VPN errors
     */
    fun exceptionToVPNError(exception: Exception): VPNError {
        return when {
            exception.message?.contains("network", ignoreCase = true) == true ->
                VPNError.NetworkUnavailable

            exception.message?.contains("timeout", ignoreCase = true) == true ->
                VPNError.ConnectionTimeout

            exception.message?.contains("certificate", ignoreCase = true) == true ->
                VPNError.CertificateInvalid

            exception.message?.contains("auth", ignoreCase = true) == true ->
                VPNError.AuthenticationFailed

            exception.message?.contains("permission", ignoreCase = true) == true ->
                VPNError.PermissionDenied

            else -> VPNError.Unknown(exception.message ?: "Unknown error")
        }
    }

    /**
     * Convert exceptions to auth errors
     */
    fun exceptionToAuthError(exception: Exception): AuthError {
        return when {
            exception.message?.contains("OTP", ignoreCase = true) == true ||
            exception.message?.contains("code", ignoreCase = true) == true ->
                AuthError.InvalidOTP

            exception.message?.contains("expired", ignoreCase = true) == true ->
                AuthError.OTPExpired

            exception.message?.contains("password", ignoreCase = true) == true ->
                AuthError.WeakPassword

            exception.message?.contains("exists", ignoreCase = true) == true ->
                AuthError.AccountExists

            exception.message?.contains("not found", ignoreCase = true) == true ->
                AuthError.AccountNotFound

            exception.message?.contains("rate limit", ignoreCase = true) == true ->
                AuthError.RateLimitExceeded

            else -> AuthError.Unknown(exception.message ?: "Unknown error")
        }
    }

    /**
     * Show error toast
     */
    private fun showError(context: Context, message: String) {
        Toast.makeText(context, message, Toast.LENGTH_LONG).show()
    }

    /**
     * Log error (only in debug builds or to crash reporting)
     */
    private fun logError(category: String, message: String) {
        if (BuildConfig.ENABLE_LOGGING) {
            android.util.Log.e("ErrorHandler", "[$category] $message")
        }
    }

    /**
     * Log exception
     */
    private fun logException(category: String, exception: Exception) {
        if (BuildConfig.ENABLE_LOGGING) {
            android.util.Log.e("ErrorHandler", "[$category] Exception", exception)
        }
    }
}

/**
 * Extension functions for easier error handling
 */
fun Exception.toVPNError(): ErrorHandler.VPNError {
    return ErrorHandler.exceptionToVPNError(this)
}

fun Exception.toAuthError(): ErrorHandler.AuthError {
    return ErrorHandler.exceptionToAuthError(this)
}

fun Exception.handle(context: Context, category: String = "General") {
    ErrorHandler.handleException(context, this, category)
}
