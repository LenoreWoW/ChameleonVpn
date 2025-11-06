package com.barqnet.android.util

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity

/**
 * VPN Permission Helper
 *
 * This class handles the VPN permission request flow for Android.
 * VPN permission is required before establishing a VPN connection.
 *
 * Usage in Activity:
 * ```kotlin
 * class MainActivity : AppCompatActivity() {
 *     private lateinit var vpnPermissionHelper: VpnPermissionHelper
 *
 *     override fun onCreate(savedInstanceState: Bundle?) {
 *         super.onCreate(savedInstanceState)
 *         vpnPermissionHelper = VpnPermissionHelper(this) { granted ->
 *             if (granted) {
 *                 // Start VPN connection
 *             } else {
 *                 // Show error message
 *             }
 *         }
 *     }
 *
 *     fun connectVpn() {
 *         vpnPermissionHelper.requestPermission()
 *     }
 * }
 * ```
 *
 * @author BarqNet Team
 */
class VpnPermissionHelper(
    private val activity: AppCompatActivity,
    private val onPermissionResult: (Boolean) -> Unit
) {

    private var vpnPermissionLauncher: ActivityResultLauncher<Intent>? = null

    init {
        // Register for VPN permission result
        vpnPermissionLauncher = activity.registerForActivityResult(
            ActivityResultContracts.StartActivityForResult()
        ) { result ->
            val granted = result.resultCode == Activity.RESULT_OK
            onPermissionResult(granted)
        }
    }

    /**
     * Request VPN permission
     *
     * This will show the system VPN permission dialog if permission
     * has not been granted before.
     */
    fun requestPermission() {
        val intent = VpnService.prepare(activity)
        if (intent != null) {
            // Permission not granted, request it
            vpnPermissionLauncher?.launch(intent)
        } else {
            // Permission already granted
            onPermissionResult(true)
        }
    }

    /**
     * Check if VPN permission is granted
     */
    fun isPermissionGranted(): Boolean {
        return VpnService.prepare(activity) == null
    }

    companion object {
        /**
         * Check VPN permission without activity context
         */
        fun checkPermission(activity: Activity): Boolean {
            return VpnService.prepare(activity) == null
        }

        /**
         * Get VPN permission intent
         */
        fun getPermissionIntent(activity: Activity): Intent? {
            return VpnService.prepare(activity)
        }
    }
}
