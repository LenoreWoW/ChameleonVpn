package com.barqnet.android.viewmodel

import android.content.Context
import android.content.Intent
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.barqnet.android.model.ConnectionState
import com.barqnet.android.model.VPNConfig
import com.barqnet.android.model.VPNStats
import com.barqnet.android.repository.VPNConfigRepository
import com.barqnet.android.vpn.ProductionVPNService
import com.barqnet.android.vpn.VpnServiceConnection
import de.blinkt.openvpn.core.VpnStatus
import de.blinkt.openvpn.core.ConnectionStatus
import de.blinkt.openvpn.core.VpnStatus.StateListener
import de.blinkt.openvpn.core.VpnStatus.ByteCountListener
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * PRODUCTION ViewModel with REAL OpenVPN Integration
 *
 * This ViewModel uses ics-openvpn for actual VPN functionality
 *
 * Key Features:
 * - REAL OpenVPN connection status
 * - ACTUAL traffic statistics from OpenVPN
 * - Real connection events
 * - Production-ready error handling
 *
 * NO SIMULATION - This is the real deal!
 *
 * @author BarqNet Team
 * @version 3.0 - Production OpenVPN Implementation
 */
class ProductionVPNViewModel(
    private val configRepository: VPNConfigRepository
) : ViewModel(), StateListener, ByteCountListener {

    // Connection State
    private val _connectionState = MutableStateFlow(ConnectionState.Disconnected)
    val connectionState: StateFlow<ConnectionState> = _connectionState

    // VPN Statistics - REAL data from OpenVPN
    private val _stats = MutableStateFlow(VPNStats())
    val stats: StateFlow<VPNStats> = _stats

    // Current Configuration
    private val _currentConfig = MutableStateFlow<VPNConfig?>(null)
    val currentConfig: StateFlow<VPNConfig?> = _currentConfig

    private var connectionStartTime: Long = 0

    init {
        loadSavedConfig()
        // Register listeners for REAL OpenVPN events
        VpnStatus.addStateListener(this)
        VpnStatus.addByteCountListener(this)
    }

    /**
     * Load saved VPN configuration
     */
    private fun loadSavedConfig() {
        viewModelScope.launch {
            val config = configRepository.getConfig()
            if (config != null) {
                _currentConfig.value = config
            }
        }
    }

    /**
     * Import VPN configuration
     */
    fun importConfig(content: String, name: String) {
        viewModelScope.launch {
            try {
                val config = VPNConfig(
                    name = name,
                    content = content,
                    serverAddress = extractServer(content),
                    protocol = extractProtocol(content),
                    port = extractPort(content)
                )

                configRepository.saveConfig(config)
                _currentConfig.value = config

            } catch (e: Exception) {
                android.util.Log.e("ProductionVPNViewModel", "Failed to import config", e)
            }
        }
    }

    /**
     * Connect to VPN using REAL OpenVPN
     *
     * This initiates an actual OpenVPN connection with full encryption
     */
    fun connect(context: Context) {
        val config = _currentConfig.value
        if (config == null) {
            android.util.Log.e("ProductionVPNViewModel", "No VPN configuration available")
            return
        }

        _connectionState.value = ConnectionState.Connecting
        connectionStartTime = System.currentTimeMillis()

        // Start REAL OpenVPN service
        val serviceIntent = Intent(context, ProductionVPNService::class.java).apply {
            action = ProductionVPNService.ACTION_START_VPN
            putExtra(ProductionVPNService.EXTRA_CONFIG_CONTENT, config.content)
            putExtra(ProductionVPNService.EXTRA_CONFIG_NAME, config.name)
            config.username?.let { putExtra(ProductionVPNService.EXTRA_USERNAME, it) }
            config.password?.let { putExtra(ProductionVPNService.EXTRA_PASSWORD, it) }
        }

        context.startService(serviceIntent)

        android.util.Log.i("ProductionVPNViewModel", "✓ REAL OpenVPN connection initiated")
    }

    /**
     * Disconnect from VPN
     */
    fun disconnect(context: Context) {
        _connectionState.value = ConnectionState.Disconnecting

        val serviceIntent = Intent(context, ProductionVPNService::class.java).apply {
            action = ProductionVPNService.ACTION_STOP_VPN
        }
        context.startService(serviceIntent)

        connectionStartTime = 0
    }

    /**
     * Delete current configuration
     */
    fun deleteConfig() {
        viewModelScope.launch {
            configRepository.deleteConfig()
            _currentConfig.value = null
            _stats.value = VPNStats()
        }
    }

    // ========== REAL OpenVPN Callbacks ==========

    /**
     * Handle REAL VPN state changes from ics-openvpn
     */
    override fun updateState(
        state: String?,
        logmessage: String?,
        localizedResId: Int,
        level: ConnectionStatus?,
        Intent: Intent?
    ) {
        viewModelScope.launch {
            when (level) {
                ConnectionStatus.LEVEL_CONNECTED -> {
                    _connectionState.value = ConnectionState.Connected
                    android.util.Log.i("ProductionVPNViewModel", "✓ VPN CONNECTED - Traffic ENCRYPTED")
                }
                ConnectionStatus.LEVEL_CONNECTING_NO_SERVER_REPLY_YET,
                ConnectionStatus.LEVEL_CONNECTING_SERVER_REPLIED -> {
                    _connectionState.value = ConnectionState.Connecting
                }
                ConnectionStatus.LEVEL_NOTCONNECTED -> {
                    _connectionState.value = ConnectionState.Disconnected
                    _stats.value = VPNStats()
                }
                ConnectionStatus.LEVEL_AUTH_FAILED -> {
                    _connectionState.value = ConnectionState.Error("Authentication failed")
                }
                ConnectionStatus.LEVEL_NONETWORK -> {
                    _connectionState.value = ConnectionState.Error("No network")
                }
                else -> {
                    // Other states
                }
            }
        }
    }

    override fun setConnectedVPN(uuid: String?) {
        // VPN connected callback
    }

    /**
     * Handle REAL traffic statistics from OpenVPN
     *
     * This receives actual bytes sent/received from the VPN tunnel
     */
    override fun updateByteCount(inBytes: Long, outBytes: Long, diffInBytes: Long, diffOutBytes: Long) {
        viewModelScope.launch {
            val duration = if (connectionStartTime > 0) {
                (System.currentTimeMillis() - connectionStartTime) / 1000
            } else {
                0
            }

            _stats.value = VPNStats(
                bytesReceived = inBytes,
                bytesSent = outBytes,
                connectionDuration = duration.toInt()
            )
        }
    }

    // ========== Helper Functions ==========

    private fun extractServer(content: String): String {
        val lines = content.lines()
        for (line in lines) {
            if (line.trim().startsWith("remote ")) {
                val parts = line.trim().split("\\s+".toRegex())
                if (parts.size >= 2) {
                    return parts[1]
                }
            }
        }
        return "unknown"
    }

    private fun extractProtocol(content: String): String {
        val lines = content.lines()
        for (line in lines) {
            if (line.trim().startsWith("proto ")) {
                return line.trim().substringAfter("proto ").trim()
            }
        }
        return "udp"
    }

    private fun extractPort(content: String): Int {
        val lines = content.lines()
        for (line in lines) {
            if (line.trim().startsWith("remote ")) {
                val parts = line.trim().split("\\s+".toRegex())
                if (parts.size >= 3) {
                    return parts[2].toIntOrNull() ?: 1194
                }
            }
        }
        return 1194
    }

    override fun onCleared() {
        super.onCleared()
        // Unregister listeners
        VpnStatus.removeStateListener(this)
        VpnStatus.removeByteCountListener(this)
    }
}
