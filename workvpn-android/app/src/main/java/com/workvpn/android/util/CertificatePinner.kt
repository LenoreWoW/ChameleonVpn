package com.barqnet.android.util

import okhttp3.CertificatePinner
import okhttp3.OkHttpClient
import java.security.cert.CertificateException
import java.security.cert.X509Certificate
import javax.net.ssl.*

/**
 * Certificate Pinning Manager
 *
 * Prevents MITM attacks by validating server certificates against known public keys
 */
object CertificatePinnerManager {

    /**
     * Build OkHttpClient with certificate pinning
     *
     * Usage:
     * val client = CertificatePinnerManager.buildClient(
     *     "vpn.server.com",
     *     listOf("sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
     * )
     */
    fun buildClient(hostname: String, pins: List<String>): OkHttpClient {
        val certificatePinner = CertificatePinner.Builder().apply {
            pins.forEach { pin ->
                add(hostname, pin)
            }
        }.build()

        return OkHttpClient.Builder()
            .certificatePinner(certificatePinner)
            .build()
    }

    /**
     * Build certificate pinner for specific domain and pins
     *
     * Example pins:
     * - "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
     * - "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
     *
     * To get SHA256 hash of a server's certificate:
     * ```bash
     * openssl s_client -connect vpn.server.com:443 < /dev/null | \
     *   openssl x509 -pubkey -noout | \
     *   openssl pkey -pubin -outform der | \
     *   openssl dgst -sha256 -binary | \
     *   base64
     * ```
     */
    fun buildPinner(vararg entries: Pair<String, List<String>>): CertificatePinner {
        val builder = CertificatePinner.Builder()

        entries.forEach { (hostname, pins) ->
            pins.forEach { pin ->
                builder.add(hostname, pin)
            }
        }

        return builder.build()
    }

    /**
     * Create a trust manager that only trusts specific certificates
     * Use for OpenVPN connections
     */
    fun createTrustManager(trustedCertificates: List<X509Certificate>): X509TrustManager {
        return object : X509TrustManager {
            override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {
                // Not used for client
            }

            override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {
                if (chain == null || chain.isEmpty()) {
                    throw CertificateException("Certificate chain is empty")
                }

                // Check if server certificate matches any of our trusted certificates
                val serverCert = chain[0]
                val isTrusted = trustedCertificates.any { trustedCert ->
                    serverCert.publicKey == trustedCert.publicKey
                }

                if (!isTrusted) {
                    throw CertificateException("Server certificate is not trusted")
                }
            }

            override fun getAcceptedIssuers(): Array<X509Certificate> {
                return trustedCertificates.toTypedArray()
            }
        }
    }

    /**
     * Create SSL context with custom trust manager
     */
    fun createSSLContext(trustManager: X509TrustManager): SSLContext {
        val sslContext = SSLContext.getInstance("TLS")
        sslContext.init(null, arrayOf<TrustManager>(trustManager), null)
        return sslContext
    }

    /**
     * Verify hostname matches certificate
     */
    fun createHostnameVerifier(expectedHostname: String): HostnameVerifier {
        return HostnameVerifier { hostname, _ ->
            hostname == expectedHostname
        }
    }
}

/**
 * Usage Example in VPN Service:
 *
 * ```kotlin
 * // Define your server's certificate pins
 * val pins = listOf(
 *     "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", // Primary cert
 *     "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="  // Backup cert
 * )
 *
 * // For HTTP connections
 * val okHttpClient = CertificatePinnerManager.buildClient("vpn.server.com", pins)
 *
 * // For OpenVPN connections
 * val pinner = CertificatePinnerManager.buildPinner(
 *     "vpn.server.com" to pins
 * )
 *
 * // Apply to OpenVPN config
 * vpnService.setCertificatePinner(pinner)
 * ```
 */
