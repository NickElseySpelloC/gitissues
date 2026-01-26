//
//  SettingsView.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: OAuth2Manager
    @StateObject private var appearanceService = AppearanceService.shared
    @StateObject private var viewModel: SettingsViewModel

    init() {
        // Note: authManager will be injected via @EnvironmentObject, but we need to
        // defer creating the viewModel until after the view is rendered with environment
        _viewModel = StateObject(wrappedValue: SettingsViewModel())
    }

    var body: some View {
        TabView {
            // General tab
            GeneralSettingsView(appearanceService: appearanceService)
                .tabItem {
                    SwiftUI.Label("General", systemImage: "gearshape.fill")
                }

            // GitHub Authorization tab
            GitHubAuthView(viewModel: viewModel, authManager: authManager)
                .tabItem {
                    SwiftUI.Label("GitHub Authorisation", systemImage: "key.fill")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var appearanceService: AppearanceService

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Appearance")
                        .font(.headline)
                    Picker("Display Mode", selection: $appearanceService.currentMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    Text("Choose how GitIssues should appear")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .formStyle(.grouped)
    }
}

struct GitHubAuthView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var authManager: OAuth2Manager

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 16) {
                // Client ID field
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Enter GitHub OAuth Client ID", text: $viewModel.clientID)
                        .textFieldStyle(.roundedBorder)
                    Text("Your GitHub OAuth application's Client ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Client Secret field
                VStack(alignment: .leading, spacing: 6) {
                    SecureField("Enter GitHub OAuth Client Secret", text: $viewModel.clientSecret)
                        .textFieldStyle(.roundedBorder)
                    Text("Your GitHub OAuth application's Client Secret (stored securely in Keychain)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Save button and message
                HStack {
                    Button("Save Credentials") {
                        viewModel.saveCredentials()
                        // Reload credentials in OAuth2Manager so they're available immediately
                        authManager.reloadCredentials()
                    }
                    .disabled(viewModel.isSaving)

                    if let message = viewModel.saveMessage {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.saveMessageIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(viewModel.saveMessageIsError ? .orange : .green)
                            Text(message)
                                .font(.caption)
                                .foregroundColor(viewModel.saveMessageIsError ? .orange : .green)
                        }
                    }
                }

                Divider()

                // Help text
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to get OAuth credentials:")
                        .font(.headline)
                    Text("1. Go to GitHub Settings → Developer settings → OAuth Apps")
                        .font(.caption)
                    Text("2. Create a new OAuth App or use an existing one")
                        .font(.caption)
                    Text("3. Set Authorization callback URL to: gitissues://oauth-callback")
                        .font(.caption)
                    Text("4. Copy the Client ID and Client Secret here")
                        .font(.caption)
                }
            }
            .padding()
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
}
