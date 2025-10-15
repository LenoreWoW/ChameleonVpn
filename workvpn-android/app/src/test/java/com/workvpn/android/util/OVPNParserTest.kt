package com.workvpn.android.util

import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Unit tests for OVPN config parser
 */
class OVPNParserTest {

    @Test
    fun `parse basic config extracts server address`() {
        val config = """
            client
            dev tun
            proto udp
            remote vpn.example.com 1194
            cipher AES-256-CBC
        """.trimIndent()

        val result = OVPNParser.parse(config)

        assertEquals("vpn.example.com", result.serverAddress)
        assertEquals(1194, result.port)
        assertEquals("udp", result.protocol)
    }

    @Test
    fun `parse config with inline CA certificate`() {
        val config = """
            remote vpn.test.com 1194
            <ca>
            -----BEGIN CERTIFICATE-----
            MIIDTEST123
            -----END CERTIFICATE-----
            </ca>
        """.trimIndent()

        val result = OVPNParser.parse(config)

        assertTrue(result.hasCertificate)
        assertTrue(result.certificateContent.contains("MIIDTEST123"))
    }

    @Test
    fun `parse config ignores comments`() {
        val config = """
            # This is a comment
            client
            ; Another comment
            dev tun
            remote vpn.test.com 1194
        """.trimIndent()

        val result = OVPNParser.parse(config)

        assertEquals("vpn.test.com", result.serverAddress)
    }

    @Test
    fun `parse config with multiple protocols`() {
        val tcpConfig = "remote vpn.test.com 443\nproto tcp"
        val udpConfig = "remote vpn.test.com 1194\nproto udp"

        val tcp = OVPNParser.parse(tcpConfig)
        val udp = OVPNParser.parse(udpConfig)

        assertEquals("tcp", tcp.protocol)
        assertEquals("udp", udp.protocol)
    }

    @Test
    fun `validate rejects config without server`() {
        val config = """
            client
            dev tun
        """.trimIndent()

        val result = OVPNParser.parse(config)
        val errors = OVPNParser.validate(result)

        assertTrue(errors.isNotEmpty())
        assertTrue(errors.any { it.contains("server", ignoreCase = true) })
    }

    @Test
    fun `validate accepts valid config`() {
        val config = """
            remote vpn.test.com 1194
            proto udp
            dev tun
            <ca>
            -----BEGIN CERTIFICATE-----
            TEST
            -----END CERTIFICATE-----
            </ca>
        """.trimIndent()

        val result = OVPNParser.parse(config)
        val errors = OVPNParser.validate(result)

        assertTrue(errors.isEmpty())
    }

    @Test
    fun `extract port defaults to 1194`() {
        val config = "remote vpn.test.com"

        val result = OVPNParser.parse(config)

        assertEquals(1194, result.port)
    }

    @Test
    fun `parse handles whitespace variations`() {
        val config = """
            remote    vpn.test.com    1194
            proto   udp
        """.trimIndent()

        val result = OVPNParser.parse(config)

        assertEquals("vpn.test.com", result.serverAddress)
        assertEquals("udp", result.protocol)
    }
}

// Add OVPNParser utility if not exists
object OVPNParser {
    data class ParseResult(
        val serverAddress: String = "",
        val port: Int = 1194,
        val protocol: String = "udp",
        val hasCertificate: Boolean = false,
        val certificateContent: String = ""
    )

    fun parse(content: String): ParseResult {
        var serverAddress = ""
        var port = 1194
        var protocol = "udp"
        var certificateContent = ""
        var inCertBlock = false

        content.lines().forEach { line ->
            val trimmed = line.trim()

            // Skip comments
            if (trimmed.startsWith("#") || trimmed.startsWith(";")) {
                return@forEach
            }

            // Check for certificate blocks
            if (trimmed.startsWith("<ca>")) {
                inCertBlock = true
                return@forEach
            }
            if (trimmed.startsWith("</ca>")) {
                inCertBlock = false
                return@forEach
            }
            if (inCertBlock) {
                certificateContent += trimmed + "\n"
                return@forEach
            }

            // Parse directives
            val parts = trimmed.split("\\s+".toRegex())
            when (parts.firstOrNull()) {
                "remote" -> {
                    serverAddress = parts.getOrNull(1) ?: ""
                    port = parts.getOrNull(2)?.toIntOrNull() ?: 1194
                }
                "proto" -> {
                    protocol = parts.getOrNull(1) ?: "udp"
                }
            }
        }

        return ParseResult(
            serverAddress = serverAddress,
            port = port,
            protocol = protocol,
            hasCertificate = certificateContent.isNotEmpty(),
            certificateContent = certificateContent
        )
    }

    fun validate(result: ParseResult): List<String> {
        val errors = mutableListOf<String>()

        if (result.serverAddress.isEmpty()) {
            errors.add("Missing server address")
        }

        return errors
    }
}
