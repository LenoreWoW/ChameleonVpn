//
//  Colors.swift
//  BarqNet
//
//  Blue theme color palette
//

import SwiftUI

extension Color {
    // Blue Theme Colors
    static let cyanBlue = Color(hex: "#00D4FF")
    static let deepBlue = Color(hex: "#0088FF")
    static let mediumBlue = Color(hex: "#3399FF")

    // Background Colors
    static let darkBg = Color(hex: "#0A0E27")
    static let darkBgSecondary = Color(hex: "#1A2332")
    static let darkBgTertiary = Color(hex: "#0F1729")

    // Status Colors
    static let green = Color(hex: "#4ADE80")
    static let greenDark = Color(hex: "#22C55E")
    static let orange = Color(hex: "#FB923C")
    static let orangeDark = Color(hex: "#F97316")
    static let red = Color(hex: "#EF4444")
    static let redDark = Color(hex: "#DC2626")
    static let grayLight = Color(hex: "#6B7280")
    static let grayDark = Color(hex: "#4B5563")

    // Helper initializer for hex colors
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
