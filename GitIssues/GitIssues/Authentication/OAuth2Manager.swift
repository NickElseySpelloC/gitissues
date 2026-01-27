//
//  OAuth2Manager.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation
import AppKit
import AuthenticationServices
import Combine
import CryptoKit

enum OAuth2Error: LocalizedError {
    case invalidAuthorizationURL
    case missingAuthorizationCode
    case tokenExchangeFailed(String)
    case invalidResponse
    case deviceFlowFailed(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .invalidAuthorizationURL:
            return "Failed to create authorization URL"
        case .missingAuthorizationCode:
            return "Authorization code not found in callback"
        case .tokenExchangeFailed(let message):
            return "Token exchange failed: \(message)"
        case .invalidResponse:
            return "Invalid response from GitHub"
        case .deviceFlowFailed(let message):
            return "Device flow failed: \(message)"
        case .userCancelled:
            return "Authentication was cancelled"
        }
    }
}

@MainActor
class OAuth2Manager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var allowPrivateRepoAccess = false {
        didSet {
            if allowPrivateRepoAccess != oldValue {
                UserDefaults.standard.set(allowPrivateRepoAccess, forKey: "allowPrivateRepoAccess")
                // Re-authenticate with new scope if already authenticated
                if isAuthenticated {
                    Task {
                        try? await reauthenticate()
                    }
                }
            }
        }
    }

    private let tokenStorage: TokenStorage

    // Hardcoded Spello Consulting OAuth App
    private let clientID = "Ov23liaOKnz48P3xVdlv"

    // GitHub OAuth endpoints
    private let authorizationURL = "https://github.com/login/oauth/authorize"
    private let tokenURL = "https://github.com/login/oauth/access_token"
    private let deviceCodeURL = "https://github.com/login/device/code"
    private let redirectURI = "spelloconsulting-gitissues://oauth-callback"

    // PKCE state
    private var codeVerifier: String?
    private var authState: String?

    // ASWebAuthenticationSession
    private var webAuthSession: ASWebAuthenticationSession?

    // Device Flow alert
    private var deviceFlowAlert: NSAlert?
    private var deviceFlowAlertWindow: NSWindow?

    init(tokenStorage: TokenStorage? = nil) {
        self.tokenStorage = tokenStorage ?? TokenStorage()

        // Load private repo preference
        self.allowPrivateRepoAccess = UserDefaults.standard.bool(forKey: "allowPrivateRepoAccess")

        // Check if we already have a token
        self.isAuthenticated = self.tokenStorage.getAccessToken() != nil

        super.init()
    }

    /// Current scope based on private repo access setting
    private var currentScope: String {
        return allowPrivateRepoAccess ? "repo user" : "public_repo user"
    }

    /// Initiates the OAuth authorization flow with PKCE
    func startAuthorization() async throws {
        isAuthenticating = true

        do {
            // Try ASWebAuthenticationSession first
            try await startWebAuthenticationSession()
        } catch {
            // Fall back to Device Flow - don't rethrow, handle silently
            print("ASWebAuthenticationSession failed, falling back to Device Flow: \(error.localizedDescription)")
            do {
                try await startDeviceFlow()
            } catch {
                // Only throw Device Flow errors
                isAuthenticating = false
                throw error
            }
        }
    }

    /// Starts authentication using ASWebAuthenticationSession with PKCE
    private func startWebAuthenticationSession() async throws {
        // Generate PKCE values
        codeVerifier = generateCodeVerifier()
        guard let codeVerifier = codeVerifier else {
            throw OAuth2Error.invalidAuthorizationURL
        }
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        print("PKCE Generated:")
        print("  Code Verifier: \(codeVerifier)")
        print("  Code Challenge: \(codeChallenge)")

        // Generate random state for CSRF protection
        authState = UUID().uuidString

        // Build authorization URL
        var components = URLComponents(string: authorizationURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: currentScope),
            URLQueryItem(name: "state", value: authState),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let url = components?.url else {
            throw OAuth2Error.invalidAuthorizationURL
        }

        // Create and start web authentication session
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "spelloconsulting-gitissues"
            ) { [weak self] callbackURL, error in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    if let error = error {
                        let nsError = error as NSError
                        if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                           nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                            continuation.resume(throwing: OAuth2Error.userCancelled)
                        } else {
                            continuation.resume(throwing: error)
                        }
                        self.isAuthenticating = false
                        return
                    }

                    guard let callbackURL = callbackURL else {
                        continuation.resume(throwing: OAuth2Error.invalidResponse)
                        self.isAuthenticating = false
                        return
                    }

                    do {
                        try await self.handleCallback(url: callbackURL)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            self.webAuthSession = session

            if !session.start() {
                continuation.resume(throwing: OAuth2Error.invalidAuthorizationURL)
                self.isAuthenticating = false
            }
        }
    }

    /// Starts Device Flow authentication as fallback
    private func startDeviceFlow() async throws {
        // Request device code
        var request = URLRequest(url: URL(string: deviceCodeURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Create form-encoded body (OAuth standard)
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "scope", value: currentScope)
        ]

        request.httpBody = components.query?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OAuth2Error.deviceFlowFailed("Failed to get device code")
        }

        // Parse device code response
        struct DeviceCodeResponse: Codable {
            let deviceCode: String
            let userCode: String
            let verificationUri: String
            let expiresIn: Int
            let interval: Int

            enum CodingKeys: String, CodingKey {
                case deviceCode = "device_code"
                case userCode = "user_code"
                case verificationUri = "verification_uri"
                case expiresIn = "expires_in"
                case interval
            }
        }

        let deviceCodeResponse = try JSONDecoder().decode(DeviceCodeResponse.self, from: data)

        // Show user code to user and start polling
        await showDeviceCodeAlert(
            userCode: deviceCodeResponse.userCode,
            verificationUri: deviceCodeResponse.verificationUri
        )

        do {
            // Poll for token
            try await pollForDeviceToken(
                deviceCode: deviceCodeResponse.deviceCode,
                interval: deviceCodeResponse.interval
            )
            // Close alert on success
            await closeDeviceFlowAlert()
        } catch {
            // Close alert on error
            await closeDeviceFlowAlert()
            isAuthenticating = false
            throw error
        }
    }

    /// Closes the device flow alert
    private func closeDeviceFlowAlert() async {
        await MainActor.run {
            if let window = deviceFlowAlertWindow, let sheet = window.attachedSheet {
                window.endSheet(sheet)
            }
            deviceFlowAlert = nil
            deviceFlowAlertWindow = nil
        }
    }

    /// Shows an alert with the device code for user to enter
    private func showDeviceCodeAlert(userCode: String, verificationUri: String) async {
        await MainActor.run {
            // Open browser immediately
            if let url = URL(string: verificationUri) {
                NSWorkspace.shared.open(url)
            }

            // Create alert
            let alert = NSAlert()
            alert.messageText = "Device Authentication"
            alert.informativeText = """
            Browser opened. Please enter this code in GitHub:

            \(userCode)

            Waiting for authorization...
            This window will close automatically once you authorize.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Cancel")

            // Store alert reference
            deviceFlowAlert = alert

            // Use beginSheetModal for non-blocking presentation
            if let window = NSApp.windows.first {
                deviceFlowAlertWindow = window
                alert.beginSheetModal(for: window) { [weak self] response in
                    if response == .alertFirstButtonReturn {
                        // User cancelled
                        Task { @MainActor in
                            self?.deviceFlowAlert = nil
                            self?.deviceFlowAlertWindow = nil
                            self?.isAuthenticating = false
                        }
                    }
                }
            } else {
                // If no window available, show as app-modal (still shouldn't block polling)
                Task.detached {
                    await MainActor.run {
                        _ = alert.runModal()
                    }
                }
            }
        }
    }

    /// Polls GitHub for device token
    private func pollForDeviceToken(deviceCode: String, interval: Int) async throws {
        let maxAttempts = 60 // 10 minutes with 10 second intervals
        var attempts = 0

        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)

            var request = URLRequest(url: URL(string: tokenURL)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            // Create form-encoded body (OAuth standard)
            var components = URLComponents()
            components.queryItems = [
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "device_code", value: deviceCode),
                URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:device_code")
            ]

            request.httpBody = components.query?.data(using: .utf8)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OAuth2Error.deviceFlowFailed("Invalid response")
            }

            // Log response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Device Flow poll response (\(httpResponse.statusCode)): \(responseString)")
            }

            if (200...299).contains(httpResponse.statusCode) {
                // Success - parse token
                struct TokenResponse: Codable {
                    let accessToken: String
                    let tokenType: String
                    let scope: String?

                    enum CodingKeys: String, CodingKey {
                        case accessToken = "access_token"
                        case tokenType = "token_type"
                        case scope
                    }
                }

                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                print("Device Flow: Successfully received access token")
                tokenStorage.saveAccessToken(tokenResponse.accessToken)
                isAuthenticated = true
                isAuthenticating = false
                return
            } else {
                // Check error response
                struct ErrorResponse: Codable {
                    let error: String
                }

                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    if errorResponse.error == "authorization_pending" {
                        // Continue polling (don't log to avoid spam)
                        attempts += 1
                        continue
                    } else if errorResponse.error == "slow_down" {
                        // Increase interval and continue
                        print("Device Flow: Slow down requested")
                        try await Task.sleep(nanoseconds: UInt64(interval + 5) * 1_000_000_000)
                        attempts += 1
                        continue
                    } else {
                        print("Device Flow error: \(errorResponse.error)")
                        throw OAuth2Error.deviceFlowFailed(errorResponse.error)
                    }
                }
            }

            attempts += 1
        }

        throw OAuth2Error.deviceFlowFailed("Timeout waiting for authorization")
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

        // Exchange code for access token using PKCE
        try await exchangeCodeForToken(code: code)
    }

    /// Exchanges authorization code for access token using PKCE
    private func exchangeCodeForToken(code: String) async throws {
        guard let codeVerifier = codeVerifier else {
            throw OAuth2Error.invalidResponse
        }

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Create form-encoded body (OAuth standard)
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_verifier", value: codeVerifier),
            URLQueryItem(name: "grant_type", value: "authorization_code")
        ]

        let bodyString = components.query ?? ""
        print("PKCE Token Exchange Request Body: \(bodyString)")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuth2Error.tokenExchangeFailed("Invalid response")
        }

        // Log response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("Token exchange response (\(httpResponse.statusCode)): \(responseString)")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorDict["error_description"] as? String ?? errorDict["error"] as? String {
                throw OAuth2Error.tokenExchangeFailed(errorMessage)
            }
            throw OAuth2Error.tokenExchangeFailed("HTTP \(httpResponse.statusCode)")
        }

        // Parse token response
        struct TokenResponse: Codable {
            let accessToken: String
            let tokenType: String
            let scope: String?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case tokenType = "token_type"
                case scope
            }
        }

        do {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

            // Store token securely
            tokenStorage.saveAccessToken(tokenResponse.accessToken)
            isAuthenticated = true
        } catch {
            print("Token decode error: \(error)")
            throw OAuth2Error.tokenExchangeFailed("Failed to parse token response: \(error.localizedDescription)")
        }
    }

    /// Re-authenticates with the current scope setting
    private func reauthenticate() async throws {
        // Sign out first to clear old token
        signOut()

        // Start new authorization with updated scope
        try await startAuthorization()
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

    // MARK: - PKCE Helper Methods

    /// Generates a code verifier for PKCE
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Generates a code challenge from the code verifier
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else {
            return ""
        }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuth2Manager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}
