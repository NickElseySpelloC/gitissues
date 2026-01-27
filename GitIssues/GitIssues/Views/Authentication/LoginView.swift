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
                        Text("Connect to GitHub")
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
                    ProgressView("Waiting for GitHub authorization…")
                        .padding()
                }

                Text("A code will be shown here. Enter it on the GitHub page that opens in your browser.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Show the Device Flow prompt whenever OAuth2Manager publishes it.
        .sheet(isPresented: $authManager.isShowingDeviceFlowPrompt) {
            DeviceFlowPromptView(authManager: authManager)
        }
        // Surface any auth errors from OAuth2Manager.
        .onChange(of: authManager.lastAuthErrorMessage) { _, newValue in
            guard let msg = newValue, !msg.isEmpty else { return }
            errorMessage = msg
            showError = true
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func signIn() {
        authManager.signIn()
    }
}

#Preview {
    LoginView(authManager: OAuth2Manager())
}
