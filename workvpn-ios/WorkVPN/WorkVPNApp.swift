//
//  WorkVPNApp.swift
//  WorkVPN
//
//  Main app entry point for WorkVPN iOS
//

import SwiftUI

@main
struct WorkVPNApp: App {
    @StateObject private var vpnManager = VPNManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vpnManager)
        }
    }
}
