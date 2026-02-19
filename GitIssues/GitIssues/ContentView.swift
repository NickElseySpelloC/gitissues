//
//  ContentView.swift
//  GitIssues
//
//  Created by Nick Elsey on 21/1/2026.
//

import SwiftUI
import Combine
import AppKit

struct ContentView: View {
    @EnvironmentObject var authManager: OAuth2Manager
    @Environment(\.openWindow) private var openWindow
    @StateObject private var viewModel: IssuesListViewModelWrapper
    @StateObject private var coordinator = WindowCoordinator.shared
    @State private var searchText = ""
    @State private var selectedIssue: Issue?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var issueToDelete: Issue?
    @State private var showDeleteConfirmation = false
    @State private var sidebarWidth: CGFloat?
    @State private var cancellables = Set<AnyCancellable>()

    private let appStateService = AppStateService()

    init() {
        _viewModel = StateObject(wrappedValue: IssuesListViewModelWrapper())

        // Restore sidebar width
        let service = AppStateService()
        if let savedWidth = service.getSidebarWidth() {
            _sidebarWidth = State(initialValue: CGFloat(savedWidth))
        }
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
                                        if let accessToken = authManager.getAccessToken() {
                                            let issueData = IssueFormWindowData.IssueData(
                                                issueId: issue.id,
                                                title: issue.title,
                                                body: issue.body,
                                                state: issue.state.rawValue,
                                                repositoryId: issue.repository.id,
                                                repositoryOwner: issue.repository.owner.login,
                                                repositoryName: issue.repository.name,
                                                labelIds: issue.labels.map { $0.id }
                                            )
                                            let windowData = IssueFormWindowData(
                                                mode: .edit,
                                                accessToken: accessToken,
                                                issueData: issueData
                                            )
                                            openWindow(id: WindowIdentifier.issueForm.rawValue, value: windowData)
                                        }
                                    } label: {
                                        SwiftUI.Label("Edit Issue", systemImage: "pencil")
                                    }

                                    Button {
                                        Task {
                                            if let accessToken = authManager.getAccessToken() {
                                                let apiService = GitHubAPIService(accessToken: accessToken)
                                                do {
                                                    _ = try await apiService.createIssue(
                                                        repositoryId: issue.repository.id,
                                                        title: issue.title + " copy",
                                                        body: issue.body,
                                                        labelIds: issue.labels.map { $0.id }
                                                    )
                                                    await viewModel.viewModel?.loadIssues(afterDelay: 1.5)
                                                } catch {
                                                    // Could show error alert here
                                                }
                                            }
                                        }
                                    } label: {
                                        SwiftUI.Label("Clone Issue", systemImage: "doc.on.doc")
                                    }

                                    Divider()

