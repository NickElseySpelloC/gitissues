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

    init() {
        // Initialize appearance service to apply saved theme
        _ = AppearanceService.shared
    }

    var body: some Scene {
        WindowGroup {
            MainAppView(authManager: authManager)
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
            if url.scheme == "spelloconsulting-gitissues" {
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
}
