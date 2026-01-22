//
//  SettingsView.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        TabView {
            // GitHub Authorization tab
            GitHubAuthView(viewModel: viewModel)
                .tabItem {
                    SwiftUI.Label("GitHub Authorisation", systemImage: "key.fill")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GitHubAuthView: View {
    @ObservedObject var viewModel: SettingsViewModel

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
