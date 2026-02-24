import SwiftUI
import AuthenticationServices

struct DeviceFlowPromptView: View {
    @ObservedObject var authManager: OAuth2Manager
    @Environment(\.dismiss) private var dismiss
    
    @State private var authSession: ASWebAuthenticationSession?
    @State private var contextProvider: WindowContextProvider = WindowContextProvider()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("GitHub Device Authorization")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
            }

            Text("To sign in, enter this code on the GitHub page in your browser:")
                .foregroundColor(.secondary)

            Text("You can close this window once authorized.")
                .font(.caption)
                .foregroundColor(.secondary)

            codeBlock

            HStack(spacing: 12) {
                Button("Copy Code") {
                    copyToClipboard(authManager.deviceFlowUserCode ?? "")
                }
                .disabled((authManager.deviceFlowUserCode ?? "").isEmpty)

                Button("Open GitHub Page") {
                    if let url = authManager.deviceFlowVerificationURL {
                        open(url)
                    } else {
                        open(URL(string: "https://github.com/login/device")!)
                    }
                }

                Spacer()

                Button("Cancel Sign-In", role: .destructive) {
                    authManager.signOut()
                    dismiss()
                }
            }

            if authManager.isAuthenticating {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Waiting for authorization…")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }

            if let err = authManager.lastAuthErrorMessage, !err.isEmpty {
                Text(err)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 520, height: 280)
        .onChange(of: authManager.isShowingDeviceFlowPrompt) { _, showing in
            // Auto-dismiss when OAuth completes.
            if !showing {
                dismiss()
            }
        }
    }

    private var codeBlock: some View {
        let code = authManager.deviceFlowUserCode ?? "—"
        return Text(code)
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 14)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(12)
            .textSelection(.enabled)
            .accessibilityLabel("Device code")
    }

    private func copyToClipboard(_ s: String) {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
        #endif
    }

    private func open(_ url: URL) {
        // Use ASWebAuthenticationSession for App Store compliance
        let callbackScheme = "gitissues"
        
        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackScheme
        ) { callbackURL, error in
            // Device flow doesn't use callbacks - polling handles completion
            if let error = error as? ASWebAuthenticationSessionError {
                if error.code != .canceledLogin {
                    print("Authentication session error: \(error.localizedDescription)")
                }
            }
        }
        
        #if os(macOS)
        authSession?.presentationContextProvider = contextProvider
        authSession?.prefersEphemeralWebBrowserSession = false
        #endif
        
        if !authSession!.start() {
            print("Failed to start ASWebAuthenticationSession from DeviceFlowPromptView")
        }
    }
}

#if os(macOS)
// Helper class to provide presentation context for ASWebAuthenticationSession
class WindowContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first { $0.isKeyWindow } ?? NSApplication.shared.windows.first!
    }
}
#endif

#Preview {
    DeviceFlowPromptView(authManager: OAuth2Manager())
}
