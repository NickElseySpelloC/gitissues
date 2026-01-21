//
//  RepositorySelectorSheet.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI

struct RepositorySelectorSheet: View {
    @ObservedObject var viewModel: IssuesListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var filteredRepositories: [Repository] {
        if searchText.isEmpty {
            return viewModel.availableRepositories
        }
        return viewModel.availableRepositories.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var selectedCount: Int {
        viewModel.filterOptions.selectedRepositories.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Filter by Repository")
                    .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter repositories", text: $searchText)
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

            // Selection summary and clear button
            if selectedCount > 0 {
                HStack {
                    Text("\(selectedCount) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Clear All") {
                        viewModel.clearRepositoryFilter()
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Divider()

            // Repository list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredRepositories) { repo in
                        RepositoryRow(
                            repository: repo,
                            isSelected: viewModel.filterOptions.selectedRepositories.contains(repo.id),
                            onToggle: {
                                viewModel.toggleRepository(repo.id)
                            }
                        )
                        Divider()
                    }
                }
            }

            Divider()

            // Done button
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .frame(width: 400, height: 500)
    }
}

struct RepositoryRow: View {
    let repository: Repository
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(repository.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Text(repository.owner.login)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if repository.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
