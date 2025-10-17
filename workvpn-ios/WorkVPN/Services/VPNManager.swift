//
//  VPNManager.swift
//  WorkVPN
//
//  Manages VPN connection using NetworkExtension
//

import Foundation
import NetworkExtension
import Combine

class VPNManager: ObservableObject {
    static let shared = VPNManager()

    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var currentConfig: VPNConfig?
    @Published var hasConfig = false
    @Published var bytesIn: UInt64 = 0
    @Published var bytesOut: UInt64 = 0
    @Published var connectionDuration: Int = 0
    @Published var errorMessage: String?

    private var vpnManager: NETunnelProviderManager?
    private var connectionTimer: Timer?
    private var connectionStartTime: Date?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadVPNManager()
        setupNotifications()
        loadSavedConfig()
    }

    // MARK: - Config Management

    func importConfig(content: String, name: String) throws {
        let config = try OVPNParser.parse(content: content, name: name)

        // Validate
        let errors = OVPNParser.validate(config: config)
        if !errors.isEmpty {
            throw NSError(
                domain: "VPNManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: errors.joined(separator: ", ")]
            )
        }

        // Save config
        saveConfig(config)

        // Configure VPN
        try configureVPN(with: config)
    }

    private func saveConfig(_ config: VPNConfig) {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: "vpn_config")
            currentConfig = config
            hasConfig = true
        }
    }

    private func loadSavedConfig() {
        if let data = UserDefaults.standard.data(forKey: "vpn_config"),
           let config = try? JSONDecoder().decode(VPNConfig.self, from: data) {
            currentConfig = config
            hasConfig = true
        }
    }

    func deleteConfig() {
        UserDefaults.standard.removeObject(forKey: "vpn_config")
        currentConfig = nil
        hasConfig = false

        // Remove VPN configuration
        vpnManager?.removeFromPreferences { _ in }
        vpnManager = nil
    }

    // MARK: - VPN Connection

    private func loadVPNManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }

            if let manager = managers?.first {
                self?.vpnManager = manager
                self?.updateConnectionStatus()
            }
        }
    }

    private func configureVPN(with config: VPNConfig) throws {
        let manager = NETunnelProviderManager()

        // Configure provider
        let providerProtocol = NETunnelProviderProtocol()
        providerProtocol.providerBundleIdentifier = "com.workvpn.ios.WorkVPNTunnelExtension"
        providerProtocol.serverAddress = config.serverAddress

        // Pass configuration to tunnel extension
        providerProtocol.providerConfiguration = [
            "ovpn": config.content,
            "server": config.serverAddress,
            "port": config.port,
            "protocol": config.protocol
        ]

        manager.protocolConfiguration = providerProtocol
        manager.localizedDescription = "WorkVPN"
        manager.isEnabled = true

        // Save configuration
        manager.saveToPreferences { [weak self] error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            } else {
                self?.vpnManager = manager
                self?.loadVPNManager()
            }
        }
    }

    func connect() {
        guard let manager = vpnManager else {
            errorMessage = "VPN not configured"
            return
        }

        guard let config = currentConfig else {
            errorMessage = "No configuration available"
            return
        }

        isConnecting = true
        errorMessage = nil

        do {
            try manager.connection.startVPNTunnel()
            connectionStartTime = Date()
            startConnectionTimer()
        } catch {
            isConnecting = false
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() {
        vpnManager?.connection.stopVPNTunnel()
        stopConnectionTimer()
        connectionStartTime = nil
        connectionDuration = 0
        bytesIn = 0
        bytesOut = 0
    }

    // MARK: - Status Updates

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .NEVPNStatusDidChange)
            .sink { [weak self] _ in
                self?.updateConnectionStatus()
            }
            .store(in: &cancellables)
    }

    private func updateConnectionStatus() {
        guard let manager = vpnManager else { return }

        switch manager.connection.status {
        case .connected:
            isConnected = true
            isConnecting = false
            errorMessage = nil

        case .connecting, .reasserting:
            isConnected = false
            isConnecting = true

        case .disconnected, .disconnecting:
            isConnected = false
            isConnecting = false
            stopConnectionTimer()

        case .invalid:
            isConnected = false
            isConnecting = false
            errorMessage = "Invalid VPN configuration"

        @unknown default:
            break
        }
    }

    // MARK: - Statistics

    private func startConnectionTimer() {
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateConnectionStats()
        }
    }

    private func stopConnectionTimer() {
        connectionTimer?.invalidate()
        connectionTimer = nil
    }

    private func updateConnectionStats() {
        guard let startTime = connectionStartTime else { return }

        connectionDuration = Int(Date().timeIntervalSince(startTime))

        // Get traffic statistics from NetworkExtension tunnel
        // TODO: Implement actual traffic counting in PacketTunnelProvider
        // Real implementation requires:
        // 1. Track bytes in PacketTunnelProvider.readPackets()
        // 2. Send stats via NEPacketTunnelProvider.setTunnelNetworkSettings()
        // 3. Read stats here via NEVPNConnection
        // For now, stats remain at 0 until backend integration is complete
    }
}
