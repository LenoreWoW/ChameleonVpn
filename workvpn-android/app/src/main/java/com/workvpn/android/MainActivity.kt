package com.barqnet.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.barqnet.android.ui.navigation.BarqNetNavHost
import com.barqnet.android.ui.theme.BarqNetTheme
import com.barqnet.android.viewmodel.RealVPNViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            BarqNetTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    val vpnViewModel: RealVPNViewModel = viewModel()
                    BarqNetNavHost(vpnViewModel = vpnViewModel)
                }
            }
        }

        // Handle .ovpn file intent
        handleIntent(intent)
    }

    override fun onNewIntent(intent: android.content.Intent?) {
        super.onNewIntent(intent)
        intent?.let { handleIntent(it) }
    }

    private fun handleIntent(intent: android.content.Intent) {
        when (intent.action) {
            android.content.Intent.ACTION_VIEW -> {
                intent.data?.let { uri ->
                    // Handle .ovpn file import
                    // This will be processed by VPNViewModel
                }
            }
        }
    }
}
