//
//  ConfigImportView.swift
//  WorkVPN
//
//  View for importing .ovpn configuration files
//

import SwiftUI
import UniformTypeIdentifiers

struct ConfigImportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vpnManager: VPNManager
    @State private var showingFilePicker = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                // Import Icon
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.bottom, 20)

                // Title
                Text("Import Configuration")
                    .font(.system(size: 28, weight: .bold))

                // Description
                Text("Select an OpenVPN configuration file (.ovpn) from your device")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Import Methods
                VStack(spacing: 15) {
                    Button(action: {
                        showingFilePicker = true
                    }) {
                        HStack {
                            Image(systemName: "folder")
                            Text("Choose from Files")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    Button(action: {
                        // TODO: Handle AirDrop import
                        errorMessage = "AirDrop import coming soon"
                        showingError = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import via AirDrop")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 30)

                Spacer()
            }
            .navigationTitle("Import Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "ovpn") ?? UTType.data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .alert("Import Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                // Read file content
                let content = try String(contentsOf: url, encoding: .utf8)

                // Parse and import config
                try vpnManager.importConfig(content: content, name: url.lastPathComponent)

                // Dismiss the sheet
                dismiss()

            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct ConfigImportView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigImportView()
            .environmentObject(VPNManager.shared)
    }
}
