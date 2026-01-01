//
//  EmailEntryView.swift
//  BarqNet
//
//  Email entry for onboarding
//

import SwiftUI

struct EmailEntryView: View {
    @Binding var email: String
    var onContinue: () -> Void
    var onLoginClick: () -> Void

    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    @State private var floatOffset: CGFloat = 0

    // Testing configuration (DEBUG only)
    #if DEBUG
    private let testEmail = "test@barqnet.local"
    #endif

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
                Text("📧")
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

                Text("Get Started")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.cyanBlue)

                Text("Enter your email address to create your secure VPN account")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Email input
                VStack(alignment: .leading, spacing: 8) {
                    Text("EMAIL ADDRESS")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.6))

                    TextField("", text: $email)
                        .placeholder(when: email.isEmpty) {
                            Text("email@example.com")
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyanBlue.opacity(email.isEmpty ? 0.2 : 1), lineWidth: 2)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(12)
                        )
                        .onChange(of: email) { _ in
                            errorMessage = nil
                        }
                }
                .padding(.horizontal, 32)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 32)
                }

                // Continue button
                Button(action: {
                    if email.isEmpty {
                        errorMessage = "Please enter your email address"
                    } else {
                        onContinue()
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
                            Text("CONTINUE")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 56)
                }
                .disabled(isLoading)
                .padding(.horizontal, 32)

                // Login link
                Button(action: onLoginClick) {
                    Text("Already have an account? Sign In")
                        .font(.body)
                        .foregroundColor(.cyanBlue)
                }

                #if DEBUG
                // Quick test email button (DEBUG only)
                Button(action: {
                    NSLog("[TESTING] Quick test email auto-fill triggered")
                    email = testEmail

                    // Trigger continue after a brief delay to show auto-fill
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onContinue()
                    }
                }) {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Use Test Email")
                                .font(.caption)
                        }
                        .foregroundColor(.yellow)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                                .background(Color.yellow.opacity(0.1))
                                .cornerRadius(8)
                        )
                }
                .padding(.top, 8)
                #endif

                Spacer()
            }
        }
    }
}

// TextField placeholder extension
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct EmailEntryView_Previews: PreviewProvider {
    static var previews: some View {
        EmailEntryView(
            email: .constant(""),
            onContinue: {},
            onLoginClick: {},
            isLoading: .constant(false),
            errorMessage: .constant(nil)
        )
    }
}
