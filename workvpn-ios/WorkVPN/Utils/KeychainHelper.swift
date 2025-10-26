//
//  KeychainHelper.swift
//  WorkVPN
//
//  Secure storage for sensitive data using iOS Keychain
//

import Foundation
import Security

class KeychainHelper {

    /**
     * Save data securely to the Keychain
     *
     * - Parameters:
     *   - data: The data to store
     *   - service: Service identifier (e.g., "com.workvpn.ios")
     *   - account: Account identifier (e.g., "vpn_config")
     * - Returns: true if successful, false otherwise
     */
    static func save(_ data: Data, service: String, account: String) -> Bool {
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked  // Only accessible when device is unlocked
        ]

        // Delete any existing item first to avoid duplicate errors
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            NSLog("[KeychainHelper] Successfully saved item to Keychain (service: \(service), account: \(account))")
            return true
        } else {
            NSLog("[KeychainHelper] ERROR: Failed to save item to Keychain - Status: \(status)")
            return false
        }
    }

    /**
     * Load data from the Keychain
     *
     * - Parameters:
     *   - service: Service identifier
     *   - account: Account identifier
     * - Returns: The stored data, or nil if not found or error occurred
     */
    static func load(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            if let data = result as? Data {
                NSLog("[KeychainHelper] Successfully loaded item from Keychain (service: \(service), account: \(account))")
                return data
            } else {
                NSLog("[KeychainHelper] ERROR: Item found but not Data type")
                return nil
            }
        } else if status == errSecItemNotFound {
            // Not an error - item simply doesn't exist
            return nil
        } else {
            NSLog("[KeychainHelper] ERROR: Failed to load item from Keychain - Status: \(status)")
            return nil
        }
    }

    /**
     * Delete data from the Keychain
     *
     * - Parameters:
     *   - service: Service identifier
     *   - account: Account identifier
     * - Returns: true if deleted or didn't exist, false on error
     */
    static func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            NSLog("[KeychainHelper] Successfully deleted item from Keychain (service: \(service), account: \(account))")
            return true
        } else {
            NSLog("[KeychainHelper] ERROR: Failed to delete item from Keychain - Status: \(status)")
            return false
        }
    }

    /**
     * Update existing data in the Keychain
     *
     * - Parameters:
     *   - data: The new data
     *   - service: Service identifier
     *   - account: Account identifier
     * - Returns: true if successful, false otherwise
     */
    static func update(_ data: Data, service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecSuccess {
            NSLog("[KeychainHelper] Successfully updated item in Keychain (service: \(service), account: \(account))")
            return true
        } else if status == errSecItemNotFound {
            // Item doesn't exist, create it instead
            return save(data, service: service, account: account)
        } else {
            NSLog("[KeychainHelper] ERROR: Failed to update item in Keychain - Status: \(status)")
            return false
        }
    }

    /**
     * Check if an item exists in the Keychain
     *
     * - Parameters:
     *   - service: Service identifier
     *   - account: Account identifier
     * - Returns: true if item exists, false otherwise
     */
    static func exists(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}
