package com.workvpn.android.viewmodel

import android.app.Application
import android.content.Context
import android.content.Intent
import android.net.VpnService
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.workvpn.android.model.ConnectionState
import com.workvpn.android.model.VPNConfig
import com.workvpn.android.model.VPNStats
import com.workvpn.android.repository.VPNConfigRepository
import com.workvpn.android.util.OVPNParser
import com.workvpn.android.vpn.RealVPNService
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.InputStream

/**
 * PRODUCTION ViewModel with REAL VPN statistics
 *
 * This replaces the fake random number generation with actual VPN statistics
 * from RealVPNService.
 *
 * Key Changes from VPNViewModel:
 * - NO fake traffic generation
 * - Real statistics from VPN service
 * - Accurate byte counts
 * - Real connection states
 * - Error handling from actual VPN
 *
 * CRITICAL: This uses RealVPNService, not OpenVPNService
 *
 * @author ChameleonVPN Team
 * @version 2.0 - Production Ready
 */
class RealVPNViewModel(application: Application) : AndroidViewModel(application) {

    private val repository = VPNConfigRepository(application)

    private val _config = MutableStateFlow<VPNConfig?>(null)
    val config: StateFlow<VPNConfig?> = _config.asStateFlow()

    private val _connectionState = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()

    private val _stats = MutableStateFlow(VPNStats())
    val stats: StateFlow<VPNStats> = _stats.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private var connectionStartTime: Long = 0

    // Reference to VPN service for statistics collection
    private var vpnService: RealVPNService? = null

    init {
        loadSavedConfig()
    }

    private fun loadSavedConfig() {
        viewModelScope.launch {
            repository.getConfig()?.let { savedConfig ->
                _config.value = savedConfig
            }
        }
    }

    fun importConfig(inputStream: InputStream, fileName: String) {
        viewModelScope.launch {
            try {
                val content = inputStream.bufferedReader().use { it.readText() }
                val parsedConfig = OVPNParser.parse(content, fileName)

                // Validate
                val errors = OVPNParser.validate(parsedConfig)
                if (errors.isNotEmpty()) {
                    _errorMessage.value = errors.joinToString(", ")
                    return@launch
                }

                // Save
                repository.saveConfig(parsedConfig)
                _config.value = parsedConfig
                _errorMessage.value = null

            } catch (e: OVPNParser.ParseError) {
                _errorMessage.value = e.message
            } catch (e: Exception) {
                _errorMessage.value = "Failed to import config: ${e.message}"
            }
        }
    }

    fun deleteConfig() {
        viewModelScope.launch {
            repository.deleteConfig()
            _config.value = null
            _stats.value = VPNStats()
            _connectionState.value = ConnectionState.Disconnected
        }
    }

    /**
     * Connect to VPN using RealVPNService
     *
     * CRITICAL: This uses real encryption, not simulation!
     */
    fun connect(context: Context) {
        val currentConfig = _config.value ?: run {
            _errorMessage.value = "No configuration available"
            return
        }

        // Check VPN permission
        val intent = VpnService.prepare(context)
        if (intent != null) {
            // Permission needed - this should trigger activity result
            _errorMessage.value = "VPN permission required"
            return
        }

        _connectionState.value = ConnectionState.Connecting
        _errorMessage.value = null
        connectionStartTime = System.currentTimeMillis()

        // Start REAL VPN service (not simulation!)
        val serviceIntent = Intent(context, RealVPNService::class.java).apply {
            action = RealVPNService.ACTION_START_VPN
            putExtra(RealVPNService.EXTRA_CONFIG_CONTENT, currentConfig.content)
            // TODO: Add username/password if required
            // putExtra(RealVPNService.EXTRA_USERNAME, username)
            // putExtra(RealVPNService.EXTRA_PASSWORD, password)
        }
        context.startService(serviceIntent)

        // Start REAL statistics monitoring (not fake random numbers!)
        startRealStatsMonitoring()

        // Monitor connection state from service
        monitorConnectionState()
    }

    /**
     * Disconnect from VPN
     */
    fun disconnect(context: Context) {
        _connectionState.value = ConnectionState.Disconnecting

        val serviceIntent = Intent(context, RealVPNService::class.java).apply {
            action = RealVPNService.ACTION_STOP_VPN
        }
        context.startService(serviceIntent)

        viewModelScope.launch {
            delay(1000)
            _connectionState.value = ConnectionState.Disconnected
            _stats.value = VPNStats()
            connectionStartTime = 0
        }
    }

    /**
     * Monitor connection state from VPN service
     */
    private fun monitorConnectionState() {
        viewModelScope.launch {
            // Poll for service instance and collect real connection state
            var attempts = 0
            while (attempts < 30 && isActive) { // 30 second timeout
                val service = RealVPNService.instance
                if (service != null) {
                    // Service is available, monitor its connection state
                    service.connectionState.collect { state ->
                        _connectionState.value = when (state) {
                            "CONNECTED" -> ConnectionState.Connected
                            "CONNECTING" -> ConnectionState.Connecting
                            "DISCONNECTING" -> ConnectionState.Disconnecting
                            else -> ConnectionState.Disconnected
                        }
                    }
                    return@launch
                }
                delay(1000)
                attempts++
            }

            // Timeout - service never started
            if (_connectionState.value is ConnectionState.Connecting) {
                _connectionState.value = ConnectionState.Disconnected
                _errorMessage.value = "Failed to connect to VPN service"
            }
        }
    }

    /**
     * CRITICAL: Collect REAL statistics from VPN service
     *
     * This replaces the fake random number generation!
     *
     * Before (FAKE):
     *   bytesIn = bytesIn + (1000..5000).random()
     *   bytesOut = bytesOut + (500..2000).random()
     *
     * Now (REAL):
     *   bytesIn = vpnService.bytesIn.value
     *   bytesOut = vpnService.bytesOut.value
     */
    private fun startRealStatsMonitoring() {
        viewModelScope.launch {
            while (isActive && _connectionState.value is ConnectionState.Connected) {
                val duration = ((System.currentTimeMillis() - connectionStartTime) / 1000).toInt()

                // Get REAL statistics from VPN service
                val service = RealVPNService.instance
                val realBytesIn = service?.bytesIn?.value ?: 0L
                val realBytesOut = service?.bytesOut?.value ?: 0L

                // Update stats with REAL data from service
                _stats.value = _stats.value.copy(
                    bytesIn = realBytesIn,
                    bytesOut = realBytesOut,
                    duration = duration
                )

                delay(1000)
            }
        }
    }

    fun clearError() {
        _errorMessage.value = null
    }

    val hasConfig: Boolean
        get() = _config.value != null

    val isConnected: Boolean
        get() = _connectionState.value is ConnectionState.Connected

    val isConnecting: Boolean
        get() = _connectionState.value is ConnectionState.Connecting
}
