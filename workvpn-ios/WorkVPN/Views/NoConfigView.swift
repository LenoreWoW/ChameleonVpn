//
//  NoConfigView.swift
//  WorkVPN
//
//  View shown when no VPN configuration is imported
//

import SwiftUI

struct NoConfigView: View {
    @Binding var showingImportConfig: Bool

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Lock Icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 100))
                .foregroundColor(.white)
                .padding(.bottom, 20)

            // Title
            Text("No VPN Configuration")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.cyanBlue)
                .multilineTextAlignment(.center)

            // Description
            Text("Import an OpenVPN configuration file (.ovpn) to get started")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            // Import Button
            Button(action: {
                showingImportConfig = true
            }) {
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [.cyanBlue, .deepBlue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .cornerRadius(15)

                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 20))
                        Text("IMPORT .OVPN FILE")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
}

struct NoConfigView_Previews: PreviewProvider {
    static var previews: some View {
        NoConfigView(showingImportConfig: .constant(false))
    }
}
