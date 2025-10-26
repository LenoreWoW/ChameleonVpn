//
//  ContentView.swift
//  BarqNet
//
//  Main view for BarqNet iOS
//

import SwiftUI

enum OnboardingState {
    case phoneEntry
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
    @State private var onboardingState: OnboardingState = .phoneEntry
    @State private var currentPhoneNumber = ""

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                mainVPNView
            } else {
                onboardingView
            }
        }
        .onAppear {
            onboardingState = authManager.isAuthenticated ? .authenticated : .phoneEntry
        }
    }

    private var onboardingView: some View {
        Group {
            switch onboardingState {
            case .phoneEntry:
                PhoneNumberView(
                    phoneNumber: $currentPhoneNumber,
                    onContinue: {
                        authManager.sendOTP(phoneNumber: currentPhoneNumber) { result in
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
                    phoneNumber: currentPhoneNumber,
                    onVerify: { code in
                        authManager.verifyOTP(phoneNumber: currentPhoneNumber, code: code) { result in
                            if case .success = result {
                                onboardingState = .passwordCreation
                            }
                        }
                    },
                    onResend: {
                        authManager.sendOTP(phoneNumber: currentPhoneNumber) { _ in }
                    }
                )

            case .passwordCreation:
                PasswordCreationView(
                    phoneNumber: currentPhoneNumber,
                    onCreate: { password in
                        authManager.createAccount(phoneNumber: currentPhoneNumber, password: password) { result in
                            if case .success = result {
                                onboardingState = .authenticated
                            }
                        }
                    }
                )

            case .login:
                LoginView(
                    onLogin: { phone, password in
                        authManager.login(phoneNumber: phone, password: password) { result in
                            if case .success = result {
                                currentPhoneNumber = phone
                                onboardingState = .authenticated
                            }
                        }
                    },
                    onSignUpClick: {
                        onboardingState = .phoneEntry
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
                        onboardingState = .phoneEntry
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
