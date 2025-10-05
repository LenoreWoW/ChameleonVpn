package com.workvpn.android.ui.screens

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.workvpn.android.viewmodel.VPNViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ImportScreen(
    vpnViewModel: VPNViewModel,
    onNavigateBack: () -> Unit
) {
    val context = LocalContext.current
    val errorMessage by vpnViewModel.errorMessage.collectAsState()

    val filePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            try {
                val inputStream = context.contentResolver.openInputStream(it)
                val fileName = it.lastPathSegment ?: "config.ovpn"

                inputStream?.use { stream ->
                    vpnViewModel.importConfig(stream, fileName)
                }

                // Navigate back on success
                if (errorMessage == null) {
                    onNavigateBack()
                }
            } catch (e: Exception) {
                // Error will be shown in UI
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Import Configuration") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF667EEA),
                    titleContentColor = Color.White,
                    navigationIconContentColor = Color.White
                )
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
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text(
                    text = "\uD83D\uDCC4",
                    style = MaterialTheme.typography.displayLarge,
                    modifier = Modifier.padding(bottom = 24.dp)
                )

                Text(
                    text = "Import Configuration",
                    style = MaterialTheme.typography.headlineMedium,
                    color = Color.White,
                    modifier = Modifier.padding(bottom = 16.dp)
                )

                Text(
                    text = "Select an OpenVPN configuration file (.ovpn) from your device",
                    style = MaterialTheme.typography.bodyLarge,
                    color = Color.White.copy(alpha = 0.9f),
                    modifier = Modifier.padding(bottom = 48.dp)
                )

                Button(
                    onClick = { filePicker.launch("*/*") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White,
                        contentColor = Color(0xFF667EEA)
                    )
                ) {
                    Text("Choose from Files", style = MaterialTheme.typography.titleMedium)
                }

                // Error message
                errorMessage?.let { error ->
                    Spacer(modifier = Modifier.height(24.dp))
                    Card(
                        colors = CardDefaults.cardColors(
                            containerColor = Color(0xFFEF4444).copy(alpha = 0.2f)
                        )
                    ) {
                        Text(
                            text = error,
                            style = MaterialTheme.typography.bodyMedium,
                            color = Color.White,
                            modifier = Modifier.padding(16.dp)
                        )
                    }
                }
            }
        }
    }

    // Clear error when leaving screen
    DisposableEffect(Unit) {
        onDispose {
            vpnViewModel.clearError()
        }
    }
}
