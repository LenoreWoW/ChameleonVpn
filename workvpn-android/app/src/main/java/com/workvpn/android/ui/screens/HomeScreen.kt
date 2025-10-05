package com.workvpn.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.workvpn.android.auth.AuthManager
import com.workvpn.android.model.ConnectionState
import com.workvpn.android.ui.screens.onboarding.*
import com.workvpn.android.ui.theme.*
import com.workvpn.android.viewmodel.VPNViewModel
import kotlinx.coroutines.launch

enum class OnboardingState {
    PHONE_ENTRY,
    OTP_VERIFICATION,
    PASSWORD_CREATION,
    LOGIN,
    AUTHENTICATED
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    vpnViewModel: VPNViewModel,
    onNavigateToSettings: () -> Unit,
    onNavigateToImport: () -> Unit
) {
    val context = LocalContext.current
    val authManager = remember { AuthManager(context) }
    val scope = rememberCoroutineScope()

    var onboardingState by remember { mutableStateOf(OnboardingState.PHONE_ENTRY) }
    var currentPhoneNumber by remember { mutableStateOf("") }
    var isAuthenticated by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        isAuthenticated = authManager.isAuthenticated()
        if (isAuthenticated) {
            onboardingState = OnboardingState.AUTHENTICATED
        }
    }

    when (onboardingState) {
        OnboardingState.PHONE_ENTRY -> {
            PhoneNumberScreen(
                onContinue = { phone ->
                    scope.launch {
                        val result = authManager.sendOTP(phone)
                        if (result.isSuccess) {
                            currentPhoneNumber = phone
                            onboardingState = OnboardingState.OTP_VERIFICATION
                        }
                    }
                },
                onLoginClick = {
                    onboardingState = OnboardingState.LOGIN
                }
            )
        }

        OnboardingState.OTP_VERIFICATION -> {
            OTPVerificationScreen(
                phoneNumber = currentPhoneNumber,
                onVerify = { code ->
                    scope.launch {
                        val result = authManager.verifyOTP(currentPhoneNumber, code)
                        if (result.isSuccess) {
                            onboardingState = OnboardingState.PASSWORD_CREATION
                        }
                    }
                },
                onResend = {
                    scope.launch {
                        authManager.sendOTP(currentPhoneNumber)
                    }
                }
            )
        }

        OnboardingState.PASSWORD_CREATION -> {
            PasswordCreationScreen(
                phoneNumber = currentPhoneNumber,
                onCreate = { password ->
                    scope.launch {
                        val result = authManager.createAccount(currentPhoneNumber, password)
                        if (result.isSuccess) {
                            isAuthenticated = true
                            onboardingState = OnboardingState.AUTHENTICATED
                        }
                    }
                }
            )
        }

        OnboardingState.LOGIN -> {
            LoginScreen(
                onLogin = { phone, password ->
                    scope.launch {
                        val result = authManager.login(phone, password)
                        if (result.isSuccess) {
                            isAuthenticated = true
                            currentPhoneNumber = phone
                            onboardingState = OnboardingState.AUTHENTICATED
                        }
                    }
                },
                onSignUpClick = {
                    onboardingState = OnboardingState.PHONE_ENTRY
                }
            )
        }

        OnboardingState.AUTHENTICATED -> {
            // Show main VPN UI
            val config by vpnViewModel.config.collectAsState()
            val connectionState by vpnViewModel.connectionState.collectAsState()
            val stats by vpnViewModel.stats.collectAsState()

            Scaffold(
                topBar = {
                    TopAppBar(
                        title = { Text("WorkVPN") },
                        colors = TopAppBarDefaults.topAppBarColors(
                            containerColor = DarkBg,
                            titleContentColor = CyanBlue,
                            actionIconContentColor = CyanBlue
                        ),
                        actions = {
                            IconButton(onClick = onNavigateToSettings) {
                                Icon(Icons.Default.Settings, "Settings")
                            }
                            IconButton(onClick = {
                                scope.launch {
                                    authManager.logout()
                                    isAuthenticated = false
                                    onboardingState = OnboardingState.PHONE_ENTRY
                                }
                            }) {
                                Text("↪", style = MaterialTheme.typography.headlineMedium)
                            }
                        }
                    )
                }
            ) { paddingValues ->
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues)
                        .background(
                            brush = Brush.verticalGradient(
                                colors = listOf(DarkBg, DarkBgSecondary, DarkBgTertiary)
                            )
                        )
                ) {
                    if (config == null) {
                        NoConfigContent(onImportClick = onNavigateToImport)
                    } else {
                        VPNStatusContent(
                            config = config!!,
                            connectionState = connectionState,
                            stats = stats,
                            vpnViewModel = vpnViewModel
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun NoConfigContent(onImportClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "🔒",
            style = MaterialTheme.typography.displayLarge,
            modifier = Modifier.padding(bottom = 24.dp)
        )

        Text(
            text = "No VPN Configuration",
            style = MaterialTheme.typography.headlineMedium,
            color = CyanBlue,
            modifier = Modifier.padding(bottom = 16.dp),
            textAlign = TextAlign.Center
        )

        Text(
            text = "Import an OpenVPN configuration file (.ovpn) to get started",
            style = MaterialTheme.typography.bodyLarge,
            color = Color.White.copy(alpha = 0.6f),
            modifier = Modifier.padding(bottom = 32.dp),
            textAlign = TextAlign.Center
        )

        Button(
            onClick = onImportClick,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
            shape = RoundedCornerShape(12.dp)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.horizontalGradient(listOf(CyanBlue, DeepBlue)),
                        shape = RoundedCornerShape(12.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text("IMPORT .OVPN FILE", style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

@Composable
fun VPNStatusContent(
    config: com.workvpn.android.model.VPNConfig,
    connectionState: ConnectionState,
    stats: com.workvpn.android.model.VPNStats,
    vpnViewModel: VPNViewModel
) {
    val context = LocalContext.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(40.dp))

        // Connection Status Circle
        Box(
            modifier = Modifier
                .size(120.dp)
                .clip(CircleShape)
                .background(
                    when (connectionState) {
                        is ConnectionState.Connected -> Brush.radialGradient(listOf(Green, GreenDark))
                        is ConnectionState.Connecting -> Brush.radialGradient(listOf(Orange, OrangeDark))
                        else -> Brush.radialGradient(listOf(GrayLight, GrayDark))
                    }
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "●",
                style = MaterialTheme.typography.displayLarge,
                color = Color.White
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = when (connectionState) {
                is ConnectionState.Connected -> "CONNECTED"
                is ConnectionState.Connecting -> "CONNECTING"
                is ConnectionState.Disconnected -> "DISCONNECTED"
                is ConnectionState.Disconnecting -> "DISCONNECTING"
                is ConnectionState.Error -> "ERROR"
            },
            style = MaterialTheme.typography.headlineSmall,
            color = CyanBlue
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Server Info Card
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = DarkBgSecondary.copy(alpha = 0.5f)
            ),
            shape = RoundedCornerShape(16.dp)
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                InfoRow("Server", config.serverAddress)
                Divider(color = Color.White.copy(alpha = 0.1f), modifier = Modifier.padding(vertical = 12.dp))
                InfoRow("Protocol", config.protocolDisplay)
                Divider(color = Color.White.copy(alpha = 0.1f), modifier = Modifier.padding(vertical = 12.dp))
                InfoRow("Duration", formatDuration(stats.duration.toLong()))
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Stats Row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            StatCard(
                label = "DOWNLOAD",
                value = formatBytes(stats.bytesIn),
                modifier = Modifier.weight(1f)
            )
            StatCard(
                label = "UPLOAD",
                value = formatBytes(stats.bytesOut),
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(modifier = Modifier.height(32.dp))

        // Connect/Disconnect Button
        Button(
            onClick = {
                if (connectionState is ConnectionState.Connected) {
                    vpnViewModel.disconnect(context)
                } else {
                    vpnViewModel.connect(context)
                }
            },
            enabled = connectionState !is ConnectionState.Connecting,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
            shape = RoundedCornerShape(12.dp)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        when (connectionState) {
                            is ConnectionState.Connected -> Brush.horizontalGradient(listOf(Red, RedDark))
                            else -> Brush.horizontalGradient(listOf(Green, GreenDark))
                        },
                        shape = RoundedCornerShape(12.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = if (connectionState is ConnectionState.Connected) "DISCONNECT" else "CONNECT",
                    style = MaterialTheme.typography.labelLarge
                )
            }
        }
    }
}

@Composable
fun InfoRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label.uppercase(),
            style = MaterialTheme.typography.labelSmall,
            color = Color.White.copy(alpha = 0.6f)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = CyanBlue
        )
    }
}

@Composable
fun StatCard(label: String, value: String, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = DarkBgSecondary.copy(alpha = 0.5f)
        ),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.5f)
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                color = CyanBlue
            )
        }
    }
}

fun formatBytes(bytes: Long): String {
    if (bytes == 0L) return "0 MB"
    val mb = bytes / (1024 * 1024)
    return "$mb MB"
}

fun formatDuration(seconds: Long): String {
    if (seconds == 0L) return "-"
    val hours = seconds / 3600
    val minutes = (seconds % 3600) / 60
    val secs = seconds % 60

    return when {
        hours > 0 -> "${hours}h ${minutes}m ${secs}s"
        minutes > 0 -> "${minutes}m ${secs}s"
        else -> "${secs}s"
    }
}
