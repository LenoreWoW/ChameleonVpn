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
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // Description
            Text("Import an OpenVPN configuration file (.ovpn) to get started")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            // Import Button
            Button(action: {
                showingImportConfig = true
            }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 20))
                    Text("Import .ovpn File")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(.white)
                .cornerRadius(15)
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
