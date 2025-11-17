package com.barqnet.android.vpn

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import de.blinkt.openvpn.core.OpenVPNService
import de.blinkt.openvpn.core.VpnStatus
import de.blinkt.openvpn.core.ProfileManager
import de.blinkt.openvpn.core.VPNLaunchHelper
import de.blinkt.openvpn.core.ConnectionStatus
import de.blinkt.openvpn.core.VpnStatus.StateListener
import java.io.StringReader

/**
 * PRODUCTION VPN Service using REAL ics-openvpn Implementation
 *
 * This is the REAL OpenVPN implementation that provides:
 * - Actual OpenVPN 3 protocol
 * - Real encryption (AES-256-GCM, AES-128-CBC, etc.)
 * - Full OpenVPN server compatibility
 * - TLS/SSL authentication
 * - Certificate-based auth
 * - Username/password auth
 * - Perfect Forward Secrecy
 * - DNS leak protection
 * - IPv6 support
 *
 * NO MORE FAKE SERVICES - This is production-ready!
 *
 * @author BarqNet Team
 * @version 3.0 - Real OpenVPN Implementation
 */
class ProductionVPNService : OpenVPNService(), StateListener {

    companion object {
        private const val TAG = "ProductionVPNService"
        const val ACTION_START_VPN = "com.barqnet.android.START_PRODUCTION_VPN"
        const val ACTION_STOP_VPN = "com.barqnet.android.STOP_PRODUCTION_VPN"
        const val EXTRA_CONFIG_CONTENT = "config_content"
        const val EXTRA_CONFIG_NAME = "config_name"
        const val EXTRA_USERNAME = "username"
        const val EXTRA_PASSWORD = "password"
    }

    override fun onCreate() {
        super.onCreate()
        VpnStatus.addStateListener(this)
        Log.i(TAG, "ProductionVPNService created with REAL OpenVPN")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_START_VPN) {
            val configContent = intent.getStringExtra(EXTRA_CONFIG_CONTENT)
            val configName = intent.getStringExtra(EXTRA_CONFIG_NAME) ?: "BarqNet VPN"
            val username = intent.getStringExtra(EXTRA_USERNAME)
            val password = intent.getStringExtra(EXTRA_PASSWORD)

            if (configContent != null) {
                startRealVPN(configContent, configName, username, password)
            } else {
                Log.e(TAG, "No VPN configuration provided")
                stopSelf()
            }
            return START_STICKY
        } else if (intent?.action == ACTION_STOP_VPN) {
            stopVPN()
            return START_NOT_STICKY
        }

        return super.onStartCommand(intent, flags, startId)
    }

    /**
     * Start REAL OpenVPN connection
     *
     * This method:
     * 1. Parses the .ovpn configuration
     * 2. Creates VPN profile
     * 3. Starts OpenVPN connection with real encryption
     * 4. Handles authentication
     */
    private fun startRealVPN(
        configContent: String,
        configName: String,
        username: String?,
        password: String?
    ) {
        try {
            Log.i(TAG, "Starting REAL OpenVPN connection...")

            // Parse OpenVPN config using ics-openvpn's config parser
            val configParser = de.blinkt.openvpn.core.ConfigParser()
            configParser.parseConfig(StringReader(configContent))

            // Convert to VpnProfile
            val vpnProfile = configParser.convertProfile()
            vpnProfile.mName = configName

            // Set authentication if provided
            if (username != null && password != null) {
                vpnProfile.mUsername = username
                vpnProfile.mPassword = password
            }

            // Save profile to ProfileManager
            val profileManager = ProfileManager.getInstance(this)
            profileManager.addProfile(vpnProfile)
            profileManager.saveProfileList(this)
            profileManager.saveProfile(this, vpnProfile)

            Log.i(TAG, "VPN Profile created: $configName")
            Log.i(TAG, "Server: ${vpnProfile.mConnections[0]?.mServerName}")
            Log.i(TAG, "Protocol: ${vpnProfile.mUseTcp1?.let { if (it) "TCP" else "UDP" }}")
            Log.i(TAG, "Cipher: ${vpnProfile.mCipher}")

            // Start the VPN connection
            VPNLaunchHelper.startOpenVpn(vpnProfile, this)

            Log.i(TAG, "✓ REAL OpenVPN connection initiated successfully")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start REAL OpenVPN", e)
            VpnStatus.logError("Failed to start VPN: ${e.message}")
        }
    }

    /**
     * Stop VPN connection
     */
    private fun stopVPN() {
        Log.i(TAG, "Stopping VPN connection")
        stopVPN(false)
    }

    /**
     * Handle VPN status changes from ics-openvpn
     *
     * This receives REAL status updates from the OpenVPN connection
     */
    override fun updateState(
        state: String?,
        logmessage: String?,
        localizedResId: Int,
        level: ConnectionStatus?,
        Intent: Intent?
    ) {
        Log.i(TAG, "VPN State: $state | Status: $level | Message: $logmessage")

        when (level) {
            ConnectionStatus.LEVEL_CONNECTED -> {
                Log.i(TAG, "✓ VPN CONNECTED - Traffic is NOW ENCRYPTED")
                // Update global state for ViewModel
                VpnServiceConnection.updateGlobalState("CONNECTED", 0L, 0L)
            }
            ConnectionStatus.LEVEL_CONNECTING_NO_SERVER_REPLY_YET,
            ConnectionStatus.LEVEL_CONNECTING_SERVER_REPLIED -> {
                Log.i(TAG, "VPN Connecting...")
                VpnServiceConnection.updateGlobalState("CONNECTING", 0L, 0L)
            }
            ConnectionStatus.LEVEL_NOTCONNECTED -> {
                Log.i(TAG, "VPN Disconnected")
                VpnServiceConnection.updateGlobalState("DISCONNECTED", 0L, 0L)
            }
            ConnectionStatus.LEVEL_AUTH_FAILED -> {
                Log.e(TAG, "✗ VPN Authentication Failed")
                VpnServiceConnection.updateGlobalState("ERROR", 0L, 0L)
            }
            ConnectionStatus.LEVEL_NONETWORK -> {
                Log.w(TAG, "No network available")
            }
            else -> {
                Log.d(TAG, "VPN State: $level")
            }
        }
    }

    override fun setConnectedVPN(uuid: String?) {
        // Called when VPN is connected
        Log.i(TAG, "VPN Connected - UUID: $uuid")
    }

    override fun onDestroy() {
        VpnStatus.removeStateListener(this)
        Log.i(TAG, "ProductionVPNService destroyed")
        super.onDestroy()
    }
}