                                    // Close/Reopen issue based on current state
                                    if issue.state == .open {
                                        Button {
                                            Task {
                                                if let accessToken = authManager.getAccessToken() {
                                                    let apiService = GitHubAPIService(accessToken: accessToken)
                                                    do {
                                                        _ = try await apiService.updateIssue(
                                                            issueId: issue.id,
                                                            title: nil,
                                                            body: nil,
                                                            state: .closed
                                                        )
                                                        await viewModel.viewModel?.loadIssues(afterDelay: 1.5)
                                                    } catch {
                                                        print("Error closing issue: \(error)")
                                                    }
                                                }
                                            }
                                        } label: {
                                            SwiftUI.Label("Close Issue", systemImage: "checkmark.circle")
                                        }
                                    } else {
                                        Button {
                                            Task {
                                                if let accessToken = authManager.getAccessToken() {
                                                    let apiService = GitHubAPIService(accessToken: accessToken)
                                                    do {
                                                        _ = try await apiService.updateIssue(
                                                            issueId: issue.id,
                                                            title: nil,
                                                            body: nil,
                                                            state: .open
                                                        )
                                                        await viewModel.viewModel?.loadIssues(afterDelay: 1.5)
                                                    } catch {
                                                        print("Error reopening issue: \(error)")
                                                    }
                                                }
                                            }
                                        } label: {
                                            SwiftUI.Label("Reopen Issue", systemImage: "arrow.counterclockwise.circle")
                                        }
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        issueToDelete = issue
                                        showDeleteConfirmation = true
                                    } label: {
                                        SwiftUI.Label("Delete Issue", systemImage: "trash")
                                    }
                                }
                            }
                            .listStyle(.sidebar)
                            .onKeyPress(.return) {
                                if let selected = selectedIssue,
                                   let accessToken = authManager.getAccessToken() {
                                    let issueData = IssueFormWindowData.IssueData(
                                        issueId: selected.id,
                                        title: selected.title,
                                        body: selected.body,
                                        state: selected.state.rawValue,
                                        repositoryId: selected.repository.id,
                                        repositoryOwner: selected.repository.owner.login,
                                        repositoryName: selected.repository.name,
                                        labelIds: selected.labels.map { $0.id }
                                    )
                                    let windowData = IssueFormWindowData(
                                        mode: .edit,
                                        accessToken: accessToken,
                                        issueData: issueData
                                    )
                                    openWindow(id: WindowIdentifier.issueForm.rawValue, value: windowData)
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
            .navigationSplitViewColumnWidth(
                min: 400,
                ideal: sidebarWidth ?? 600,
                max: 800
            )
            .toolbar(content: {
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        if let accessToken = authManager.getAccessToken() {
                            let windowData = IssueFormWindowData(mode: .create, accessToken: accessToken)
                            openWindow(id: WindowIdentifier.issueForm.rawValue, value: windowData)
                        }
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
                IssueDetailHost(issue: selectedIssue, accessToken: accessToken, listViewModel: vm)
                    .id("\(selectedIssue.id)-\(selectedIssue.updatedAt.timeIntervalSince1970)") // Force view recreation when issue changes
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

            // Subscribe to coordinator events
            coordinator.issueFormSuccess
                .sink { (windowId, issue) in
                    Task {
                        await viewModel.viewModel?.loadIssues(afterDelay: 1.5)
                        // Update selected issue if needed
                        if let currentSelectedId = selectedIssue?.id {
                            selectedIssue = viewModel.viewModel?.allIssues.first { $0.id == currentSelectedId }
                        }
                    }
                }
                .store(in: &cancellables)
        }
        .background(WindowAccessor { window in
            // Use macOS native window frame autosave
            window.setFrameAutosaveName("MainWindow")
        })
        .onReceive(NotificationCenter.default.publisher(for: NSSplitView.didResizeSubviewsNotification)) { notification in
            // Save sidebar width when split view is resized
            if let splitView = notification.object as? NSSplitView,
               splitView.subviews.count > 0 {
                let width = splitView.subviews[0].frame.width
                sidebarWidth = width
                appStateService.saveSidebarWidth(Double(width))
            }
        }
        .alert("Delete Issue", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                issueToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let issue = issueToDelete, let accessToken = authManager.getAccessToken() {
                    Task {
                        let apiService = GitHubAPIService(accessToken: accessToken)
                        do {
                            try await apiService.deleteIssue(issueId: issue.id)
                            // Refresh issues list with delay to allow GitHub to process
                            await viewModel.viewModel?.loadIssues(afterDelay: 1.5)
                            // Clear selection if we deleted the selected issue
                            if selectedIssue?.id == issue.id {
                                selectedIssue = nil
                            }
                        } catch {
                            print("Error deleting issue: \(error)")
                        }
                        issueToDelete = nil
                    }
                }
            }
        } message: {
            if let issue = issueToDelete {
                Text("Are you sure you want to delete \"\(issue.title)\"? This action cannot be undone.")
            }
        }
    }
}

struct IssueDetailHost: View {
    let issue: Issue
    let accessToken: String
    let listViewModel: IssuesListViewModel

    @StateObject private var viewModel: IssueDetailViewModel

    init(issue: Issue, accessToken: String, listViewModel: IssuesListViewModel) {
        self.issue = issue
        self.accessToken = accessToken
        self.listViewModel = listViewModel
        let apiService = GitHubAPIService(accessToken: accessToken)
        _viewModel = StateObject(wrappedValue: IssueDetailViewModel(
            issue: issue,
            apiService: apiService,
            pinningService: listViewModel.pinningService,
            listViewModel: listViewModel
        ))
    }

    var body: some View {
        IssueDetailView(viewModel: viewModel)
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
