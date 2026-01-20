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
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
