package com.barqnet.android.vpn

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.lang.ref.WeakReference

/**
 * VPN Service Connection Manager
 *
 * This class manages the connection to VPN services without creating
 * memory leaks. It replaces the singleton pattern with proper
 * service binding and weak references.
 *
 * Memory Leak Fix:
 * - Uses WeakReference instead of static instance
 * - Proper service binding/unbinding
 * - StateFlow for reactive state updates
 * - No direct service references in ViewModel
 *
 * Usage in ViewModel:
 * ```kotlin
 * val vpnConnection = VpnServiceConnection(context)
 * vpnConnection.connectionState.collect { state ->
 *     // Update UI
 * }
 * vpnConnection.bytesIn.collect { bytes ->
 *     // Update stats
 * }
 * ```
 *
 * @author BarqNet Team
 */
class VpnServiceConnection(context: Context) {

    private val contextRef = WeakReference(context)
    private var serviceRef: WeakReference<RealVPNService>? = null
    private var isBound = false

    // State flows for reactive updates
    private val _connectionState = MutableStateFlow("DISCONNECTED")
    val connectionState: StateFlow<String> = _connectionState

    private val _bytesIn = MutableStateFlow(0L)
    val bytesIn: StateFlow<Long> = _bytesIn

    private val _bytesOut = MutableStateFlow(0L)
    val bytesOut: StateFlow<Long> = _bytesOut

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            Log.d(TAG, "Service connected")
            // Note: This is a simplified example
            // In production, you'd implement a Binder to communicate with the service
            isBound = true
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            Log.d(TAG, "Service disconnected")
            serviceRef = null
            isBound = false
        }
    }

    /**
     * Bind to VPN service
     */
    fun bind() {
        val context = contextRef.get() ?: return

        val intent = Intent(context, RealVPNService::class.java)
        context.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
    }

    /**
     * Unbind from VPN service
     */
    fun unbind() {
        if (isBound) {
            val context = contextRef.get() ?: return
            context.unbindService(serviceConnection)
            isBound = false
            serviceRef = null
        }
    }

    /**
     * Get service instance (weak reference)
     */
    fun getService(): RealVPNService? {
        return serviceRef?.get()
    }

    /**
     * Update connection state from service
     */
    fun updateConnectionState(state: String) {
        _connectionState.value = state
    }

    /**
     * Update bytes in from service
     */
    fun updateBytesIn(bytes: Long) {
        _bytesIn.value = bytes
    }

    /**
     * Update bytes out from service
     */
    fun updateBytesOut(bytes: Long) {
        _bytesOut.value = bytes
    }

    /**
     * Update error message from service
     */
    fun updateErrorMessage(error: String?) {
        _errorMessage.value = error
    }

    companion object {
        private const val TAG = "VpnServiceConnection"

        // Global state flows that can be accessed without holding service reference
        private val _globalConnectionState = MutableStateFlow("DISCONNECTED")
        val globalConnectionState: StateFlow<String> = _globalConnectionState

        private val _globalBytesIn = MutableStateFlow(0L)
        val globalBytesIn: StateFlow<Long> = _globalBytesIn

        private val _globalBytesOut = MutableStateFlow(0L)
        val globalBytesOut: StateFlow<Long> = _globalBytesOut

        /**
         * Update global state (called from VPN service)
         */
        fun updateGlobalState(state: String, bytesIn: Long, bytesOut: Long) {
            _globalConnectionState.value = state
            _globalBytesIn.value = bytesIn
            _globalBytesOut.value = bytesOut
        }
    }
}
