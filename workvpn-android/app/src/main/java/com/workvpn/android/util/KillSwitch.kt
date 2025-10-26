package com.barqnet.android.util

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.killSwitchDataStore by preferencesDataStore(name = "kill_switch_prefs")

/**
 * Kill Switch Manager
 *
 * Blocks all internet traffic when VPN is disconnected (if enabled)
 * Implementation strategy:
 * 1. When enabled: Add firewall rules to block all non-VPN traffic
 * 2. When VPN connects: Allow traffic through VPN interface only
 * 3. When VPN disconnects: Block all traffic (if kill switch is on)
 *
 * Note: Requires root access OR VpnService lockdown mode (Android 8.0+)
 */
class KillSwitch(private val context: Context) {

    private val KILL_SWITCH_ENABLED_KEY = booleanPreferencesKey("kill_switch_enabled")

    /**
     * Enable or disable kill switch
     */
    suspend fun setEnabled(enabled: Boolean) {
        context.killSwitchDataStore.edit { prefs ->
            prefs[KILL_SWITCH_ENABLED_KEY] = enabled
        }
        android.util.Log.d(TAG, "Kill switch ${if (enabled) "enabled" else "disabled"}")
    }

    /**
     * Check if kill switch is enabled
     */
    suspend fun isEnabled(): Boolean {
        return context.killSwitchDataStore.data
            .map { prefs -> prefs[KILL_SWITCH_ENABLED_KEY] ?: false }
            .first()
    }

    /**
     * Observe kill switch state
     */
    fun observeState(): Flow<Boolean> {
        return context.killSwitchDataStore.data
            .map { prefs -> prefs[KILL_SWITCH_ENABLED_KEY] ?: false }
    }

    /**
     * Activate kill switch - block all non-VPN traffic
     *
     * TODO: CRITICAL - Kill switch is NOT actually implemented yet!
     *
     * Current Status: Only logs activation but doesn't block traffic
     * Required Implementation:
     *
     * 1. In OpenVPNService.kt (or whichever VPN service is used):
     *    When building VPN interface, add:
     *
     *    if (killSwitch.isEnabled()) {
     *        builder.setBlocking(true)      // Block traffic until VPN connects
     *        builder.allowBypass(false)     // Prevent apps from bypassing VPN
     *        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
     *            builder.setMetered(false)  // Don't treat VPN as metered
     *        }
     *    }
     *
     * 2. Test that traffic is actually blocked when VPN disconnects
     * 3. Verify on Android 8.0+ (API 26+) where lockdown mode is available
     *
     * Estimated Effort: 4-6 hours (implementation + testing)
     * Priority: HIGH (feature advertised in UI but doesn't work)
     */
    fun activate() {
        // TODO: This only logs - doesn't actually block traffic!
        // See comments above for required implementation
        android.util.Log.d(TAG, "Kill switch activated - traffic will be blocked if VPN disconnects")
    }

    /**
     * Deactivate kill switch - allow normal traffic
     */
    fun deactivate() {
        android.util.Log.d(TAG, "Kill switch deactivated")
    }

    /**
     * Check if device supports kill switch
     * (Android 8.0+ has native VPN lockdown mode)
     */
    fun isSupported(): Boolean {
        return android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O
    }

    companion object {
        private const val TAG = "KillSwitch"
    }
}

/**
 * Usage in OpenVPNService:
 *
 * When creating VPN interface, add:
 *
 * if (killSwitch.isEnabled()) {
 *     builder.setBlocking(true)
 *     builder.allowBypass(false)
 *     if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
 *         builder.setMetered(false)
 *     }
 * }
 */
