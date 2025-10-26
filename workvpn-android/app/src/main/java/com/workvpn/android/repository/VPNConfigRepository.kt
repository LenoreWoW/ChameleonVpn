package com.barqnet.android.repository

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.barqnet.android.model.VPNConfig
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "vpn_config")

class VPNConfigRepository(private val context: Context) {

    private val json = Json { ignoreUnknownKeys = true }

    private object PreferencesKeys {
        val CONFIG = stringPreferencesKey("vpn_config")
        val AUTO_CONNECT = stringPreferencesKey("auto_connect")
        val USE_BIOMETRIC = stringPreferencesKey("use_biometric")
    }

    suspend fun saveConfig(config: VPNConfig) {
        context.dataStore.edit { preferences ->
            preferences[PreferencesKeys.CONFIG] = json.encodeToString(config)
        }
    }

    suspend fun getConfig(): VPNConfig? {
        return context.dataStore.data.map { preferences ->
            preferences[PreferencesKeys.CONFIG]?.let { configJson ->
                try {
                    json.decodeFromString<VPNConfig>(configJson)
                } catch (e: Exception) {
                    null
                }
            }
        }.first()
    }

    suspend fun deleteConfig() {
        context.dataStore.edit { preferences ->
            preferences.remove(PreferencesKeys.CONFIG)
        }
    }

    suspend fun setAutoConnect(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[PreferencesKeys.AUTO_CONNECT] = enabled.toString()
        }
    }

    suspend fun getAutoConnect(): Boolean {
        return context.dataStore.data.map { preferences ->
            preferences[PreferencesKeys.AUTO_CONNECT]?.toBoolean() ?: false
        }.first()
    }

    suspend fun setUseBiometric(enabled: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[PreferencesKeys.USE_BIOMETRIC] = enabled.toString()
        }
    }

    suspend fun getUseBiometric(): Boolean {
        return context.dataStore.data.map { preferences ->
            preferences[PreferencesKeys.USE_BIOMETRIC]?.toBoolean() ?: false
        }.first()
    }
}
