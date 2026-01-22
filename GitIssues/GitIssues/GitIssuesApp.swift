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

    init() {
        // Check if environment variables exist but credentials are not saved
        let credentialsStorage = CredentialsStorage()
        let hasStoredCredentials = credentialsStorage.getClientID() != nil &&
                                   credentialsStorage.getClientSecret() != nil

        let hasEnvCredentials = ProcessInfo.processInfo.environment["GITHUB_CLIENT_ID"] != nil &&
                               ProcessInfo.processInfo.environment["GITHUB_CLIENT_SECRET"] != nil

        if hasEnvCredentials && !hasStoredCredentials {
            _showEnvironmentCredentialsAlert = State(initialValue: true)
        }
    }

    var body: some Scene {
        WindowGroup {
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
                    openSettings()
                }
                Button("Dismiss", role: .cancel) { }
            } message: {
                Text("GitHub OAuth credentials were found in environment variables. Would you like to save them to the app's secure storage?")
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        // Settings window
        Settings {
            SettingsView()
        }
    }

    @MainActor
    private func openSettings() {
        // Open settings window after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}
