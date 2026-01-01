//
//  PasswordCreationView.swift
//  BarqNet
//
//  Password creation for onboarding
//

import SwiftUI

struct PasswordCreationView: View {
    let email: String
    var onCreate: (String) -> Void

    @State private var password = ""
    @State private var confirmPassword = ""
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
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
                Text("🔒")
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

                Text("Secure Your Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.cyanBlue)

                Text("Create a strong password to protect your VPN account")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
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

                // Confirm password input
                VStack(alignment: .leading, spacing: 8) {
                    Text("CONFIRM PASSWORD")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.6))

                    SecureField("", text: $confirmPassword)
                        .placeholder(when: confirmPassword.isEmpty) {
                            Text("Confirm password")
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyanBlue.opacity(confirmPassword.isEmpty ? 0.2 : 1), lineWidth: 2)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(12)
                        )
                        .onChange(of: confirmPassword) { _ in
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

                // Create account button
                Button(action: {
                    if password.isEmpty || confirmPassword.isEmpty {
                        errorMessage = "Please fill in all fields"
                    } else if password != confirmPassword {
                        errorMessage = "Passwords don't match"
                    } else if password.count < 8 {
                        errorMessage = "Password must be at least 8 characters"
                    } else {
                        onCreate(password)
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
                            Text("CREATE ACCOUNT")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 56)
                }
                .disabled(isLoading)
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }
}

struct PasswordCreationView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordCreationView(
            email: "user@example.com",
            onCreate: { _ in },
            isLoading: .constant(false),
            errorMessage: .constant(nil)
        )
    }
}
