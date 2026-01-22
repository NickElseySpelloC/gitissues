//
//  ContentView.swift
//  GitIssues
//
//  Created by Nick Elsey on 21/1/2026.
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var authManager: OAuth2Manager
    @StateObject private var viewModel: IssuesListViewModelWrapper
    @State private var searchText = ""
    @State private var selectedIssue: Issue?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showCreateIssue = false
    @State private var issueToEdit: Issue?

    init() {
        _viewModel = StateObject(wrappedValue: IssuesListViewModelWrapper())
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                // Title and count
                HStack {
                    Text("Issues")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("(\(viewModel.viewModel?.filteredIssues.count ?? 0))")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search issues...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onChange(of: searchText) { _, newValue in
                            viewModel.viewModel?.setSearchText(newValue)
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            viewModel.viewModel?.setSearchText("")
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))

                // Filter bar
                if let vm = viewModel.viewModel {
                    FilterBarView(viewModel: vm)
                }

                Divider()

                // Issues list
                Group {
                    if let vm = viewModel.viewModel {
                        if vm.isLoading {
                            ProgressView("Loading issues...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let error = vm.errorMessage {
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
                                        await vm.loadIssues()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if vm.filteredIssues.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: searchText.isEmpty ? "checkmark.circle" : "magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundColor(.green)
                                Text(searchText.isEmpty ? "No Issues" : "No Results")
                                    .font(.headline)
                                Text(searchText.isEmpty
                                     ? "You don't have any issues matching the current filters."
                                     : "No issues match your search criteria.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List(vm.filteredIssues, selection: $selectedIssue) { issue in
                                IssueRow(
                                    issue: issue,
                                    isPinned: vm.isPinned(issue.id),
                                    onPinToggle: {
                                        vm.togglePin(for: issue.id)
                                    }
                                )
                                .tag(issue)
                                .contextMenu {
                                    Button {
                                        issueToEdit = issue
                                    } label: {
                                        SwiftUI.Label("Edit Issue", systemImage: "pencil")
                                    }
                                }
                            }
                            .listStyle(.sidebar)
                            .onKeyPress(.return) {
                                if let selected = selectedIssue {
                                    issueToEdit = selected
                                    return .handled
                                }
                                return .ignored
                            }
                        }
                    } else {
                        ProgressView("Initializing...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("GitIssues")
            .navigationSplitViewColumnWidth(min: 400, ideal: 600, max: 800)
            .toolbar(content: {
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        showCreateIssue = true
                    } label: {
                        SwiftUI.Label("New Issue", systemImage: "plus")
                    }
                    .disabled(viewModel.viewModel == nil)
                    .help("Create new issue")

                    Button {
                        Task { await viewModel.viewModel?.loadIssues() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.viewModel?.isLoading ?? true)
                    .help("Refresh issues")

                    Button {
                        authManager.signOut()
                    } label: {
                        Text("Sign Out")
                    }
                }
            })
        } detail: {
            // Detail view
            if let selectedIssue = selectedIssue,
               let accessToken = authManager.getAccessToken(),
               let vm = viewModel.viewModel {
                let apiService = GitHubAPIService(accessToken: accessToken)
                let detailViewModel = IssueDetailViewModel(
                    issue: selectedIssue,
                    apiService: apiService,
                    pinningService: vm.pinningService, // Share the same service instance
                    listViewModel: vm // Pass the list view model for updates
                )
                IssueDetailView(viewModel: detailViewModel)
                    .id(selectedIssue.id) // Force view recreation when selection changes
                    .onChange(of: vm.allIssues) { _, newIssues in
                        // Update selected issue to the refreshed version after list changes
                        if let currentId = self.selectedIssue?.id {
                            self.selectedIssue = newIssues.first { $0.id == currentId }
                        }
                    }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select an issue to view details")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            // Initialize viewModel with actual token
            if viewModel.viewModel == nil, let accessToken = authManager.getAccessToken() {
                let newViewModel = IssuesListViewModel(accessToken: accessToken)
                viewModel.viewModel = newViewModel
                await newViewModel.loadIssues()
            }
        }
        .sheet(isPresented: $showCreateIssue) {
            if let accessToken = authManager.getAccessToken(),
               let vm = viewModel.viewModel {
                let apiService = GitHubAPIService(accessToken: accessToken)
                let formViewModel = IssueFormViewModel(
                    apiService: apiService,
                    mode: .create(availableRepositories: vm.availableRepositories)
                )
                IssueFormSheet(viewModel: formViewModel) { createdIssue in
                    // Refresh the issues list
                    Task {
                        await vm.loadIssues()
                    }
                }
            }
        }
        .sheet(item: $issueToEdit) { issue in
            if let accessToken = authManager.getAccessToken(),
               let vm = viewModel.viewModel {
                let apiService = GitHubAPIService(accessToken: accessToken)
                let formViewModel = IssueFormViewModel(
                    apiService: apiService,
                    mode: .edit(issue: issue)
                )
                IssueFormSheet(viewModel: formViewModel) { updatedIssue in
                    // Refresh the issues list to reflect changes
                    Task {
                        await vm.loadIssues()
                        // Update the selected issue to the refreshed version from the list
                        if let currentSelectedId = selectedIssue?.id {
                            selectedIssue = vm.allIssues.first { $0.id == currentSelectedId }
                        }
                    }
                    // Clear the edit state
                    issueToEdit = nil
                }
            } else {
                // Fallback empty view if requirements aren't met
                EmptyView()
            }
        }
    }
}

struct IssueRow: View {
    let issue: Issue
    let isPinned: Bool
    let onPinToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Pin button
            Button(action: onPinToggle) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .foregroundColor(isPinned ? .accentColor : .secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help(isPinned ? "Unpin issue" : "Pin issue")

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

// Wrapper to allow StateObject with late initialization
@MainActor
class IssuesListViewModelWrapper: ObservableObject {
    var viewModel: IssuesListViewModel? {
        didSet {
            if let viewModel = viewModel {
                // Forward changes from the nested ViewModel
                viewModel.objectWillChange.sink { [weak self] _ in
                    self?.objectWillChange.send()
                }.store(in: &cancellables)
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()
}

#Preview {
    ContentView()
        .environmentObject(OAuth2Manager())
}
