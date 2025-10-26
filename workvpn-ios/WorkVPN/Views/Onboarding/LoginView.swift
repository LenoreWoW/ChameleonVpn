//
//  LoginView.swift
//  BarqNet
//
//  Login view for returning users
//

import SwiftUI

struct LoginView: View {
    var onLogin: (String, String) -> Void
    var onSignUpClick: () -> Void

    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [.darkBg, .darkBgSecondary, .darkBgTertiary]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Floating icon
                Text("👋")
                    .font(.system(size: 80))
                    .offset(y: floatOffset)
                    .onAppear {
                        withAnimation(
                            Animation.easeInOut(duration: 3)
                                .repeatForever(autoreverses: true)
                        ) {
                            floatOffset = -10
                        }
                    }

                Text("Welcome Back")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.cyanBlue)

                Text("Sign in to access your secure VPN connection")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Phone number input
                VStack(alignment: .leading, spacing: 8) {
                    Text("PHONE NUMBER")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.6))

                    TextField("", text: $phoneNumber)
                        .placeholder(when: phoneNumber.isEmpty) {
                            Text("+1 (555) 123-4567")
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .keyboardType(.phonePad)
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyanBlue.opacity(phoneNumber.isEmpty ? 0.2 : 1), lineWidth: 2)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(12)
                        )
                        .onChange(of: phoneNumber) { _ in
                            errorMessage = nil
                        }
                }
                .padding(.horizontal, 32)

                // Password input
                VStack(alignment: .leading, spacing: 8) {
                    Text("PASSWORD")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.6))

                    SecureField("", text: $password)
                        .placeholder(when: password.isEmpty) {
                            Text("Enter password")
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyanBlue.opacity(password.isEmpty ? 0.2 : 1), lineWidth: 2)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(12)
                        )
                        .onChange(of: password) { _ in
                            errorMessage = nil
                        }
                }
                .padding(.horizontal, 32)

                if let error = errorMessage {
                    HStack {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    )
                    .padding(.horizontal, 32)
                }

                // Sign in button
                Button(action: {
                    if phoneNumber.isEmpty || password.isEmpty {
                        errorMessage = "Please fill in all fields"
                    } else {
                        isLoading = true
                        onLogin(phoneNumber, password)
                    }
                }) {
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [.cyanBlue, .deepBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .cornerRadius(12)

                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("SIGN IN")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 56)
                }
                .disabled(isLoading)
                .padding(.horizontal, 32)

                // Sign up link
                Button(action: onSignUpClick) {
                    Text("New user? Create Account")
                        .font(.body)
                        .foregroundColor(.cyanBlue)
                }

                Spacer()
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(
            onLogin: { _, _ in },
            onSignUpClick: {}
        )
    }
}
