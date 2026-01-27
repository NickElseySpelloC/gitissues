//
//  LoginView.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authManager: OAuth2Manager
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // App icon and title
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.badge.questionmark.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)

                Text("GitIssues")
                    .font(.system(size: 36, weight: .bold))

                Text("Manage GitHub issues across all your repositories")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            // Sign in button
            VStack(spacing: 16) {
                Button(action: signIn) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                        Text("Sign in with GitHub")
                            .font(.headline)
                    }
                    .frame(maxWidth: 300)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(authManager.isAuthenticating)

                if authManager.isAuthenticating {
                    ProgressView("Authenticating...")
                        .padding()
                }

                Text("You'll be redirected to GitHub to authorize this app")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func signIn() {
        Task {
            do {
                try await authManager.startAuthorization()
            } catch {
                // Only show errors if authentication is no longer in progress
                // (Device Flow might still be running)
                if !authManager.isAuthenticating {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    LoginView(authManager: OAuth2Manager())
}
