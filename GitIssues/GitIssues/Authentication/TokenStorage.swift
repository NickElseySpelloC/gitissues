//
//  TokenStorage.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation
import Security

/// Manages secure storage of OAuth tokens in the Keychain
class TokenStorage {
    private let service = "com.gitissues.tokens"
    private let account = "github_access_token"

    /// Saves the access token to the Keychain
    func saveAccessToken(_ token: String) {
        // Delete existing token first
        deleteAccessToken()

        // Prepare token data
        guard let tokenData = token.data(using: .utf8) else { return }

        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Add to keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("Error saving token to keychain: \(status)")
        }
    }

    /// Retrieves the access token from the Keychain
    func getAccessToken() -> String? {
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
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    /// Deletes the access token from the Keychain
    func deleteAccessToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
