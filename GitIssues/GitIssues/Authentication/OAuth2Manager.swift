import Foundation
import Combine
import SwiftUI
#if os(macOS)
import AppKit
#endif

@MainActor
final class OAuth2Manager: ObservableObject {

    // MARK: - Published state
    @Published var isAuthenticated: Bool = false
    @Published var isAuthenticating: Bool = false

    /// Used by UI to present the GitHub Device Flow prompt.
    @Published var deviceFlowUserCode: String? = nil
    @Published var deviceFlowVerificationURL: URL? = nil
    @Published var isShowingDeviceFlowPrompt: Bool = false

    /// Optional UI-friendly error message.
    @Published var lastAuthErrorMessage: String? = nil

    // MARK: - OAuth config (Spello Consulting OAuth App)
    private let clientID = "Ov23liaOKnz48P3xVdlv"
    private let tokenURL = "https://github.com/login/oauth/access_token"
    private let deviceCodeURL = "https://github.com/login/device/code"

    // MARK: - Scope selection (matches your Settings toggle)
    @AppStorage("allowPrivateRepoAccess") var allowPrivateRepoAccess: Bool = false
    
    init() {
        if tokenStorage.loadAccessToken() != nil {
            isAuthenticated = true
        }
    }

    private var currentScope: String {
        // Minimal default vs private repo access.
        // Keep `user` because your app appears to read user profile details.
        allowPrivateRepoAccess ? "repo user" : "public_repo user"
    }

    // MARK: - Storage
    private let tokenStorage = TokenStorage()

    // MARK: - Errors
    enum OAuth2Error: Error, LocalizedError {
        case deviceFlowFailed(String)

        var errorDescription: String? {
            switch self {
            case .deviceFlowFailed(let msg):
                return msg
            }
        }
    }

    // MARK: - Public API

    /// Primary sign-in: GitHub Device Flow (no client secret required).
    func signIn() {
        lastAuthErrorMessage = nil
        isAuthenticated = false
        isAuthenticating = true
        startDeviceFlow()
    }

    /// Call this after the user changes the "Private repo access" toggle.
    /// GitHub tokens do not "upgrade" scopes; we must re-authorize to obtain a new token.
    func reauthorizeForScopeChange() {
        tokenStorage.clear()
        isAuthenticated = false
        signIn()
    }

    func signOut() {
        tokenStorage.clear()
        isAuthenticated = false
        isAuthenticating = false
        deviceFlowUserCode = nil
        deviceFlowVerificationURL = nil
        isShowingDeviceFlowPrompt = false
        lastAuthErrorMessage = nil
    }

    // MARK: - Device Flow

    private func startDeviceFlow() {
        Task {
            do {
                let response = try await requestDeviceCode(scope: currentScope)

                // Publish info for UI.
                deviceFlowUserCode = response.userCode
                deviceFlowVerificationURL = URL(string: response.verificationUri)
                isShowingDeviceFlowPrompt = true

                // Optionally open the verification URL automatically.
                if let url = deviceFlowVerificationURL {
                    openInBrowser(url)
                }

                try await pollForDeviceToken(
                    deviceCode: response.deviceCode,
                    interval: response.interval,
                    expiresIn: response.expiresIn
                )
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                lastAuthErrorMessage = msg
                isAuthenticating = false
                // keep the prompt visible so the user can retry/cancel as they wish
            }
        }
    }

    private func requestDeviceCode(scope: String) async throws -> GitHubDeviceCodeResponse {
        var request = URLRequest(url: URL(string: deviceCodeURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8",
                         forHTTPHeaderField: "Content-Type")

        request.httpBody = formURLEncoded([
            "client_id": clientID,
            "scope": scope
        ])

        let (data, _) = try await URLSession.shared.data(for: request)

        if let responseString = String(data: data, encoding: .utf8) {
            print("Device Flow start response: \(responseString)")
        }

        return try JSONDecoder().decode(GitHubDeviceCodeResponse.self, from: data)
    }

    private func pollForDeviceToken(deviceCode: String, interval: Int, expiresIn: Int) async throws {
        let deadline = Date().addingTimeInterval(TimeInterval(expiresIn))
        var pollInterval = max(1, interval)

        while Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)

            var request = URLRequest(url: URL(string: tokenURL)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded; charset=utf-8",
                             forHTTPHeaderField: "Content-Type")

            request.httpBody = formURLEncoded([
                "client_id": clientID,
                "device_code": deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
            ])

            let (data, _) = try await URLSession.shared.data(for: request)

            if let responseString = String(data: data, encoding: .utf8) {
                print("Device Flow poll response: \(responseString)")
            }

            let decoded = try JSONDecoder().decode(GitHubTokenResponse.self, from: data)

            if let token = decoded.accessToken, !token.isEmpty {
                tokenStorage.saveAccessToken(token)
                isAuthenticated = true
                isAuthenticating = false
                isShowingDeviceFlowPrompt = false
                return
            }

            if let err = decoded.error {
                switch err {
                case "authorization_pending":
                    continue
                case "slow_down":
                    pollInterval += 5
                    continue
                case "access_denied":
                    throw OAuth2Error.deviceFlowFailed("User denied authorization.")
                case "expired_token":
                    throw OAuth2Error.deviceFlowFailed("Device code expired. Please try again.")
                default:
                    throw OAuth2Error.deviceFlowFailed(decoded.errorDescription ?? err)
                }
            }
        }

        throw OAuth2Error.deviceFlowFailed("Timed out waiting for authorization.")
    }

    private func openInBrowser(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
    
    func getAccessToken() -> String? {
        tokenStorage.loadAccessToken()
    }

}

// MARK: - Models

private struct GitHubTokenResponse: Decodable {
    let accessToken: String?
    let tokenType: String?
    let scope: String?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case error
        case errorDescription = "error_description"
    }
}

private struct GitHubDeviceCodeResponse: Decodable {
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

// MARK: - Form encoding

private func formURLEncoded(_ params: [String: String]) -> Data {
    func esc(_ s: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    let body = params
        .map { "\(esc($0.key))=\(esc($0.value))" }
        .joined(separator: "&")
    return Data(body.utf8)
}
