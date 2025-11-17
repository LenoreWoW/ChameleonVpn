//
//  ContentView.swift
//  BarqNet
//
//  Main view for BarqNet iOS
//

import SwiftUI

enum OnboardingState {
    case emailEntry
    case otpVerification
    case passwordCreation
    case login
    case authenticated
}

struct ContentView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @StateObject private var authManager = AuthManager.shared
    @State private var showingImportConfig = false
    @State private var showingSettings = false
    @State private var onboardingState: OnboardingState = .emailEntry
    @State private var currentEmail = ""

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                mainVPNView
            } else {
                onboardingView
            }
        }
        .onAppear {
            onboardingState = authManager.isAuthenticated ? .authenticated : .emailEntry
        }
    }

    private var onboardingView: some View {
        Group {
            switch onboardingState {
            case .emailEntry:
                EmailEntryView(
                    email: $currentEmail,
                    onContinue: {
                        authManager.sendOTP(email: currentEmail) { result in
                            if case .success = result {
                                onboardingState = .otpVerification
                            }
                        }
                    },
                    onLoginClick: {
                        onboardingState = .login
                    }
                )

            case .otpVerification:
                OTPVerificationView(
                    email: currentEmail,
                    onVerify: { code in
                        authManager.verifyOTP(email: currentEmail, code: code) { result in
                            if case .success = result {
                                onboardingState = .passwordCreation
                            }
                        }
                    },
                    onResend: {
                        authManager.sendOTP(email: currentEmail) { _ in }
                    }
                )

            case .passwordCreation:
                PasswordCreationView(
                    email: currentEmail,
                    onCreate: { password in
                        authManager.createAccount(email: currentEmail, password: password) { result in
                            if case .success = result {
                                onboardingState = .authenticated
                            }
                        }
                    }
                )

            case .login:
                LoginView(
                    onLogin: { email, password in
                        authManager.login(email: email, password: password) { result in
                            if case .success = result {
                                currentEmail = email
                                onboardingState = .authenticated
                            }
                        }
                    },
                    onSignUpClick: {
                        onboardingState = .emailEntry
                    }
                )

            case .authenticated:
                mainVPNView
            }
        }
    }

    private var mainVPNView: some View {
        NavigationView {
            ZStack {
                // Background gradient - Blue theme
                LinearGradient(
                    gradient: Gradient(colors: [.darkBg, .darkBgSecondary, .darkBgTertiary]),
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
            .navigationTitle("BarqNet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .foregroundColor(.cyanBlue)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        authManager.logout()
                        onboardingState = .emailEntry
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.cyanBlue)
                    }
                }

                if vpnManager.hasConfig {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showingImportConfig = true
                        }) {
                            Image(systemName: "doc.badge.plus")
                                .foregroundColor(.cyanBlue)
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
