//
//  ContentView.swift
//  GitIssues
//
//  Created by Nick Elsey on 21/1/2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: OAuth2Manager
    @State private var issues: [Issue] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationSplitView {
            // Sidebar with issues list
            Group {
                if isLoading {
                    ProgressView("Loading issues...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Error Loading Issues")
                            .font(.headline)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            Task {
                                await loadIssues()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if issues.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("No Issues")
                            .font(.headline)
                        Text("You don't have any issues assigned to you.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(issues) { issue in
                        IssueRow(issue: issue)
                    }
                    .listStyle(.sidebar)
                }
            }
            .navigationTitle("Issues (\(issues.count))")
            .toolbar(content: {
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        Task { await loadIssues() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    .help("Refresh issues")

                    Button {
                        authManager.signOut()
                    } label: {
                        Text("Sign Out")
                    }
                }
            })
        } detail: {
            // Detail view (placeholder for now)
            Text("Select an issue to view details")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await loadIssues()
        }
    }

    private func loadIssues() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let accessToken = authManager.getAccessToken() else {
                errorMessage = "No access token available"
                isLoading = false
                return
            }

            let apiService = GitHubAPIService(accessToken: accessToken)
            let fetchedIssues = try await apiService.fetchAllIssues(states: [.open])

            await MainActor.run {
                self.issues = fetchedIssues
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct IssueRow: View {
    let issue: Issue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: issue.state == .open ? "circle" : "checkmark.circle.fill")
                    .foregroundColor(issue.state == .open ? .green : .purple)

                Text(issue.title)
                    .font(.headline)
                    .lineLimit(2)

                Spacer()

                Text("#\(issue.number)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 4) {
                Text(issue.repository.fullName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(issue.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !issue.labels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(issue.labels) { label in
                            LabelBadge(label: label)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct LabelBadge: View {
    let label: Label

    var body: some View {
        Text(label.name)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: label.color).opacity(0.2))
            .foregroundColor(Color(hex: label.color))
            .cornerRadius(4)
    }
}

// Helper extension to convert hex color strings to SwiftUI Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (128, 128, 128) // Default gray
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(OAuth2Manager())
}
