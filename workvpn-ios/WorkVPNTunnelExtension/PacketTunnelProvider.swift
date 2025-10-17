//
//  PacketTunnelProvider.swift
//  WorkVPNTunnelExtension
//
//  Network Extension tunnel provider for OpenVPN
//

import NetworkExtension
// TODO: Add OpenVPNAdapter when library is available
// import OpenVPNAdapter

// MARK: - Stub OpenVPN Classes (Remove when real library is added)
protocol OpenVPNAdapterDelegate: AnyObject {
    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, configureTunnelWithNetworkSettings networkSettings: NEPacketTunnelNetworkSettings?, completionHandler: @escaping (Error?) -> Void)
    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleEvent event: OpenVPNAdapterEvent, message: String?)
    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleError error: Error)
    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleLogMessage logMessage: String)
}

enum OpenVPNAdapterEvent {
    case connected, disconnected, reconnecting
}

struct OpenVPNConfiguration {
    init(fileContent: String) throws {
        // Stub implementation - parse config when library is available
    }
}

struct OpenVPNCredentials {
    // Stub implementation
}

class OpenVPNAdapter {
    weak var delegate: OpenVPNAdapterDelegate?
    
    func apply(configuration: OpenVPNConfiguration) throws {
        // Stub implementation
    }
    
    func connect(using credentials: OpenVPNCredentials) {
        // Stub implementation - simulate connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.delegate?.openVPNAdapter(self, handleEvent: .connected, message: "Connected")
        }
    }
    
    func disconnect() {
        // Stub implementation
        delegate?.openVPNAdapter(self, handleEvent: .disconnected, message: "Disconnected")
    }
}

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
        self.startHandler = completionHandler

        // Get configuration from provider configuration
        guard
            let providerConfig = protocolConfiguration as? NETunnelProviderProtocol,
            let providerConfiguration = providerConfig.providerConfiguration,
            let ovpnContent = providerConfiguration["ovpn"] as? String
        else {
            completionHandler(NSError(
                domain: "WorkVPN",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing OpenVPN configuration"]
            ))
            return
        }

        // Parse and configure OpenVPN
        do {
            let configuration = try OpenVPNConfiguration(fileContent: ovpnContent)
            try vpnAdapter.apply(configuration: configuration)
        } catch {
            completionHandler(error)
            return
        }

        // Start connection with custom credentials if provided
        let credentials = OpenVPNCredentials()
        // Note: Username/password can be provided via providerConfiguration if needed

        vpnAdapter.connect(using: credentials)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        self.stopHandler = completionHandler

        vpnAdapter.disconnect()

        // Wait a bit for graceful disconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Handle messages from the main app if needed
        completionHandler?(nil)
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
        if let settings = networkSettings {
            setTunnelNetworkSettings(settings) { error in
                completionHandler(error)
            }
        } else {
            completionHandler(nil)
        }
    }

    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleEvent event: OpenVPNAdapterEvent, message: String?) {

        switch event {
        case .connected:
            // Connection established
            if let startHandler = startHandler {
                startHandler(nil)
                self.startHandler = nil
            }

        case .disconnected:
            // Connection closed
            if let stopHandler = stopHandler {
                stopHandler()
                self.stopHandler = nil
            }

        case .reconnecting:
            // Attempting to reconnect
            break

        default:
            break
        }
    }

    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleError error: Error) {
        // Handle VPN errors
        if let startHandler = startHandler {
            startHandler(error)
            self.startHandler = nil
        }
    }

    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleLogMessage logMessage: String) {
        // Log VPN messages
        NSLog("[OpenVPN] %@", logMessage)
    }
}
