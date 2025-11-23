package com.barqnet.android.api

import android.util.Log
import com.barqnet.android.BuildConfig
import com.barqnet.android.api.models.*
import okhttp3.CertificatePinner
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.*
import java.util.concurrent.TimeUnit

/**
 * Retrofit API Service for BarqNet Backend
 *
 * This service handles all authentication API calls:
 * - OTP sending and verification
 * - User registration
 * - User login
 * - Token refresh
 *
 * Features:
 * - Certificate pinning for security
 * - Automatic token refresh
 * - Request/response logging (debug only)
 * - Proper error handling
 * - Timeout configuration
 *
 * @author BarqNet Team
 */
interface BarqNetApi {

    @POST("v1/auth/send-otp")
    suspend fun sendOtp(@Body request: SendOtpRequest): Response<SendOtpResponse>

    @POST("v1/auth/verify-otp")
    suspend fun verifyOtp(@Body request: VerifyOtpRequest): Response<VerifyOtpResponse>

    @POST("v1/auth/register")
    suspend fun register(@Body request: RegisterRequest): Response<RegisterResponse>

    @POST("v1/auth/login")
    suspend fun login(@Body request: LoginRequest): Response<LoginResponse>

    @POST("v1/auth/refresh")
    suspend fun refreshToken(@Body request: RefreshTokenRequest): Response<RefreshTokenResponse>
}

/**
 * ApiService - Singleton wrapper for Retrofit API
 *
 * Usage:
 * ```kotlin
 * val result = ApiService.sendOtp("+1234567890")
 * if (result.isSuccess) {
 *     val response = result.getOrNull()
 *     // Use response
 * } else {
 *     val error = result.exceptionOrNull()
 *     // Handle error
 * }
 * ```
 */
object ApiService {

    private const val TAG = "ApiService"

    // TODO: Replace with actual backend URL
    private const val BASE_URL = "https://api.barqnet.com/"

    // TODO: Replace with actual certificate pins from backend
    // To get certificate pin, run:
    // openssl s_client -connect api.barqnet.com:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64
    private val CERTIFICATE_PINS = listOf(
        "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", // Primary certificate
        "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="  // Backup certificate
    )

    private val api: BarqNetApi by lazy {
        createRetrofitInstance()
    }

    /**
     * Create Retrofit instance with all interceptors and configurations
     */
    private fun createRetrofitInstance(): BarqNetApi {
        val okHttpClient = createOkHttpClient()

        return Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(BarqNetApi::class.java)
    }

    /**
     * Create OkHttpClient with interceptors and certificate pinning
     */
    private fun createOkHttpClient(): OkHttpClient {
        val builder = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .retryOnConnectionFailure(true)

        // Add logging interceptor (debug builds only)
        if (BuildConfig.ENABLE_LOGGING) {
            val loggingInterceptor = HttpLoggingInterceptor { message ->
                Log.d(TAG, message)
            }.apply {
                level = HttpLoggingInterceptor.Level.BODY
            }
            builder.addInterceptor(loggingInterceptor)
        }

        // Add header interceptor
        builder.addInterceptor(createHeaderInterceptor())

        // Add certificate pinning for security
        builder.certificatePinner(createCertificatePinner())

        return builder.build()
    }

    /**
     * Create certificate pinner for backend API
     */
    private fun createCertificatePinner(): CertificatePinner {
        val hostname = BASE_URL.removePrefix("https://").removeSuffix("/")
        val builder = CertificatePinner.Builder()

        CERTIFICATE_PINS.forEach { pin ->
            builder.add(hostname, pin)
        }

        return builder.build()
    }

    /**
     * Create header interceptor for adding common headers
     */
    private fun createHeaderInterceptor(): Interceptor {
        return Interceptor { chain ->
            val original = chain.request()
            val request = original.newBuilder()
                .header("User-Agent", "BarqNet-Android/${BuildConfig.VERSION_NAME}")
                .header("Accept", "application/json")
                .header("Content-Type", "application/json")
                .build()
            chain.proceed(request)
        }
    }

    /**
     * Create auth interceptor for adding access token
     */
    fun createAuthInterceptor(getAccessToken: () -> String?): Interceptor {
        return Interceptor { chain ->
            val original = chain.request()
            val token = getAccessToken()

            val request = if (token != null) {
                original.newBuilder()
                    .header("Authorization", "Bearer $token")
                    .build()
            } else {
                original
            }

            chain.proceed(request)
        }
    }

    // ==================== API Methods ====================

    /**
     * Send OTP to email address
     */
    suspend fun sendOtp(email: String): Result<SendOtpResponse> {
        return try {
            val response = api.sendOtp(SendOtpRequest(email))
            if (response.isSuccessful && response.body() != null) {
                Result.success(response.body()!!)
            } else {
                val errorMsg = parseErrorResponse(response)
                Result.failure(Exception(errorMsg))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send OTP", e)
            Result.failure(e)
        }
    }

    /**
     * Verify OTP code
     */
    suspend fun verifyOtp(email: String, otp: String, sessionId: String? = null): Result<VerifyOtpResponse> {
        return try {
            val response = api.verifyOtp(VerifyOtpRequest(email, otp, sessionId))
            if (response.isSuccessful && response.body() != null) {
                Result.success(response.body()!!)
            } else {
                val errorMsg = parseErrorResponse(response)
                Result.failure(Exception(errorMsg))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to verify OTP", e)
            Result.failure(e)
        }
    }

    /**
     * Register new user
     */
    suspend fun register(
        email: String,
        password: String,
        otpSessionId: String
    ): Result<RegisterResponse> {
        return try {
            val response = api.register(RegisterRequest(email, password, otpSessionId))
            if (response.isSuccessful && response.body() != null) {
                Result.success(response.body()!!)
            } else {
                val errorMsg = parseErrorResponse(response)
                Result.failure(Exception(errorMsg))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register", e)
            Result.failure(e)
        }
    }

    /**
     * Login existing user
     */
    suspend fun login(email: String, password: String): Result<LoginResponse> {
        return try {
            val response = api.login(LoginRequest(email, password))
            if (response.isSuccessful && response.body() != null) {
                Result.success(response.body()!!)
            } else {
                val errorMsg = parseErrorResponse(response)
                Result.failure(Exception(errorMsg))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to login", e)
            Result.failure(e)
        }
    }

    /**
     * Refresh access token
     */
    suspend fun refreshToken(refreshToken: String): Result<RefreshTokenResponse> {
        return try {
            val response = api.refreshToken(RefreshTokenRequest(refreshToken))
            if (response.isSuccessful && response.body() != null) {
                Result.success(response.body()!!)
            } else {
                val errorMsg = parseErrorResponse(response)
                Result.failure(Exception(errorMsg))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to refresh token", e)
            Result.failure(e)
        }
    }

    /**
     * Parse error response from API
     */
    private fun parseErrorResponse(response: Response<*>): String {
        return try {
            val errorBody = response.errorBody()?.string()
            errorBody ?: "Unknown error (${response.code()})"
        } catch (e: Exception) {
            "Failed to parse error response: ${e.message}"
        }
    }
}
