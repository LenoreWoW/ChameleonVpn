package com.barqnet.android.util

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Monitors network connectivity changes
 * Useful for auto-reconnect when network becomes available
 */
class NetworkMonitor(context: Context) {

    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private val _isNetworkAvailable = MutableStateFlow(false)
    val isNetworkAvailable: StateFlow<Boolean> = _isNetworkAvailable

    private val _networkType = MutableStateFlow(NetworkType.NONE)
    val networkType: StateFlow<NetworkType> = _networkType

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            _isNetworkAvailable.value = true
            updateNetworkType(network)
            android.util.Log.d(TAG, "Network available: ${_networkType.value}")
        }

        override fun onLost(network: Network) {
            _isNetworkAvailable.value = false
            _networkType.value = NetworkType.NONE
            android.util.Log.d(TAG, "Network lost")
        }

        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
            updateNetworkType(network)
        }
    }

    init {
        // Check current network state
        val activeNetwork = connectivityManager.activeNetwork
        val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
        _isNetworkAvailable.value = capabilities != null

        // Register network callback
        val networkRequest = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        connectivityManager.registerNetworkCallback(networkRequest, networkCallback)
    }

    private fun updateNetworkType(network: Network) {
        val capabilities = connectivityManager.getNetworkCapabilities(network)
        _networkType.value = when {
            capabilities == null -> NetworkType.NONE
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> NetworkType.WIFI
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> NetworkType.CELLULAR
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> NetworkType.ETHERNET
            else -> NetworkType.OTHER
        }
    }

    fun unregister() {
        connectivityManager.unregisterNetworkCallback(networkCallback)
    }

    companion object {
        private const val TAG = "NetworkMonitor"
    }
}

enum class NetworkType {
    NONE,
    WIFI,
    CELLULAR,
    ETHERNET,
    OTHER
}
