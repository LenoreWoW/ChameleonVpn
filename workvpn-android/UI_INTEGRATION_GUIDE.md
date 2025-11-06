# UI Integration Guide for Backend API

This guide shows how to update your Compose UI screens to use the new backend-integrated AuthManager.

---

## 1. Phone Number Screen (OTP Request)

### Update imports:
```kotlin
import com.barqnet.android.auth.AuthManager
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.launch
```

### Update ViewModel:
```kotlin
class OnboardingViewModel(application: Application) : AndroidViewModel(application) {
    private val authManager = AuthManager(application)

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    fun sendOtp(phoneNumber: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null

            val result = authManager.sendOTP(phoneNumber)

            _isLoading.value = false

            if (result.isSuccess) {
                // Navigate to OTP verification screen
                _navigationEvent.value = NavigationEvent.OtpVerification
            } else {
                _errorMessage.value = result.exceptionOrNull()?.message
                    ?: "Failed to send OTP"
            }
        }
    }
}
```

### Update Composable:
```kotlin
@Composable
fun PhoneNumberScreen(viewModel: OnboardingViewModel, navController: NavController) {
    val isLoading by viewModel.isLoading.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()

    Column {
        OutlinedTextField(
            value = phoneNumber,
            onValueChange = { phoneNumber = it },
            label = { Text("Phone Number") },
            enabled = !isLoading
        )

        if (errorMessage != null) {
            Text(
                text = errorMessage!!,
                color = MaterialTheme.colorScheme.error
            )
        }

        Button(
            onClick = { viewModel.sendOtp(phoneNumber) },
            enabled = !isLoading && phoneNumber.isNotBlank()
        ) {
            if (isLoading) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp))
            } else {
                Text("Send OTP")
            }
        }
    }
}
```

---

## 2. OTP Verification Screen

### Update ViewModel:
```kotlin
fun verifyOtp(phoneNumber: String, otpCode: String) {
    viewModelScope.launch {
        _isLoading.value = true
        _errorMessage.value = null

        val result = authManager.verifyOTP(phoneNumber, otpCode)

        _isLoading.value = false

        if (result.isSuccess) {
            // Navigate to password creation or main app
            _navigationEvent.value = NavigationEvent.PasswordCreation
        } else {
            _errorMessage.value = result.exceptionOrNull()?.message
                ?: "Invalid OTP code"
        }
    }
}
```

---

## 3. Password Creation Screen (Registration)

### Update ViewModel:
```kotlin
fun createAccount(phoneNumber: String, password: String) {
    viewModelScope.launch {
        _isLoading.value = true
        _errorMessage.value = null

        val result = authManager.createAccount(phoneNumber, password)

        _isLoading.value = false

        if (result.isSuccess) {
            // Account created! Navigate to main app
            _navigationEvent.value = NavigationEvent.MainApp
        } else {
            _errorMessage.value = result.exceptionOrNull()?.message
                ?: "Failed to create account"
        }
    }
}
```

---

## 4. Login Screen

### Update ViewModel:
```kotlin
fun login(phoneNumber: String, password: String) {
    viewModelScope.launch {
        _isLoading.value = true
        _errorMessage.value = null

        val result = authManager.login(phoneNumber, password)

        _isLoading.value = false

        if (result.isSuccess) {
            // Login successful! Navigate to main app
            _navigationEvent.value = NavigationEvent.MainApp
        } else {
            _errorMessage.value = result.exceptionOrNull()?.message
                ?: "Invalid credentials"
        }
    }
}
```

---

## 5. Settings Screen

### Update ViewModel:
```kotlin
class SettingsViewModel(application: Application) : AndroidViewModel(application) {
    private val settingsManager = SettingsManager(application)
    private val authManager = AuthManager(application)

    val autoConnect = settingsManager.autoConnectFlow.stateIn(
        viewModelScope,
        SharingStarted.Eagerly,
        false
    )

    val biometricEnabled = settingsManager.biometricEnabledFlow.stateIn(
        viewModelScope,
        SharingStarted.Eagerly,
        false
    )

    fun setAutoConnect(enabled: Boolean) {
        viewModelScope.launch {
            settingsManager.setAutoConnect(enabled)
        }
    }

    fun setBiometricEnabled(enabled: Boolean) {
        viewModelScope.launch {
            settingsManager.setBiometricEnabled(enabled)
        }
    }

    fun logout() {
        viewModelScope.launch {
            authManager.logout()
            // Navigate to login screen
        }
    }
}
```

### Update Composable:
```kotlin
@Composable
fun SettingsScreen(viewModel: SettingsViewModel) {
    val autoConnect by viewModel.autoConnect.collectAsState()
    val biometricEnabled by viewModel.biometricEnabled.collectAsState()

    Column {
        SwitchPreference(
            title = "Auto-Connect",
            subtitle = "Connect automatically when device starts",
            checked = autoConnect,
            onCheckedChange = { viewModel.setAutoConnect(it) }
        )

        SwitchPreference(
            title = "Biometric Authentication",
            subtitle = "Use fingerprint or face to unlock",
            checked = biometricEnabled,
            onCheckedChange = { viewModel.setBiometricEnabled(it) }
        )

        Button(onClick = { viewModel.logout() }) {
            Text("Logout")
        }
    }
}
```

---

## 6. VPN Connection with Permission

### Update MainActivity:
```kotlin
class MainActivity : AppCompatActivity() {
    private lateinit var vpnPermissionHelper: VpnPermissionHelper

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        vpnPermissionHelper = VpnPermissionHelper(this) { granted ->
            if (granted) {
                // Permission granted, retry connection
                viewModel.retryAfterPermission(this)
            } else {
                // Permission denied, show error
                Toast.makeText(this, "VPN permission required", Toast.LENGTH_LONG).show()
            }
        }

        setContent {
            BarqNetApp()
        }
    }
}
```

