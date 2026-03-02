//
//  IssuesListViewModel.swift
//  GitIssues
//
//  Created by Claude Code
//

import Foundation
import Combine

@MainActor
class IssuesListViewModel: ObservableObject {
    @Published var allIssues: [Issue] = []
    @Published var filteredIssues: [Issue] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var filterOptions = FilterOptions()
    @Published var pinnedIssueIDs: Set<String> = []
    @Published var viewerLogin: String?

    private let apiService: GitHubAPIService
    let pinningService: PinningService // Made public so detail view can access it
    private let appStateService = AppStateService()
    private var cancellables = Set<AnyCancellable>()

    init(accessToken: String) {
        self.apiService = GitHubAPIService(accessToken: accessToken)
        self.pinningService = PinningService()
        self.pinnedIssueIDs = pinningService.getPinnedIssues()

        // Restore saved filter state
        if let savedFilterOptions = appStateService.loadFilterState() {
            self.filterOptions = savedFilterOptions
        }

        // Observe filter changes and refilter
        Publishers.CombineLatest4($filterOptions, $allIssues, $pinnedIssueIDs, $viewerLogin)
            .map { filterOptions, allIssues, pinnedIDs, viewerLogin in
                Self.applyFiltersAndSort(filterOptions: filterOptions, to: allIssues, pinnedIDs: pinnedIDs, viewerLogin: viewerLogin)
            }
            .assign(to: &$filteredIssues)

        // Save filter state whenever it changes
        $filterOptions
            .dropFirst() // Skip initial value
            .sink { [weak self] newFilterOptions in
                self?.appStateService.saveFilterState(newFilterOptions)
            }
            .store(in: &cancellables)
    }

    /// Loads all issues from the API. Shows a full-screen spinner on first load;
    /// on subsequent loads keeps existing data visible while refreshing in the background.
    func loadIssues(afterDelay delay: TimeInterval = 0) async {
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        // First load: show full-screen spinner. Subsequent loads: keep list visible.
        if allIssues.isEmpty {
            isLoading = true
        } else {
            isRefreshing = true
        }
        errorMessage = nil

        do {
            // Fetch viewer login if not already fetched
            if viewerLogin == nil {
                viewerLogin = try await apiService.fetchViewerLogin()
            }

            // Fetch all issues regardless of state/visibility — filtering is done client-side
            let issues = try await apiService.fetchAllIssues()
            self.allIssues = issues
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
        isRefreshing = false
    }

    // MARK: - Cache Mutations

    /// Inserts or updates an issue in the local cache without a full reload.
    /// If the issue already exists it is updated in place; otherwise it is inserted at the front.
    func upsertIssueInCache(_ issue: Issue) {
        if let index = allIssues.firstIndex(where: { $0.id == issue.id }) {
            allIssues[index] = issue
        } else {
            allIssues.insert(issue, at: 0)
        }
    }

    /// Removes an issue from the local cache without a full reload.
    func removeIssueFromCache(id: String) {
        allIssues.removeAll { $0.id == id }
    }

    /// Closes an issue via the API and immediately updates the local cache.
    func closeIssue(_ issue: Issue) async {
        do {
            let updatedIssue = try await apiService.updateIssue(issueId: issue.id, title: nil, body: nil, state: .closed)
            upsertIssueInCache(updatedIssue)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reopens an issue via the API and immediately updates the local cache.
    func reopenIssue(_ issue: Issue) async {
        do {
            let updatedIssue = try await apiService.updateIssue(issueId: issue.id, title: nil, body: nil, state: .open)
            upsertIssueInCache(updatedIssue)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes an issue via the API and immediately removes it from the local cache.
    func deleteIssue(_ issue: Issue) async {
        do {
            try await apiService.deleteIssue(issueId: issue.id)
            removeIssueFromCache(id: issue.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Updates assignees for an issue via the API and immediately updates the local cache.
    func assignIssue(_ issue: Issue, assignees: [User]) async {
        do {
            try await apiService.setIssueAssignees(
                issueId: issue.id,
                currentAssigneeIds: issue.assignees.map { $0.id },
                newAssigneeIds: assignees.map { $0.id }
            )
            let updated = Issue(
                id: issue.id,
                number: issue.number,
                title: issue.title,
                body: issue.body,
                state: issue.state,
                createdAt: issue.createdAt,
                updatedAt: issue.updatedAt,
                repository: issue.repository,
                labels: issue.labels,
                assignees: assignees,
                author: issue.author
            )
            upsertIssueInCache(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Clones an issue via the API and immediately adds the copy to the local cache.
    func cloneIssue(_ issue: Issue) async {
        do {
            let cloned = try await apiService.createIssue(
                repositoryId: issue.repository.id,
                title: issue.title + " copy",
                body: issue.body,
                labelIds: issue.labels.map { $0.id }
            )
            upsertIssueInCache(cloned)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Filters

    /// Applies filters and sorting to issues
    private static func applyFiltersAndSort(filterOptions: FilterOptions, to issues: [Issue], pinnedIDs: Set<String>, viewerLogin: String?) -> [Issue] {
        // Filter issues
        let filtered = issues.filter { filterOptions.matches(issue: $0, viewerLogin: viewerLogin) }

        // Sort issues
        let sorted = filterOptions.sortOption.sort(filtered)

        // Separate pinned and unpinned
        let pinned = sorted.filter { pinnedIDs.contains($0.id) }
        let unpinned = sorted.filter { !pinnedIDs.contains($0.id) }

        // Return pinned first, then unpinned
        return pinned + unpinned
    }

    /// Toggles the pinned state of an issue
    func togglePin(for issueID: String) {
        pinningService.togglePin(issueID)
        pinnedIssueIDs = pinningService.getPinnedIssues()
    }

    /// Checks if an issue is pinned
    func isPinned(_ issueID: String) -> Bool {
        return pinnedIssueIDs.contains(issueID)
    }

    /// Gets all unique repositories from the issues list
    var availableRepositories: [Repository] {
        let repos = allIssues.map { $0.repository }
        let uniqueRepos = Dictionary(grouping: repos, by: { $0.id })
            .compactMap { $0.value.first }
        return uniqueRepos.sorted { $0.fullName < $1.fullName }
    }

    /// Updates the state filter (client-side; no API call needed)
    func setStateFilter(_ filter: IssueStateFilter) {
        filterOptions.stateFilter = filter
    }

    /// Updates the visibility filter (client-side; no API call needed)
    func setVisibilityFilter(_ filter: VisibilityFilter) {
        filterOptions.visibilityFilter = filter
    }

    /// Updates the involvement filter
    func setInvolvementFilter(_ filter: InvolvementFilter) {
        var options = filterOptions
        options.involvementFilter = filter
        filterOptions = options
    }

    /// Updates the sort option
    func setSortOption(_ option: SortOption) {
        var options = filterOptions
        options.sortOption = option
        filterOptions = options
    }

    /// Updates the search text
    func setSearchText(_ text: String) {
        var options = filterOptions
        options.searchText = text
        filterOptions = options
    }

    /// Toggles repository selection
    func toggleRepository(_ repositoryID: String) {
        var options = filterOptions
        if options.selectedRepositories.contains(repositoryID) {
            options.selectedRepositories.remove(repositoryID)
        } else {
            options.selectedRepositories.insert(repositoryID)
        }
        filterOptions = options
    }

    /// Clears all repository filters
    func clearRepositoryFilter() {
        var options = filterOptions
        options.selectedRepositories.removeAll()
        filterOptions = options
    }
}
