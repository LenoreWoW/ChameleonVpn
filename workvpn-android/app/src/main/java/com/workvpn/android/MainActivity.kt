package com.workvpn.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.workvpn.android.ui.navigation.WorkVPNNavHost
import com.workvpn.android.ui.theme.WorkVPNTheme
import com.workvpn.android.viewmodel.RealVPNViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            WorkVPNTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    val vpnViewModel: RealVPNViewModel = viewModel()
                    WorkVPNNavHost(vpnViewModel = vpnViewModel)
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
