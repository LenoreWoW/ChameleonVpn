package com.barqnet.android

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class BarqNetApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        // Create notification channel for VPN service
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                VPN_CHANNEL_ID,
                "VPN Connection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Persistent notification while VPN is active"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    companion object {
        const val VPN_CHANNEL_ID = "vpn_channel"
    }
}
