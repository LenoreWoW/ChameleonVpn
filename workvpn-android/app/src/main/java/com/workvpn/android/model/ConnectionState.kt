package com.barqnet.android.model

sealed class ConnectionState {
    object Disconnected : ConnectionState()
    object Connecting : ConnectionState()
    object Connected : ConnectionState()
    object Disconnecting : ConnectionState()
    data class Error(val message: String) : ConnectionState()
}

data class VPNStats(
    val bytesIn: Long = 0,
    val bytesOut: Long = 0,
    val duration: Int = 0  // seconds
) {
    val formattedBytesIn: String
        get() = formatBytes(bytesIn)

    val formattedBytesOut: String
        get() = formatBytes(bytesOut)

    val formattedDuration: String
        get() {
            val hours = duration / 3600
            val minutes = (duration % 3600) / 60
            val seconds = duration % 60

            return when {
                hours > 0 -> String.format("%dh %dm %ds", hours, minutes, seconds)
                minutes > 0 -> String.format("%dm %ds", minutes, seconds)
                else -> String.format("%ds", seconds)
            }
        }

    private fun formatBytes(bytes: Long): String {
        val mb = bytes.toDouble() / (1024 * 1024)
        return String.format("%.2f MB", mb)
    }
}
