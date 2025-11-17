//
//  OTPVerificationView.swift
//  BarqNet
//
//  OTP verification for onboarding
//

import SwiftUI

struct OTPVerificationView: View {
    let email: String
    var onVerify: (String) -> Void
    var onResend: () -> Void

    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedField: Int?
    @State private var isLoading = false
    @State private var showError = false
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
                Text("🔐")
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

                Text("Verify Your Email")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.cyanBlue)

                Text("We've sent a 6-digit code to \(email)")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // OTP input
                GeometryReader { geometry in
                    HStack(spacing: 8) {
                        ForEach(0..<6, id: \.self) { index in
                            TextField("", text: $otpDigits[index])
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: min(50, (geometry.size.width - 40 - 40) / 6), height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(otpDigits[index].isEmpty ? Color.cyanBlue.opacity(0.3) : Color.cyanBlue, lineWidth: 2)
                                        .background(Color.black.opacity(0.4))
                                        .cornerRadius(12)
                                )
                                .focused($focusedField, equals: index)
                                .onChange(of: otpDigits[index]) { newValue in
                                    handleOTPChange(at: index, newValue: newValue)
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .position(x: geometry.size.width / 2, y: 30)
                }
                .frame(height: 60)
                .padding(.horizontal, 32)

                if showError {
                    Text("Invalid code. Please try again.")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // Verify button
                Button(action: {
                    let code = otpDigits.joined()
                    if code.count == 6 {
                        isLoading = true
                        onVerify(code)
                    } else {
                        showError = true
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
                            Text("VERIFY CODE")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 56)
                }
                .disabled(isLoading)
                .padding(.horizontal, 32)

                // Resend link
                Button(action: onResend) {
                    Text("Didn't receive code? Resend")
                        .font(.body)
                        .foregroundColor(.cyanBlue)
                }

                Spacer()
            }
        }
        .onAppear {
            focusedField = 0
        }
    }

    private func handleOTPChange(at index: Int, newValue: String) {
        // Only allow single digit
        if newValue.count > 1 {
            otpDigits[index] = String(newValue.last ?? Character(""))
        }

        // Filter non-digits
        otpDigits[index] = otpDigits[index].filter { $0.isNumber }

        showError = false

        // Auto-advance to next field
        if !otpDigits[index].isEmpty && index < 5 {
            focusedField = index + 1
        }

        // Auto-verify when all filled
        if index == 5 && !otpDigits[index].isEmpty {
            let code = otpDigits.joined()
            if code.count == 6 {
                isLoading = true
                onVerify(code)
            }
        }

        // Go back on delete
        if otpDigits[index].isEmpty && index > 0 {
            focusedField = index - 1
        }
    }
}

struct OTPVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        OTPVerificationView(
            email: "user@example.com",
            onVerify: { _ in },
            onResend: {}
        )
    }
}
