package com.barqnet.android.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import com.barqnet.android.MainActivity
import com.barqnet.android.R
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer

/**
 * DEPRECATED: This is the OLD loopback simulation service
 *
 * ⚠️ WARNING: This service does NOT provide real VPN encryption!
 * ⚠️ Traffic is just echoed back (loopback simulation)
 *
 * FOR PRODUCTION: Use RealVPNService.kt instead
 *
 * This is kept for backwards compatibility only.
 * Migration to RealVPNService is CRITICAL before production release.
 *
 * See: RealVPNService.kt for production-ready implementation with:
 * - AES-256-GCM encryption
 * - Real server communication
 * - Actual traffic statistics
 * - DNS leak protection
 * - Kill switch
 *
 * @deprecated Use RealVPNService for production
 */
@Deprecated("Use RealVPNService for production with real encryption")
class OpenVPNService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var isRunning = false

    private val _connectionState = MutableStateFlow("DISCONNECTED")
    val connectionState: StateFlow<String> = _connectionState

    private val _bytesIn = MutableStateFlow(0L)
    val bytesIn: StateFlow<Long> = _bytesIn

    private val _bytesOut = MutableStateFlow(0L)
    val bytesOut: StateFlow<Long> = _bytesOut

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_VPN -> {
                val configContent = intent.getStringExtra(EXTRA_CONFIG_CONTENT)
                if (configContent != null) {
                    startVPN(configContent)
                }
            }
            ACTION_STOP_VPN -> {
                stopVPN()
            }
        }
        return START_STICKY
    }

    private fun startVPN(configContent: String) {
        if (isRunning) {
            android.util.Log.d(TAG, "VPN already running")
            return
        }

        _connectionState.value = "CONNECTING"
        startForeground(NOTIFICATION_ID, createNotification("Connecting to VPN..."))

        serviceScope.launch {
            try {
                // Parse config to extract server address
                val serverAddress = extractServerAddress(configContent)

                // Create VPN interface
                vpnInterface = createVPNInterface(serverAddress)

                if (vpnInterface != null) {
                    isRunning = true
                    _connectionState.value = "CONNECTED"
                    updateNotification("VPN Connected to $serverAddress")

                    // Start packet processing
                    processPackets()
                } else {
                    _connectionState.value = "ERROR"
                    updateNotification("VPN Connection Failed")
                }
            } catch (e: Exception) {
                android.util.Log.e(TAG, "VPN start failed", e)
                _connectionState.value = "ERROR"
                updateNotification("VPN Error: ${e.message}")
            }
        }
    }

    private fun createVPNInterface(serverAddress: String): ParcelFileDescriptor? {
        return try {
            val builder = Builder()
                .setSession("BarqNet")
                .addAddress("10.8.0.2", 24)  // Local VPN IP
                .addRoute("0.0.0.0", 0)      // Route all traffic
                .addDnsServer("8.8.8.8")      // Google DNS
                .addDnsServer("8.8.4.4")

            // Allow apps to bypass VPN (for testing)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                builder.setMetered(false)
            }

            builder.establish()
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to create VPN interface", e)
            null
        }
    }

    private suspend fun processPackets() {
        withContext(Dispatchers.IO) {
            val vpnFileDescriptor = vpnInterface ?: return@withContext

            val inputStream = FileInputStream(vpnFileDescriptor.fileDescriptor)
            val outputStream = FileOutputStream(vpnFileDescriptor.fileDescriptor)
            val buffer = ByteBuffer.allocate(32767)

            try {
                while (isRunning && !Thread.currentThread().isInterrupted) {
                    // Read packet from VPN interface
                    buffer.clear()
                    val length = inputStream.read(buffer.array())

                    if (length > 0) {
                        // Update statistics
                        _bytesIn.value += length

                        // In a real VPN: encrypt packet and send to VPN server
                        // For now: just echo it back (loopback for demo)

                        // Write packet back
                        outputStream.write(buffer.array(), 0, length)
                        _bytesOut.value += length

                        // Yield to prevent blocking
                        yield()
                    }
                }
            } catch (e: Exception) {
                if (isRunning) {
                    android.util.Log.e(TAG, "Packet processing error", e)
                }
            }
        }
    }

    private fun stopVPN() {
        _connectionState.value = "DISCONNECTING"
        isRunning = false

        serviceScope.launch {
            try {
                vpnInterface?.close()
                vpnInterface = null

                delay(500)

                _connectionState.value = "DISCONNECTED"
                _bytesIn.value = 0
                _bytesOut.value = 0

                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            } catch (e: Exception) {
                android.util.Log.e(TAG, "VPN stop failed", e)
            }
        }
    }

    private fun extractServerAddress(configContent: String): String {
        // Parse .ovpn file to extract server address
        val lines = configContent.lines()
        for (line in lines) {
            val trimmed = line.trim()
            if (trimmed.startsWith("remote ")) {
                val parts = trimmed.split("\\s+".toRegex())
                if (parts.size >= 2) {
                    return parts[1]  // Server address
                }
            }
        }
        return "vpn.server.com"  // Default
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "WorkVPN connection status"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(message: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("BarqNet")
            .setContentText(message)
            .setSmallIcon(R.drawable.ic_vpn_key)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(message: String) {
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, createNotification(message))
    }

    override fun onDestroy() {
        isRunning = false
        vpnInterface?.close()
        serviceScope.cancel()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "OpenVPNService"
        const val ACTION_START_VPN = "com.barqnet.android.START_VPN"
        const val ACTION_STOP_VPN = "com.barqnet.android.STOP_VPN"
        const val EXTRA_CONFIG_CONTENT = "config_content"

        private const val CHANNEL_ID = "vpn_service_channel"
        private const val NOTIFICATION_ID = 1
    }
}
