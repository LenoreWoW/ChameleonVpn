//
//  TestingConfig.swift
//  WorkVPN
//
//  Created for testing and development purposes
//  This file provides test credentials and bypass mechanisms for development
//

import Foundation

/// Configuration for testing and development
struct TestingConfig {

    // MARK: - Debug Flag

    /// Enable testing features only in DEBUG builds
    #if DEBUG
    static let isTestingEnabled = true
    #else
    static let isTestingEnabled = false
    #endif

    // MARK: - Test Credentials

    /// Test account email for quick login during development
    static let testEmail = "test@barqnet.local"

    /// Test account password for quick login during development
    static let testPassword = "Test1234"

    /// Test OTP code (if backend supports test mode)
    static let testOTP = "123456"

    // MARK: - Testing Features

    /// Enable auto-fill of test credentials
    static let enableAutoFill = true

    /// Enable quick login button
    static let enableQuickLogin = true

    /// Enable bypass OTP in test mode
    static let enableOTPBypass = true

    // MARK: - Helper Methods

    /// Check if we're in testing mode
    static var isInTestMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Log testing actions (only in DEBUG)
    static func logTestAction(_ message: String) {
        #if DEBUG
        NSLog("[TESTING] \(message)")
        #endif
    }
}
