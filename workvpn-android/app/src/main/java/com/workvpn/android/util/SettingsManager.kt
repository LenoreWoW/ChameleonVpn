package com.barqnet.android.util

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

/**
 * Settings Manager using DataStore
 *
 * This class handles persistent storage of app settings:
 * - Auto-connect on VPN
 * - Biometric authentication
 * - Kill switch
 * - DNS servers
 * - Protocol preferences
 *
 * Features:
 * - Type-safe settings storage
 * - Asynchronous operations
 * - Flow-based reactive updates
 * - Migration from SharedPreferences (if needed)
 *
 * Usage:
 * ```kotlin
 * val settingsManager = SettingsManager(context)
 *
 * // Save setting
 * settingsManager.setAutoConnect(true)
 *
 * // Get setting
 * val autoConnect = settingsManager.getAutoConnect()
 *
 * // Observe setting changes
 * settingsManager.autoConnectFlow.collect { enabled ->
 *     // React to changes
 * }
 * ```
 *
 * @author BarqNet Team
 */
class SettingsManager(private val context: Context) {

    private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = SETTINGS_NAME)

    // ==================== Settings Keys ====================

    companion object {
        private const val SETTINGS_NAME = "barqnet_settings"

        // Keys
        private val KEY_AUTO_CONNECT = booleanPreferencesKey("auto_connect")
        private val KEY_BIOMETRIC_ENABLED = booleanPreferencesKey("biometric_enabled")
        private val KEY_KILL_SWITCH = booleanPreferencesKey("kill_switch")
        private val KEY_DNS_PREFERENCE = stringPreferencesKey("dns_preference")
        private val KEY_PROTOCOL = stringPreferencesKey("protocol")
        private val KEY_AUTO_RECONNECT = booleanPreferencesKey("auto_reconnect")
        private val KEY_NOTIFICATIONS_ENABLED = booleanPreferencesKey("notifications_enabled")
        private val KEY_DARK_MODE = booleanPreferencesKey("dark_mode")

        // Default values
        private const val DEFAULT_AUTO_CONNECT = false
        private const val DEFAULT_BIOMETRIC_ENABLED = false
        private const val DEFAULT_KILL_SWITCH = false
        private const val DEFAULT_DNS_PREFERENCE = "auto"
        private const val DEFAULT_PROTOCOL = "openvpn"
        private const val DEFAULT_AUTO_RECONNECT = true
        private const val DEFAULT_NOTIFICATIONS_ENABLED = true
        private const val DEFAULT_DARK_MODE = false
    }

    // ==================== Auto Connect ====================

    val autoConnectFlow: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[KEY_AUTO_CONNECT] ?: DEFAULT_AUTO_CONNECT
    }

    suspend fun setAutoConnect(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[KEY_AUTO_CONNECT] = enabled
        }
    }

    suspend fun getAutoConnect(): Boolean {
        return autoConnectFlow.first()
    }

    // ==================== Biometric Authentication ====================

    val biometricEnabledFlow: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[KEY_BIOMETRIC_ENABLED] ?: DEFAULT_BIOMETRIC_ENABLED
    }

    suspend fun setBiometricEnabled(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[KEY_BIOMETRIC_ENABLED] = enabled
        }
    }

    suspend fun getBiometricEnabled(): Boolean {
        return biometricEnabledFlow.first()
    }

    // ==================== Kill Switch ====================

    val killSwitchFlow: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[KEY_KILL_SWITCH] ?: DEFAULT_KILL_SWITCH
    }

    suspend fun setKillSwitch(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[KEY_KILL_SWITCH] = enabled
        }
    }

    suspend fun getKillSwitch(): Boolean {
        return killSwitchFlow.first()
    }

    // ==================== DNS Preference ====================

    val dnsPreferenceFlow: Flow<String> = context.dataStore.data.map { preferences ->
        preferences[KEY_DNS_PREFERENCE] ?: DEFAULT_DNS_PREFERENCE
    }

    suspend fun setDnsPreference(preference: String) {
        context.dataStore.edit { preferences ->
            preferences[KEY_DNS_PREFERENCE] = preference
        }
    }

    suspend fun getDnsPreference(): String {
        return dnsPreferenceFlow.first()
    }

    // ==================== Protocol ====================

    val protocolFlow: Flow<String> = context.dataStore.data.map { preferences ->
        preferences[KEY_PROTOCOL] ?: DEFAULT_PROTOCOL
    }

    suspend fun setProtocol(protocol: String) {
        context.dataStore.edit { preferences ->
            preferences[KEY_PROTOCOL] = protocol
        }
    }

    suspend fun getProtocol(): String {
        return protocolFlow.first()
    }

    // ==================== Auto Reconnect ====================

    val autoReconnectFlow: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[KEY_AUTO_RECONNECT] ?: DEFAULT_AUTO_RECONNECT
    }

    suspend fun setAutoReconnect(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[KEY_AUTO_RECONNECT] = enabled
        }
    }

    suspend fun getAutoReconnect(): Boolean {
        return autoReconnectFlow.first()
    }

    // ==================== Notifications ====================

    val notificationsEnabledFlow: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[KEY_NOTIFICATIONS_ENABLED] ?: DEFAULT_NOTIFICATIONS_ENABLED
    }

    suspend fun setNotificationsEnabled(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[KEY_NOTIFICATIONS_ENABLED] = enabled
        }
    }

    suspend fun getNotificationsEnabled(): Boolean {
        return notificationsEnabledFlow.first()
    }

    // ==================== Dark Mode ====================

    val darkModeFlow: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[KEY_DARK_MODE] ?: DEFAULT_DARK_MODE
    }

    suspend fun setDarkMode(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[KEY_DARK_MODE] = enabled
        }
    }

    suspend fun getDarkMode(): Boolean {
        return darkModeFlow.first()
    }

    // ==================== Clear All Settings ====================

    suspend fun clearAllSettings() {
        context.dataStore.edit { preferences ->
            preferences.clear()
        }
    }

    // ==================== Export/Import ====================

    suspend fun getAllSettings(): Map<String, Any> {
        val preferences = context.dataStore.data.first()
        return mapOf(
            "auto_connect" to (preferences[KEY_AUTO_CONNECT] ?: DEFAULT_AUTO_CONNECT),
            "biometric_enabled" to (preferences[KEY_BIOMETRIC_ENABLED] ?: DEFAULT_BIOMETRIC_ENABLED),
            "kill_switch" to (preferences[KEY_KILL_SWITCH] ?: DEFAULT_KILL_SWITCH),
            "dns_preference" to (preferences[KEY_DNS_PREFERENCE] ?: DEFAULT_DNS_PREFERENCE),
            "protocol" to (preferences[KEY_PROTOCOL] ?: DEFAULT_PROTOCOL),
            "auto_reconnect" to (preferences[KEY_AUTO_RECONNECT] ?: DEFAULT_AUTO_RECONNECT),
            "notifications_enabled" to (preferences[KEY_NOTIFICATIONS_ENABLED] ?: DEFAULT_NOTIFICATIONS_ENABLED),
            "dark_mode" to (preferences[KEY_DARK_MODE] ?: DEFAULT_DARK_MODE)
        )
    }
}
