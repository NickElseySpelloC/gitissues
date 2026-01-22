//
//  OAuth2Manager.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation
import AppKit
import Combine

enum OAuth2Error: LocalizedError {
    case missingClientCredentials
    case invalidAuthorizationURL
    case missingAuthorizationCode
    case tokenExchangeFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingClientCredentials:
            return "GitHub OAuth client ID or secret not configured"
        case .invalidAuthorizationURL:
            return "Failed to create authorization URL"
        case .missingAuthorizationCode:
            return "Authorization code not found in callback"
        case .tokenExchangeFailed(let message):
            return "Token exchange failed: \(message)"
        case .invalidResponse:
            return "Invalid response from GitHub"
        }
    }
}

@MainActor
class OAuth2Manager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false

    private let tokenStorage: TokenStorage
    private let credentialsStorage: CredentialsStorage
    private var clientID: String
    private var clientSecret: String

    // GitHub OAuth endpoints
    private let authorizationURL = "https://github.com/login/oauth/authorize"
    private let tokenURL = "https://github.com/login/oauth/access_token"
    private let redirectURI = "gitissues://oauth-callback"
    private let scope = "repo user"

    // State for CSRF protection
    private var authState: String?

    init(tokenStorage: TokenStorage? = nil, credentialsStorage: CredentialsStorage? = nil) {
        self.tokenStorage = tokenStorage ?? TokenStorage()
        self.credentialsStorage = credentialsStorage ?? CredentialsStorage()

        // Load credentials from Keychain first, then fall back to environment variables
        if let storedClientID = self.credentialsStorage.getClientID(),
           let storedClientSecret = self.credentialsStorage.getClientSecret() {
            self.clientID = storedClientID
            self.clientSecret = storedClientSecret
        } else {
            // Fall back to environment variables
            self.clientID = ProcessInfo.processInfo.environment["GITHUB_CLIENT_ID"] ?? ""
            self.clientSecret = ProcessInfo.processInfo.environment["GITHUB_CLIENT_SECRET"] ?? ""
        }

        // Check if we already have a token
        self.isAuthenticated = self.tokenStorage.getAccessToken() != nil
    }

    /// Reloads credentials from storage (called after settings are updated)
    func reloadCredentials() {
        if let storedClientID = credentialsStorage.getClientID(),
           let storedClientSecret = credentialsStorage.getClientSecret() {
            self.clientID = storedClientID
            self.clientSecret = storedClientSecret
        } else {
            // Fall back to environment variables
            self.clientID = ProcessInfo.processInfo.environment["GITHUB_CLIENT_ID"] ?? ""
            self.clientSecret = ProcessInfo.processInfo.environment["GITHUB_CLIENT_SECRET"] ?? ""
        }
    }

    /// Initiates the OAuth authorization flow
    func startAuthorization() throws {
        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            throw OAuth2Error.missingClientCredentials
        }

        // Generate random state for CSRF protection
        authState = UUID().uuidString

        // Build authorization URL
        var components = URLComponents(string: authorizationURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: authState)
        ]

        guard let url = components?.url else {
            throw OAuth2Error.invalidAuthorizationURL
        }

        isAuthenticating = true

        // Open authorization URL in default browser
        NSWorkspace.shared.open(url)
    }

    /// Handles the OAuth callback URL
    func handleCallback(url: URL) async throws {
        defer { isAuthenticating = false }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw OAuth2Error.invalidResponse
        }

        // Extract code and state from callback
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw OAuth2Error.missingAuthorizationCode
        }

        // Verify state matches (CSRF protection)
        let returnedState = queryItems.first(where: { $0.name == "state" })?.value
        guard returnedState == authState else {
            throw OAuth2Error.invalidResponse
        }

        // Exchange code for access token
        try await exchangeCodeForToken(code: code)
    }

    /// Exchanges authorization code for access token
    private func exchangeCodeForToken(code: String) async throws {
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "redirect_uri": redirectURI
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OAuth2Error.tokenExchangeFailed("HTTP error")
        }

        // Parse token response
        struct TokenResponse: Codable {
            let accessToken: String
            let tokenType: String
            let scope: String

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case tokenType = "token_type"
                case scope
            }
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Store token securely
        tokenStorage.saveAccessToken(tokenResponse.accessToken)
        isAuthenticated = true
    }

    /// Signs out the user
    func signOut() {
        tokenStorage.deleteAccessToken()
        isAuthenticated = false
    }

    /// Gets the current access token
    func getAccessToken() -> String? {
        return tokenStorage.getAccessToken()
    }
}
