//
//  VPNConfig.swift
//  WorkVPN
//
//  Model for VPN configuration
//

import Foundation

struct VPNConfig: Codable {
    var name: String
    var content: String
    var serverAddress: String
    var port: Int
    var `protocol`: String
    var importedAt: Date

    // Parsed certificate components
    var ca: String?
    var cert: String?
    var key: String?
    var tlsAuth: String?
    var cipher: String?
    var auth: String?

    init(name: String, content: String, serverAddress: String, port: Int = 1194, protocol: String = "udp") {
        self.name = name
        self.content = content
        self.serverAddress = serverAddress
        self.port = port
        self.protocol = `protocol`
        self.importedAt = Date()
    }
}

extension VPNConfig {
    var displayName: String {
        name.replacingOccurrences(of: ".ovpn", with: "")
    }

    var protocolDisplay: String {
        "\(`protocol`.uppercased()):\(port)"
    }
}
