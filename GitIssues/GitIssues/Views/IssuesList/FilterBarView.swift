//
//  FilterBarView.swift
//  GitIssues
//
//  Created by Claude Code
//

import SwiftUI

struct FilterBarView: View {
    @ObservedObject var viewModel: IssuesListViewModel
    @State private var showRepositorySelector = false

    var body: some View {
        VStack(spacing: 12) {
            // State filter (Open/Closed/All)
            HStack(spacing: 8) {
                Text("State:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("State", selection: Binding(
                    get: { viewModel.filterOptions.stateFilter },
                    set: { viewModel.setStateFilter($0) }
                )) {
                    ForEach(IssueStateFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                Spacer()
            }

            // Visibility and Sort row
            HStack(spacing: 16) {
                // Visibility filter
                HStack(spacing: 8) {
                    Text("Visibility:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Visibility", selection: Binding(
                        get: { viewModel.filterOptions.visibilityFilter },
                        set: { viewModel.setVisibilityFilter($0) }
                    )) {
                        ForEach(VisibilityFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                Spacer()

                // Sort picker
                HStack(spacing: 8) {
                    Text("Sort:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Menu {
                        Button("Updated (Newest)") {
                            viewModel.setSortOption(.updatedDesc)
                        }
                        Button("Updated (Oldest)") {
                            viewModel.setSortOption(.updatedAsc)
                        }
                        Divider()
                        Button("Created (Newest)") {
                            viewModel.setSortOption(.createdDesc)
                        }
                        Button("Created (Oldest)") {
                            viewModel.setSortOption(.createdAsc)
                        }
                        Divider()
                        Button("Issue # (High to Low)") {
                            viewModel.setSortOption(.numberDesc)
                        }
                        Button("Issue # (Low to High)") {
                            viewModel.setSortOption(.numberAsc)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.filterOptions.sortOption.displayName)
                                .font(.caption)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                    }
                }
            }

            // Repository filter (if multiple repos)
            if viewModel.availableRepositories.count > 1 {
                HStack(spacing: 8) {
                    Text("Repositories:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button {
                        showRepositorySelector = true
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.filterOptions.selectedRepositories.isEmpty {
                                Text("All (\(viewModel.availableRepositories.count))")
                                    .font(.caption)
                            } else {
                                Text("\(viewModel.filterOptions.selectedRepositories.count) selected")
                                    .font(.caption)
                            }
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    if !viewModel.filterOptions.selectedRepositories.isEmpty {
                        Button {
                            viewModel.clearRepositoryFilter()
                        } label: {
                            Text("Clear")
                                .font(.caption2)
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showRepositorySelector) {
            RepositorySelectorSheet(viewModel: viewModel)
        }
    }
}

