//
//  BarqNetApp.swift
//  BarqNet
//
//  Main app entry point for BarqNet iOS
//

import SwiftUI

@main
struct BarqNetApp: App {
    @StateObject private var vpnManager = VPNManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vpnManager)
        }
    }
}
