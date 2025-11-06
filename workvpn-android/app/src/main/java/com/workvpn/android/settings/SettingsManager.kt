package com.barqnet.android.settings

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

/**
 * Settings Manager - Persistent storage for app settings
 *
 * Uses DataStore for type-safe, encrypted preferences storage.
 * All settings are persisted and survive app restarts.
 *
 * Features:
 * - Auto-connect on app launch
 * - Biometric authentication preference
 * - Type-safe settings access
 * - Coroutine-based async operations
 *
 * Security:
 * - DataStore provides encrypted storage
 * - Settings are scoped to the app
 *
 * @author BarqNet Team
 */
class SettingsManager(private val context: Context) {

    companion object {
        private val Context.settingsDataStore by preferencesDataStore(name = "app_settings")

        private val AUTO_CONNECT_KEY = booleanPreferencesKey("auto_connect")
        private val USE_BIOMETRIC_KEY = booleanPreferencesKey("use_biometric")
    }

    // ==================== Auto-Connect Setting ====================

    /**
     * Get auto-connect setting as Flow
     */
    val autoConnectFlow: Flow<Boolean> = context.settingsDataStore.data.map { preferences ->
        preferences[AUTO_CONNECT_KEY] ?: false
    }

    /**
     * Get auto-connect setting (suspend)
     */
    suspend fun getAutoConnect(): Boolean {
        return autoConnectFlow.first()
    }

    /**
     * Set auto-connect setting
     */
    suspend fun setAutoConnect(enabled: Boolean) {
        context.settingsDataStore.edit { preferences ->
            preferences[AUTO_CONNECT_KEY] = enabled
        }
    }

    // ==================== Biometric Authentication Setting ====================

    /**
     * Get biometric authentication setting as Flow
     */
    val useBiometricFlow: Flow<Boolean> = context.settingsDataStore.data.map { preferences ->
        preferences[USE_BIOMETRIC_KEY] ?: false
    }

    /**
     * Get biometric authentication setting (suspend)
     */
    suspend fun getUseBiometric(): Boolean {
        return useBiometricFlow.first()
    }

    /**
     * Set biometric authentication setting
     */
    suspend fun setUseBiometric(enabled: Boolean) {
        context.settingsDataStore.edit { preferences ->
            preferences[USE_BIOMETRIC_KEY] = enabled
        }
    }

    // ==================== Bulk Operations ====================

    /**
     * Get all settings at once
     */
    suspend fun getAllSettings(): AppSettings {
        val preferences = context.settingsDataStore.data.first()
        return AppSettings(
            autoConnect = preferences[AUTO_CONNECT_KEY] ?: false,
            useBiometric = preferences[USE_BIOMETRIC_KEY] ?: false
        )
    }

    /**
     * Reset all settings to defaults
     */
    suspend fun resetToDefaults() {
        context.settingsDataStore.edit { preferences ->
            preferences.clear()
        }
    }
}

/**
 * Data class representing all app settings
 */
data class AppSettings(
    val autoConnect: Boolean = false,
    val useBiometric: Boolean = false
)
