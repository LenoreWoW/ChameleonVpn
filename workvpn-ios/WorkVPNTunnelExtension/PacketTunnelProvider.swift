//
//  PacketTunnelProvider.swift
//  BarqNetTunnelExtension
//
//  Network Extension tunnel provider for OpenVPN
//

import NetworkExtension
import OpenVPNAdapter

// MARK: - Traffic Statistics

struct TrafficStats: Codable {
    let bytesIn: Int64
    let bytesOut: Int64
}

// MARK: - PacketTunnelProvider

class PacketTunnelProvider: NEPacketTunnelProvider {

    private lazy var vpnAdapter: OpenVPNAdapter = {
        let adapter = OpenVPNAdapter()
        adapter.delegate = self
        return adapter
    }()

    private var startHandler: ((Error?) -> Void)?
    private var stopHandler: (() -> Void)?

    // MARK: - Tunnel Lifecycle

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("[PacketTunnel] Starting VPN tunnel...")

        self.startHandler = completionHandler

        // Get configuration from provider configuration
        guard
            let providerConfig = protocolConfiguration as? NETunnelProviderProtocol,
            let providerConfiguration = providerConfig.providerConfiguration,
            let ovpnContent = providerConfiguration["ovpn"] as? String
        else {
            NSLog("[PacketTunnel] ERROR: No configuration found")
            completionHandler(NSError(
                domain: "BarqNet",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "VPN configuration not found"]
            ))
            return
        }

        // Get credentials if provided (for future use with auth-user-pass)
        let _ = providerConfiguration["username"] as? String
        let _ = providerConfiguration["password"] as? String

        // Parse and configure OpenVPN
        let configuration = OpenVPNConfiguration()
        configuration.fileContent = Data(ovpnContent.utf8)

        // Note: Credentials for auth-user-pass are typically embedded in the .ovpn file
        // or provided through OpenVPN's management interface

        // Apply configuration and connect
        do {
            let properties = try vpnAdapter.apply(configuration: configuration)
            NSLog("[PacketTunnel] Configuration applied successfully")

            // Start OpenVPN connection with packet flow
            vpnAdapter.connect(using: packetFlow)

        } catch {
            NSLog("[PacketTunnel] ERROR applying configuration: \(error)")
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("[PacketTunnel] Stopping VPN tunnel: \(reason)")

        self.stopHandler = completionHandler

        vpnAdapter.disconnect()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let message = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }

        if message == "stats" {
            // Get current traffic statistics
            let stats = TrafficStats(
                bytesIn: Int64(vpnAdapter.transportStatistics.bytesIn),
                bytesOut: Int64(vpnAdapter.transportStatistics.bytesOut)
            )

            if let data = try? JSONEncoder().encode(stats) {
                completionHandler?(data)
            } else {
                completionHandler?(nil)
            }
        } else {
            completionHandler?(nil)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func wake() {
        // Handle wake from sleep
    }
}

// MARK: - OpenVPNAdapterDelegate

extension PacketTunnelProvider: OpenVPNAdapterDelegate {

    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, configureTunnelWithNetworkSettings networkSettings: NEPacketTunnelNetworkSettings?, completionHandler: @escaping (Error?) -> Void) {
        // Configure tunnel network settings
        NSLog("[PacketTunnel] Configuring tunnel network settings...")

        setTunnelNetworkSettings(networkSettings) { error in
            if let error = error {
                NSLog("[PacketTunnel] ERROR setting network settings: \(error)")
            } else {
                NSLog("[PacketTunnel] Network settings configured successfully")
            }
            completionHandler(error)
        }
    }

    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleEvent event: OpenVPNAdapterEvent, message: String?) {
        // Handle OpenVPN events
        NSLog("[PacketTunnel] Event: \(event)")

        switch event {
        case .connected:
            NSLog("[PacketTunnel] ✓ VPN CONNECTED")

            // Notify success
            if let handler = startHandler {
                handler(nil)
                startHandler = nil
            }

        case .disconnected:
            NSLog("[PacketTunnel] ✗ VPN DISCONNECTED")

            // Notify stopped
            if let handler = stopHandler {
                handler()
                stopHandler = nil
            }

        case .reconnecting:
            NSLog("[PacketTunnel] ↻ VPN RECONNECTING...")

        @unknown default:
            break
        }

        // Log message if provided
        if let message = message {
            NSLog("[PacketTunnel] Message: \(message)")
        }
    }

    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleError error: Error) {
        NSLog("[PacketTunnel] ✗ ERROR: \(error.localizedDescription)")

        // Notify failure
        if let handler = startHandler {
            handler(error)
            startHandler = nil
        }
    }

    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleLogMessage logMessage: String) {
        // Log OpenVPN messages
        NSLog("[OpenVPN] \(logMessage)")
    }
}
