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
import com.workvpn.android.vpn.OpenVPNService
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.InputStream

class VPNViewModel(application: Application) : AndroidViewModel(application) {

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

        // Start VPN service
        val serviceIntent = Intent(context, OpenVPNService::class.java).apply {
            action = OpenVPNService.ACTION_START_VPN
            putExtra(OpenVPNService.EXTRA_CONFIG_CONTENT, currentConfig.content)
        }
        context.startService(serviceIntent)

        // Start stats monitoring
        startStatsMonitoring()

        // Simulate connection success after a delay
        viewModelScope.launch {
            delay(3000)
            if (_connectionState.value is ConnectionState.Connecting) {
                _connectionState.value = ConnectionState.Connected
            }
        }
    }

    fun disconnect(context: Context) {
        _connectionState.value = ConnectionState.Disconnecting

        val serviceIntent = Intent(context, OpenVPNService::class.java).apply {
            action = OpenVPNService.ACTION_STOP_VPN
        }
        context.startService(serviceIntent)

        viewModelScope.launch {
            delay(1000)
            _connectionState.value = ConnectionState.Disconnected
            _stats.value = VPNStats()
            connectionStartTime = 0
        }
    }

    private fun startStatsMonitoring() {
        viewModelScope.launch {
            while (isActive && _connectionState.value is ConnectionState.Connected) {
                val duration = ((System.currentTimeMillis() - connectionStartTime) / 1000).toInt()

                // Simulate traffic stats (in real implementation, get from VPN service)
                _stats.value = _stats.value.copy(
                    bytesIn = _stats.value.bytesIn + (1000..5000).random(),
                    bytesOut = _stats.value.bytesOut + (500..2000).random(),
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
