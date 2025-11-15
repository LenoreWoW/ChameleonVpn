//
//  VPNManager.swift
//  BarqNet
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
        migrateConfigToKeychain()
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

    /**
     * Save VPN configuration securely to Keychain
     * ✅ SECURITY: VPN config is stored in Keychain (encrypted and secure)
     */
    private func saveConfig(_ config: VPNConfig) {
        if let encoded = try? JSONEncoder().encode(config) {
            // SECURE: Store VPN config in Keychain instead of UserDefaults
            let success = KeychainHelper.save(
                encoded,
                service: "com.workvpn.ios",
                account: "vpn_config"
            )

            if success {
                currentConfig = config
                hasConfig = true
                NSLog("[VPNManager] VPN configuration saved securely to Keychain")
            } else {
                NSLog("[VPNManager] ERROR: Failed to save VPN configuration to Keychain")
            }
        }
    }

    private func loadSavedConfig() {
        // SECURE: Load VPN config from Keychain instead of UserDefaults
        if let data = KeychainHelper.load(service: "com.workvpn.ios", account: "vpn_config"),
           let config = try? JSONDecoder().decode(VPNConfig.self, from: data) {
            currentConfig = config
            hasConfig = true
            NSLog("[VPNManager] VPN configuration loaded from Keychain")
        }
    }

    func deleteConfig() {
        // SECURE: Delete VPN config from Keychain instead of UserDefaults
        _ = KeychainHelper.delete(service: "com.workvpn.ios", account: "vpn_config")

        currentConfig = nil
        hasConfig = false

        // Remove VPN configuration
        vpnManager?.removeFromPreferences { _ in }
        vpnManager = nil

        NSLog("[VPNManager] VPN configuration deleted from Keychain")
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
        providerProtocol.providerBundleIdentifier = "com.workvpn.ios.BarqNetTunnelExtension"
        providerProtocol.serverAddress = config.serverAddress

        // Pass configuration to tunnel extension
        providerProtocol.providerConfiguration = [
            "ovpn": config.content,
            "server": config.serverAddress,
            "port": config.port,
            "protocol": config.protocol
        ]

        manager.protocolConfiguration = providerProtocol
        manager.localizedDescription = "BarqNet"
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

        // Get traffic statistics from PacketTunnelProvider
        guard let session = vpnManager?.connection as? NETunnelProviderSession else { return }

        // Request stats from packet tunnel provider
        do {
            try session.sendProviderMessage(Data("stats".utf8)) { [weak self] response in
                guard let response = response,
                      let stats = try? JSONDecoder().decode(TrafficStats.self, from: response) else {
                    return
                }

                DispatchQueue.main.async {
                    self?.bytesIn = UInt64(stats.bytesIn)
                    self?.bytesOut = UInt64(stats.bytesOut)
                }
            }
        } catch {
            NSLog("[VPNManager] Error requesting stats: \(error)")
        }
    }

    // MARK: - Migration

    /**
     * Migrate VPN configuration from UserDefaults to Keychain
     *
     * This migration ensures existing users' VPN configs are moved to secure storage.
     * Called once on initialization to safely migrate legacy storage.
     *
     * Migration Process:
     * 1. Check if config exists in UserDefaults (old location)
     * 2. Save to Keychain (new secure location)
     * 3. Remove from UserDefaults (cleanup)
     * 4. Log migration success
     *
     * Security Note: This ensures all VPN configs are stored securely in Keychain,
     * protected by iOS security features (encryption, secure enclave, etc.)
     */
    private func migrateConfigToKeychain() {
        // Check if data exists in old UserDefaults location
        if let oldData = UserDefaults.standard.data(forKey: "vpn_config") {
            // Check if it's already in Keychain (avoid duplicate migration)
            if KeychainHelper.exists(service: "com.workvpn.ios", account: "vpn_config") {
                // Already migrated, just clean up UserDefaults
                UserDefaults.standard.removeObject(forKey: "vpn_config")
                NSLog("[VPNManager] Cleaned up old VPN config from UserDefaults (already in Keychain)")
                return
            }

            // Save to Keychain
            let success = KeychainHelper.save(
                oldData,
                service: "com.workvpn.ios",
                account: "vpn_config"
            )

            if success {
                // Remove from UserDefaults
                UserDefaults.standard.removeObject(forKey: "vpn_config")
                NSLog("[VPNManager] Successfully migrated VPN config from UserDefaults to Keychain")
            } else {
                NSLog("[VPNManager] WARNING: Failed to migrate VPN config to Keychain - keeping in UserDefaults as fallback")
            }
        }
    }
}

// MARK: - Traffic Statistics

struct TrafficStats: Codable {
    let bytesIn: Int64
    let bytesOut: Int64
}
