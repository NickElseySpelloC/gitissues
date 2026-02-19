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
        WindowGroup(id: "main") {
            MainAppView(authManager: authManager)
        }
        .commands {
            // Keep the New Item command empty since we don't need File > New
            CommandGroup(replacing: .newItem) { }

            // Add custom commands
            MainWindowCommands()
        }
        .defaultPosition(.center)
        .defaultSize(width: 1200, height: 800)

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
    }
}

// MARK: - Window Commands
struct MainWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .windowList) {
            Button("GitIssues") {
                openWindow(id: "main")
            }
            .keyboardShortcut("0", modifiers: [.command])
        }
    }
}
