//
//  SettingsViewModel.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var clientID: String = ""
    @Published var clientSecret: String = ""
    @Published var isSaving: Bool = false
    @Published var saveMessage: String?
    @Published var saveMessageIsError: Bool = false

    private let credentialsStorage = CredentialsStorage()

    init() {
        loadCredentials()
    }

    /// Loads credentials from storage or environment variables
    func loadCredentials() {
        // First try to load from Keychain
        if let storedClientID = credentialsStorage.getClientID(),
           let storedClientSecret = credentialsStorage.getClientSecret() {
            clientID = storedClientID
            clientSecret = storedClientSecret
        } else {
            // Fall back to environment variables
            clientID = ProcessInfo.processInfo.environment["GITHUB_CLIENT_ID"] ?? ""
            clientSecret = ProcessInfo.processInfo.environment["GITHUB_CLIENT_SECRET"] ?? ""

            // If environment variables are present, show a message
            if !clientID.isEmpty && !clientSecret.isEmpty {
                saveMessage = "Credentials loaded from environment variables. Click Save to store them securely."
                saveMessageIsError = false
            }
        }
    }

    /// Saves credentials to Keychain
    func saveCredentials() {
        let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate inputs
        guard !trimmedClientID.isEmpty else {
            saveMessage = "Client ID cannot be empty"
            saveMessageIsError = true
            return
        }

        guard !trimmedClientSecret.isEmpty else {
            saveMessage = "Client Secret cannot be empty"
            saveMessageIsError = true
            return
        }

        isSaving = true

        // Save to Keychain
        credentialsStorage.saveClientID(trimmedClientID)
        credentialsStorage.saveClientSecret(trimmedClientSecret)

        isSaving = false
        saveMessage = "Credentials saved successfully"
        saveMessageIsError = false

        // Clear message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.saveMessage = nil
        }
    }

    /// Checks if credentials are already configured
    func hasStoredCredentials() -> Bool {
        return credentialsStorage.getClientID() != nil &&
               credentialsStorage.getClientSecret() != nil
    }

    /// Imports credentials from environment variables
    func importFromEnvironment() -> Bool {
        let envClientID = ProcessInfo.processInfo.environment["GITHUB_CLIENT_ID"] ?? ""
        let envClientSecret = ProcessInfo.processInfo.environment["GITHUB_CLIENT_SECRET"] ?? ""

        guard !envClientID.isEmpty, !envClientSecret.isEmpty else {
            return false
        }

        clientID = envClientID
        clientSecret = envClientSecret
        saveCredentials()
        return true
    }
}
