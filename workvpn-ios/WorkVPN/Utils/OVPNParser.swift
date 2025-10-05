//
//  OVPNParser.swift
//  WorkVPN
//
//  Parser for .ovpn configuration files
//

import Foundation

enum OVPNParserError: LocalizedError {
    case missingRemote
    case missingCA
    case invalidFormat
    case invalidPort

    var errorDescription: String? {
        switch self {
        case .missingRemote:
            return "Configuration is missing remote server address"
        case .missingCA:
            return "Configuration is missing CA certificate"
        case .invalidFormat:
            return "Invalid OpenVPN configuration format"
        case .invalidPort:
            return "Invalid port number"
        }
    }
}

struct OVPNParser {
    static func parse(content: String, name: String) throws -> VPNConfig {
        let lines = content.components(separatedBy: .newlines)

        var serverAddress: String?
        var port: Int = 1194
        var `protocol`: String = "udp"
        var ca: String?
        var cert: String?
        var key: String?
        var tlsAuth: String?
        var cipher: String?
        var auth: String?

        var currentBlock: String?
        var blockContent: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") {
                continue
            }

            // Handle inline blocks
            if trimmed.hasPrefix("<") {
                if let match = trimmed.range(of: #"<(\/?)([

\w-]+)>"#, options: .regularExpression) {
                    let tag = String(trimmed[match])
                    let isClosing = tag.hasPrefix("</")
                    let blockType = tag.replacingOccurrences(of: "<", with: "")
                        .replacingOccurrences(of: "</", with: "")
                        .replacingOccurrences(of: ">", with: "")

                    if isClosing {
                        // End of block
                        if currentBlock == blockType {
                            let content = blockContent.joined(separator: "\n")

                            switch blockType {
                            case "ca":
                                ca = content
                            case "cert":
                                cert = content
                            case "key":
                                key = content
                            case "tls-auth":
                                tlsAuth = content
                            default:
                                break
                            }

                            currentBlock = nil
                            blockContent = []
                        }
                    } else {
                        // Start of block
                        currentBlock = blockType
                        blockContent = []
                    }
                }
                continue
            }

            // If in block, collect content
            if currentBlock != nil {
                blockContent.append(line)
                continue
            }

            // Parse key-value pairs
            let parts = trimmed.components(separatedBy: .whitespaces)
            guard let key = parts.first else { continue }
            let values = Array(parts.dropFirst())

            switch key {
            case "remote":
                if values.count > 0 {
                    serverAddress = values[0]
                    if values.count > 1, let portValue = Int(values[1]) {
                        port = portValue
                    }
                }

            case "proto":
                if let proto = values.first {
                    `protocol` = proto
                }

            case "cipher":
                if let cipherValue = values.first {
                    cipher = cipherValue
                }

            case "auth":
                if let authValue = values.first {
                    auth = authValue
                }

            default:
                break
            }
        }

        // Validation
        guard let server = serverAddress else {
            throw OVPNParserError.missingRemote
        }

        if ca == nil {
            throw OVPNParserError.missingCA
        }

        // Create config
        var config = VPNConfig(
            name: name,
            content: content,
            serverAddress: server,
            port: port,
            protocol: `protocol`
        )

        config.ca = ca
        config.cert = cert
        config.key = key
        config.tlsAuth = tlsAuth
        config.cipher = cipher
        config.auth = auth

        return config
    }

    static func validate(config: VPNConfig) -> [String] {
        var errors: [String] = []

        if config.serverAddress.isEmpty {
            errors.append("Missing remote server address")
        }

        if config.ca == nil {
            errors.append("Missing CA certificate")
        }

        if config.port < 1 || config.port > 65535 {
            errors.append("Invalid port number")
        }

        return errors
    }
}
