//
//  VPNStatusView.swift
//  WorkVPN
//
//  Shows VPN connection status and controls
//

import SwiftUI

struct VPNStatusView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var animateStatusIcon = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .scaleEffect(animateStatusIcon ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: animateStatusIcon)

                Circle()
                    .fill(statusColor)
                    .frame(width: 150, height: 150)

                Image(systemName: statusIcon)
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            .onAppear {
                if vpnManager.isConnected {
                    animateStatusIcon = true
                }
            }
            .onChange(of: vpnManager.isConnected) { newValue in
                animateStatusIcon = newValue
            }

            // Status Text
            Text(statusText)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .textCase(.uppercase)
                .tracking(2)

            // Connection Info
            if vpnManager.isConnected {
                VStack(spacing: 15) {
                    InfoRow(label: "Server", value: vpnManager.currentConfig?.serverAddress ?? "-")
                    InfoRow(label: "Protocol", value: vpnManager.currentConfig?.protocol.uppercased() ?? "UDP")
                    InfoRow(label: "Duration", value: formattedDuration)

                    // Traffic Stats
                    HStack(spacing: 30) {
                        StatBox(title: "Download", value: formatBytes(vpnManager.bytesIn))
                        StatBox(title: "Upload", value: formatBytes(vpnManager.bytesOut))
                    }
                    .padding(.top, 10)
                }
                .padding()
                .background(Color.white.opacity(0.15))
                .cornerRadius(15)
            }

            Spacer()

            // Connect/Disconnect Button
            Button(action: {
                if vpnManager.isConnected || vpnManager.isConnecting {
                    vpnManager.disconnect()
                } else {
                    vpnManager.connect()
                }
            }) {
                Text(buttonText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(buttonTextColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(buttonBackgroundColor)
                    .cornerRadius(15)
            }
            .disabled(vpnManager.isConnecting)
            .padding(.horizontal)

            // Delete Config Button
            Button(action: {
                vpnManager.deleteConfig()
            }) {
                Text("Delete Configuration")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.bottom, 20)
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        if vpnManager.isConnected {
            return Color.green
        } else if vpnManager.isConnecting {
            return Color.orange
        } else {
            return Color.red
        }
    }

    private var statusIcon: String {
        if vpnManager.isConnected {
            return "checkmark.shield.fill"
        } else if vpnManager.isConnecting {
            return "arrow.triangle.2.circlepath"
        } else {
            return "xmark.shield.fill"
        }
    }

    private var statusText: String {
        if vpnManager.isConnected {
            return "Connected"
        } else if vpnManager.isConnecting {
            return "Connecting"
        } else {
            return "Disconnected"
        }
    }

    private var buttonText: String {
        if vpnManager.isConnected {
            return "Disconnect"
        } else if vpnManager.isConnecting {
            return "Connecting..."
        } else {
            return "Connect"
        }
    }

    private var buttonTextColor: Color {
        if vpnManager.isConnected {
            return .white
        } else {
            return Color(red: 0.4, green: 0.49, blue: 0.92)
        }
    }

    private var buttonBackgroundColor: Color {
        if vpnManager.isConnected {
            return .red
        } else {
            return .white
        }
    }

    private var formattedDuration: String {
        let duration = vpnManager.connectionDuration
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576.0
        return String(format: "%.2f MB", mb)
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 14, weight: .medium))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .foregroundColor(.white.opacity(0.7))
                .font(.system(size: 12, weight: .medium))
                .textCase(.uppercase)
                .tracking(1)

            Text(value)
                .foregroundColor(.white)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
}

struct VPNStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VPNStatusView()
            .environmentObject(VPNManager.shared)
    }
}