### Update HomeScreen:
```kotlin
@Composable
fun HomeScreen(viewModel: RealVPNViewModel) {
    val vpnPermissionNeeded by viewModel.vpnPermissionNeeded.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(vpnPermissionNeeded) {
        if (vpnPermissionNeeded) {
            // Request VPN permission
            val activity = context as? AppCompatActivity
            activity?.let {
                val vpnPermissionHelper = VpnPermissionHelper(it) { granted ->
                    if (granted) {
                        viewModel.retryAfterPermission(context)
                    } else {
                        viewModel.clearVpnPermissionFlag()
                    }
                }
                vpnPermissionHelper.requestPermission()
            }
        }
    }

    // Rest of your UI...
}
```

---

## 7. Initialize Token Refresh Worker

### Update Application class:
```kotlin
class BarqNetApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        // Initialize token refresh worker
        TokenRefreshWorker.schedule(this)
    }
}
```

---

## 8. Check Authentication State on App Start

### Update MainActivity:
```kotlin
class MainActivity : AppCompatActivity() {
    private val authManager by lazy { AuthManager(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        lifecycleScope.launch {
            if (authManager.isAuthenticated()) {
                // User is logged in, go to main screen
                startDestination = "home"
            } else {
                // User not logged in, go to onboarding
                startDestination = "phone_number"
            }
        }

        setContent {
            BarqNetApp(startDestination = startDestination)
        }
    }
}
```

---

## 9. Handle Authentication State Changes

### Create AuthViewModel:
```kotlin
class AuthViewModel(application: Application) : AndroidViewModel(application) {
    private val authManager = AuthManager(application)

    val authState = authManager.authState.stateIn(
        viewModelScope,
        SharingStarted.Eagerly,
        AuthState.Unauthenticated
    )

    val isAuthenticated = authState.map {
        it is AuthState.Authenticated
    }.stateIn(
        viewModelScope,
        SharingStarted.Eagerly,
        false
    )

    val currentUser = authState.map {
        (it as? AuthState.Authenticated)?.userData
    }.stateIn(
        viewModelScope,
        SharingStarted.Eagerly,
        null
    )
}
```

### Use in NavHost:
```kotlin
@Composable
fun BarqNetNavHost(authViewModel: AuthViewModel) {
    val isAuthenticated by authViewModel.isAuthenticated.collectAsState()

    NavHost(
        navController = navController,
        startDestination = if (isAuthenticated) "home" else "phone_number"
    ) {
        // Onboarding screens
        composable("phone_number") { PhoneNumberScreen(...) }
        composable("otp_verification") { OTPVerificationScreen(...) }
        composable("password_creation") { PasswordCreationScreen(...) }
        composable("login") { LoginScreen(...) }

        // Main screens (protected)
        composable("home") {
            if (isAuthenticated) {
                HomeScreen(...)
            } else {
                LaunchedEffect(Unit) {
                    navController.navigate("phone_number")
                }
            }
        }
    }
}
```

---

## 10. Error Handling Best Practices

### Show user-friendly errors:
```kotlin
fun String?.toUserFriendlyError(): String {
    return when {
        this == null -> "An unknown error occurred"
        this.contains("network", ignoreCase = true) -> "Network error. Please check your connection."
        this.contains("timeout", ignoreCase = true) -> "Request timed out. Please try again."
        this.contains("unauthorized", ignoreCase = true) -> "Session expired. Please login again."
        this.contains("invalid", ignoreCase = true) -> "Invalid input. Please check and try again."
        else -> this
    }
}

// Usage
_errorMessage.value = result.exceptionOrNull()?.message.toUserFriendlyError()
```

---

## Complete Example: Phone Number to Main App Flow

```kotlin
// 1. PhoneNumberScreen
Button(onClick = { viewModel.sendOtp(phoneNumber) })

// 2. After OTP sent, navigate to OTPVerificationScreen
navController.navigate("otp_verification/$phoneNumber")

// 3. OTPVerificationScreen
Button(onClick = { viewModel.verifyOtp(phoneNumber, otpCode) })

// 4. After OTP verified, navigate to PasswordCreationScreen
navController.navigate("password_creation/$phoneNumber")

// 5. PasswordCreationScreen
Button(onClick = { viewModel.createAccount(phoneNumber, password) })

// 6. After account created, navigate to main app
navController.navigate("home") {
    popUpTo("phone_number") { inclusive = true }
}

// 7. HomeScreen - user is now authenticated!
// AuthManager has:
// - Saved access token to EncryptedSharedPreferences
// - Started automatic token refresh monitoring
// - TokenRefreshWorker will refresh token every 15 minutes
```

---

## Testing Checklist

- [ ] Phone number screen sends OTP
- [ ] OTP verification works
- [ ] Account creation succeeds
- [ ] Login works with existing account
- [ ] Token is stored securely
- [ ] Token refreshes automatically
- [ ] VPN permission dialog shows
- [ ] VPN connects after permission
- [ ] Settings persist after app restart
- [ ] Logout clears all data
- [ ] Auto-login works on app restart

---

## Common Issues and Solutions

### Issue: "VPN permission required" error
**Solution:** Use VpnPermissionHelper and handle the callback properly

### Issue: "Failed to send OTP" error
**Solution:** Check backend URL and certificate pins in ApiService.kt

### Issue: Token expired immediately
**Solution:** Check system time synchronization

### Issue: Settings not persisting
**Solution:** Make sure SettingsManager is using the correct DataStore instance

### Issue: Memory leak warnings
**Solution:** Don't hold direct references to VPN service - use VpnServiceConnection global flows

---

That's it! Your Android app is now fully integrated with the backend API.
