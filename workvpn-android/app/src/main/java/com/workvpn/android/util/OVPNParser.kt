package com.workvpn.android.util

import com.workvpn.android.model.VPNConfig

object OVPNParser {

    sealed class ParseError : Exception() {
        object MissingRemote : ParseError()
        object MissingCA : ParseError()
        object InvalidFormat : ParseError()
        object InvalidPort : ParseError()

        override val message: String
            get() = when (this) {
                is MissingRemote -> "Configuration is missing remote server address"
                is MissingCA -> "Configuration is missing CA certificate"
                is InvalidFormat -> "Invalid OpenVPN configuration format"
                is InvalidPort -> "Invalid port number"
            }
    }

    fun parse(content: String, name: String): VPNConfig {
        val lines = content.lines()

        var serverAddress: String? = null
        var port: Int = 1194
        var protocol: String = "udp"
        var deviceType: String = "tun"
        var ca: String? = null
        var cert: String? = null
        var key: String? = null
        var tlsAuth: String? = null
        var cipher: String? = null
        var auth: String? = null

        var currentBlock: String? = null
        val blockContent = mutableListOf<String>()

        for (line in lines) {
            val trimmed = line.trim()

            // Skip empty lines and comments
            if (trimmed.isEmpty() || trimmed.startsWith("#") || trimmed.startsWith(";")) {
                continue
            }

            // Handle inline blocks
            if (trimmed.startsWith("<")) {
                val blockPattern = Regex("""<(/?)([\\w-]+)>""")
                val match = blockPattern.find(trimmed)

                if (match != null) {
                    val isClosing = match.groupValues[1] == "/"
                    val blockType = match.groupValues[2]

                    if (isClosing) {
                        // End of block
                        if (currentBlock == blockType) {
                            val content = blockContent.joinToString("\n")

                            when (blockType) {
                                "ca" -> ca = content
                                "cert" -> cert = content
                                "key" -> key = content
                                "tls-auth" -> tlsAuth = content
                            }

                            currentBlock = null
                            blockContent.clear()
                        }
                    } else {
                        // Start of block
                        currentBlock = blockType
                        blockContent.clear()
                    }
                }
                continue
            }

            // If in block, collect content
            if (currentBlock != null) {
                blockContent.add(line)
                continue
            }

            // Parse key-value pairs
            val parts = trimmed.split(Regex("\\s+"))
            val keyword = parts.firstOrNull() ?: continue
            val values = parts.drop(1)

            when (keyword) {
                "remote" -> {
                    if (values.isNotEmpty()) {
                        serverAddress = values[0]
                        if (values.size > 1) {
                            port = values[1].toIntOrNull() ?: 1194
                        }
                    }
                }
                "proto" -> {
                    if (values.isNotEmpty()) {
                        protocol = values[0]
                    }
                }
                "dev" -> {
                    if (values.isNotEmpty()) {
                        deviceType = values[0]
                    }
                }
                "cipher" -> {
                    if (values.isNotEmpty()) {
                        cipher = values[0]
                    }
                }
                "auth" -> {
                    if (values.isNotEmpty()) {
                        auth = values[0]
                    }
                }
            }
        }

        // Validation
        if (serverAddress == null) {
            throw ParseError.MissingRemote
        }

        if (ca == null) {
            throw ParseError.MissingCA
        }

        return VPNConfig(
            name = name,
            content = content,
            serverAddress = serverAddress,
            port = port,
            protocol = protocol,
            ca = ca,
            cert = cert,
            key = key,
            tlsAuth = tlsAuth,
            cipher = cipher,
            auth = auth,
            deviceType = deviceType
        )
    }

    fun validate(config: VPNConfig): List<String> {
        val errors = mutableListOf<String>()

        if (config.serverAddress.isBlank()) {
            errors.add("Missing remote server address")
        }

        if (config.ca == null) {
            errors.add("Missing CA certificate")
        }

        if (config.port !in 1..65535) {
            errors.add("Invalid port number")
        }

        return errors
    }
}
