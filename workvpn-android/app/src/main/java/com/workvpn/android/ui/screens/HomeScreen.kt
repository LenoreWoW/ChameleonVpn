package com.workvpn.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.workvpn.android.model.ConnectionState
import com.workvpn.android.viewmodel.VPNViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    vpnViewModel: VPNViewModel,
    onNavigateToSettings: () -> Unit,
    onNavigateToImport: () -> Unit
) {
    val config by vpnViewModel.config.collectAsState()
    val connectionState by vpnViewModel.connectionState.collectAsState()
    val stats by vpnViewModel.stats.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("WorkVPN") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF667EEA),
                    titleContentColor = Color.White,
                    actionIconContentColor = Color.White
                ),
                actions = {
                    IconButton(onClick = onNavigateToSettings) {
                        Icon(Icons.Default.Settings, "Settings")
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
                        colors = listOf(
                            Color(0xFF667EEA),
                            Color(0xFF764BA2)
                        )
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
            text = "\uD83D\uDD12",
            style = MaterialTheme.typography.displayLarge,
            modifier = Modifier.padding(bottom = 24.dp)
        )

        Text(
            text = "No VPN Configuration",
            style = MaterialTheme.typography.headlineMedium,
            color = Color.White,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        Text(
            text = "Import an OpenVPN configuration file (.ovpn) to get started",
            style = MaterialTheme.typography.bodyLarge,
            color = Color.White.copy(alpha = 0.9f),
            modifier = Modifier.padding(bottom = 48.dp)
        )

        Button(
            onClick = onImportClick,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.White,
                contentColor = Color(0xFF667EEA)
            )
        ) {
            Text("Import .ovpn File", style = MaterialTheme.typography.titleMedium)
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
        Spacer(modifier = Modifier.height(32.dp))

        // Status Icon
        StatusIndicator(connectionState)

        Spacer(modifier = Modifier.height(24.dp))

        // Status Text
        Text(
            text = when (connectionState) {
                is ConnectionState.Connected -> "CONNECTED"
                is ConnectionState.Connecting -> "CONNECTING"
                is ConnectionState.Disconnecting -> "DISCONNECTING"
                is ConnectionState.Disconnected -> "DISCONNECTED"
                is ConnectionState.Error -> "ERROR"
            },
            style = MaterialTheme.typography.headlineMedium,
            color = Color.White
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Connection Info
        if (connectionState is ConnectionState.Connected) {
            ConnectionInfoCard(config, stats)
            Spacer(modifier = Modifier.height(24.dp))
        }

        // Connect/Disconnect Button
        Button(
            onClick = {
                when (connectionState) {
                    is ConnectionState.Connected,
                    is ConnectionState.Connecting -> vpnViewModel.disconnect(context)
                    else -> vpnViewModel.connect(context)
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(60.dp),
            enabled = connectionState !is ConnectionState.Connecting &&
                     connectionState !is ConnectionState.Disconnecting,
            colors = ButtonDefaults.buttonColors(
                containerColor = if (connectionState is ConnectionState.Connected) {
                    Color(0xFFEF4444)
                } else {
                    Color.White
                },
                contentColor = if (connectionState is ConnectionState.Connected) {
                    Color.White
                } else {
                    Color(0xFF667EEA)
                }
            )
        ) {
            Text(
                text = when (connectionState) {
                    is ConnectionState.Connected -> "Disconnect"
                    is ConnectionState.Connecting -> "Connecting..."
                    is ConnectionState.Disconnecting -> "Disconnecting..."
                    else -> "Connect"
                },
                style = MaterialTheme.typography.titleMedium
            )
        }

        Spacer(modifier = Modifier.weight(1f))

        // Delete Config Button
        TextButton(
            onClick = { vpnViewModel.deleteConfig() },
            modifier = Modifier.padding(top = 16.dp)
        ) {
            Text("Delete Configuration", color = Color.White.copy(alpha = 0.8f))
        }
    }
}

@Composable
fun StatusIndicator(connectionState: ConnectionState) {
    val color = when (connectionState) {
        is ConnectionState.Connected -> Color(0xFF10B981)
        is ConnectionState.Connecting,
        is ConnectionState.Disconnecting -> Color(0xFFF59E0B)
        is ConnectionState.Disconnected -> Color(0xFFEF4444)
        is ConnectionState.Error -> Color(0xFFEF4444)
    }

    Box(
        modifier = Modifier.size(150.dp),
        contentAlignment = Alignment.Center
    ) {
        // Outer glow
        Surface(
            modifier = Modifier.size(150.dp),
            shape = MaterialTheme.shapes.extraLarge,
            color = color.copy(alpha = 0.3f)
        ) {}

        // Inner circle
        Surface(
            modifier = Modifier.size(100.dp),
            shape = MaterialTheme.shapes.extraLarge,
            color = color
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text(
                    text = when (connectionState) {
                        is ConnectionState.Connected -> "✓"
                        is ConnectionState.Connecting -> "⟳"
                        is ConnectionState.Disconnecting -> "⟳"
                        else -> "✗"
                    },
                    style = MaterialTheme.typography.displayLarge,
                    color = Color.White
                )
            }
        }
    }
}

@Composable
fun ConnectionInfoCard(
    config: com.workvpn.android.model.VPNConfig,
    stats: com.workvpn.android.model.VPNStats
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.15f)
        )
    ) {
        Column(modifier = Modifier.padding(20.dp)) {
            InfoRow("Server", config.serverAddress)
            Spacer(modifier = Modifier.height(12.dp))
            InfoRow("Protocol", config.protocolDisplay)
            Spacer(modifier = Modifier.height(12.dp))
            InfoRow("Duration", stats.formattedDuration)
            Spacer(modifier = Modifier.height(20.dp))

            // Traffic Stats
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                StatBox("Download", stats.formattedBytesIn, Modifier.weight(1f))
                Spacer(modifier = Modifier.width(16.dp))
                StatBox("Upload", stats.formattedBytesOut, Modifier.weight(1f))
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
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White.copy(alpha = 0.8f)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White
        )
    }
}

@Composable
fun StatBox(label: String, value: String, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.1f)
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                color = Color.White.copy(alpha = 0.7f)
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                color = Color.White
            )
        }
    }
}
