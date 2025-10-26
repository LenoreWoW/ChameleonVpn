package com.barqnet.android.model

import kotlinx.serialization.Serializable
import java.util.Date

@Serializable
data class VPNConfig(
    val name: String,
    val content: String,
    val serverAddress: String,
    val port: Int = 1194,
    val protocol: String = "udp",
    val importedAt: Long = System.currentTimeMillis(),

    // Parsed certificate components
    val ca: String? = null,
    val cert: String? = null,
    val key: String? = null,
    val tlsAuth: String? = null,
    val cipher: String? = null,
    val auth: String? = null,
    val deviceType: String = "tun"
) {
    val displayName: String
        get() = name.removeSuffix(".ovpn")

    val protocolDisplay: String
        get() = "${protocol.uppercase()}:$port"

    val importedDate: Date
        get() = Date(importedAt)
}
