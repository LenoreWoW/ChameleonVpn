//
//  SettingsView.swift
//  BarqNet
//
//  App settings view
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vpnManager: VPNManager
    @AppStorage("autoConnect") private var autoConnect = false
    @AppStorage("faceIDEnabled") private var faceIDEnabled = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Connection")) {
                    Toggle("Auto-connect on app launch", isOn: $autoConnect)
                        .tint(.blue)
                }

                Section(header: Text("Security")) {
                    Toggle("Quick connect with Face ID", isOn: $faceIDEnabled)
                        .tint(.blue)
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Support")) {
                    Link(destination: URL(string: "https://github.com/workvpn/ios")!) {
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://github.com/workvpn/ios/issues")!) {
                        HStack {
                            Text("Report an Issue")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    Button(role: .destructive, action: {
                        vpnManager.deleteConfig()
                        dismiss()
                    }) {
                        Text("Delete Configuration")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(!vpnManager.hasConfig)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(VPNManager.shared)
    }
}
