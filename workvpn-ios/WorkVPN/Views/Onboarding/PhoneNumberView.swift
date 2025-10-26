//
//  PhoneNumberView.swift
//  BarqNet
//
//  Phone number entry for onboarding
//

import SwiftUI

struct PhoneNumberView: View {
    @Binding var phoneNumber: String
    var onContinue: () -> Void
    var onLoginClick: () -> Void

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
                Text("📱")
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

                Text("Enter your phone number to create your secure VPN account")
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

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 32)
                }

                // Continue button
                Button(action: {
                    if phoneNumber.isEmpty {
                        errorMessage = "Please enter your phone number"
                    } else {
                        isLoading = true
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

struct PhoneNumberView_Previews: PreviewProvider {
    static var previews: some View {
        PhoneNumberView(
            phoneNumber: .constant(""),
            onContinue: {},
            onLoginClick: {}
        )
    }
}
