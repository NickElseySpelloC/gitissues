//
//  CredentialsStorage.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation
import Security

/// Manages secure storage of OAuth credentials in the Keychain
class CredentialsStorage {
    private let service = "com.gitissues.credentials"
    private let clientIDAccount = "github_client_id"
    private let clientSecretAccount = "github_client_secret"

    /// Saves the client ID to the Keychain
    func saveClientID(_ clientID: String) {
        saveToKeychain(value: clientID, account: clientIDAccount)
    }

    /// Saves the client secret to the Keychain
    func saveClientSecret(_ clientSecret: String) {
        saveToKeychain(value: clientSecret, account: clientSecretAccount)
    }

    /// Retrieves the client ID from the Keychain
    func getClientID() -> String? {
        return getFromKeychain(account: clientIDAccount)
    }

    /// Retrieves the client secret from the Keychain
    func getClientSecret() -> String? {
        return getFromKeychain(account: clientSecretAccount)
    }

    /// Deletes the client ID from the Keychain
    func deleteClientID() {
        deleteFromKeychain(account: clientIDAccount)
    }

    /// Deletes the client secret from the Keychain
    func deleteClientSecret() {
        deleteFromKeychain(account: clientSecretAccount)
    }

    /// Deletes all credentials from the Keychain
    func deleteAll() {
        deleteClientID()
        deleteClientSecret()
    }

    // MARK: - Private Helpers

    private func saveToKeychain(value: String, account: String) {
        // Delete existing value first
        deleteFromKeychain(account: account)

        // Prepare value data
        guard let valueData = value.data(using: .utf8) else { return }

        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: valueData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Add to keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("Error saving \(account) to keychain: \(status)")
        }
    }

    private func getFromKeychain(account: String) -> String? {
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
