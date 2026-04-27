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
            .frame(width: 500, height: 450)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var appearanceService: AppearanceService
    @ObservedObject var authManager: OAuth2Manager

    @AppStorage(AppStateService.syncEnabledKey) private var syncEnabled = true
    @AppStorage(AppStateService.syncIntervalSecondsKey) private var syncIntervalSeconds = 30

    private static let intervalOptions = [10, 15, 30, 60, 120, 300]

    private static func intervalLabel(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) seconds" }
        let minutes = seconds / 60
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

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

                // Background Sync Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("Background Sync")
                        .font(.headline)

                    Toggle("Automatically sync issues with GitHub", isOn: $syncEnabled)

                    if syncEnabled {
                        Picker("Sync every", selection: $syncIntervalSeconds) {
                            ForEach(Self.intervalOptions, id: \.self) { interval in
                                Text(Self.intervalLabel(interval)).tag(interval)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 250)
                    }

                    Text("When enabled, issues are refreshed in the background at the chosen interval.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
                            authManager.reauthorizeForScopeChange()
                        }
                        .padding(.top, 6)

                        Text("If you previously granted private repository access, use this to re-authorize GitIssues with reduced permissions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
