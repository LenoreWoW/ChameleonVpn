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
    
    // Email Entry state
    @State private var isEmailLoading = false
    @State private var emailErrorMessage: String?
    
    // OTP Verification state
    @State private var isOTPLoading = false
    @State private var otpErrorMessage: String?
    
    // Password Creation state
    @State private var isPasswordLoading = false
    @State private var passwordErrorMessage: String?
    
    // Login state
    @State private var isLoginLoading = false
    @State private var loginErrorMessage: String?

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
                        isEmailLoading = true
                        emailErrorMessage = nil
                        
                        authManager.sendOTP(email: currentEmail) { result in
                            isEmailLoading = false
                            
                            switch result {
                            case .success:
                                // Reset OTP state before transitioning
                                isOTPLoading = false
                                otpErrorMessage = nil
                                onboardingState = .otpVerification
                            case .failure(let error):
                                emailErrorMessage = error.localizedDescription
                                NSLog("[EMAIL] Send OTP failed: \(error.localizedDescription)")
                            }
                        }
                    },
                    onLoginClick: {
                        onboardingState = .login
                    },
                    isLoading: $isEmailLoading,
                    errorMessage: $emailErrorMessage
                )

            case .otpVerification:
                OTPVerificationView(
                    email: currentEmail,
                    onVerify: { code in
                        isOTPLoading = true
                        otpErrorMessage = nil
                        
                        authManager.verifyOTP(email: currentEmail, code: code) { result in
                            isOTPLoading = false
                            
                            switch result {
                            case .success:
                                // Reset password state before transitioning
                                isPasswordLoading = false
                                passwordErrorMessage = nil
                                onboardingState = .passwordCreation
                            case .failure(let error):
                                otpErrorMessage = error.localizedDescription
                                NSLog("[OTP] Verification failed: \(error.localizedDescription)")
                            }
                        }
                    },
                    onResend: {
                        otpErrorMessage = nil
                        authManager.sendOTP(email: currentEmail) { result in
                            switch result {
                            case .success:
                                NSLog("[OTP] Resend successful")
                            case .failure(let error):
                                otpErrorMessage = "Failed to resend: \(error.localizedDescription)"
                            }
                        }
                    },
                    isLoading: $isOTPLoading,
                    errorMessage: $otpErrorMessage
                )

            case .passwordCreation:
                PasswordCreationView(
                    email: currentEmail,
                    onCreate: { password in
                        isPasswordLoading = true
                        passwordErrorMessage = nil

                        authManager.createAccount(email: currentEmail, password: password) { result in
                            switch result {
                            case .success:
                                // Download and configure VPN automatically
                                NSLog("[ONBOARDING] Registration successful, downloading VPN config")
                                authManager.downloadAndConfigureVPN { vpnResult in
                                    isPasswordLoading = false

                                    switch vpnResult {
                                    case .success:
                                        NSLog("[ONBOARDING] VPN configured successfully")
                                        onboardingState = .authenticated
                                    case .failure(let error):
                                        NSLog("[ONBOARDING] VPN config failed (non-critical): \(error.localizedDescription)")
                                        // Still proceed to authenticated state even if VPN config fails
                                        onboardingState = .authenticated
                                    }
                                }
                            case .failure(let error):
                                isPasswordLoading = false
                                passwordErrorMessage = error.localizedDescription
                                NSLog("[PASSWORD] Account creation failed: \(error.localizedDescription)")
                            }
                        }
                    },
                    isLoading: $isPasswordLoading,
                    errorMessage: $passwordErrorMessage
                )

            case .login:
                LoginView(
                    onLogin: { email, password in
                        isLoginLoading = true
                        loginErrorMessage = nil

                        authManager.login(email: email, password: password) { result in
                            switch result {
                            case .success:
                                currentEmail = email

                                // Download and configure VPN automatically
                                NSLog("[ONBOARDING] Login successful, downloading VPN config")
                                authManager.downloadAndConfigureVPN { vpnResult in
                                    isLoginLoading = false

                                    switch vpnResult {
                                    case .success:
                                        NSLog("[ONBOARDING] VPN configured successfully")
                                        onboardingState = .authenticated
                                        loginErrorMessage = nil
                                    case .failure(let error):
                                        NSLog("[ONBOARDING] VPN config failed (non-critical): \(error.localizedDescription)")
                                        // Still proceed to authenticated state even if VPN config fails
                                        onboardingState = .authenticated
                                        loginErrorMessage = nil
                                    }
                                }
                            case .failure(let error):
                                isLoginLoading = false
                                loginErrorMessage = error.localizedDescription
                                NSLog("[LOGIN] Failed: \(error.localizedDescription)")
                            }
                        }
                    },
                    onSignUpClick: {
                        onboardingState = .emailEntry
                    },
                    isLoading: $isLoginLoading,
                    errorMessage: $loginErrorMessage
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
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if vpnManager.hasConfig {
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
