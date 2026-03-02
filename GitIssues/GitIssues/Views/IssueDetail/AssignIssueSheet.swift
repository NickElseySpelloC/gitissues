//
//  AssignIssueSheet.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI

struct AssignIssueSheet: View {
    let issue: Issue
    let apiService: GitHubAPIService
    let onSave: ([User]) -> Void
    let onCancel: () -> Void

    @State private var collaborators: [User] = []
    @State private var selectedIds: Set<String> = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    var filteredCollaborators: [User] {
        if searchText.isEmpty {
            return collaborators
        }
        return collaborators.filter { $0.login.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Assign Issue")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Assign") {
                    let selectedUsers = collaborators.filter { selectedIds.contains($0.id) }
                    onSave(selectedUsers)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }
            .padding()

            Divider()

            if isLoading {
                ProgressView("Loading collaborators...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Unable to load collaborators")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search collaborators...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .padding(.horizontal)
                .padding(.top, 8)

                if filteredCollaborators.isEmpty {
                    Text("No collaborators found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredCollaborators) { user in
                        HStack {
                            Image(systemName: selectedIds.contains(user.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedIds.contains(user.id) ? .accentColor : .secondary)
                            Text(user.login)
                                .font(.body)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedIds.contains(user.id) {
                                selectedIds.remove(user.id)
                            } else {
                                selectedIds.insert(user.id)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .frame(width: 320, height: 400)
        .task {
            await loadCollaborators()
        }
    }

    private func loadCollaborators() async {
        isLoading = true
        errorMessage = nil
        do {
            let users = try await apiService.fetchAllCollaborators(
                owner: issue.repository.owner.login,
                repo: issue.repository.name
            )
            collaborators = users.sorted {
                $0.login.localizedCaseInsensitiveCompare($1.login) == .orderedAscending
            }
            selectedIds = Set(issue.assignees.map { $0.id })
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
