//
//  GitIssuesApp.swift
//  GitIssues
//
//  Created by Nick Elsey on 21/1/2026.
//

import SwiftUI

@main
struct GitIssuesApp: App {
    @StateObject private var authManager = OAuth2Manager()
    @State private var showEnvironmentCredentialsAlert = false
    @State private var showMissingCredentialsAlert = false

    init() {
        // Initialize appearance service to apply saved theme
        _ = AppearanceService.shared

        // Check if environment variables exist but credentials are not saved
        let credentialsStorage = CredentialsStorage()
        let hasStoredCredentials = credentialsStorage.getClientID() != nil &&
                                   credentialsStorage.getClientSecret() != nil

        let hasEnvCredentials = ProcessInfo.processInfo.environment["GITHUB_CLIENT_ID"] != nil &&
                               ProcessInfo.processInfo.environment["GITHUB_CLIENT_SECRET"] != nil

        if hasEnvCredentials && !hasStoredCredentials {
            _showEnvironmentCredentialsAlert = State(initialValue: true)
        } else if !hasStoredCredentials && !hasEnvCredentials {
            // No credentials at all - show warning
            _showMissingCredentialsAlert = State(initialValue: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            MainAppView(
                authManager: authManager,
                showEnvironmentCredentialsAlert: $showEnvironmentCredentialsAlert,
                showMissingCredentialsAlert: $showMissingCredentialsAlert
            )
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        // Settings window
        Settings {
            SettingsView()
                .environmentObject(authManager)
        }

        // Issue Form Window
        WindowGroup(id: WindowIdentifier.issueForm.rawValue, for: IssueFormWindowData.self) { $windowData in
            if let data = windowData {
                IssueFormWindow(windowData: data)
                    .environmentObject(authManager)
            }
        }

        // Comment Form Window
        WindowGroup(id: WindowIdentifier.commentForm.rawValue, for: CommentFormWindowData.self) { $windowData in
            if let data = windowData {
                CommentFormWindow(windowData: data)
                    .environmentObject(authManager)
            }
        }
    }

}

// MARK: - Main App View
struct MainAppView: View {
    @ObservedObject var authManager: OAuth2Manager
    @Binding var showEnvironmentCredentialsAlert: Bool
    @Binding var showMissingCredentialsAlert: Bool
    @Environment(\.openSettings) private var openSettingsAction

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ContentView()
            } else {
                LoginView(authManager: authManager)
            }
        }
        .environmentObject(authManager)
        .onOpenURL { url in
            // Handle OAuth callback URL
            if url.scheme == "gitissues" {
                Task {
                    do {
                        try await authManager.handleCallback(url: url)
                    } catch {
                        print("OAuth callback error: \(error.localizedDescription)")
                    }
                }
            }
        }
        .alert("Environment Variables Detected", isPresented: $showEnvironmentCredentialsAlert) {
            Button("Open Settings") {
                handleOpenSettings()
            }
            Button("Dismiss", role: .cancel) { }
        } message: {
            Text("GitHub OAuth credentials were found in environment variables. Would you like to save them to the app's secure storage?")
        }
        .alert("OAuth Credentials Required", isPresented: $showMissingCredentialsAlert) {
            Button("Open Settings") {
                handleOpenSettings()
            }
            Button("Dismiss", role: .cancel) { }
        } message: {
            Text("GitHub OAuth Client ID and Secret are missing. Please configure them in Settings to use GitIssues.")
        }
    }

    private func handleOpenSettings() {
        if #available(macOS 14.0, *) {
            openSettingsAction()
        } else {
            // Fallback for older macOS versions
            NSApp.sendAction(Selector("showPreferencesWindow:"), to: nil, from: nil)
        }
    }
}
