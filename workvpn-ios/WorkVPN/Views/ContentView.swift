//
//  ContentView.swift
//  WorkVPN
//
//  Main view for WorkVPN iOS
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var showingImportConfig = false
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.4, green: 0.49, blue: 0.92),
                        Color(red: 0.46, green: 0.29, blue: 0.64)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Content
                if vpnManager.hasConfig {
                    VPNStatusView()
                } else {
                    NoConfigView(showingImportConfig: $showingImportConfig)
                }
            }
            .navigationTitle("WorkVPN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .foregroundColor(.white)
                    }
                }

                if vpnManager.hasConfig {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showingImportConfig = true
                        }) {
                            Image(systemName: "doc.badge.plus")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingImportConfig) {
                ConfigImportView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(VPNManager.shared)
    }
}
