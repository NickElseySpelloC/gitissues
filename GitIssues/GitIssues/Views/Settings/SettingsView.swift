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

    var body: some View {
        GeneralSettingsView(appearanceService: appearanceService, authManager: authManager)
            .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var appearanceService: AppearanceService
    @ObservedObject var authManager: OAuth2Manager

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 20) {
                // Appearance Section
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

                Divider()

                // GitHub Access Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("GitHub Access")
                        .font(.headline)

                    Toggle("Allow private repository access", isOn: $authManager.allowPrivateRepoAccess)
                        .onChange(of: authManager.allowPrivateRepoAccess) { _, newValue in
                            // If the user turns ON private access while signed in, we must re-auth to request the broader scope.
                            if authManager.isAuthenticated && newValue {
                                authManager.reauthorizeForScopeChange()
                            }
                        }

                    Text("When enabled, GitIssues will request access to your private repositories. You'll need to re-authenticate with GitHub.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if authManager.isAuthenticated && !authManager.allowPrivateRepoAccess {
                        Button("Reduce permissions (re-authenticate)") {
                            // Re-auth with the minimal scope (public_repo user).
                            authManager.reauthorizeForScopeChange()
                        }
                        .padding(.top, 6)

                        Text("If you previously granted private repository access, use this to re-authorize GitIssues with reduced permissions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

//                        .foregroundColor(.secondary)
//                        .fixedSize(horizontal: false, vertical: true)
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
