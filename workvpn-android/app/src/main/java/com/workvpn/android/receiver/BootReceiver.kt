package com.workvpn.android.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Handle auto-start on boot
            CoroutineScope(Dispatchers.IO).launch {
                // Check if auto-connect is enabled in preferences
                // If enabled, start VPN service
                // This requires accessing VPNConfigRepository
            }
        }
    }
}
